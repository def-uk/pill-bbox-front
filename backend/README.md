# pillbbox 백엔드

pillbbox 앱의 사진을 모아 탐지 모델을 개선하고, 약·복용 기록을 맡아 두는 FastAPI 서버의 설계 문서입니다. 집에 있는 맥미니 한 대에서 돌리고, 코드는 이 저장소의 `backend/`에 두고, 앱은 `frontend/`에 있습니다.

## 1. 왜 만드는가

두 가지 이유가 있습니다.

**모델 정확도.** 지금 모델(`combofix-v1-fold1`)의 mAP75-95는 검증 데이터와 캐글 제출 점수가 크게 다릅니다.

| 평가 | mAP75-95 | 비고 |
|---|---|---|
| 검증 (fold 1, `results.csv`) | 98.7% | 가장 높은 epoch 16. precision 99.7% |
| 캐글 제출 | 63% | 대회 테스트 사진 |
| 휴대폰 사진 | 모름 | 아직 잰 적 없음 |

검증 점수는 거의 끝까지 찼는데 테스트는 63%입니다. 대회 사진 232장은 같은 배경·조명·각도이고 같은 약이 여러 장에 나와서, fold로 나눠도 검증 사진이 학습 사진과 거의 같기 때문으로 보입니다. 그래서 **검증 점수로는 모델이나 epoch를 고를 수 없습니다**. 같은 대회 사진에서도 63%이니, 사용자가 찍는 휴대폰 사진에서는 더 낮을 수 있습니다. 올리려면 모델 크기보다 **실제 환경 사진**이 필요합니다. 앱은 사용자가 결과를 확인·수정해야 기록이 저장되므로, 저장할 때마다 사용자가 확정한 라벨이 붙은 사진이 생깁니다. 이 사진을 동의를 받아 모읍니다(4장).

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
[휴대폰 브라우저 / 앱]  https://www.<도메인>의 웹 앱. SampleUploader(사진), ServerBackupService(백업)
        │ HTTPS
        ▼
[Cloudflare]  https://www.<도메인>, https://api.<도메인>   Cloudflare Tunnel
        │ 터널 (맥미니의 cloudflared가 바깥으로 연결해 둠)
        ▼
[맥미니]  cloudflared
        │ 127.0.0.1:8100
        ▼
         uvicorn + FastAPI   launchd가 띄우고 죽으면 다시 띄움
        │
        ▼
         SQLite              ~/srv/pillbbox-data/data/pillbbox.db
         사진 파일            ~/srv/pillbbox-data/data/samples/
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
| 바깥 공개 | Cloudflare Tunnel (맥미니에 이미 있는 터널에 호스트 이름 추가) | 맥미니에 다른 프로젝트용 터널과 cloudflared가 이미 있음. 공유기 포트를 열지 않고 HTTPS 주소가 생김. 웹 앱(HTTPS)에서 부르려면 API도 HTTPS여야 함. `www.<도메인>` → `127.0.0.1:8200`(웹), `api.<도메인>` → `127.0.0.1:8100`(API) |
| 배포 | `main`에 합치면 GitHub Actions가 SSH로 맥미니에 들어가 `git pull` 후 `deploy.sh` (5장) | 맥미니에 따로 프로그램을 띄워 둘 필요가 없음. GitHub가 제공하는 러너에서 돌고 `main` push에만 돌아, public 저장소여도 PR 코드가 맥미니에서 돌지 않음 |

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
| `GET` | `/v1/drugs?q=<이름>&page=1` | 없음 | 식약처 의약품을 이름으로 찾음 (3.5). 한 쪽에 20개 |
| `GET` | `/v1/drugs/{item_seq}` | 없음 | 약 정보: 생김새와 복약 정보. 식약처에 없으면 404 |
| `GET` | `/v1/drugs/{item_seq}/image` | 없음 | 낱알 사진. 없으면 404 |

### 3.1 동기화 코드

로그인 대신 보관함마다 무작위 코드를 하나 줍니다. 코드를 아는 기기는 같은 보관함을 씁니다. 사진 수집만 켜고 백업은 쓰지 않아도, 앱이 보관함을 하나 만들어 둡니다. 올린 사진을 지울 때 이 코드로 찾습니다.

- 형식은 `7K3Q-M9XD-2HWB-PF4R-ZC8N`처럼 Crockford Base32 20자(약 100비트)입니다. 다른 기기에서 손으로 넣거나 QR로 옮길 수 있습니다.
- 요청에는 `Authorization: Bearer <코드>`로 실어 보냅니다.
- 서버에는 코드의 SHA-256만 저장합니다. DB 파일이 새어도 코드를 알 수 없습니다.
- 코드를 잃어버리면 되찾을 수 없습니다. 앱 설정 화면에 코드를 보여 주고 어딘가 적어 두라고 안내합니다.
- `POST /v1/vaults`는 누구나 부를 수 있으므로 서버 전체에서 시간당 30개로 막습니다(메모리 카운터). 필요하면 Cloudflare의 Rate limiting 규칙으로 바깥에서도 막습니다.

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

### 3.5 약 정보 (식약처 공공데이터)

모델이 아는 96종 밖의 약도 이름으로 찾아 등록하고, 효능·주의사항·생김새를 보여 주려고 식약처 공공데이터포털 API 두 개를 대신 부릅니다. 인증키를 앱에 넣지 않으려고 서버를 거칩니다(`app/drugs.py`, `app/mfds.py`).

| API | 쓰는 곳 | 활용신청 |
|---|---|---|
| 의약품 낱알식별 정보 (`MdcinGrnIdntfcInfoService03`) | 이름으로 찾기, 모양·색·각인·크기·사진 | https://www.data.go.kr/data/15057639/openapi.do |
| 의약품개요정보 e약은요 (`DrbEasyDrugInfoService`) | 효능, 사용법, 주의사항, 상호작용, 부작용, 보관법 | https://www.data.go.kr/data/15075057/openapi.do |

- 두 API는 품목기준코드(`item_seq`)로 잇습니다. e약은요에는 주로 일반의약품만 있어, 전문의약품은 생김새만 나오고 `guide`가 `null`입니다.
- 인증키는 공공데이터포털 마이페이지의 **일반 인증키(Decoding)**를 `PILLBBOX_MFDS_SERVICE_KEY`에 넣습니다. 비어 있으면 `/v1/drugs`는 503이고 다른 API는 그대로 돕니다.
- 같은 질문은 24시간 메모리에 캐시하고, 캐시에 없어 식약처를 부르는 횟수는 서버 전체에서 시간당 1,000번(`PILLBBOX_DRUG_CALLS_PER_HOUR`)으로 막습니다. 넘으면 429, 식약처가 답하지 않으면 502입니다.
- 웹은 교차 출처 격리(COEP `require-corp`)를 켜서 의약품안전나라의 사진을 바로 읽지 못합니다. 그래서 사진도 서버가 받아 `Cross-Origin-Resource-Policy: cross-origin`을 붙여 돌려줍니다. 응답에 든 주소라도 `nedrug.mfds.go.kr` 밖으로는 받지 않습니다.
- 약학정보원(health.kr)은 공식 오픈 API가 없어 쓰지 않습니다. 사이트 내부 주소를 부르는 방식은 예고 없이 바뀌고 이용 조건도 없습니다. 출처를 `DrugInfoSource`로 감싸 두었으므로, 정식으로 쓸 수 있게 되면 구현만 더하면 됩니다.

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
| mAP75-95 (캐글 63%) | 박스가 정답과 75~95% 넘게 겹치는지. 박스가 꼭 맞아야 점수가 남 | 모델 저장소의 평가. 사람이 박스를 그린 평가 사진이 있어야 함 |
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
- **처음 모인 사진은 평가 세트부터 채웁니다**(보관함 단위로 200장쯤, 박스는 사람이 다시 그림). 검증 점수(98.7%)가 실제(캐글 63%)를 보여 주지 못하므로, 이 평가 세트가 모델과 epoch를 고르는 기준이 됩니다. 기준이 먼저 있어야 모은 사진으로 학습한 모델이 나아졌는지 압니다.
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
├── pyproject.toml          # fastapi, uvicorn, sqlalchemy, pydantic-settings, python-multipart, pillow / dev: pytest, httpx2, ruff
├── uv.lock
├── .python-version         # 3.12
├── .env.example
├── app/
│   ├── main.py             # FastAPI 앱, CORS, 라우터 등록, /health
│   ├── web.py              # 웹 빌드를 내보내는 서버 (www.<도메인>, 8200)
│   ├── config.py           # 설정 (pydantic-settings, PILLBBOX_ 접두사 환경 변수)
│   ├── db.py               # 엔진, 세션, 시작할 때 create_all
│   ├── models.py           # vaults, backups, samples 테이블
│   ├── schemas.py          # 백업 JSON (3.2), 사진 라벨 JSON (4.2)
│   ├── auth.py             # 동기화 코드 만들기·검사
│   ├── photos.py           # JPEG 검사, EXIF 지우기
│   └── api.py              # /v1 라우터
├── scripts/
│   └── export_yolo.py      # 모은 사진을 YOLO 학습 데이터로 (4.5)
├── tests/
│   ├── test_vaults.py      # 코드, 401, 생성 제한, 보관함 지우기, 본문 크기
│   ├── test_backup.py      # PUT → 412 → GET, 리비전 10개
│   ├── test_samples.py     # 사진 올리기·지우기, EXIF, 같은 id
│   └── test_export_yolo.py
└── deploy/
    ├── launchd.plist               # API(com.pillbbox.api, 8100)와 웹(com.pillbbox.web, 8200) 에이전트의 틀
    ├── deploy.sh                   # 의존성 맞추고 재시작, /health 확인, 실패하면 되돌림
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
| `PILLBBOX_DATABASE_URL` | `sqlite:////Users/<사용자>/srv/pillbbox-data/data/pillbbox.db` | DB 파일. 코드 폴더 밖에 둠 |
| `PILLBBOX_SAMPLES_DIR` | `/Users/<사용자>/srv/pillbbox-data/data/samples` | 모은 사진 |
| `PILLBBOX_CORS_ORIGINS` | `https://www.<도메인>,http://localhost:8080` | 부를 수 있는 웹 주소. 경로 없이 scheme + host |
| `PILLBBOX_COMMIT` | (deploy.sh가 넣음) | `/health`에 보여 줄 커밋 |
| `PILLBBOX_MFDS_SERVICE_KEY` | (공공데이터포털 일반 인증키, Decoding) | 약 찾기·약 정보 (3.5). 비우면 꺼짐 |

### 5.2 맥미니 준비 (처음 한 번)

```bash
# 1. 도구
brew install uv git          # cloudflared와 터널은 이미 있음

# 2. 배포용 클론. 첫 배포 때 워크플로가 만들어도 됨
git clone https://github.com/def-uk/pill-bbox-front.git ~/srv/pillbbox

# 3. 첫 배포. 데이터 폴더(~/srv/pillbbox-data), .env, launchd 에이전트(api 8100, web 8200)를 만들고 띄움
bash ~/srv/pillbbox/backend/deploy/deploy.sh

# 4. 배포용 SSH 키. 원격 로그인을 켜고(포트 2222로 열어 둔 경우), 키는 이 저장소 전용으로 따로 만듦
ssh-keygen -t ed25519 -f ~/pillbbox-deploy -N "" -C pillbbox-deploy
cat ~/pillbbox-deploy.pub >> ~/.ssh/authorized_keys
# ~/pillbbox-deploy(비밀 키)를 저장소 secrets의 MAC_MINI_SSH_KEY에 넣고 파일은 지움

# 호스트 키 지문. appleboy/ssh-action은 ECDSA 호스트 키를 먼저 고르므로 ED25519가 아니라 ECDSA 지문을 넣는다.
# 출력의 "SHA256:…"을 앞머리까지 그대로 MAC_MINI_SSH_FINGERPRINT에 넣음. 맥미니를 다시 설치하면 바뀜
ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub

# 5. 바깥에 HTTPS로 공개: Cloudflare Tunnel에 호스트 이름 추가, HTTPS 마무리 (아래)
curl https://api.<도메인>/health
```

#### 터널에 호스트 이름 더하기

맥미니에는 다른 프로젝트용으로 만든 터널이 이미 있습니다. 터널 하나에 호스트 이름을 여러 개 둘 수 있으므로, 새 터널을 만들지 않고 그 터널에 두 개만 더합니다. 기존 호스트 이름은 건드리지 않습니다.

| 호스트 이름 | 서비스 |
|---|---|
| `www.<도메인>` | `http://localhost:8200` (웹, `com.pillbbox.web`) |
| `api.<도메인>` | `http://localhost:8100` (API, `com.pillbbox.api`) |

터널을 어떻게 만들었는지에 따라 더하는 방법이 다릅니다. 어느 쪽인지는 맥미니에서 `ls ~/.cloudflared/`에 `config.yml`이 있는지로 압니다.

- **대시보드에서 만든 터널**(`cloudflared service install <토큰>`으로 설치): Cloudflare Zero Trust → Networks → Tunnels → 그 터널 → Public Hostname에서 위 두 줄을 하나씩 추가. DNS 레코드는 저절로 생기고, 맥미니에서 할 일은 없습니다.
- **설정 파일로 만든 터널**(`~/.cloudflared/config.yml`): `ingress`의 맨 끝(`service: http_status:404`) **앞에** 두 항목을 더하고, DNS를 잇고, cloudflared를 다시 띄웁니다.

  ```yaml
  ingress:
    - hostname: www.<도메인>
      service: http://localhost:8200
    - hostname: api.<도메인>
      service: http://localhost:8100
    # … 이미 있는 항목들
    - service: http_status:404
  ```

  ```bash
  cloudflared tunnel route dns <터널 이름> www.<도메인>
  cloudflared tunnel route dns <터널 이름> api.<도메인>
  ```

인증서는 Cloudflare가 `<도메인>`과 `*.<도메인>`에 저절로 붙입니다. 맥미니와 Cloudflare 사이는 터널이 감싸므로 맥미니에서 인증서를 만들 필요가 없습니다.

#### HTTPS 마무리 (Cloudflare 대시보드, 처음 한 번)

터널만 붙이면 `https://`는 되지만 `http://`로 들어와도 그대로 보여 주고, 앞에 아무것도 없는 `<도메인>`은 열리지 않습니다. 대시보드에서 그 도메인을 골라 아래 셋을 합니다.

1. **http를 https로 보내기**: SSL/TLS → Edge Certificates → **Always Use HTTPS** 켬. 같은 화면의 Minimum TLS Version은 `TLS 1.2`.
2. **`<도메인>`을 `www.<도메인>`으로 보내기**: 리다이렉트 규칙은 Cloudflare 프록시를 지나는 주소에만 걸리므로, 가짜 레코드를 하나 만든 뒤 규칙을 둡니다.
   - DNS → Records → Add record: Type `AAAA`, Name `@`, IPv6 `100::`, Proxy status **Proxied**(주황 구름). `100::`은 아무 데도 가지 않는 주소이고, 요청은 그 전에 Cloudflare가 리다이렉트합니다.
   - Rules → Redirect Rules → Create rule: When incoming requests match → Custom filter expression, Field `Hostname` equals `<도메인>`. Then → Type `Dynamic`, Expression `concat("https://www.<도메인>", http.request.uri.path)`, Status code `301`, **Preserve query string** 켬.
3. **HSTS**(선택): SSL/TLS → Edge Certificates → HTTP Strict Transport Security → Enable. 처음에는 Max Age `1 month`, `includeSubDomains`와 Preload는 끔. 켜 두면 브라우저가 그 기간 동안 http로 들어가지 않으므로, 몇 주 문제없이 쓴 뒤에 늘립니다. 이 도메인에 HTTPS가 아닌 하위 도메인을 둘 계획이 없을 때만 `includeSubDomains`를 켭니다.

확인 (몇 분 걸릴 수 있음):

```bash
curl -sI http://www.<도메인>/ | grep -i -E '^HTTP|^location'     # 301, location: https://www.<도메인>/
curl -sI 'https://<도메인>/foo?a=1' | grep -i -E '^HTTP|^location' # 301, location: https://www.<도메인>/foo?a=1
curl -sI https://www.<도메인>/ | grep -i strict-transport         # HSTS를 켰으면 보임
curl -s https://api.<도메인>/health                               # {"status":"ok","commit":"…"}
```

- 배포용 클론은 개발용과 따로 둡니다. 워크플로가 `git pull --ff-only`로 맞추므로 여기서 코드를 고치지 않습니다. 고치면 다음 배포가 실패합니다.
- DB·사진·`.env`·로그는 클론 밖(`~/srv/pillbbox-data/`)에 둡니다. 클론을 지우고 다시 받아도 데이터는 남습니다.
- 포트는 맥미니의 다른 서비스와 겹치지 않게 `8100`을 씁니다.
- 맥미니 설정: **잠자기 안 함**(설정 → 에너지 → "디스플레이가 꺼져 있을 때 자동으로 잠자지 않기"), **정전 후 자동 시작** 켬.
- `launchd` 에이전트는 사용자가 로그인해야 뜹니다. SSH로 들어온 `deploy.sh`의 `launchctl kickstart gui/…`도 로그인한 세션이 있어야 됩니다. 건강 정보라 FileVault는 켜 두고, 그 대신 재부팅 뒤에는 한 번 직접 로그인합니다. 계획한 재부팅은 `sudo fdesetup authrestart`로 로그인까지 건너뜁니다.
- 두 에이전트(`com.pillbbox.api`, `com.pillbbox.web`)는 `KeepAlive`를 켜서 죽으면 다시 뜨고, 로그는 `~/srv/pillbbox-data/logs/api.log`, `web.log`에 씁니다.

```xml
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/uv</string>
  <string>run</string><string>--frozen</string><string>--env-file</string><string>/Users/<사용자>/srv/pillbbox-data/.env</string>
  <string>uvicorn</string><string>app.main:create_app</string><string>--factory</string>
  <string>--host</string><string>127.0.0.1</string><string>--port</string><string>8100</string>
</array>
<key>WorkingDirectory</key><string>/Users/<사용자>/srv/pillbbox/backend</string>
<key>KeepAlive</key><true/>
```

uvicorn은 `127.0.0.1`에만 엽니다. 바깥에서는 Cloudflare Tunnel을 거쳐서만 들어옵니다. 요청한 사람의 IP는 `CF-Connecting-IP` 헤더에 있습니다.

### 5.3 배포 흐름

```text
작업 브랜치 ──PR──▶ backend.yml: ruff, pytest ──▶ main에 합침
                                                     │ backend/** 가 바뀌었으면 (문서만 바뀌면 건너뜀)
                                                     ▼
                         deploy-backend.yml (GitHub 러너) ──SSH :2222──▶ 맥미니
                                                                         cd ~/srv/pillbbox
                                                                         git pull --ff-only origin main
                                                                         bash backend/deploy/deploy.sh
```

`.github/workflows/deploy-backend.yml`:

```yaml
on:
  push:
    branches: [main]
    paths: ['backend/**', '.github/workflows/deploy-backend.yml', '!**/*.md']
  workflow_dispatch:

concurrency:
  group: deploy-mac-mini        # 이 저장소의 배포를 한 번에 하나씩, 들어온 순서대로
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.MAC_MINI_IP }}
          username: ${{ secrets.MAC_MINI_USERNAME }}
          key: ${{ secrets.MAC_MINI_SSH_KEY }}
          fingerprint: ${{ secrets.MAC_MINI_SSH_FINGERPRINT }}
          port: 2222
          command_timeout: 5m
          # git pull을 먼저 끝내고 스크립트를 부른다. 실행 중인 스크립트 파일을 pull로 바꾸지 않기 위해서다
          script: |
            set -e
            if [ ! -d ~/srv/pillbbox/.git ]; then
              mkdir -p ~/srv
              git clone ${{ github.server_url }}/${{ github.repository }}.git ~/srv/pillbbox
            fi
            cd ~/srv/pillbbox
            git pull --ff-only origin main
            bash backend/deploy/deploy.sh
```

- secrets는 넷입니다: `MAC_MINI_IP`, `MAC_MINI_USERNAME`, `MAC_MINI_SSH_KEY`, `MAC_MINI_SSH_FINGERPRINT`. 키와 지문은 5.2의 배포 전용 키와 ECDSA 호스트 키 지문입니다. 집 IP가 바뀌면 `MAC_MINI_IP`도 바꿔야 하니, 고정 IP가 아니면 DDNS 주소를 넣습니다.

`deploy.sh`가 하는 일:

1. SSH로 들어온 셸에는 Homebrew 경로가 없으므로 `PATH`에 `/opt/homebrew/bin`을 더합니다.
2. DB를 `~/srv/pillbbox-data/backups/`에 복사(`sqlite3 .backup`)하고 `uv sync --frozen`.
3. `.env`의 `PILLBBOX_COMMIT`을 지금 커밋으로 바꾸고 `launchctl kickstart -k gui/$(id -u)/com.pillbbox.api`.
4. `/health`가 20초 안에 지금 커밋을 돌려주는지 봅니다.
5. 아니면 직전 배포 커밋(`~/srv/pillbbox-data/deployed`)으로 `git reset --hard`하고 다시 띄운 뒤 실패로 끝냅니다. 워크플로가 빨간색이 되어 바로 압니다. 직전 커밋은 `main`의 조상이라 다음 배포의 `git pull --ff-only`가 그대로 됩니다.
6. 성공하면 지금 커밋을 `~/srv/pillbbox-data/deployed`에 적습니다.

바로 다시 배포하고 싶으면 Actions에서 `workflow_dispatch`로 돌리거나, 맥미니에서 `cd ~/srv/pillbbox && bash backend/deploy/deploy.sh`를 실행합니다.

### 5.4 GitHub Actions

| 워크플로 | 바꿀 것 |
|---|---|
| `backend.yml` | 모든 PR과 `main` push에서 돌고, `backend/**`가 바뀌었을 때만 `backend-check` job이 `ruff check`, `ruff format --check`, `pytest`를 돌림. main의 필수 체크 |
| `deploy-backend.yml` | 5.3. `main`에 `backend/**`가 합쳐지면 같은 검사를 다시 하고 맥미니에 배포. 끝나면 바깥 `API_BASE_URL/health`가 이 커밋인지 확인 |
| `deploy-web.yml` | `frontend/**`가 바뀌었을 때만 `web-build`(필수 체크)와 배포. 빌드에 `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`, 배포 뒤 바깥 `WEB_BASE_URL/commit.txt`와 COOP/COEP 확인 |

검증 시나리오와 결과는 [docs/CICD.md](../docs/CICD.md)에 있습니다.

### 5.5 데이터 백업

- `backup-db.sh`가 매일 새벽 `sqlite3 pillbbox.db ".backup ..."`으로 `~/srv/pillbbox-data/backups/`에 날짜별로 남기고, 14일 넘은 것은 지웁니다.
- 사진 폴더는 매일 백업하지 않고 Time Machine에 맡깁니다. DB만 있으면 어떤 사진이 있었는지는 압니다.
- 맥미니 Time Machine에 `~/srv/pillbbox-data/`를 포함합니다.

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
uv run uvicorn app.main:create_app --factory --reload --env-file .env   # http://localhost:8000/docs
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
| 2 | 보관함, `POST`/`DELETE /v1/samples`, `export_yolo.py` | 테스트: 코드 없이 401, 같은 `id`를 두 번 올려도 한 장, 지우면 파일도 지워짐, EXIF가 남지 않음 |
| 3 | `GET`/`PUT /v1/backup`, 412 | 테스트: 리비전이 어긋나면 412, 리비전 10개만 남음 |
| 4 | 앱: 박스별 결과, 동의 화면, `SampleUploader` | 로컬 서버에 붙여 웹에서 찍은 사진과 바꾼 약이 쌓임 |
| 5 (나중) | 맥미니 배포: launchd, 터널 호스트 이름과 도메인, `deploy.sh`, `deploy-backend.yml` | `main`에 합치면 워크플로가 끝날 때 `https://api.<도메인>/health`가 새 커밋을 보여 줌. 일부러 깨뜨린 커밋은 되돌려지고 워크플로가 실패 |
| 6 | 휴대폰 평가 세트 먼저, 검수(박스 포함), 학습 | 모은 사진을 더해 학습한 모델이, 보관함 단위로 떼어 둔 휴대폰 평가 세트에서 mAP75-95와 그대로 저장한 비율 모두 지금 모델보다 나음. 지금 모델의 휴대폰 점수를 먼저 잼 |
| 7 | 앱: `exportSnapshot`/`importSnapshot`, `ServerBackupService`, 자동 올리기 | 웹에서 기록 → 사이트 데이터 지우기 → 코드 입력 → 기록이 돌아옴 |
| 8 (나중) | 2단계 동기화 (3.4), 서버 추론 (4.6) | 필요해졌을 때 |

API(1~3)와 앱(4)은 로컬 서버로 먼저 만들고, 맥미니 배포와 도메인(5)은 그 뒤에 붙입니다. 정확도가 급하므로 수집을 백업 화면(7)보다 먼저 합니다.

## 9. 결정할 것

| 항목 | 기본값 | 정할 사람 |
|---|---|---|
| 서버를 둘지 | 둠. [docs/DESIGN.md](../docs/DESIGN.md) 2장의 "서버 저장·기기 간 동기화 하지 않음"과 3.2의 "약 사진이 기기 밖으로 안 나감"을 이 문서로 바꿈 | 팀 |
| 추론 위치 | 기기 안 그대로. 서버 추론은 큰 모델이 필요하거나 휴대폰이 느리다고 확인되면 (4.6) | 팀 |
| 사진 보관 기간 | 1년. 검수해 학습 데이터로 옮긴 사진은 모델 저장소 규칙을 따름 | 팀 |
| 수집 동의 문구 | 4.3의 항목. 팀 밖 사람에게 열기 전에 개인정보 처리방침과 민감정보 동의가 법에 맞는지 확인 | 팀 |
| 검수 도구 | 처음에는 내보낸 폴더를 직접 봄. 많아지면 Label Studio 같은 도구 | 모델 팀 |
| 바깥 공개 방법 | 맥미니의 기존 Cloudflare Tunnel에 `www.<도메인>`, `api.<도메인>` 추가. 그 터널을 지우거나 옮기면 이 서버도 끊기므로, 다른 프로젝트와 따로 관리하고 싶으면 이 저장소용 터널을 새로 만듦(cloudflared 하나로 터널 둘을 돌릴 수 있음). 도메인은 터널과 같은 Cloudflare 계정에 있어야 함 | 팀 |
| 건강 정보 보관 | 맥미니 FileVault + 코드 해시만 저장. 서버 데이터는 암호화하지 않음. 백업은 필요하면 앱에서 코드로 암호화해 올릴 수 있음(종단 간 암호화). 사진은 학습에 써야 하므로 서버가 읽을 수 있어야 함. Cloudflare Tunnel은 Cloudflare에서 HTTPS를 풀었다가 다시 감싸므로, 사진과 백업이 Cloudflare를 지남. 수집 동의 화면의 "어디에"에 적음 | 팀 |
| 엑셀 백업을 남길지 | 남김. 서버 없이도 쓸 수 있고, 서버를 내려도 데이터를 옮길 수 있음 | 팀 |
