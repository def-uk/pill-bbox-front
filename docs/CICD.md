# CI/CD 검증

GitHub Actions가 의도대로 막고, 의도대로 배포하는지 확인한 기록입니다. 워크플로 설정은 `.github/workflows/`, 맥미니 배포는 [backend/README.md](../backend/README.md) 5장에 있습니다.

## 1. 파이프라인

```text
작업 브랜치 ──PR──▶ backend-check (ruff, pytest)      ─┐ 필수 체크. 둘 다 통과해야 main에 합칠 수 있음
                    web-build (flutter build web)     ─┘ 해당 폴더를 안 건드렸으면 건너뛰고 통과
                              │ 머지
                              ▼
main push ──▶ deploy-backend.yml (backend/** 바뀌면)       deploy-web.yml (frontend/** 바뀌면)
              검사 다시 → SSH로 deploy.sh                    빌드 → releases/<커밋>에 풀고 current 바꿈
              맥미니 안: /health가 이 커밋인지, 아니면 롤백    맥미니 안: 127.0.0.1:8200이 200인지
              바깥: api.<도메인>/health가 이 커밋인지          바깥: www.<도메인>/commit.txt가 이 커밋인지, COOP/COEP
```

| 단계 | 무엇이 막는가 | 실패하면 |
|---|---|---|
| PR | `backend-check`, `web-build` 필수 체크 (main ruleset) | 머지 버튼이 잠김 |
| 배포 전 | `deploy-backend.yml`의 test job이 같은 검사를 다시 함 | 배포하지 않음 |
| 배포 중 (맥미니 안) | `deploy.sh`가 20초 안에 `/health`의 commit을 확인 | 직전 배포 커밋으로 `git reset --hard`하고 다시 띄운 뒤 실패 |
| 배포 뒤 (바깥) | `.github/scripts/smoke.sh`가 Cloudflare Tunnel 너머 주소로 확인 | 워크플로가 빨간불 |

맥미니 안의 확인만으로는 터널, DNS, HTTPS가 깨진 것을 모릅니다. 그래서 배포 뒤에 GitHub 러너에서 바깥 주소로 한 번 더 봅니다.

## 2. 이 문서를 쓰기 전에 찾은 문제

| 날짜 | 무엇이 | 왜 | 고친 것 |
|---|---|---|---|
| 2026-11-04 | PR #21이 `백엔드` 체크 실패(ruff E501)인데 머지되고, 맥미니에 배포까지 됨 | main ruleset이 꺼져 있었음. 배포 워크플로의 test job은 pytest만 돌리고 ruff는 안 돌림 | 필수 체크 지정, 배포 test job에 ruff 추가 |
| 2026-11-04 | PR #18 배포가 `.env` 공백으로 실패. 롤백한 커밋(677eb18)에 `launchd.plist`가 없어 롤백도 실패 | 롤백 대상이 지금 배포 스크립트보다 오래된 구조였음 | `deploy.sh`가 띄우기 전에 `.env` 공백을 막음. 지금은 `deployed`에 적힌 커밋이 모두 `launchd.plist`를 가짐 |
| 2026-11-04 | 웹 배포가 웹 서버가 죽어 있어도 초록불 | 마지막 확인이 `curl … \|\| echo`였음 | 200이 아니면 실패, 바깥 확인 추가 |
| 2026-11-04 | 경로 필터 때문에 필수 체크를 걸면 상관없는 PR이 영영 대기 | `on: paths`면 워크플로 자체가 안 돎 | 워크플로는 항상 돌고 job만 건너뜀 (`dorny/paths-filter`) |

## 3. 검증 시나리오

일부러 실패하는 PR과 배포를 만들어, 막아야 할 때 막는지 봅니다. 결과에는 Actions 실행 링크를 붙입니다. 1~4번 PR은 확인한 뒤 머지하지 않고 닫았습니다.

| # | 시나리오 | 기대 | 결과 |
|---|---|---|---|
| 1 | 백엔드 테스트를 깨뜨린 PR | `backend-check` 빨간불, 머지 잠김 | 통과 (2026-11-04). [#23](https://github.com/def-uk/pill-bbox-front/pull/23): `assert 1 == 2` 테스트 추가 → pytest `1 failed, 31 passed`로 [`backend-check` 실패](https://github.com/def-uk/pill-bbox-front/actions/runs/41845579373), 머지 상태 `BLOCKED` |
| 2 | 린트 위반 PR (줄 길이) | `backend-check` 빨간불, 머지 잠김 | 통과 (2026-11-04). [#24](https://github.com/def-uk/pill-bbox-front/pull/24): 185자 주석 줄 추가 → ruff `E501 Line too long (185 > 100)`으로 [`backend-check` 실패](https://github.com/def-uk/pill-bbox-front/actions/runs/41845596462), 머지 상태 `BLOCKED` |
| 3 | Flutter 빌드를 깨뜨린 PR | `web-build` 빨간불, 머지 잠김 | 통과 (2026-11-04). [#25](https://github.com/def-uk/pill-bbox-front/pull/25): `const int ciProbe = 'not an int';` 추가 → `flutter build web`이 타입 오류로 [`web-build` 실패](https://github.com/def-uk/pill-bbox-front/actions/runs/41845609684), 머지 상태 `BLOCKED`. `backend-check`는 건너뜀 |
| 4 | 문서만 바꾼 PR | 두 체크 모두 건너뛰고 통과, 머지 가능 | 통과 (2026-11-04). [#26](https://github.com/def-uk/pill-bbox-front/pull/26): `docs/CICD.md`만 바꿈 → [`backend-check`](https://github.com/def-uk/pill-bbox-front/actions/runs/41845625809), [`web-build`](https://github.com/def-uk/pill-bbox-front/actions/runs/41845625816) 둘 다 건너뜀, 머지 상태 `CLEAN` |
| 5 | 정상 머지 | 배포 후 바깥 확인 통과 | 통과 (2026-11-04). [#22](https://github.com/def-uk/pill-bbox-front/pull/22) 머지(`a6ef2bd`) 뒤 [API](https://github.com/def-uk/pill-bbox-front/actions/runs/41827329216) `/health`가 `a6ef2bd`, [웹](https://github.com/def-uk/pill-bbox-front/actions/runs/41827329269) `commit.txt`가 `a6ef2bd`이고 COOP/COEP 있음. 둘 다 첫 시도에 통과 |
| 6 | 앱이 뜨지 않는 커밋 배포 | 배포 빨간불, `/health`가 직전 커밋 (롤백) | 아직 안 함 |

6번은 실제 서버가 20초쯤 멈추므로 사람이 적은 시간에 합니다.

검증하면서 본 빈 곳입니다. 아직 고치지 않았습니다.

- PR 검사는 Flutter를 `flutter build web`으로만 봅니다. `flutter analyze`와 `flutter test`는 CI에서 돌지 않아서, 빌드는 되지만 테스트가 깨진 PR은 막지 못합니다.
- 웹 배포는 `current`를 새 빌드로 바꾼 뒤에 확인합니다. 확인이 실패하면 워크플로는 빨간불이지만 사이트는 새 빌드를 계속 내보냅니다. 되돌리려면 `current`를 이전 `releases/` 폴더로 손으로 바꿔야 합니다.
- 백엔드는 맥미니 안의 `/health` 확인이 실패할 때만 롤백합니다. 바깥 확인(`smoke.sh`)만 실패하면 롤백하지 않습니다.

바깥 확인은 손으로도 돌릴 수 있습니다.

```bash
.github/scripts/smoke.sh api https://api.havepills.party <배포한 커밋 전체 해시>
```
