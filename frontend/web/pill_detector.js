// 탐지 모델은 web/pill_detector_worker.js(Web Worker)에서 돈다. 이 파일은 그 Worker를 띄우고 부르는 창구다.
// lib/data/services/onnx_pill_detector.dart와 lib/data/services/platform_services_web.dart가 부른다.
(() => {
  // 스레드를 여러 개 쓸 때 추론이 이 시간 안에 답이 없으면 멈춘 것으로 본다. 휴대폰에서도 몇 초면 끝난다.
  // 사파리처럼 여러 스레드로는 추론이 돌아오지 않는 브라우저가 있어, 그때는 스레드 1개로 다시 한다.
  const threadedTimeoutMs = 20000;

  let current; // { worker, calls }. 처음 부를 때 띄운다. 앱 첫 화면을 받는 동안 onnxruntime을 같이 받지 않는다.
  let nextId = 0;
  let modelUrl;
  let singleThread = false;
  let loading; // 모델을 읽고 warmUp까지 하는 Promise. 결과는 { threads, isolated }.

  function spawn() {
    const worker = new Worker(new URL('pill_detector_worker.js', document.baseURI));
    const calls = new Map();
    worker.onmessage = ({ data: { id, result, error } }) => {
      const call = calls.get(id);
      if (!call) return;
      calls.delete(id);
      if (error === undefined) call.resolve(result);
      else call.reject(new Error(error));
    };
    worker.onerror = (event) => rejectAll(calls, new Error(`탐지 Worker 오류: ${event.message}`));
    return { worker, calls };
  }

  function rejectAll(calls, error) {
    for (const call of calls.values()) call.reject(error);
    calls.clear();
  }

  /// Worker의 [method]를 부른다. [timeoutMs]가 있으면 그 안에 답이 없을 때 실패로 끝낸다.
  function call(method, args, transfer = [], timeoutMs) {
    const { worker, calls } = (current ??= spawn());
    return new Promise((resolve, reject) => {
      const id = nextId++;
      let timer;
      const settled = (settle) => (value) => {
        clearTimeout(timer);
        settle(value);
      };
      calls.set(id, { resolve: settled(resolve), reject: settled(reject) });
      if (timeoutMs !== undefined) {
        timer = setTimeout(() => {
          calls.delete(id);
          reject(new Error(`${method}가 ${timeoutMs / 1000}초 안에 끝나지 않았습니다`));
        }, timeoutMs);
      }
      worker.postMessage({ id, method, args }, transfer);
    });
  }

  /// 모델을 읽고 추론을 한 번 해 본다. 여러 스레드로 실패하면 1개로 다시 한다.
  async function prepare() {
    const info = await call('load', [modelUrl, { singleThread }]);
    if (info.threads === 1) {
      await call('warmUp', []);
      return info;
    }
    try {
      await call('warmUp', [], [], threadedTimeoutMs);
      return info;
    } catch (e) {
      return fallBack(e);
    }
  }

  /// 지금 Worker를 끝내고 스레드 1개로 새로 띄워 모델을 다시 읽는다. 모델은 브라우저 캐시에서 온다.
  function fallBack(error) {
    if (singleThread) return loading;
    console.warn(`탐지를 스레드 여러 개로 하지 못해 1개로 다시 합니다: ${error.message}`);
    singleThread = true;
    if (current) {
      current.worker.terminate();
      rejectAll(current.calls, new Error('탐지 Worker를 다시 띄웠습니다'));
      current = undefined;
    }
    return track(prepare());
  }

  /// [attempt]를 지금 읽기로 둔다. 실패하면(네트워크 등) 다음에 부를 때 처음부터 다시 읽는다.
  function track(attempt) {
    loading = attempt;
    attempt.catch(() => {
      if (loading === attempt) loading = undefined;
    });
    return attempt;
  }

  function load(url) {
    if (!loading || url !== modelUrl) {
      modelUrl = url;
      track(prepare());
    }
    return loading;
  }

  async function detect(bytes, minConfidence) {
    if (!loading) throw new Error('모델을 먼저 읽어야 합니다');
    const info = await loading;
    // Dart가 넘긴 바이트는 Dart 쪽에서도 계속 쓰므로 복사본을 Worker로 옮긴다.
    const run = (timeoutMs) => {
      const data = bytes.slice();
      return call('detect', [data, minConfidence], [data.buffer], timeoutMs);
    };
    if (info.threads === 1) return run();
    try {
      return await run(threadedTimeoutMs);
    } catch (e) {
      await fallBack(e);
      return run();
    }
  }

  function pixels(bytes, side) {
    const data = bytes.slice();
    return call('pixels', [data, side], [data.buffer]);
  }

  window.pillbbox = {
    // 상대 주소는 Worker 기준이 아니라 문서 기준으로 풀어 넘긴다. 끝나면 warmUp까지 한 상태다.
    load: (url) => load(new URL(url, document.baseURI).href),
    detect,
    pixels,
  };
})();
