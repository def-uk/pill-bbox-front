# 웹 탐지가 사파리에서 멈추는 문제와 첫 탐지가 느린 문제 고치기

## 목적

배포한 웹(`www.havepills.party`)에서 샘플 사진을 고르면 "알약을 찾는 중"이 끝나지 않습니다. 첫 탐지도 오래 걸립니다.

직접 재 본 결과 (Playwright, 같은 빌드, 샘플 사진 `1.jpg`):

| 브라우저 | 서버 | 스레드 | 모델 읽기 | 추론 |
| --- | --- | --- | --- | --- |
| Chromium | 배포 서버 (COOP/COEP 켬) | 4 | 1.0초 | 0.36초 |
| WebKit (사파리 엔진) | 배포 서버 (COOP/COEP 켬) | 4 | 1.3초 | **40초 넘게 답이 없음** |
| WebKit | 로컬 `http.server` (격리 없음) | 1 | 0.2초 | 1.2초 |

- 원인: 사파리(WebKit)에서 onnxruntime-web을 wasm 스레드 여러 개로 돌리면 추론(`session.run`)이 돌아오지 않습니다. 모델 읽기와 사진 디코드는 됩니다. 배포 서버만 COOP/COEP를 켜서 스레드를 여러 개 쓰므로, `flutter run`이나 로컬 서버에서는 안 보이고 배포한 사이트의 사파리·아이폰(아이폰은 크롬도 WebKit)에서만 보입니다.
  - onnxruntime 파일을 같은 출처에서 내보내도 스레드 Worker가 `Out of bounds memory access`로 죽고, 최신 1.29.0에서도 똑같이 멈춥니다. 버전이나 배포 위치로는 풀리지 않습니다.
  - Worker가 답을 안 하면 `pill_detector.js`의 Promise가 끝나지 않아, 화면이 "모델 실패" 안내로도 넘어가지 못합니다.
- 첫 탐지가 느린 이유: 모델(20.5MB)과 onnxruntime wasm(2.5MB)을 샘플 사진을 누른 뒤에야 받습니다. 4G(약 9Mbps)면 받는 데만 20초쯤 걸립니다. 앱 첫 화면(main.dart.js 1.3MB, CanvasKit 1.6MB)은 같은 조건에서 5초쯤으로, 이번 범위의 주된 원인은 아닙니다.

## 범위

- 프론트만 바뀝니다 (`web/pill_detector.js`, `web/pill_detector_worker.js`, `lib/main.dart`). 백엔드(COOP/COEP 헤더)는 그대로입니다. 크롬·안드로이드는 지금처럼 스레드 여러 개로 돕니다.
- 하지 않는 것: 모델 크기 줄이기, 모델 gzip 전송, onnxruntime 버전 올리기·직접 내보내기, 앱 첫 화면(Flutter 엔진) 로딩 줄이기, 결과 화면에 받는 진행률 보여 주기.

## 설계

### Worker (`web/pill_detector_worker.js`)

- `load(modelUrl, { singleThread })`: `singleThread`이거나 WebKit이면 세션을 만들기 전에 `ort.env.wasm.numThreads = 1`로 둡니다.
  - WebKit 판별: `navigator.userAgent`에 `AppleWebKit`이 있고 `Chrome|Chromium|Edg|OPR`이 없으면 WebKit으로 봅니다. 아이폰 크롬(`CriOS`)·파이어폭스(`FxiOS`)도 WebKit이라 여기에 들어갑니다.
- `warmUp()` 추가: 회색 640×640 한 장으로 추론을 한 번 돌립니다. 스레드가 제대로 도는지 미리 확인하고, 첫 실제 추론도 빨라집니다.
- 돌려주는 값에 지금처럼 `threads`, `isolated`를 넣습니다.

### 창구 (`web/pill_detector.js`)

- Worker를 페이지를 열 때가 아니라 처음 부를 때 띄웁니다. 앱 첫 화면을 받는 동안 onnxruntime을 같이 받지 않게 합니다.
- 스레드가 여러 개일 때 `warmUp`·`detect`가 20초 안에 답이 없거나 오류가 나면, Worker를 끝내고 스레드 1개로 새 Worker를 띄워 모델을 다시 읽고(모델은 브라우저 캐시에 있음) 한 번 더 합니다. 그 뒤로는 계속 1개로 돕니다. 1개로도 실패하면 오류를 그대로 돌려줘 결과 화면이 "모델 실패" 안내로 넘어갑니다.
- `load`(모델 받기)에는 시간 제한을 두지 않습니다. 느린 망에서는 받는 데 오래 걸릴 수 있습니다.
- `window.pillbbox`의 `load`, `detect`, `pixels` 모양은 그대로입니다. `load`가 끝나면 `warmUp`까지 끝난 상태입니다.

### 앱 (`lib/main.dart`)

- 웹(`kIsWeb`)에서 실제 모델을 쓸 때, 첫 화면이 그려진 뒤 `detector.load()`를 불러 모델을 미리 받아 둡니다. 실패해도 무시합니다(`OnnxPillDetector.load`가 실패하면 다음에 다시 읽음). 사용자가 샘플 사진을 누를 때쯤엔 모델이 준비돼 있게 합니다.
- 앱은 Android·iOS에서는 모델이 앱 안에 있어 미리 읽지 않습니다.
- View, ViewModel, Repository, 라우트는 바뀌지 않습니다.

### 문서

- `docs/DESIGN.md` 3장 표의 웹 줄에 "사파리(WebKit)는 스레드 여러 개로 돌리면 추론이 멈춰 1개로 돈다", "앱을 열면 모델을 미리 받는다"를 더합니다.

## 작업 순서

1. `web/pill_detector_worker.js`: `singleThread`·WebKit이면 1스레드, `warmUp` 추가
2. `web/pill_detector.js`: Worker 늦게 띄우기, 20초 감시와 1스레드로 다시 하기, `load` 뒤 `warmUp`
3. `lib/main.dart`: 웹에서 첫 화면 뒤 모델 미리 읽기
4. `docs/DESIGN.md` 수정

## 검증

- `fvm flutter analyze`, `fvm flutter test` (JS는 Flutter 테스트가 닿지 않아 아래로 직접 확인)
- 직접 확인 (Playwright로 `flutter build web --release` 결과를 띄워 잼)
  - COOP/COEP를 켠 로컬 서버 + WebKit: `load`·`detect`가 끝나고 `threads: 1`, 박스 4개
  - COOP/COEP를 켠 로컬 서버 + Chromium: `threads: 4` 그대로, 추론 시간이 지금과 같음
  - 격리 없는 로컬 서버 + Chromium·WebKit: 지금처럼 1스레드로 됨
  - 앱 흐름: 첫 화면이 뜬 뒤 모델 요청이 나가고, 기록하기 → 샘플 사진에서 결과 화면이 뜸
  - 스레드 실패 대비: Chromium에서 Worker 추론을 일부러 멈추게 해 20초 뒤 1스레드로 다시 해서 결과가 나오는지
- 배포 뒤 아이폰 사파리에서 샘플 사진으로 확인
