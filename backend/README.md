# pillbbox 백엔드

pillbbox 앱의 약·복용 기록을 맡아 두는 FastAPI 서버의 설계 문서입니다. 집에 있는 맥미니 한 대에서 돌리고, 코드는 이 저장소의 `backend/`에 두고, 앱은 `frontend/`에 있습니다.

## 1. 왜 만드는가

웹은 기록이 **그 브라우저에만** 남습니다([docs/DESIGN.md](../docs/DESIGN.md) 5.2). 사이트 데이터를 지우거나 iOS Safari가 저장소를 비우면 기록이 사라지고, 지금은 엑셀로 내보내 두는 수밖에 없습니다. 서버에 자동으로 백업해 두면 이 걱정이 없어지고, 다른 기기나 브라우저에서도 기록을 이어 씁니다.

| 구분 | 내용 |
|---|---|
| 1단계 (이번) | 기기 데이터를 서버에 통째로 백업하고, 다른 기기에서 받아 합치기. 로그인 없이 "동기화 코드" 하나로 |
| 2단계 (필요해지면) | 변경 단위 동기화. 두 기기를 번갈아 써도 지운 기록이 되살아나지 않게 |
| 하지 않음 | 서버에서 탐지(추론), 사진 올리기, 회원가입·로그인, 여러 사람이 데이터 공유 |

**탐지는 계속 기기 안에서** 합니다. 약 사진은 서버로 보내지 않고, 서버에는 엑셀 백업과 같은 내용(약, 복용 시간, 기록, 색·모양)만 올라갑니다.

## 2. 구성

```text
[휴대폰 브라우저 / 앱]  GitHub Pages의 웹 앱, BackupRepository → ServerBackupService
        │ HTTPS
        ▼
[맥미니]  Tailscale Funnel   https://<맥미니>.<tailnet>.ts.net
        │ 127.0.0.1:8000
        ▼
         uvicorn + FastAPI   launchd가 띄우고 죽으면 다시 띄움
        │
        ▼
         SQLite              ~/pillbbox/data/pillbbox.db
```

| 항목 | 고른 것 | 이유 |
|---|---|---|
| 프레임워크 | FastAPI, Pydantic v2 | 빠르게 만들 수 있고 `/docs`에 API 문서가 저절로 생김 |
| 실행 | uvicorn 하나, `launchd`가 띄우고 죽으면 다시 띄움 | 사용자가 몇 명이라 워커 하나로 충분. Docker 없이 맥에 기본으로 있는 것만 씀 |
| 패키지 | [uv](https://docs.astral.sh/uv/) (`uv.lock`으로 고정) | 모델 스크립트에서 이미 씀. 맥미니에서 `uv sync --frozen` 한 줄로 같은 환경 |
| DB | SQLite + SQLAlchemy 2.0 | 맥미니 한 대라 DB 서버가 필요 없음. 파일 하나라 백업이 쉬움 |
| 바깥 공개 | Tailscale Funnel | 공유기 포트를 열지 않고 HTTPS 주소가 생김. GitHub Pages(HTTPS)에서 부르려면 API도 HTTPS여야 함 |
| 배포 | 맥미니가 5분마다 `main`을 확인해 `backend/`가 바뀌었으면 당겨 와 재시작 (4장) | 저장소가 public이라 self-hosted runner를 두면 PR 코드가 맥미니에서 돌 수 있음. 당겨 오는 방식은 바깥에서 맥미니로 들어올 길이 없음 |

## 3. API

모든 경로는 `/v1` 아래에 둡니다. 2단계에서 바뀌면 `/v2`를 따로 둡니다.

| 메서드 | 경로 | 인증 | 하는 일 |
|---|---|---|---|
| `GET` | `/health` | 없음 | `{"status": "ok", "commit": "<배포된 커밋>"}`. 배포 확인용 |
| `POST` | `/v1/vaults` | 없음 | 보관함을 새로 만들고 동기화 코드를 돌려줌. 코드는 이때 한 번만 보여 줌 |
| `GET` | `/v1/backup` | 코드 | 마지막 백업. `ETag`에 리비전. 아직 없으면 404 |
| `PUT` | `/v1/backup` | 코드 | 백업을 통째로 바꿈. `If-Match`가 지금 리비전과 다르면 412 |
| `DELETE` | `/v1/vaults/me` | 코드 | 보관함과 백업을 모두 지움 |

### 3.1 동기화 코드

로그인 대신 보관함마다 무작위 코드를 하나 줍니다. 코드를 아는 기기는 같은 보관함을 씁니다.

- 형식은 `7K3Q-M9XD-2HWB-PF4R-ZC8N`처럼 Crockford Base32 20자(약 100비트)입니다. 다른 기기에서 손으로 넣거나 QR로 옮길 수 있습니다.
- 요청에는 `Authorization: Bearer <코드>`로 실어 보냅니다.
- 서버에는 코드의 SHA-256만 저장합니다. DB 파일이 새어도 코드를 알 수 없습니다.
- 코드를 잃어버리면 되찾을 수 없습니다. 앱 설정 화면에 코드를 보여 주고 어딘가 적어 두라고 안내합니다.
- `POST /v1/vaults`는 누구나 부를 수 있으므로 서버 전체에서 시간당 30개로 막습니다(메모리 카운터).

### 3.2 백업 형식

엑셀 백업(`BackupRepository`)의 세 시트를 그대로 JSON으로 옮깁니다. 앱에서 엑셀과 서버가 같은 변환·합치기 코드를 씁니다.

```json
{
  "schema": 1,
  "exported_at": "2026-11-04T21:30:00+09:00",
  "medications": [
    {"name": "타이레놀정500mg", "category_id": 250, "dose_per_take": 1, "times": ["08:00", "20:00"]}
  ],
  "records": [
    {"taken_at": "2026-11-04T08:05:12+09:00", "medication": "타이레놀정500mg", "count": 1, "source": "camera"}
  ],
  "appearances": [
    {"medication": "타이레놀정500mg", "l": 82.1, "a": -1.3, "b": 6.4, "elongation": 2.31}
  ]
}
```

- 기록과 색·모양은 엑셀처럼 **약 이름으로** 약을 잇습니다. 기기마다 약 `id`가 다르기 때문입니다.
- 시각은 시간대를 붙인 ISO 8601입니다.
- `source`는 `IntakeSource`의 이름(`camera`, `manual`)입니다.
- 사진(`photo_path`)은 넣지 않습니다.
- 서버는 Pydantic으로 형식만 검사하고(개수 > 0, 시간 `HH:mm`, 기록의 약 이름이 `medications`에 있는지) 내용은 손대지 않습니다. 요청 본문은 5MB까지 받습니다. 기록 1만 건이 1MB 남짓입니다.

### 3.3 백업과 복원 흐름

```text
기기 A                          서버                         기기 B
변경 ──(3초 모아서)── PUT  If-Match: 3 ──▶ 리비전 4 저장
                                                ◀── GET ── 동기화 코드 입력
                                                ──▶ 리비전 4 ── 지금 데이터에 합치기(엑셀 가져오기 규칙)
                                                                 PUT If-Match: 4 ──▶ 리비전 5
변경 ── PUT If-Match: 4 ──▶ 412 (5가 있음)
     ◀── GET 리비전 5 ── 합치고 다시 PUT If-Match: 5 ──▶ 리비전 6
```

- **올리기**: 약·기록·색·모양이 바뀌면 3초 모아서 기기의 전체 데이터를 `PUT`합니다. 서버 데이터는 마지막으로 올린 기기의 데이터로 바뀝니다.
- **받기**: 코드를 처음 넣었을 때, 그리고 `PUT`이 412를 받았을 때 `GET`해서 지금 데이터에 **합칩니다**. 합치는 규칙은 엑셀 가져오기와 같습니다(약은 약 번호나 이름이 같으면 같은 약, 기록은 같은 약·시각(초까지)·개수면 건너뜀). 합친 뒤 다시 `PUT`합니다.
- **오프라인**: 올리지 못한 변경은 "올릴 것 있음" 표시만 남기고, 다음에 앱을 열거나 변경이 생길 때 다시 올립니다. 올리는 것은 늘 전체 데이터라 큐가 필요 없습니다.
- 서버는 보관함마다 최근 리비전 10개를 남깁니다. 잘못 덮어썼을 때 맥미니에서 직접 되살리는 용도이고 1단계에는 API가 없습니다.

**1단계의 한계**: 합치기는 더하기만 하므로, 기기 A에서 지운 기록이 아직 그 기록을 가진 기기 B가 합칠 때 되살아납니다. 한 사람이 주로 한 기기에서 쓰고 다른 기기는 가끔 보는 정도라면 문제가 되지 않습니다. 두 기기를 번갈아 쓰게 되면 2단계로 갑니다.

### 3.4 2단계: 변경 단위 동기화 (나중)

| 바꿀 것 | 내용 |
|---|---|
| 앱 DB | 모든 행에 `uid`(UUID), `updated_at`, `deleted_at`. 지우면 행을 남기고 `deleted_at`만 적음 (DB 버전 3) |
| API | `POST /v2/sync {cursor, changes}` → 서버가 `cursor` 이후 바뀐 행을 돌려줌. 같은 `uid`끼리는 `updated_at`이 늦은 쪽이 이김 |
| 서버 DB | 백업 JSON 대신 테이블별로 저장. 이때 Alembic을 넣음 |

## 4. 맥미니 배포

### 4.1 폴더 구조

```text
backend/
├── README.md               # 이 문서
├── pyproject.toml          # fastapi, uvicorn, sqlalchemy, pydantic-settings / dev: pytest, httpx, ruff
├── uv.lock
├── .python-version         # 3.12
├── .env.example
├── app/
│   ├── main.py             # FastAPI 앱, CORS, 라우터 등록, /health
│   ├── config.py           # 설정 (pydantic-settings, PILLBBOX_ 접두사 환경 변수)
│   ├── db.py               # 엔진, 세션, 시작할 때 create_all
│   ├── models.py           # vaults, backups 테이블
│   ├── schemas.py          # 백업 JSON (3.2)
│   ├── auth.py             # 동기화 코드 만들기·검사
│   └── api.py              # /v1 라우터
├── tests/
│   └── test_api.py         # TestClient로 보관함 → PUT → 412 → GET
└── deploy/
    ├── com.pillbbox.api.plist      # uvicorn을 띄우는 launchd 에이전트
    ├── com.pillbbox.update.plist   # 5분마다 update.sh
    ├── update.sh                   # main을 확인해 바뀌었으면 당겨 와 재시작
    └── backup-db.sh                # 매일 SQLite 백업
```

DB 테이블은 둘입니다.

| 테이블 | 열 |
|---|---|
| `vaults` | `id`, `code_hash`(유일), `created_at` |
| `backups` | `id`, `vault_id`, `revision`, `data`(JSON), `created_at`. `(vault_id, revision)` 유일. 보관함마다 최근 10개만 남김 |

설정(`.env`)은 셋뿐입니다.

| 환경 변수 | 예 | 뜻 |
|---|---|---|
| `PILLBBOX_DATABASE_URL` | `sqlite:////Users/<사용자>/pillbbox/data/pillbbox.db` | DB 파일. 코드 폴더 밖에 둠 |
| `PILLBBOX_CORS_ORIGINS` | `https://def-uk.github.io,http://localhost:8080` | 부를 수 있는 웹 주소. 경로 없이 scheme + host |
| `PILLBBOX_COMMIT` | (update.sh가 넣음) | `/health`에 보여 줄 커밋 |

### 4.2 맥미니 준비 (처음 한 번)

```bash
# 1. 도구
brew install uv git
# Tailscale은 앱으로 설치하고 로그인. 관리 화면(Access controls)에서 이 기기에 Funnel을 허용

# 2. 배포용 클론. backend/만 받는다
mkdir -p ~/pillbbox/data ~/pillbbox/backups ~/pillbbox/logs
git clone --filter=blob:none --sparse https://github.com/def-uk/pill-bbox-front.git ~/pillbbox/repo
git -C ~/pillbbox/repo sparse-checkout set backend
cp ~/pillbbox/repo/backend/.env.example ~/pillbbox/.env   # 값 채우기

# 3. 서비스 등록
cp ~/pillbbox/repo/backend/deploy/*.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pillbbox.api.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pillbbox.update.plist

# 4. 바깥에 HTTPS로 공개
tailscale funnel --bg 8000
tailscale funnel status          # https://<맥미니>.<tailnet>.ts.net
curl https://<맥미니>.<tailnet>.ts.net/health
```

- 배포용 클론은 개발용과 따로 둡니다. `update.sh`가 `reset --hard`로 맞추므로 여기서 코드를 고치지 않습니다.
- 맥미니 설정: **잠자기 안 함**(설정 → 에너지 → "디스플레이가 꺼져 있을 때 자동으로 잠자지 않기"), **정전 후 자동 시작** 켬.
- `launchd` 에이전트는 사용자가 로그인해야 뜹니다. 건강 정보라 FileVault는 켜 두고, 그 대신 재부팅 뒤에는 한 번 직접 로그인합니다. 계획한 재부팅은 `sudo fdesetup authrestart`로 로그인까지 건너뜁니다.
- `com.pillbbox.api.plist`는 `KeepAlive`를 켜서 서버가 죽으면 다시 띄우고, 로그는 `~/pillbbox/logs/`에 씁니다.

```xml
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/uv</string>
  <string>run</string><string>--frozen</string><string>--env-file</string><string>/Users/<사용자>/pillbbox/.env</string>
  <string>uvicorn</string><string>app.main:app</string>
  <string>--host</string><string>127.0.0.1</string><string>--port</string><string>8000</string>
</array>
<key>WorkingDirectory</key><string>/Users/<사용자>/pillbbox/repo/backend</string>
<key>KeepAlive</key><true/>
```

uvicorn은 `127.0.0.1`에만 엽니다. 바깥에서는 Funnel을 거쳐서만 들어옵니다.

### 4.3 배포 흐름

```text
작업 브랜치 ──PR──▶ GitHub Actions (backend.yml): ruff, pytest ──▶ main에 합침
                                                                        │
맥미니 update.sh (5분마다) ◀──────── git fetch origin main ─────────────┘
  backend/가 바뀌었나? ── 아니오 → 끝
        │ 예
  reset --hard → uv sync --frozen → launchctl kickstart -k → /health 확인
        │ 실패
  이전 커밋으로 되돌리고 다시 띄움
```

`update.sh`가 하는 일:

1. `git fetch origin main`. `origin/main`과 지금 커밋 사이에 `backend/` 변경이 없으면 끝냅니다.
2. 지금 커밋을 `~/pillbbox/deployed-prev`에 적고 `git reset --hard origin/main`.
3. DB를 `~/pillbbox/backups/`에 복사(`sqlite3 .backup`)하고 `uv sync --frozen`.
4. `.env`의 `PILLBBOX_COMMIT`을 새 커밋으로 바꾸고 `launchctl kickstart -k gui/$(id -u)/com.pillbbox.api`.
5. `/health`가 10초 안에 새 커밋을 돌려주지 않으면 이전 커밋으로 되돌리고 다시 띄웁니다. 실패는 로그에 남깁니다.

맥미니가 GitHub에서 가져오기만 하므로 저장소에 비밀값을 넣을 필요가 없습니다. 바로 배포하고 싶으면 맥미니에서 `~/pillbbox/repo/backend/deploy/update.sh`를 직접 실행합니다.

### 4.4 GitHub Actions

| 워크플로 | 바꿀 것 |
|---|---|
| `backend.yml` (새로) | `backend/**`가 바뀐 PR과 `main` push에서 `uv sync --frozen`, `uv run ruff check`, `uv run pytest`. 웹 배포는 `frontend/**`가 바뀔 때만 돌아 서로 건드리지 않음 |
| `deploy-web.yml` | 빌드에 `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`. 주소는 저장소 Variables에 둠 |

### 4.5 데이터 백업

- `backup-db.sh`가 매일 새벽 `sqlite3 pillbbox.db ".backup ..."`으로 `~/pillbbox/backups/`에 날짜별로 남기고, 14일 넘은 것은 지웁니다.
- 맥미니 Time Machine에 `~/pillbbox/`를 포함합니다.

## 5. 앱 쪽 변경

| 할 것 | 내용 |
|---|---|
| `BackupRepository` | 엑셀 시트 대신 3.2의 JSON으로도 내보내고 합치기(`exportSnapshot`, `importSnapshot`). 엑셀과 합치기 코드를 같이 씀 |
| `ServerBackupService` (새로) | `http` 패키지로 3장 API 호출. `API_BASE_URL`이 비어 있으면 서버 백업 메뉴를 숨김 |
| 동기화 코드 저장 | 기기 DB에 `settings` 테이블(키·값). 코드, 마지막 리비전, "올릴 것 있음" (DB 버전 3) |
| 화면 | 홈 더 보기 메뉴에 "서버 백업": 새 코드 만들기 / 코드 입력 / 코드 보기·복사 / 연결 끊기. 마지막으로 올린 시각 |
| 올리는 때 | 기록 저장·삭제, 약 저장·삭제, 색·모양 추가 뒤 3초 모아서. 앱을 열 때 "올릴 것 있음"이면 한 번 |

로컬 DB가 늘 먼저입니다. 서버가 꺼져 있어도 앱은 지금처럼 돌고, 올리기는 나중에 다시 합니다.

## 6. 로컬 개발

```bash
cd backend
uv sync
cp .env.example .env
uv run uvicorn app.main:app --reload --env-file .env   # http://localhost:8000/docs
uv run pytest
uv run ruff check . && uv run ruff format .
```

앱을 로컬 서버에 붙일 때는 `frontend/`에서 이렇게 띄웁니다.

```bash
cd frontend
fvm flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000
```

## 7. 개발 순서

| 순서 | 할 일 | 끝난 기준 |
|---|---|---|
| 1 | `backend/` 뼈대, `/health`, `backend.yml` | PR에서 pytest가 돎 |
| 2 | 맥미니 준비, launchd, Funnel, `update.sh` | `main`에 합치고 5분 안에 `https://…ts.net/health`가 새 커밋을 보여 줌 |
| 3 | 보관함, `GET`/`PUT /v1/backup`, 412 | 테스트: 코드 없이 401, 리비전이 어긋나면 412, 리비전 10개만 남음 |
| 4 | 앱: `exportSnapshot`/`importSnapshot`, `ServerBackupService`, 설정 화면 | 웹에서 기록 → 사이트 데이터 지우기 → 코드 입력 → 기록이 돌아옴 |
| 5 | 자동 올리기, 오프라인 다시 올리기 | 서버를 끈 채 기록하고 다시 켜면 다음 변경 때 올라감 |
| 6 (나중) | 2단계 동기화 (3.4) | 두 기기에서 지운 기록이 되살아나지 않음 |

## 8. 결정할 것

| 항목 | 기본값 | 정할 사람 |
|---|---|---|
| 서버를 둘지 | 둠. [docs/DESIGN.md](../docs/DESIGN.md) 2장의 "서버 저장·기기 간 동기화 하지 않음"을 이 문서로 바꿈 | 팀 |
| 바깥 공개 방법 | Tailscale Funnel. 도메인이 있으면 Cloudflare Tunnel로 `api.<도메인>`을 써도 됨 | 팀 |
| 건강 정보 보관 | 맥미니 FileVault + 코드 해시만 저장. 서버 데이터는 암호화하지 않음. 필요하면 앱에서 코드로 암호화해 올리고 서버는 읽지 못하게(종단 간 암호화) | 팀 |
| 엑셀 백업을 남길지 | 남김. 서버 없이도 쓸 수 있고, 서버를 내려도 데이터를 옮길 수 있음 | 팀 |
