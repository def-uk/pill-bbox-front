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
| MVP | 복용 일정 등록(약, 시간, 1회 수량) |
| MVP | 촬영 → 탐지 결과 확인·수정 → 복용 기록 저장 |
| MVP | 오늘 복용 현황(예정 vs 복용), 날짜별 기록 조회 |
| 2차 | 복용 시간 알림(로컬 알림) |
| 2차 | 갤러리 사진으로 기록 |
| 하지 않음 | 회원가입·로그인, 서버 저장·기기 간 동기화, 처방전 OCR, 웹 버전 |

## 3. 모델 연동

### 3.1 모델 현황 (2026-10-29 기준)

| 항목 | 내용 | 앱에 주는 영향 |
|---|---|---|
| 모델 | ultralytics YOLO. 후보 `yolo11m`, `yolo26m` (미확정) | export 형식과 크기가 확정되면 앱에 넣음 |
| 클래스 | 약 56종. `class_map.csv`에 `yolo_idx → category_id → dl_name` | 56종 밖의 약은 인식 못 함 → 사용자가 직접 고르는 화면 필요 |
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

구현은 Ultralytics 공식 Flutter 플러그인 [`ultralytics_yolo`](https://pub.dev/packages/ultralytics_yolo)를 씁니다. Android는 TFLite, iOS는 Core ML 모델을 읽습니다.

> `ultralytics_yolo`와 Ultralytics 모델은 AGPL-3.0입니다. 스토어에 배포하기 전에 소스 공개로 갈지 Ultralytics Enterprise License를 받을지 정해야 합니다(8장).

### 3.3 모델 전달 절차

```text
pill-bbox (모델 저장소)                       pillbbox-front (이 저장소)
best.pt ─ export ─▶ pillbox.tflite        ─┐
                    pillbox.mlpackage.zip ┼─ GitHub Release ─▶ scripts/fetch_model.sh ─▶ assets/models/
class_map.csv ─ 변환 ─▶ labels.json         ─┘
```

1. 모델 저장소에서 확정한 `best.pt`를 export합니다.

   ```python
   from ultralytics import YOLO

   model = YOLO("best.pt")
   model.export(format="litert", nms=None, imgsz=640)    # Android → pillbox.tflite
   model.export(format="coreml", nms=False, imgsz=640)   # iOS → .mlpackage를 zip으로 묶어 pillbox.mlpackage.zip
   ```

   인자는 `ultralytics_yolo` 0.7.1 문서(공식 YOLO26 모델과 같은 설정, `ultralytics>=8.4.142`)를 따릅니다. iOS는 Flutter 에셋에서 `.mlpackage.zip`만 읽으므로 zip으로 묶습니다.
   **모델의 클래스 이름(`names`)은 `labels.json`의 `name`과 같거나 `category_id` 숫자여야 합니다.** 플러그인 0.7.1은 iOS에서 클래스 번호를 주지 않아, 앱이 이름으로 약을 찾습니다(`toDetections`).
2. `class_map.csv`를 앱이 읽을 `labels.json`으로 바꿉니다.

   ```json
   [{"yolo_idx": 0, "category_id": <원본 category_id>, "name": "<dl_name>"}]
   ```

3. 세 파일을 모델 저장소의 GitHub Release(`model-v1` 같은 태그)에 올립니다.
4. 이 저장소에서 `scripts/fetch_model.sh <태그>`로 받아 `assets/models/`에 둡니다. 모델 파일은 크기가 커서 Git에 올리지 않고, 쓰는 태그만 `assets/models/VERSION`에 적어 커밋합니다. 태그 없이 실행하면 `VERSION`의 태그를 받습니다.
   - 파일은 `pillbox-<태그>.tflite`처럼 태그를 넣은 이름으로 둡니다. 플러그인이 모델을 기기에 파일 이름으로 캐시하므로, 이름이 같으면 앱을 업데이트해도 예전 모델이 계속 쓰입니다.
   - 모델을 받지 않았으면 앱은 `FakePillDetector`로 돕니다.
   - 모델 확정 전에는 `standin-yolo26n`(공식 YOLO26n, COCO 80종)으로 플러그인 연동을 확인합니다. 약이 아니라 사람·버스 같은 물체를 찾습니다.

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
| `YoloPillDetector` | `ultralytics_yolo`로 실제 추론 |

### 3.5 정확도 한계와 앱의 대응

모델이 틀리는 것을 전제로 화면을 설계합니다. **사용자가 확정해야 기록이 저장**되고, 모델 결과는 확정을 돕는 초안입니다.

| 상황 | 대응 |
|---|---|
| 신뢰도 낮은 결과 | 신뢰도 0.5 미만은 "확인 필요"로 표시. 0.5는 모델 저장소의 평가 기준(`POINT_CONF`)과 같음 |
| 56종 밖의 약, 못 찾은 약 | 결과 화면에서 "약 추가"로 등록된 약 중에서 직접 고름 |
| 다른 약으로 인식 | 박스를 눌러 약을 바꿈. 닮은 약 3쌍(EDA 8.2)은 특히 자주 틀릴 수 있음 |
| 휴대폰 사진과 학습 사진의 차이 | 촬영 화면에 가이드(단색 배경, 위에서 수직, 알약끼리 떨어지게) 표시 |

> 모델 저장소의 제출용 기본 신뢰도 0.001은 mAP 채점용입니다. 앱에서는 쓰지 않습니다.

## 4. 화면

```text
홈(오늘) ──촬영──▶ 촬영 ──▶ 결과 확인 ──저장──▶ 홈(오늘)
   │
   ├─▶ 기록 (날짜별)
   └─▶ 약 관리 ──▶ 약 등록·수정 (약, 복용 시간, 1회 수량)
```

| 화면 | 내용 |
|---|---|
| 홈(오늘) | 시간대별 복용 예정 약과 완료 여부. 촬영 버튼 |
| 촬영 | 카메라 미리보기, 촬영 가이드 |
| 결과 확인 | 사진 위 박스와 약 이름. 예정과 비교한 결과(예: "A 1정 ✓, B 2정 중 1정 인식"). 수정 후 저장 |
| 기록 | 달력 또는 날짜 목록. 날짜를 누르면 그날의 복용 기록 |
| 약 관리 | 등록한 약 목록. 약은 `labels.json`의 56종에서 검색해 고름 |

결과 확인 화면의 **예정과 비교**가 이 앱의 핵심입니다. 지금 시간대에 먹을 약 목록과 인식된 약·개수를 맞춰 보여 주므로, 사용자는 빠진 약을 바로 알 수 있습니다.

## 5. 아키텍처: MVVM

[Flutter 공식 아키텍처 가이드](https://docs.flutter.dev/app-architecture)가 권장하는 구조를 그대로 따르되, 이 앱 규모에 맞게 줄입니다.

```text
View (Widget) ──▶ ViewModel (ChangeNotifier) ──▶ Repository ──▶ Service
   화면 그리기          화면 상태, 사용자 동작         데이터의 단일 출처     DB, 모델, 카메라
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
│   └── services/             # database_service.dart, pill_detector.dart (+ fake, yolo)
├── ui/
│   ├── home/                 # home_screen.dart, home_view_model.dart
│   ├── capture/
│   ├── result/
│   ├── history/
│   ├── medication/
│   └── common/               # 공통 위젯, 테마
└── utils/                    # intake_matcher.dart
assets/models/                # pillbox-<태그>.tflite / .mlpackage.zip / .labels.json (Git 제외), VERSION
```

### 5.2 데이터

저장은 기기 안 SQLite(`sqflite`)입니다.

| 테이블 | 열 |
|---|---|
| `medications` | `id`, `category_id`(56종 중 하나, 직접 등록한 약은 null), `name`, `dose_per_take` |
| `schedules` | `id`, `medication_id`, `time`(HH:mm) |
| `intake_records` | `id`, `medication_id`, `taken_at`, `count`, `source`(camera/manual), `photo_path` |

사진은 앱 전용 폴더에만 저장하고, 기록을 지우면 함께 지웁니다.

### 5.3 주요 패키지

| 용도 | 패키지 |
|---|---|
| 상태관리 | `provider` |
| 탐지 | `ultralytics_yolo` |
| 카메라 | `camera` (갤러리는 2차에 `image_picker`) |
| DB | `sqflite` |
| 화면 이동 | `go_router` |
| 알림 (2차) | `flutter_local_notifications` |

## 6. 배포: fastlane

### 6.1 범위

빌드는 `flutter build`로 하고, fastlane은 **스토어 테스트 채널에 올리는 일만** 맡깁니다. 플랫폼마다 lane 하나(`beta`)만 둡니다.

| 단계 | 내용 | 언제 |
|---|---|---|
| 0 | 로컬에서 `flutter run` / `flutter build` | 처음부터 |
| 1 | fastlane `beta` lane: Android → Play Console 내부 테스트, iOS → TestFlight | 팀원·사용자에게 설치본을 처음 나눠 줄 때 |
| 2 (선택) | GitHub Actions에서 태그 push 시 1단계 실행 | 수동 배포가 반복되어 번거로울 때 |

### 6.2 준비물

| 플랫폼 | 필요한 것 |
|---|---|
| Android | Google Play Console 계정(1회 $25), 업로드 키스토어, Play API 서비스 계정 JSON |
| iOS | Apple Developer Program(연 $99), Mac + Xcode, App Store Connect API 키(.p8) |

키스토어, JSON, .p8은 Git에 올리지 않습니다(`.gitignore`). 경로는 환경 변수로 넘깁니다.

### 6.3 Fastfile

Flutter 문서대로 `android/`와 `ios/`에 fastlane을 따로 두고, 각각 `beta` lane 하나만 둡니다.

| 파일 | 하는 일 |
|---|---|
| `android/fastlane/Fastfile` | `app-release.aab`를 Play Console 내부 테스트 트랙에 올림 |
| `ios/fastlane/Fastfile` | `flutter build ipa`가 만든 아카이브를 App Store Connect API 키로 서명·내보낸 뒤 TestFlight에 올림 |

iOS는 Xcode에 Apple ID로 로그인하지 않고 API 키로 클라우드 서명합니다. 배포 인증서와 프로비저닝 프로파일은 Xcode가 만듭니다. 그래서 API 키는 **Admin** 역할(또는 클라우드 관리 배포 인증서 권한)이어야 합니다.

### 6.4 배포 명령

| 상황 | 명령 |
|---|---|
| Android 테스트 배포 | `fvm flutter build appbundle --build-number=<N>` → `cd android && bundle exec fastlane beta` |
| iOS 테스트 배포 | `fvm flutter build ipa --build-number=<N>` → `cd ios && bundle exec fastlane beta` |

- 버전 이름은 `pubspec.yaml`의 `version`, 빌드 번호는 배포할 때마다 1씩 올립니다. Android와 iOS에 같은 번호를 씁니다.
- 모델을 바꾼 빌드는 릴리스 노트에 모델 태그(`assets/models/VERSION`)를 적습니다. 빌드에는 그때 `assets/models/`에 받아 둔 모델이 들어갑니다.
- 키 경로는 환경 변수로 넘깁니다: `PLAY_JSON_KEY_PATH`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.

### 6.5 처음 한 번 할 일

앱 ID는 두 스토어 모두 `io.github.defuk.pillbbox`입니다. Play에 한 번 올리면 바꿀 수 없습니다.

**Android**

1. 업로드 키를 만들고 안전한 곳(저장소 밖)에 백업합니다. 잃어버리면 Play Console에서 키 재설정을 요청해야 합니다.

   ```bash
   keytool -genkey -v -keystore ~/keys/pillbbox-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. `android/key.properties`를 만듭니다(Git 제외).

   ```properties
   storeFile=/Users/<사용자>/keys/pillbbox-upload.jks
   storePassword=<키스토어 비밀번호>
   keyAlias=upload
   keyPassword=<키 비밀번호>
   ```

3. Play Console에서 앱을 만들고, **첫 번들은 Console에서 직접** 내부 테스트 트랙에 올립니다. Play API는 한 번도 번들을 받지 않은 앱에 올리지 못합니다. Play 앱 서명은 기본값(Google이 관리)을 씁니다.
4. 내부 테스트 트랙에 테스터 이메일 목록을 넣고, 참여 링크를 테스터에게 보냅니다.
5. Google Cloud에서 서비스 계정 JSON 키를 만들고, Play Console 사용자 및 권한에서 그 계정에 이 앱의 출시 권한을 줍니다. 경로를 `PLAY_JSON_KEY_PATH`로 넘깁니다.
6. 앱을 아직 출시하지 않았으면(Console에서 첫 출시 전) `PLAY_RELEASE_STATUS=draft`로 올리고 Console에서 출시합니다.

**iOS**

1. App Store Connect > 사용자 및 액세스 > 통합 > App Store Connect API에서 Admin 역할의 팀 키를 만듭니다. `.p8`은 한 번만 받을 수 있으니 저장소 밖에 보관하고, 키 ID·발급자 ID와 함께 `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`로 넘깁니다.
2. Certificates, Identifiers & Profiles > Identifiers에서 번들 ID `io.github.defuk.pillbbox`를 등록합니다.
3. App Store Connect > 나의 앱에서 그 번들 ID로 새 앱을 만듭니다.
4. 업로드한 빌드가 처리되면(보통 10~30분) TestFlight > 내부 테스트 그룹에 테스터를 넣습니다. 내부 테스터(팀 멤버)는 심사 없이 바로 설치합니다.

## 7. 개발 순서

| 순서 | 할 일 | 끝난 기준 |
|---|---|---|
| 1 | Flutter 프로젝트 생성, MVVM 뼈대, `FakePillDetector` | 가짜 결과로 촬영 → 결과 확인 → 저장 흐름이 돎 |
| 2 | 약 관리, 일정, 기록, 홈(오늘) | 일정 등록 후 홈에 예정·완료가 보임 |
| 3 | 모델 export, `YoloPillDetector` | 실제 기기에서 테스트 사진 10장의 결과가 모델 저장소 예측과 같음 |
| 4 | 휴대폰 사진으로 성능 확인 | 실제로 찍은 사진 20장 이상의 인식 결과 정리, 모델 팀과 공유 |
| 5 | fastlane `beta` | 팀원이 TestFlight / 내부 테스트로 설치 |
| 6 (2차) | 알림, 갤러리 입력 | |

## 8. 결정할 것

| 항목 | 기본값 | 정할 사람 |
|---|---|---|
| 지원 플랫폼 | Android, iOS 둘 다. Apple 계정이 없으면 Android 먼저 | 팀 |
| 스토어 계정 | 위 6.2 준비물 | 팀 |
| 최종 모델과 크기 | 모델 팀 결정. 기기 속도를 위해 s/n 크기 export도 함께 받아 비교 | 모델 팀 |
| 알림을 MVP에 넣을지 | 2차 | 팀 |
| 직접 등록한 약(56종 밖) 허용 | 허용하되 촬영 인식은 안 됨, 수동 기록만 | 팀 |
| 탐지 플러그인 라이선스 | `ultralytics_yolo`와 모델이 AGPL-3.0. 배포 전 소스 공개 또는 Enterprise License | 팀 |
