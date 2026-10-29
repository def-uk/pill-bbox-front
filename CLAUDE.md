# CLAUDE.md

알약 사진 한 장으로 복용 기록을 남기는 Flutter 앱입니다. 목적, 화면, 아키텍처, 개발 순서는 [docs/DESIGN.md](docs/DESIGN.md)에 있습니다.

## Git 작업 규칙

- 새 작업을 시작할 때는 무조건 `main`에서 브랜치를 새로 따서 작업합니다. `main`에서 바로 커밋하지 않습니다.
- `main`에는 절대 푸시하지 않습니다. `git push origin main`, `git push --force` 등 `main`을 바꾸는 푸시는 사용자가 요청해도 하지 않고, 작업 브랜치를 푸시한 뒤 PR로 합칩니다.
- 위 두 규칙은 `.claude/hooks/guard-main.sh` 훅(`.claude/settings.json`)이 막습니다. 훅에 막히면 우회하지 말고 브랜치를 새로 땁니다.
- 브랜치 이름은 커밋 접두사를 따릅니다: `feat/…`, `fix/…`, `docs/…`, `refactor/…`, `chore/…` (예: `feat/model-integration`).
- 시작하기 전에 `main`을 최신으로 맞춥니다.

```bash
git switch main
git pull --ff-only
git switch -c feat/작업-이름
```

- 커밋 메시지는 한국어로, `feat:`, `fix:`, `docs:` 같은 접두사를 붙입니다 (예: `feat: 약 관리, 일정, 기록 추가`).

## 실행

Flutter 버전은 fvm으로 고정합니다(`.fvmrc`). `flutter` 대신 `fvm flutter`를 씁니다.

```bash
fvm flutter run
fvm flutter test
fvm flutter analyze
```

## 구조

MVVM입니다 (View, ViewModel, Repository, Service).

- `lib/ui/` 화면별 View와 ViewModel, `router.dart`(go_router)
- `lib/data/models/` 모델, `lib/data/repositories/` 저장소, `lib/data/services/` 탐지·카메라·DB(sqflite) 등 서비스
- `lib/utils/` 공용 함수

지금은 탐지 모델 대신 `FakePillDetector`가 고정된 결과를 돌려줍니다.
