# pillbbox-front

알약 사진 한 장으로 복용 기록을 남기는 Flutter 앱입니다. 알약 탐지 모델은 [pill-bbox](https://github.com/def-uk/pill-bbox)에서 학습합니다.

- 입력: 복용할 알약 사진 / 출력: 약 종류·개수와 복용 기록
- 추론: 기기 안 (Android TFLite, iOS CoreML)
- 아키텍처: MVVM (View, ViewModel, Repository, Service)
- 배포: fastlane (Play Console 내부 테스트, TestFlight)

## 실행

Flutter 버전은 [fvm](https://fvm.app)으로 고정합니다(`.fvmrc`).

```bash
fvm install
fvm flutter run
fvm flutter test
```

지금은 탐지 모델 대신 `FakePillDetector`가 고정된 결과를 돌려줍니다. 카메라가 없는 iOS 시뮬레이터에서는 촬영 화면의 "샘플 사진으로 계속"으로 흐름을 확인합니다.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | 목적, 범위, 모델 연동, 화면, 아키텍처, 배포, 개발 순서 |
