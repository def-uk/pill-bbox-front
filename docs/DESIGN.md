# pillbbox 앱 설계

[pill-bbox](https://github.com/def-uk/pill-bbox)에서 학습한 알약 탐지 모델을 Flutter 앱에 넣어, 사진 한 장으로 복용 기록을 남기는 앱의 설계 문서입니다.

## 1. 목적

여러 종류의 약을 복용하는 사용자는 약마다 정해진 복용 시간과 수량을 관리해야 합니다. 알약 객체 탐지 모델과 앱을 연결해 복용 기록을 남기는 부담을 줄이고, 사용자가 자신의 복용 내역을 쉽게 확인할 수 있게 합니다.

- 기록 부담 줄이기: 먹을 약을 손바닥이나 책상에 놓고 한 장 찍으면 약 종류와 개수가 기록됩니다.
- 내역 확인: 오늘 먹을 약과 먹은 약, 지난 기록을 한 화면에서 봅니다.

## 2. 범위

**간단하게 만드는 것**이 원칙입니다. 서버, 로그인, 동기화 없이 기기 하나에서 끝나는 앱을 만듭니다.

| 구분 | 기능 |
|---|---|
| MVP | 복용 일정 등록(약, 시간, 1회 수량). 선택 사항이며, 정해 두면 예정과 비교해 줌 |
| MVP | 사진 찍기·사진 올리기 → 탐지 결과 확인·수정 → 복용 기록 저장. 약을 미리 등록하지 않아도 되고, 처음 기록하는 약은 저장할 때 등록됨 |
| MVP | 오늘 복용 현황(예정 vs 복용), 날짜별 기록 조회 |
| 2차 | 복용 시간 알림(로컬 알림) |
| 하지 않음 | 회원가입·로그인, 서버 저장·기기 간 동기화, 처방전 OCR |

같은 Flutter 코드로 웹과 앱(Android, iOS)을 만듭니다. 스토어 심사·서명 없이 링크로 바로 열 수 있도록 **웹을 먼저 배포**하고(6장), 앱 배포는 뒤로 미룹니다.

## 3. 모델 연동

### 3.1 모델 현황 (2026-11-02 기준)

| 항목 | 내용 | 앱에 주는 영향 |
|---|---|---|
| 모델 | ultralytics `yolo11m`. 지금 앱에 넣은 것은 `combofix-v1-fold1` (대회 + AI Hub 조합 데이터, fold 1) | 형식마다 약 65~77MB |
| 클래스 | 약 96종(대회 56종 + AI Hub 40종). `aihub_class_map.csv`에 `yolo_idx → category_id → dl_name` | 96종 밖의 약은 인식 못 함 → 사용자가 직접 고르는 화면 필요 |
| 입력 | 640 × 640 (letterbox) | 플러그인이 전처리 |
| 주 지표 | mAP75-95 (박스가 꼭 맞는지) | 앱은 박스 정밀도보다 **약 종류·개수**가 중요 |
| 학습 데이터 | 대회 데이터 232장. 정해진 배경·조명·각도에서 찍은 사진 | 휴대폰 사진에서 성능이 떨어질 수 있음 (3.5) |

### 3.2 추론 위치: 기기 안 (on-device)

| | 기기 안 (선택) | 서버 |
|---|---|---|
| 만들 것 | 모델 변환 파일만 앱에 포함 | 추론 API 서버 + 호스팅 + 배포 |
| 오프라인 | 됨 | 안 됨 |
| 개인정보 | 약 사진이 기기 밖으로 안 나감 | 건강 정보 사진을 서버로 전송 |
| 모델 교체 | 앱 업데이트 필요 | 서버만 바꾸면 됨 |
| 앱 크기 | m 모델 기준 수십 MB 증가 | 변화 없음 |

간단하게 만드는 것이 목표이고 약 사진은 민감 정보이므로 **기기 안 추론**으로 합니다. 서버를 두지 않으니 백엔드 개발·운영이 통째로 빠집니다.

| 플랫폼 | 구현 | 모델 파일 |
|---|---|---|
| Android, iOS | Ultralytics 공식 Flutter 플러그인 [`ultralytics_yolo`](https://pub.dev/packages/ultralytics_yolo) | Android TFLite, iOS Core ML |
| 웹 | 브라우저에서 [onnxruntime-web](https://onnxruntime.ai/docs/tutorials/web/)(`web/pill_detector.js`). `ultralytics_yolo`는 웹을 지원하지 않음 | ONNX |

웹도 사진을 서버로 보내지 않고 브라우저 안에서 추론합니다.

> `ultralytics_yolo`와 Ultralytics 모델은 AGPL-3.0입니다. 웹에 공개하거나 스토어에 배포하기 전에 소스 공개로 갈지 Ultralytics Enterprise License를 받을지 정해야 합니다(8장).

### 3.3 모델 전달 절차

```text
pill-bbox (모델 저장소)                       pillbbox-front (이 저장소)
best.pt ─ export ─▶ pillbox.tflite        ─┐
                    pillbox.mlpackage.zip ┤
                    pillbox.onnx          ┼─ GitHub Release ─▶ scripts/fetch_model.sh ─▶ assets/models/
class_map.csv ─ 변환 ─▶ labels.json         ─┘
```

1. 모델 저장소에서 확정한 `best.pt`를 export합니다.

   ```python
   from ultralytics import YOLO

   model = YOLO("best.pt")
   model.export(format="litert", nms=None, imgsz=640, quantize="w8a32")   # Android → pillbox.tflite
   model.export(format="coreml", nms=False, imgsz=640, quantize="w8a16")  # iOS → .mlpackage를 zip으로 묶어 pillbox.mlpackage.zip
   model.export(format="onnx", imgsz=640)                                 # 웹 → scripts/quantize_onnx.py로 줄여 pillbox.onnx
   ```

   가중치를 int8로 저장해 파일마다 약 80MB에서 20MB로 줄입니다. 계산은 그대로라 대회 학습 사진 232장에서 탐지 결과가 원래 모델과 같았습니다(신뢰도 차이 최대 0.04). 웹은 onnxruntime-web의 wasm이 int8 계산을 잘 받지 못해, Conv 가중치만 int8로 저장하고 불러올 때 fp32로 되돌리는 `scripts/quantize_onnx.py`를 씁니다.

   인자는 `ultralytics_yolo` 0.7.1 문서(공식 YOLO26 모델과 같은 설정, `ultralytics>=8.4.142`)를 따릅니다. iOS는 Flutter 에셋에서 `.mlpackage.zip`만 읽으므로 zip으로 묶습니다.
   웹은 ONNX 출력이 NMS 전(`[1, 4+클래스 수, 8400]`)이든 YOLO26 end2end(`[1, 300, 6]`)든 읽습니다. 입력은 640 고정입니다.
   **모델의 클래스 이름(`names`)은 `labels.json`의 `name`과 같거나 `category_id` 숫자여야 합니다.** 플러그인 0.7.1은 iOS에서 클래스 번호를 주지 않아, 앱이 이름으로 약을 찾습니다(`toDetections`).
2. `class_map.csv`를 앱이 읽을 `labels.json`으로 바꿉니다.

   ```json
   [{"yolo_idx": 0, "category_id": <원본 category_id>, "name": "<dl_name>"}]
   ```

3. 네 파일을 모델 저장소의 GitHub Release(`model-v1` 같은 태그)에 올립니다.
4. 이 저장소에서 `scripts/fetch_model.sh <태그>`로 받아 `assets/models/`에 둡니다. 모델은 `android/`, `ios/`, `web/` 폴더에 나눠 두고 `pubspec.yaml`의 `platforms`로 그 플랫폼 빌드에만 넣습니다. 모델 파일은 크기가 커서 Git에 올리지 않고, 쓰는 태그만 `assets/models/VERSION`에 적어 커밋합니다. 태그 없이 실행하면 `VERSION`의 태그를 받습니다.
   - 파일은 `pillbox-<태그>.tflite`처럼 태그를 넣은 이름으로 둡니다. 플러그인이 모델을 기기에 파일 이름으로 캐시하므로, 이름이 같으면 앱을 업데이트해도 예전 모델이 계속 쓰입니다.
   - 모델을 받지 않았으면 앱은 `FakePillDetector`로 돕니다.
   - `standin-yolo26n`(공식 YOLO26n, COCO 80종)은 모델 확정 전 연동 확인용입니다. 약이 아니라 사람·버스 같은 물체를 찾습니다. 웹용 ONNX는 공식 가중치를 받아 내보내므로 [uv](https://docs.astral.sh/uv/)가 있어야 합니다.
   - export는 `ultralytics` 8.4.198 기준으로, Core ML은 `torch==2.7.1`·`coremltools`, LiteRT는 `litert-torch`·`ai-edge-litert`를 미리 함께 설치해야 됩니다(실행 중 자동 설치되면 torch 버전이 어긋나 실패).

### 3.4 앱 쪽 인터페이스

모델이 확정되기 전에도 화면을 만들 수 있도록 탐지기를 인터페이스로 감쌉니다.

```dart
abstract class PillDetector {
  Future<void> load();
  Future<List<Detection>> detect(Uint8List imageBytes);
}

class Detection {
  final int categoryId;   // labels.json의 category_id
  final String name;
  final double confidence;
  final Rect box;          // 원본 이미지 픽셀 좌표
}
```

| 구현 | 쓰는 때 |
|---|---|
| `FakePillDetector` | 모델 확정 전 화면 개발, 위젯 테스트. 고정된 결과를 돌려줌 |
| `YoloPillDetector` | Android, iOS. `ultralytics_yolo`로 실제 추론 |
| `OnnxPillDetector` | 웹. `web/pill_detector.js`(onnxruntime-web)로 실제 추론 |

### 3.5 정확도 한계와 앱의 대응

모델이 틀리는 것을 전제로 화면을 설계합니다. **사용자가 확정해야 기록이 저장**되고, 모델 결과는 확정을 돕는 초안입니다.

| 상황 | 대응 |
|---|---|
| 신뢰도 낮은 결과 | 신뢰도 0.5 미만은 약으로 보지 않음(`minDetectionConfidence`). 0.5는 모델 저장소의 평가 기준(`POINT_CONF`)과 같음. 버린 알약은 "알 수 없는 물체"로 나와 사용자가 고를 수 있음. 낮은 기준(0.25)에서는 알약이 아닌 물체도 아무 약으로 잡는 경우가 있었음 |
| 96종 밖의 약, 못 찾은 약 | 결과 화면에서 "약 추가"로 등록한 약이나 96종 중에서 고르거나, 이름을 직접 넣어 등록 |
| 모델이 알약으로 보지 않은 물체 | 알약을 하나도 못 찾으면 "알약이 없습니다". 따로 배경과 다른 색의 덩어리를 찾아(`findObjects`) 모델 박스와 겹치지 않는 것을 "알 수 없는 물체"로 보여 주고, 사용자가 무엇인지 고르면 1정으로 기록 (3.6) |
| 다른 약으로 인식 | 박스를 눌러 약을 바꿈. 닮은 약 3쌍(EDA 8.2)은 특히 자주 틀릴 수 있음 |
| 알약 하나에 두 약이 겹쳐 잡힘 | 서로 다른 약이라도 박스가 0.7 넘게 겹치면 신뢰도가 높은 쪽만 남김(`mergeOverlaps`). 둘 다 남기면 1정을 두 약 1정씩으로 기록하기 때문. 지운 약은 약 바꾸기 맨 위에 "모델이 헷갈린 약"으로 보여 줌. 같은 약끼리는 NMS 기준(0.45)대로 |
| 휴대폰 사진과 학습 사진의 차이 | 홈의 빈 화면에 가이드(단색 배경, 위에서 수직, 알약끼리 떨어지게) 표시 |

> 모델 저장소의 제출용 기본 신뢰도 0.001은 mAP 채점용입니다. 앱에서는 쓰지 않습니다.

### 3.6 알 수 없는 물체와 비슷한 약 추천

모델은 배운 96종만 찾습니다. 모델이 놓친 알약이나 96종 밖의 약도 기록할 수 있도록, 모델과 별개로 사진에서 물체를 찾습니다(`lib/utils/object_finder.dart`). OpenCV 대신 Dart로 직접 구현해 웹과 앱에서 같은 코드가 돕니다.

1. 긴 변 640px, CIELAB 색으로 바꾸고 가장자리 픽셀의 중앙값을 배경색으로 봅니다.
2. 배경색과의 색 거리를 Otsu로 나누고(최소 12), 열기·닫기·구멍 메우기로 다듬습니다.
3. 이어진 덩어리마다 박스를 칩니다. 넓이가 이미지의 0.2% 미만·30% 초과이거나 가장자리에 닿으면 버립니다.

대회 학습 사진 232장에서 알약 763개 중 99%를 찾았고, 알약이 아닌 박스는 17개였습니다(그중 상당수는 정답 라벨에서 빠진 실제 알약). 단색 배경이 아니면 박스가 많이 생길 수 있어, 사용자가 "약이 아님"으로 뺄 수 있습니다.

사용자가 물체에 약을 고르면 그 물체의 색(CIELAB 평균)과 길쭉함(긴 축/짧은 축, 비율로 비교)을 `appearances`에 남깁니다. 다음 사진의 알 수 없는 물체는 남겨 둔 것 중 거리 2.0 안에서 가장 가까운 약을 추천합니다. 학습 데이터에서 같은 약끼리는 94%가 이 안에, 다른 약끼리는 5%만 이 안에 들었고, 등록한 약 5개 중에서 고를 때 99% 맞혔습니다. 같은 배경·조명에서 찍은 사진이라 휴대폰 사진에서는 더 낮을 수 있고, 흰색 둥근 알약끼리는 구분이 어렵습니다. 추천은 고르기 쉽게 맨 위에 둘 뿐이고 확정은 사용자가 합니다.

모델이 찾은 알약도 같은 자리(IoU 0.5 이상)의 물체에서 색·모양을 얻어, 저장할 때 그 줄의 약에 남깁니다. 사용자가 줄의 약을 바꾸면 바꾼 약에 남습니다. 다음 사진에서 모델이 찾은 알약이 예전 기록 중 다른 약과 가장 가까우면 "○○과(와) 더 비슷해요"로 바꿀 후보를 보여 줍니다. 모델이 배우지 않은 약은 모르는 물체가 아니라 비슷한 다른 약으로 잡히기 쉬워, 한 번 고쳐 두면 다음부터 바로 고를 수 있게 하려는 것입니다. 맞게 기록한 알약의 색·모양도 남기므로, 모델이 맞힌 약을 다른 약으로 바꾸자고 하는 일은 드뭅니다. 색·모양은 약마다 최근 20개만 둡니다.

탐지 모델을 불러오지 못하거나 돌리다 실패해도 물체 찾기는 모델 없이 되므로, "알약 인식 모델을 쓰지 못했습니다"와 함께 찾은 물체를 골라 기록할 수 있게 합니다. 물체 찾기는 모델과 동시에 시작합니다.

## 4. 화면

```text
홈(오늘) ──기록하기 → 사진 찍기 / 사진 올리기──▶ 결과 확인 ──저장──▶ 홈(오늘)
   │
   ├─▶ 기록 (날짜별)
   └─▶ 약 관리 ──▶ 약 등록·수정 (약, 복용 시간, 1회 수량)
```

| 화면 | 내용 |
|---|---|
| 홈(오늘) | 시간대별 복용 예정 약과 완료 여부. 기록하기 버튼을 누르면 사진 찍기(카메라)·사진 올리기(갤러리)를 고름. 기록이 없으면 사진 가이드와 샘플 사진. 더 보기 메뉴에서 엑셀로 내보내기·가져오기(5.2) |
| 결과 확인 | 사진 위 박스와 약 이름. 예정과 비교한 결과(예: "A 1정 ✓, B 2정 중 1정 인식"). 수정 후 저장. 처음 기록하는 약은 복용 시간 없이, 1회 수량은 이번 개수로 등록. 알약이 없으면 "알약이 없습니다", 알 수 없는 물체는 번호를 붙여 무엇인지 고르게 함(비슷한 약 추천) |
| 기록 | 달력 또는 날짜 목록. 날짜를 누르면 그날의 복용 기록 |
| 약 관리 | 등록한 약 목록. 약은 `labels.json`의 96종에서 검색해 고름 |

결과 확인 화면의 **예정과 비교**가 이 앱의 핵심입니다. 지금 시간대에 먹을 약 목록과 인식된 약·개수를 맞춰 보여 주므로, 사용자는 빠진 약을 바로 알 수 있습니다.

## 5. 아키텍처: MVVM

[Flutter 공식 아키텍처 가이드](https://docs.flutter.dev/app-architecture)가 권장하는 구조를 그대로 따르되, 이 앱 규모에 맞게 줄입니다.

```text
View (Widget) ──▶ ViewModel (ChangeNotifier) ──▶ Repository ──▶ Service
   화면 그리기          화면 상태, 사용자 동작         데이터의 단일 출처     DB, 모델, 사진 선택
```

- **View**: 화면을 그리고 사용자 입력을 ViewModel에 넘깁니다. 로직을 두지 않습니다.
- **ViewModel**: 화면 하나에 하나. 화면 상태를 들고 `notifyListeners()`로 알립니다.
- **Repository**: 약·일정·기록 데이터를 다룹니다. ViewModel은 Repository만 봅니다.
- **Service**: SQLite, 탐지 모델처럼 바깥 것을 감쌉니다.

줄이는 것:

- Domain 계층(UseCase)은 두지 않습니다. 예정과 인식 결과를 비교하는 로직 하나만 `IntakeMatcher` 함수로 둡니다.
- 상태관리는 `provider` + `ChangeNotifier`만 씁니다. Riverpod, Bloc, DI 프레임워크, 코드 생성(freezed 등)은 쓰지 않습니다.

### 5.1 폴더 구조

```text
lib/
├── main.dart                 # provider 등록, 앱 시작
├── data/
│   ├── models/               # Medication, Schedule, IntakeRecord, Detection
│   ├── repositories/         # medication_repository.dart, intake_repository.dart
│   └── services/             # database_service.dart, pill_detector.dart (+ fake, yolo, onnx),
│                             # platform_services(_web).dart: 플랫폼별 DB·사진 저장소·탐지기
├── ui/
│   ├── home/                 # home_screen.dart, home_view_model.dart
│   ├── result/
│   ├── history/
│   ├── medication/
│   └── common/               # 공통 위젯, 테마
└── utils/                    # intake_matcher.dart
assets/models/                # android/·ios/·web/pillbox-<태그>.tflite / .mlpackage.zip / .onnx, pillbox-<태그>.labels.json (Git 제외), VERSION
web/pill_detector.js          # 웹 탐지 (onnxruntime-web)
```

### 5.2 데이터

저장은 기기 안 SQLite입니다. 앱은 `sqflite`, 웹은 `sqflite_common_ffi_web`(SQLite wasm, 브라우저 IndexedDB에 저장)을 씁니다.

| 테이블 | 열 |
|---|---|
| `medications` | `id`, `category_id`(96종 중 하나, 직접 등록한 약은 null), `name`, `dose_per_take` |
| `schedules` | `id`, `medication_id`, `time`(HH:mm) |
| `intake_records` | `id`, `medication_id`, `taken_at`, `count`, `source`(camera/manual, camera는 사진으로 남긴 기록), `photo_path` |
| `appearances` | `id`, `medication_id`, `l`, `a`, `b`, `elongation`. 알 수 없는 물체에 고른 약의 색·모양 (DB 버전 2, 3.6) |

사진은 앱 전용 폴더(웹은 브라우저 안 별도 DB)에만 저장하고, 기록을 지우면 함께 지웁니다.

웹은 기록이 **그 브라우저에만** 남습니다. 사이트 데이터를 지우면 기록도 지워지고, iOS Safari는 7일 동안 열지 않은 사이트의 저장소를 지울 수 있으므로 홈 화면에 추가해 쓰도록 안내합니다.

그래서 약·기록·색·모양을 엑셀(.xlsx)로 내보내고 가져옵니다(`BackupRepository`). 시트는 `약`(이름, 약 번호, 1회 개수, 복용 시간), `기록`(시각, 약, 개수, 방법), `색·모양`입니다. 기록은 약 이름으로 잇습니다.

- 사진은 넣지 않습니다. 엑셀 칸 하나에 담기 어렵고, 기록을 옮기는 데는 없어도 됩니다.
- 가져오기는 지금 데이터에 합칩니다. 약은 약 번호나 이름이 같으면 같은 약으로 보고 지금 설정을 그대로 두고, 기록은 같은 약·시각(초까지)·개수면 건너뜁니다. 같은 파일을 두 번 가져와도 겹치지 않습니다.
- 엑셀에서 고쳐 저장한 파일(공유 문자열, 날짜·시각 서식)도 읽습니다. 읽을 수 없는 행은 건너뛰고 몇 행인지 알립니다.
- `excel` 패키지는 `image`와 `archive` 버전이 맞지 않아, xlsx를 `archive`·`xml`로 직접 읽고 씁니다(`lib/utils/xlsx.dart`).

### 5.3 주요 패키지

| 용도 | 패키지 |
|---|---|
| 상태관리 | `provider` |
| 탐지 | `ultralytics_yolo`(앱), onnxruntime-web(웹, CDN에서 `<script>`로 읽음) |
| 사진 선택 | `image_picker`, `image` (긴 변 640px(모델 입력과 같음), JPEG 품질 80으로 줄여 저장. 웹의 image_picker는 PNG를 PNG로 두므로 `image`로 다시 씀) |
| DB | `sqflite`(앱), `sqflite_common_ffi_web`(웹) |
| 엑셀 백업 | `archive`, `xml`(xlsx 직접 읽고 쓰기), `file_picker`(파일 고르기·저장. 웹은 내려받기) |
| 화면 이동 | `go_router` |
| 알림 (2차) | `flutter_local_notifications` |

## 6. 배포: 웹 (GitHub Pages)

### 6.1 범위

먼저 웹으로 배포합니다. 스토어 계정·심사·서명 없이 링크만 나누면 휴대폰 브라우저에서 바로 씁니다. 서버는 두지 않고 `flutter build web` 결과를 정적 사이트로 올립니다.

| 단계 | 내용 | 언제 |
|---|---|---|
| 0 | 로컬에서 `fvm flutter run -d chrome` | 처음부터 |
| 1 | `main`에 합치면 GitHub Actions가 빌드해 GitHub Pages에 올림 | 지금 |
| 2 | 앱 스토어 테스트 배포 (fastlane `beta`) | 앱이 필요해질 때. 설정은 `feat/fastlane-beta` 브랜치에 있음 |

### 6.2 워크플로

`.github/workflows/deploy-web.yml`

| 단계 | 하는 일 |
|---|---|
| 모델 받기 | `scripts/fetch_model.sh` (`VERSION`의 태그). 받은 모델은 `VERSION`·스크립트가 바뀔 때까지 캐시 |
| SQLite wasm | `dart run sqflite_common_ffi_web:setup`이 `web/sqlite3.wasm`, `web/sqflite_sw.js`를 만듦 (Git 제외) |
| 빌드 | `flutter build web --base-href /<저장소 이름>/` |
| 올리기 | `main` push일 때만 Pages에 배포. PR에서는 빌드만 확인 |

- 주소는 `https://def-uk.github.io/pill-bbox-front/`입니다.
- 처음 한 번 저장소 설정에서 Pages의 Source를 **GitHub Actions**로 바꿔야 합니다.
- 화면 이동은 해시 URL(`/#/history`)이라 Pages에 별도 404 처리가 필요 없습니다.

### 6.3 로컬에서 웹 확인

```bash
scripts/fetch_model.sh
fvm dart run sqflite_common_ffi_web:setup
fvm flutter run -d chrome
```

- 사진 찍기는 휴대폰 브라우저에서 카메라가 바로 열리고, PC 브라우저에서는 파일 선택 창이 열립니다. 사진이 없으면 샘플 사진으로 흐름을 확인합니다.
- 모델을 바꾼 배포는 PR에 모델 태그(`assets/models/VERSION`)를 적습니다. 빌드에는 그때 `VERSION`에 적힌 모델이 들어갑니다.

## 7. 개발 순서

| 순서 | 할 일 | 끝난 기준 |
|---|---|---|
| 1 | Flutter 프로젝트 생성, MVVM 뼈대, `FakePillDetector` | 가짜 결과로 사진 → 결과 확인 → 저장 흐름이 돎 |
| 2 | 약 관리, 일정, 기록, 홈(오늘) | 일정 등록 후 홈에 예정·완료가 보임 |
| 3 | 모델 export, `YoloPillDetector` | 실제 기기에서 테스트 사진 10장의 결과가 모델 저장소 예측과 같음 |
| 4 | 휴대폰 사진으로 성능 확인 | 실제로 찍은 사진 20장 이상의 인식 결과 정리, 모델 팀과 공유 |
| 5 | 웹 배포 (GitHub Pages) | 팀원이 휴대폰 브라우저에서 링크로 열어 사진을 올려 기록 |
| 5-1 (나중) | 앱 스토어 테스트 배포 (fastlane `beta`) | 팀원이 TestFlight / 내부 테스트로 설치 |
| 6 (2차) | 알림 | |

## 8. 결정할 것

| 항목 | 기본값 | 정할 사람 |
|---|---|---|
| 지원 플랫폼 | 웹 먼저. 앱(Android, iOS)은 스토어 배포가 필요해질 때 | 팀 |
| 최종 모델과 크기 | 모델 팀 결정. 기기 속도를 위해 s/n 크기 export도 함께 받아 비교 | 모델 팀 |
| 알림을 MVP에 넣을지 | 2차 | 팀 |
| 직접 등록한 약(96종 밖) 허용 | 허용하되 사진 인식은 안 됨, 수동 기록만 | 팀 |
| 탐지 플러그인 라이선스 | `ultralytics_yolo`와 모델이 AGPL-3.0. 웹은 모델 파일을 그대로 내려받게 하므로 공개 배포 전에 소스 공개 또는 Enterprise License | 팀 |
