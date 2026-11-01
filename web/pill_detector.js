// 브라우저에서 탐지 모델(ONNX)을 돌린다. lib/data/services/onnx_pill_detector.dart가 부른다.
//
// 모델 출력은 두 형식을 받는다.
//   [1, N, 6]      모델 안에서 NMS까지 한 결과 (YOLO26 end2end): x1, y1, x2, y2, 점수, 클래스
//   [1, 4 + C, A]  NMS 전 결과 (YOLO11 등): cx, cy, w, h, 클래스 C개의 점수
(() => {
  // scripts/fetch_model.sh가 imgsz=640으로 내보낸다.
  const inputSize = 640;
  const iouThreshold = 0.45;
  let session;

  async function load(modelUrl) {
    if (session) return;
    // GitHub Pages는 교차 출처 격리(COOP/COEP)를 켤 수 없어 wasm 스레드를 쓰지 못한다.
    ort.env.wasm.numThreads = 1;
    session = await ort.InferenceSession.create(modelUrl, {
      executionProviders: ['wasm'],
    });
  }

  async function detect(bytes, minConfidence) {
    // 640×640에 비율을 지켜 넣고 남는 곳은 회색으로 채운다 (Ultralytics letterbox).
    const bitmap = await createImageBitmap(new Blob([bytes]));
    const { width, height } = bitmap;
    const scale = Math.min(inputSize / width, inputSize / height);
    const padX = (inputSize - width * scale) / 2;
    const padY = (inputSize - height * scale) / 2;
    const canvas = new OffscreenCanvas(inputSize, inputSize);
    const context = canvas.getContext('2d');
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
    return boxes.map((b) => ({
      x1: toX(b.x1),
      y1: toY(b.y1),
      x2: toX(b.x2),
      y2: toY(b.y2),
      confidence: b.confidence,
      classIndex: b.classIndex,
    }));
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

  window.pillbbox = { load, detect };
})();
