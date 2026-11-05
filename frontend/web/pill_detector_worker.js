// 탐지 모델(ONNX)을 Web Worker에서 돌린다. web/pill_detector.js가 띄우고 메시지로 부른다.
// 메인 스레드에서 돌리면 추론하는 동안 화면이 멈춘다.
//
// 모델 출력은 두 형식을 받는다.
//   [1, N, 6]      모델 안에서 NMS까지 한 결과 (YOLO26 end2end): x1, y1, x2, y2, 점수, 클래스
//   [1, 4 + C, A]  NMS 전 결과 (YOLO11 등): cx, cy, w, h, 클래스 C개의 점수
const ortDist = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.20.1/dist/';
importScripts(`${ortDist}ort.min.js`);

// Worker 안에서는 ort가 wasm 위치를 스스로 찾지 못한다(우리 출처에서 찾는다).
ort.env.wasm.wasmPaths = ortDist;
// 교차 출처 격리(COOP/COEP, backend/app/web.py)가 켜져 있으면 ort가 코어 수에 맞춰 스레드를 여러 개 쓰고,
// 꺼져 있으면(flutter run 등) 1개로 돈다. 사파리(WebKit)는 스레드를 여러 개 쓰면 추론이 돌아오지 않아 1개로 둔다.
// 아이폰의 크롬(CriOS)·파이어폭스(FxiOS)도 WebKit이다.
const isWebKit = /AppleWebKit/.test(navigator.userAgent) && !/Chrome|Chromium|Edg|OPR/.test(navigator.userAgent);

// scripts/fetch_model.sh가 imgsz=640으로 내보낸다.
const inputSize = 640;
const iouThreshold = 0.45;
let session;

const handlers = { load, warmUp, detect, pixels };

self.onmessage = async ({ data: { id, method, args } }) => {
  try {
    const { result, transfer } = await handlers[method](...args);
    self.postMessage({ id, result }, transfer ?? []);
  } catch (e) {
    self.postMessage({ id, error: String(e?.message ?? e) });
  }
};

/// [singleThread]면 스레드 1개로 돈다. web/pill_detector.js가 여러 스레드로 실패한 뒤 새 Worker에 넘긴다.
async function load(modelUrl, { singleThread = false } = {}) {
  if (!session) {
    // 첫 세션을 만들기 전에 정해야 한다.
    if (singleThread || isWebKit) ort.env.wasm.numThreads = 1;
    session = await ort.InferenceSession.create(modelUrl, {
      executionProviders: ['wasm'],
      // 가중치 int8 모델의 DequantizeLinear를 불러올 때 한 번 풀어 둔다. 그대로 두면 추론마다 다시 푼다.
      // 결과는 같고, 네이티브 1스레드에서 122ms가 95ms가 됐다.
      extra: { session: { disable_quant_qdq: '1' } },
    });
  }
  return { result: { threads: ort.env.wasm.numThreads, isolated: self.crossOriginIsolated } };
}

/// 회색 사진 한 장으로 추론을 한 번 돌린다. 스레드가 제대로 도는지 미리 보고, 첫 실제 추론도 빨라진다.
async function warmUp() {
  if (!session) throw new Error('모델을 먼저 읽어야 합니다');
  const input = new Float32Array(3 * inputSize * inputSize).fill(114 / 255);
  await session.run({
    [session.inputNames[0]]: new ort.Tensor('float32', input, [1, 3, inputSize, inputSize]),
  });
  return { result: null };
}

/// 사진을 긴 변 [side]px 이하로 줄인 RGBA 픽셀. lib/utils/object_finder.dart가 쓴다.
/// Dart(JS로 컴파일)로 원본 사진을 디코드하면 몇 초씩 걸려 브라우저가 대신 한다.
async function pixels(bytes, side) {
  const bitmap = await createImageBitmap(new Blob([bytes]));
  const { width, height } = bitmap;
  const scale = Math.min(1, side / Math.max(width, height));
  const w = Math.max(1, Math.round(width * scale));
  const h = Math.max(1, Math.round(height * scale));
  const context = new OffscreenCanvas(w, h).getContext('2d', { willReadFrequently: true });
  context.imageSmoothingQuality = 'high';
  context.drawImage(bitmap, 0, 0, w, h);
  bitmap.close();
  const data = new Uint8Array(context.getImageData(0, 0, w, h).data.buffer);
  return {
    result: { width: w, height: h, sourceWidth: width, sourceHeight: height, data },
    transfer: [data.buffer],
  };
}

async function detect(bytes, minConfidence) {
  if (!session) throw new Error('모델을 먼저 읽어야 합니다');
  // 640×640에 비율을 지켜 넣고 남는 곳은 회색으로 채운다 (Ultralytics letterbox).
  const bitmap = await createImageBitmap(new Blob([bytes]));
  const { width, height } = bitmap;
  const scale = Math.min(inputSize / width, inputSize / height);
  const padX = (inputSize - width * scale) / 2;
  const padY = (inputSize - height * scale) / 2;
  const context = new OffscreenCanvas(inputSize, inputSize).getContext('2d', { willReadFrequently: true });
  context.fillStyle = 'rgb(114, 114, 114)';
  context.fillRect(0, 0, inputSize, inputSize);
  context.drawImage(bitmap, padX, padY, width * scale, height * scale);
  bitmap.close();

  const pixels = context.getImageData(0, 0, inputSize, inputSize).data;
  const area = inputSize * inputSize;
  const input = new Float32Array(3 * area);
  for (let i = 0; i < area; i++) {
    input[i] = pixels[i * 4] / 255;
    input[area + i] = pixels[i * 4 + 1] / 255;
    input[2 * area + i] = pixels[i * 4 + 2] / 255;
  }
  const outputs = await session.run({
    [session.inputNames[0]]: new ort.Tensor('float32', input, [1, 3, inputSize, inputSize]),
  });
  const output = outputs[session.outputNames[0]];
  const [, rows, cols] = output.dims;
  const boxes = cols === 6
    ? endToEnd(output.data, rows, minConfidence)
    : nms(decode(output.data, rows, cols, minConfidence));

  // 모델 입력 좌표를 원본 이미지 좌표로 되돌린다.
  const toX = (x) => Math.min(Math.max((x - padX) / scale, 0), width);
  const toY = (y) => Math.min(Math.max((y - padY) / scale, 0), height);
  return {
    result: boxes.map((b) => ({
      x1: toX(b.x1),
      y1: toY(b.y1),
      x2: toX(b.x2),
      y2: toY(b.y2),
      confidence: b.confidence,
      classIndex: b.classIndex,
    })),
  };
}

function endToEnd(data, rows, minConfidence) {
  const boxes = [];
  for (let i = 0; i < rows; i++) {
    const o = i * 6;
    if (data[o + 4] < minConfidence) continue;
    boxes.push({
      x1: data[o],
      y1: data[o + 1],
      x2: data[o + 2],
      y2: data[o + 3],
      confidence: data[o + 4],
      classIndex: Math.round(data[o + 5]),
    });
  }
  return boxes;
}

function decode(data, channels, anchors, minConfidence) {
  const boxes = [];
  for (let a = 0; a < anchors; a++) {
    let confidence = 0;
    let classIndex = 0;
    for (let c = 4; c < channels; c++) {
      const score = data[c * anchors + a];
      if (score > confidence) {
        confidence = score;
        classIndex = c - 4;
      }
    }
    if (confidence < minConfidence) continue;
    const cx = data[a];
    const cy = data[anchors + a];
    const w = data[2 * anchors + a];
    const h = data[3 * anchors + a];
    boxes.push({
      x1: cx - w / 2,
      y1: cy - h / 2,
      x2: cx + w / 2,
      y2: cy + h / 2,
      confidence,
      classIndex,
    });
  }
  return boxes;
}

// 같은 클래스에서 많이 겹치는 박스는 점수가 가장 높은 것만 남긴다.
function nms(boxes) {
  boxes.sort((a, b) => b.confidence - a.confidence);
  const kept = [];
  for (const box of boxes) {
    if (kept.every((k) => k.classIndex !== box.classIndex || iou(k, box) <= iouThreshold)) {
      kept.push(box);
    }
  }
  return kept;
}

function iou(a, b) {
  const w = Math.max(0, Math.min(a.x2, b.x2) - Math.max(a.x1, b.x1));
  const h = Math.max(0, Math.min(a.y2, b.y2) - Math.max(a.y1, b.y1));
  const intersection = w * h;
  const area = (box) => (box.x2 - box.x1) * (box.y2 - box.y1);
  return intersection / (area(a) + area(b) - intersection);
}
