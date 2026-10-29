# pillbbox-front

알약 사진 한 장으로 복용 기록을 남기는 Flutter 앱입니다. 알약 탐지 모델은 [pill-bbox](https://github.com/def-uk/pill-bbox)에서 학습합니다.

- 입력: 복용할 알약 사진 / 출력: 약 종류·개수와 복용 기록
- 추론: 기기 안 (Android TFLite, iOS CoreML)
- 아키텍처: MVVM (View, ViewModel, Repository, Service)
- 배포: fastlane (Play Console 내부 테스트, TestFlight)

## 문서

| 문서 | 내용 |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | 목적, 범위, 모델 연동, 화면, 아키텍처, 배포, 개발 순서 |
