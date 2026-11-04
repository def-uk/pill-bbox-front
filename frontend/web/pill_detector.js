// 탐지 모델은 web/pill_detector_worker.js(Web Worker)에서 돈다. 이 파일은 그 Worker를 띄우고 부르는 창구다.
// lib/data/services/onnx_pill_detector.dart와 lib/data/services/platform_services_web.dart가 부른다.
(() => {
  const worker = new Worker(new URL('pill_detector_worker.js', document.baseURI));
  const pending = new Map();
  let nextId = 0;

  worker.onmessage = ({ data: { id, result, error } }) => {
    const call = pending.get(id);
    pending.delete(id);
    if (error === undefined) call.resolve(result);
    else call.reject(new Error(error));
  };
  worker.onerror = (event) => {
    const error = new Error(`탐지 Worker 오류: ${event.message}`);
    for (const call of pending.values()) call.reject(error);
    pending.clear();
  };

  function call(method, args, transfer = []) {
    return new Promise((resolve, reject) => {
      const id = nextId++;
      pending.set(id, { resolve, reject });
      worker.postMessage({ id, method, args }, transfer);
    });
  }

  // Dart가 넘긴 바이트는 Dart 쪽에서도 계속 쓰므로 복사본을 Worker로 옮긴다.
  const copy = (bytes) => bytes.slice();

  window.pillbbox = {
    // 상대 주소는 Worker 기준이 아니라 문서 기준으로 풀어 넘긴다.
    load: (modelUrl) => call('load', [new URL(modelUrl, document.baseURI).href]),
    detect: (bytes, minConfidence) => {
      const data = copy(bytes);
      return call('detect', [data, minConfidence], [data.buffer]);
    },
    pixels: (bytes, side) => {
      const data = copy(bytes);
      return call('pixels', [data, side], [data.buffer]);
    },
  };
})();
