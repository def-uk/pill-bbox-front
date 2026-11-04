# pillbbox 백엔드

pillbbox 앱의 사진을 모아 탐지 모델을 개선하고, 약·복용 기록을 맡아 두는 FastAPI 서버의 설계 문서입니다. 집에 있는 맥미니 한 대에서 돌리고, 코드는 이 저장소의 `backend/`에 두고, 앱은 `frontend/`에 있습니다.

## 1. 왜 만드는가

두 가지 이유가 있습니다.

**모델 정확도.** 지금 모델은 mAP75-95가 63% 정도입니다. 학습 데이터가 정해진 배경·조명·각도에서 찍은 대회 사진 232장뿐이라([docs/DESIGN.md](../docs/DESIGN.md) 3.1), 사용자가 실제로 찍는 사진과 차이가 큽니다. 올리려면 모델 크기보다 **실제 환경 사진**이 필요합니다. 앱은 사용자가 결과를 확인·수정해야 기록이 저장되므로, 저장할 때마다 사용자가 확정한 라벨이 붙은 사진이 생깁니다. 이 사진을 동의를 받아 모읍니다(4장).

**기록 보관.** 웹은 기록이 **그 브라우저에만** 남습니다([docs/DESIGN.md](../docs/DESIGN.md) 5.2). 사이트 데이터를 지우거나 iOS Safari가 저장소를 비우면 기록이 사라지고, 지금은 엑셀로 내보내 두는 수밖에 없습니다. 서버에 자동으로 백업해 두면 이 걱정이 없어지고, 다른 기기나 브라우저에서도 기록을 이어 씁니다.

| 구분 | 내용 |
|---|---|
| 1단계 (이번) | 사진 수집: 동의한 사용자가 기록을 저장하면 사진과 확정한 라벨을 올림. 모은 사진을 YOLO 학습 데이터로 내보냄 |
| 1단계 (이번) | 백업: 기기 데이터를 서버에 통째로 백업하고, 다른 기기에서 받아 합치기. 로그인 없이 "동기화 코드" 하나로 |
| 2단계 (필요해지면) | 변경 단위 동기화. 두 기기를 번갈아 써도 지운 기록이 되살아나지 않게 |
| 2단계 (필요해지면) | 서버 추론. 기기에 넣기 어려운 큰 모델이 필요해지면 (4.6) |
| 하지 않음 | 회원가입·로그인, 여러 사람이 데이터 공유 |

**탐지는 계속 기기 안에서** 합니다. 맥미니가 꺼져도 기록은 되어야 하고, 수집에는 서버 추론이 필요 없기 때문입니다(4.6). 사진은 수집에 동의한 사용자의 것만 올라가고, 백업에는 엑셀 백업과 같은 내용(약, 복용 시간, 기록, 색·모양)만 올라갑니다.

## 2. 구성

```text
[휴대폰 브라우저 / 앱]  GitHub Pages의 웹 앱. SampleUploader(사진), ServerBackupService(백업)
        │ HTTPS
        ▼
[맥미니]  Tailscale Funnel   https://<맥미니>.<tailnet>.ts.net
        │ 127.0.0.1:8000
        ▼
         uvicorn + FastAPI   launchd가 띄우고 죽으면 다시 띄움
        │
        ▼
         SQLite              ~/pillbbox/data/pillbbox.db
         사진 파일            ~/pillbbox/data/samples/
        │ export_yolo.py
        ▼
[Mac Studio]  pill-bbox 저장소에서 학습 → 새 모델 태그 → 앱에 배포
```

| 항목 | 고른 것 | 이유 |
|---|---|---|
| 프레임워크 | FastAPI, Pydantic v2 | 빠르게 만들 수 있고 `/docs`에 API 문서가 저절로 생김 |
| 실행 | uvicorn 하나, `launchd`가 띄우고 죽으면 다시 띄움 | 사용자가 몇 명이라 워커 하나로 충분. Docker 없이 맥에 기본으로 있는 것만 씀 |
| 패키지 | [uv](https://docs.astral.sh/uv/) (`uv.lock`으로 고정) | 모델 스크립트에서 이미 씀. 맥미니에서 `uv sync --frozen` 한 줄로 같은 환경 |
| DB | SQLite + SQLAlchemy 2.0 | 맥미니 한 대라 DB 서버가 필요 없음. 파일 하나라 백업이 쉬움 |
| 사진 | DB 밖 파일 (`samples/<연-월>/<id>.jpg`) | 장당 약 20KB. 하루 1,000장이어도 20MB |
| 바깥 공개 | Tailscale Funnel | 공유기 포트를 열지 않고 HTTPS 주소가 생김. GitHub Pages(HTTPS)에서 부르려면 API도 HTTPS여야 함 |
| 배포 | 맥미니가 5분마다 `main`을 확인해 `backend/`가 바뀌었으면 당겨 와 재시작 (5장) | 저장소가 public이라 self-hosted runner를 두면 PR 코드가 맥미니에서 돌 수 있음. 당겨 오는 방식은 바깥에서 맥미니로 들어올 길이 없음 |

## 3. API

모든 경로는 `/v1` 아래에 둡니다. 2단계에서 바뀌면 `/v2`를 따로 둡니다.

| 메서드 | 경로 | 인증 | 하는 일 |
|---|---|---|---|
| `GET` | `/health` | 없음 | `{"status": "ok", "commit": "<배포된 커밋>"}`. 배포 확인용 |
| `POST` | `/v1/vaults` | 없음 | 보관함을 새로 만들고 동기화 코드를 돌려줌. 코드는 이때 한 번만 보여 줌 |
| `GET` | `/v1/backup` | 코드 | 마지막 백업. `ETag`에 리비전. 아직 없으면 404 |
| `PUT` | `/v1/backup` | 코드 | 백업을 통째로 바꿈. `If-Match`가 지금 리비전과 다르면 412 |
| `POST` | `/v1/samples` | 코드 | 사진 한 장과 라벨을 올림 (4.2). 같은 `id`를 다시 올리면 그대로 200 |
| `DELETE` | `/v1/samples` | 코드 | 이 보관함이 올린 사진을 모두 지움 |
| `DELETE` | `/v1/vaults/me` | 코드 | 보관함, 백업, 사진을 모두 지움 |

### 3.1 동기화 코드

로그인 대신 보관함마다 무작위 코드를 하나 줍니다. 코드를 아는 기기는 같은 보관함을 씁니다. 사진 수집만 켜고 백업은 쓰지 않아도, 앱이 보관함을 하나 만들어 둡니다. 올린 사진을 지울 때 이 코드로 찾습니다.

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

## 4. 사진 수집

### 4.1 무엇이 쓸모 있는가

결과 확인 화면에서 사용자가 한 일이 그대로 라벨이 됩니다. 사용자가 손댄 사진이 특히 값집니다. 모델이 틀린 곳이기 때문입니다.

| 사용자가 한 일 | 학습에서의 쓰임 |
|---|---|
| 모델 결과를 그대로 저장 | 실제 환경에서 맞힌 예 |
| 박스를 눌러 다른 약으로 바꿈 | 틀린 예. 닮은 약을 구분하게 함 |
| 알 수 없는 물체에 약을 고름 | 모델이 놓친 알약. 박스는 `findObjects`가 찾은 것 |
| "약이 아님"으로 뺌 | 알약이 아닌데 잡은 것. 그 자리는 배경으로 학습 |
| 96종 밖의 약을 직접 등록 | 지금은 학습하지 못함. 많이 모이면 클래스를 늘릴 근거 |

모델 버전별로 "모델 결과를 그대로 저장한 박스의 비율"을 보면, 실제 사진에서의 정확도를 새 모델마다 따로 재지 않아도 알 수 있습니다.

지표는 둘을 따로 봅니다.

| 지표 | 무엇을 재나 | 어디서 |
|---|---|---|
| mAP75-95 (지금 63%) | 박스가 정답과 75~95% 넘게 겹치는지. 박스가 꼭 맞아야 점수가 남 | 모델 저장소의 평가. 사람이 박스를 그린 평가 사진이 있어야 함 |
| 그대로 저장한 비율 | 약 종류와 개수를 맞혔는지 | 모은 사진에서 저절로 나옴 |

앱에 중요한 것은 약 종류와 개수라 뒤쪽이 사용자가 느끼는 정확도에 더 가깝습니다([docs/DESIGN.md](../docs/DESIGN.md) 3.1). 박스가 조금 어긋나도 약과 개수만 맞으면 기록은 맞습니다.

### 4.2 올리는 내용

기록을 저장할 때 앱이 사진과 아래 JSON을 `multipart/form-data`로 올립니다.

```json
{
  "id": "0b6f3c1e-5d0a-4e57-9a51-2b1f0c7e9d42",
  "model_version": "combofix-v1-fold1-w8",
  "platform": "web",
  "app_version": "0.1.0+1",
  "captured_on": "2026-11-04",
  "width": 640, "height": 480,
  "boxes": [
    {"box": [102, 88, 171, 140], "from": "model",
     "predicted": {"category_id": 250, "confidence": 0.81, "alternatives": [{"category_id": 1899, "confidence": 0.62}]},
     "final": {"category_id": 1899, "name": "…"}, "action": "changed"},
    {"box": [300, 210, 352, 251], "from": "finder", "predicted": null,
     "final": {"category_id": null, "name": "비타민C"}, "action": "picked"},
    {"box": [410, 60, 470, 115], "from": "model",
     "predicted": {"category_id": 250, "confidence": 0.55}, "final": null, "action": "removed"}
  ]
}
```

- `id`는 앱이 만든 UUID입니다. 올리다 끊겨 다시 올려도 한 장으로 남습니다.
- `box`는 올린 사진의 픽셀 좌표 `[x1, y1, x2, y2]`, `from`은 박스를 누가 찾았는지(`model` 탐지 모델, `finder` 색으로 찾은 물체)입니다.
- `action`은 `kept`(그대로), `changed`(다른 약으로 바꿈), `picked`(알 수 없는 물체에 약을 고름), `removed`(약이 아님)입니다.
- 사진은 기기에 저장하는 것과 같은 긴 변 640px JPEG입니다. 모델 입력도 640이라 학습에 충분합니다.
- **올리기 전에 꼭 JPEG로 다시 씁니다.** 지금 `shrinkPhoto`는 이미 작은 JPEG이면 그대로 돌려주므로, 위치 같은 EXIF가 남을 수 있습니다.
- 찍은 시각은 날짜까지만 보냅니다. 복용 시각은 학습에 필요 없습니다.
- 서버는 사진이 JPEG이고 1MB 이하인지, 박스가 사진 안에 있는지만 검사합니다. 보관함마다 하루 300장까지 받습니다.

### 4.3 동의와 개인정보

약 사진과 먹는 약은 건강 정보입니다. 개인정보보호법상 민감정보에 들어갈 수 있어, 따로 분명하게 동의를 받습니다.

- **기본은 꺼짐**입니다. 앱 설정의 "사진을 보내 인식 개선에 참여" 화면에서 무엇을(사진, 약 이름), 왜(모델 학습), 어디에(운영자의 서버), 얼마나 오래(9장의 보관 기간) 두는지, 어떻게 지우는지를 보여 주고 켜게 합니다.
- 켠 뒤에 저장한 기록의 사진만 올립니다. 결과 확인 화면에 "이 사진은 인식 개선에 쓰입니다"를 작게 보여 주고, 이번 사진만 빼는 체크를 둡니다.
- 사진 가이드(단색 배경 위에 약만)를 다시 보여 줍니다. 얼굴이나 처방전이 찍히지 않게 하기 위해서입니다.
- 끄면 아직 올리지 않은 사진은 버리고, "올린 사진도 지우기"(`DELETE /v1/samples`)를 고를 수 있게 합니다. 이미 학습한 모델에서 그 사진을 빼낼 수는 없다는 것도 함께 알립니다.

### 4.4 올리는 흐름

```text
결과 확인 → 저장 ──▶ 기기 DB에 기록 저장 (지금과 같음)
                └─▶ 수집이 켜져 있으면 pending_samples에 (기록 id, 라벨 JSON) 추가
                         │
            앱을 열 때, 저장할 때 ──▶ POST /v1/samples ──▶ 성공하면 pending_samples에서 지움
                                       실패하면 남겨 두고 다음에 다시
```

사진은 기록과 함께 이미 기기에 저장되어 있으므로, 대기열에는 기록 id와 라벨만 둡니다. 올리기 전에 그 기록을 지웠으면 사진도 올리지 않습니다.

### 4.5 학습으로 넘기기

```text
맥미니 samples ──export_yolo.py──▶ YOLO 폴더 ──검수──▶ pill-bbox 저장소 학습 (Mac Studio)
       ▲                                                       │
       └──── 앱 배포 (VERSION 바꿈) ◀── 새 모델 태그 Release ◀──┘
```

- `backend/scripts/export_yolo.py --since 2026-11-01 --out <폴더>`가 `images/`, `labels/`(YOLO txt)를 만듭니다. 약 번호는 `labels.json`으로 `yolo_idx`로 바꾸고, `removed` 박스는 빼며, 96종 밖의 약은 따로 목록으로 남깁니다.
- **학습 전에 사람이 검수**합니다. 사용자가 확인하지 않고 저장했을 수 있고, `finder` 박스는 색 덩어리라 꼭 맞지 않을 수 있습니다. 처음에는 `changed`·`picked`·`removed`가 있는 사진부터 봅니다.
- **박스도 검수할 때 맞춥니다.** 사용자는 약만 고르고 박스는 그리지 않습니다. 모델이나 `findObjects`가 친 박스를 그대로 정답으로 학습하면 약 구분은 나아져도 박스는 정확해지지 않고, mAP75-95는 오히려 떨어질 수 있습니다. 평가용 사진은 반드시 사람이 박스를 다시 그립니다.
- 평가 데이터는 보관함 단위로 나눕니다. 한 사람이 같은 약을 여러 번 찍으므로, 사진 단위로 나누면 평가가 실제보다 좋게 나옵니다.
- 배포한 뒤에는 4.1의 "그대로 저장한 비율"을 모델 버전별로 비교해 정말 나아졌는지 봅니다.

### 4.6 서버 추론은 왜 지금 하지 않는가

수집하는 데 서버 추론은 필요 없습니다. 쓸모 있는 라벨은 사용자가 확인·수정하고 저장한 **뒤에** 생기므로, 어차피 저장할 때 올려야 합니다. 추론까지 서버로 옮기면 맥미니가 꺼지거나 집 인터넷이 끊기거나 정전이 났을 때 사진 기록 자체가 안 됩니다. 수집에 동의하지 않은 사람의 사진도 서버로 가게 됩니다.

맥미니 한 대의 부하는 문제가 되지 않습니다. 사진이 장당 약 20KB이고 하루에 몇 번 찍는 앱이라 워커 하나로 충분합니다. 기기에 넣기 어려운 큰 모델이 필요해지거나, 휴대폰 웹에서 추론이 너무 느리다고 실제로 확인되면 그때 붙입니다.

- 서버에 `POST /v1/detect`(사진을 받아 박스·약·신뢰도를 돌려줌, 사진은 저장하지 않음)를 둡니다.
- 앱에 `ServerPillDetector`를 더합니다. `PillDetector` 인터페이스 뒤에 있어 화면은 바꾸지 않습니다.
- 서버에 닿지 않으면 기기 안 추론으로 돌아갑니다.

## 5. 맥미니 배포

### 5.1 폴더 구조

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
│   ├── models.py           # vaults, backups, samples 테이블
│   ├── schemas.py          # 백업 JSON (3.2), 사진 라벨 JSON (4.2)
│   ├── auth.py             # 동기화 코드 만들기·검사
│   └── api.py              # /v1 라우터
├── scripts/
│   └── export_yolo.py      # 모은 사진을 YOLO 학습 데이터로 (4.5)
├── tests/
│   └── test_api.py         # TestClient로 보관함 → PUT → 412 → GET, 사진 올리기·지우기
└── deploy/
    ├── com.pillbbox.api.plist      # uvicorn을 띄우는 launchd 에이전트
    ├── com.pillbbox.update.plist   # 5분마다 update.sh
    ├── update.sh                   # main을 확인해 바뀌었으면 당겨 와 재시작
    └── backup-db.sh                # 매일 SQLite 백업
```

DB 테이블은 셋입니다.

| 테이블 | 열 |
|---|---|
| `vaults` | `id`, `code_hash`(유일), `created_at` |
| `backups` | `id`, `vault_id`, `revision`, `data`(JSON), `created_at`. `(vault_id, revision)` 유일. 보관함마다 최근 10개만 남김 |
| `samples` | `id`(앱이 만든 UUID), `vault_id`, `model_version`, `platform`, `meta`(4.2의 JSON), `photo_path`, `created_at`, `reviewed_at`(검수한 때) |

설정(`.env`)은 넷뿐입니다.

| 환경 변수 | 예 | 뜻 |
|---|---|---|
| `PILLBBOX_DATABASE_URL` | `sqlite:////Users/<사용자>/pillbbox/data/pillbbox.db` | DB 파일. 코드 폴더 밖에 둠 |
| `PILLBBOX_SAMPLES_DIR` | `/Users/<사용자>/pillbbox/data/samples` | 모은 사진 |
| `PILLBBOX_CORS_ORIGINS` | `https://def-uk.github.io,http://localhost:8080` | 부를 수 있는 웹 주소. 경로 없이 scheme + host |
| `PILLBBOX_COMMIT` | (update.sh가 넣음) | `/health`에 보여 줄 커밋 |

### 5.2 맥미니 준비 (처음 한 번)

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

### 5.3 배포 흐름

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

### 5.4 GitHub Actions

| 워크플로 | 바꿀 것 |
|---|---|
| `backend.yml` (새로) | `backend/**`가 바뀐 PR과 `main` push에서 `uv sync --frozen`, `uv run ruff check`, `uv run pytest`. 웹 배포는 `frontend/**`가 바뀔 때만 돌아 서로 건드리지 않음 |
| `deploy-web.yml` | 빌드에 `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`. 주소는 저장소 Variables에 둠 |

### 5.5 데이터 백업

- `backup-db.sh`가 매일 새벽 `sqlite3 pillbbox.db ".backup ..."`으로 `~/pillbbox/backups/`에 날짜별로 남기고, 14일 넘은 것은 지웁니다.
- 사진 폴더는 매일 백업하지 않고 Time Machine에 맡깁니다. DB만 있으면 어떤 사진이 있었는지는 압니다.
- 맥미니 Time Machine에 `~/pillbbox/`를 포함합니다.

## 6. 앱 쪽 변경

| 할 것 | 내용 |
|---|---|
| 박스별 결과 남기기 | `ResultViewModel`이 저장할 때 박스마다 모델 결과·최종 약·`action`을 모아 4.2의 JSON을 만듦. 지금도 `_corrections`, `_alternatives`, `_picked`에 거의 다 있음 |
| `SampleUploader` (새로) | `pending_samples` 대기열(DB 버전 3)을 `POST /v1/samples`로 올림. 올리기 전에 사진을 JPEG로 다시 써서 EXIF를 지움 |
| 수집 동의 화면 | 4.3. 기본 꺼짐. 켜면 보관함이 없을 때 하나 만듦. 끄면 올린 사진 지우기를 고름 |
| `BackupRepository` | 엑셀 시트 대신 3.2의 JSON으로도 내보내고 합치기(`exportSnapshot`, `importSnapshot`). 엑셀과 합치기 코드를 같이 씀 |
| `ServerBackupService` (새로) | `http` 패키지로 3장 API 호출. `API_BASE_URL`이 비어 있으면 서버 백업 메뉴를 숨김 |
| 동기화 코드 저장 | 기기 DB에 `settings` 테이블(키·값). 코드, 수집 동의, 마지막 리비전, "올릴 것 있음" (DB 버전 3) |
| 화면 | 홈 더 보기 메뉴에 "서버 백업": 새 코드 만들기 / 코드 입력 / 코드 보기·복사 / 연결 끊기. 마지막으로 올린 시각 |
| 올리는 때 | 기록 저장·삭제, 약 저장·삭제, 색·모양 추가 뒤 3초 모아서. 앱을 열 때 "올릴 것 있음"이면 한 번 |

로컬 DB가 늘 먼저입니다. 서버가 꺼져 있어도 앱은 지금처럼 돌고, 올리기는 나중에 다시 합니다.

## 7. 로컬 개발

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

## 8. 개발 순서

| 순서 | 할 일 | 끝난 기준 |
|---|---|---|
| 1 | `backend/` 뼈대, `/health`, `backend.yml` | PR에서 pytest가 돎 |
| 2 | 맥미니 준비, launchd, Funnel, `update.sh` | `main`에 합치고 5분 안에 `https://…ts.net/health`가 새 커밋을 보여 줌 |
| 3 | 보관함, `POST`/`DELETE /v1/samples` | 테스트: 코드 없이 401, 같은 `id`를 두 번 올려도 한 장, 지우면 파일도 지워짐 |
| 4 | 앱: 박스별 결과, 동의 화면, `SampleUploader` | 팀원이 웹에서 찍은 사진과 바꾼 약이 맥미니에 쌓임. EXIF가 없음 |
| 5 | `export_yolo.py`, 검수(박스 포함), 학습 | 모은 사진을 더해 학습한 모델이, 보관함 단위로 떼어 둔 휴대폰 평가 사진에서 mAP75-95와 그대로 저장한 비율 모두 지금 모델보다 나음 |
| 6 | `GET`/`PUT /v1/backup`, 412 | 테스트: 리비전이 어긋나면 412, 리비전 10개만 남음 |
| 7 | 앱: `exportSnapshot`/`importSnapshot`, `ServerBackupService`, 자동 올리기 | 웹에서 기록 → 사이트 데이터 지우기 → 코드 입력 → 기록이 돌아옴 |
| 8 (나중) | 2단계 동기화 (3.4), 서버 추론 (4.6) | 필요해졌을 때 |

정확도가 급하므로 수집(3~5)을 백업(6~7)보다 먼저 합니다.

## 9. 결정할 것

| 항목 | 기본값 | 정할 사람 |
|---|---|---|
| 서버를 둘지 | 둠. [docs/DESIGN.md](../docs/DESIGN.md) 2장의 "서버 저장·기기 간 동기화 하지 않음"과 3.2의 "약 사진이 기기 밖으로 안 나감"을 이 문서로 바꿈 | 팀 |
| 추론 위치 | 기기 안 그대로. 서버 추론은 큰 모델이 필요하거나 휴대폰이 느리다고 확인되면 (4.6) | 팀 |
| 사진 보관 기간 | 1년. 검수해 학습 데이터로 옮긴 사진은 모델 저장소 규칙을 따름 | 팀 |
| 수집 동의 문구 | 4.3의 항목. 팀 밖 사람에게 열기 전에 개인정보 처리방침과 민감정보 동의가 법에 맞는지 확인 | 팀 |
| 검수 도구 | 처음에는 내보낸 폴더를 직접 봄. 많아지면 Label Studio 같은 도구 | 모델 팀 |
| 바깥 공개 방법 | Tailscale Funnel. 도메인이 있으면 Cloudflare Tunnel로 `api.<도메인>`을 써도 됨 | 팀 |
| 건강 정보 보관 | 맥미니 FileVault + 코드 해시만 저장. 서버 데이터는 암호화하지 않음. 백업은 필요하면 앱에서 코드로 암호화해 올릴 수 있음(종단 간 암호화). 사진은 학습에 써야 하므로 서버가 읽을 수 있어야 함 | 팀 |
| 엑셀 백업을 남길지 | 남김. 서버 없이도 쓸 수 있고, 서버를 내려도 데이터를 옮길 수 있음 | 팀 |
