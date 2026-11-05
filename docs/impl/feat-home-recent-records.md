# 홈 빈 화면을 최근 기록으로 바꾸기

## 목적

오늘 일정도 기록도 없을 때 홈 아래(`_EmptyGuide`)에는 제목, 긴 안내 문단, "복용 시간 정하기" 버튼, "이렇게 찍어 주세요" 가이드가 한꺼번에 나옵니다. 무대 아래가 설명서처럼 길어지고, 이미 앱을 쓰던 사람도 오늘 기록이 없으면 매번 같은 안내를 봅니다.

- 홈 빈 화면에는 "오늘 기록이 없습니다"와 최근 기록만 둡니다. 어제까지 무엇을 먹었는지가 오늘 무엇을 할지보다 먼저 궁금한 정보입니다.
- "복용 시간 정하기"는 아래 바의 약 관리 탭이 같은 일을 합니다. 홈에서는 뺍니다.
- 찍는 법 가이드는 찍기 직전에 보는 기록하기 시트로 옮깁니다.

## 범위

- 프론트만 바뀝니다. 백엔드, DB 구조는 그대로입니다.
- 오늘 일정이나 기록이 있을 때의 홈(오늘의 퀘스트, 일정 외 기록)은 그대로입니다.
- 약 관리 탭의 빈 화면(처방 등록, 약 등록)은 그대로입니다.

## 설계

### 홈 빈 화면 (`lib/ui/home/home_screen.dart`)

`_EmptyGuide`를 `_RecentRecords`로 바꿉니다.

```text
오늘 기록이 없습니다                       (headlineMedium)
아래 기록하기로 알약 사진을 찍어 보세요       (한 줄, inkMuted)

[최근 기록                      전체 보기 >]   ← GroupCard, 헤더 오른쪽은 /history로
 📷 샘플약 A     11월 4일 08:12        2정
 ✏️ 샘플약 B     11월 4일 08:10        1정
 ...최대 5개, 최근 것부터
```

- 기록이 하나도 없으면 카드 없이 제목과 한 줄 안내만 둡니다.
- 줄을 누르면 그 날짜 기록 화면(`/history/<dateKey>`)으로 갑니다.
- 줄 모양은 지금 "일정 외 기록" 카드의 `_Row`를 그대로 씁니다(사진/직접 아이콘, 이름, 시각, 개수). 부제만 "11월 4일 08:12"처럼 날짜를 붙입니다.

### 기록하기 시트 (`lib/ui/shell/app_shell.dart`)

`showCaptureSheet`의 세 버튼 아래 "샘플 사진" 안내 문구 위에 "이렇게 찍어 주세요" 세 줄(단색 배경 위에 놓기, 바로 위에서 수직으로 찍기, 알약끼리 떨어지게 놓기)을 `surfaceSunken` 상자로 넣습니다. 지금 홈 가이드와 같은 아이콘·문구입니다.

시트가 길어져 작은 화면에서는 기본 높이(화면의 9/16)를 넘으므로 `isScrollControlled: true`로 열고 내용을 `SingleChildScrollView`로 감쌉니다.

### ViewModel (`lib/ui/home/home_view_model.dart`)

- `List<IntakeRecord> recent`를 추가합니다. `load()`에서 `_intakes.recentRecords(limit: recentLimit)`로 채웁니다.
- `static const recentLimit = 5`.

### Repository (`lib/data/repositories/intake_repository.dart`)

- `Future<List<IntakeRecord>> recentRecords({required int limit})`: `ORDER BY taken_at DESC, id DESC LIMIT ?`. 최근 것부터.

### 공용 함수 (`lib/utils/time_format.dart`)

- `formatMonthDayTime(DateTime)` → `11월 4일 08:12`. 이미 있는 `formatTime`을 씁니다.

### 라우트

새 라우트는 없습니다. `/history`, `/history/:date`를 씁니다.

### 문서

- `docs/DESIGN.md` 3장 표의 "휴대폰 사진과 학습 사진의 차이" 대응을 "기록하기 시트에 가이드 표시"로 고칩니다.

## 작업 순서

1. `intake_repository.dart`: `recentRecords` 추가
2. `time_format.dart`: `formatMonthDayTime` 추가
3. `home_view_model.dart`: `recent` 로드
4. `home_screen.dart`: `_EmptyGuide` → `_RecentRecords`, 복용 시간 정하기·가이드 제거
5. `app_shell.dart`: 기록하기 시트에 찍는 법 가이드 추가
6. 테스트 수정·추가
7. `docs/DESIGN.md` 수정

## 검증

- 테스트 수정: `app_flow_test`, `prescription_flow_test`, `drug_info_flow_test`, `age_gate_flow_test`는 홈의 "복용 시간 정하기"를 눌러 약 관리로 갔습니다. 아래 바의 "약 관리" 탭을 누르도록 바꿉니다. 첫 화면 확인은 "오늘 기록이 없습니다"로 합니다.
- 테스트 추가
  - `intake_repository` 단위: `recentRecords`가 최근 것부터 `limit`개만 준다.
  - `home_view_model_test`: 어제 기록이 있고 오늘이 비면 `isEmpty`이고 `recent`에 어제 기록이 있다.
  - 위젯 흐름(`home_recent_flow_test`, 새 파일): 어제 기록이 있으면 홈에 "최근 기록"과 약 이름이 보이고 "복용 시간 정하기"는 없다. "전체 보기"는 기록 탭으로 가고, 기록하기 시트에 "이렇게 찍어 주세요"가 보인다.
- `fvm flutter analyze`, `fvm flutter test`
- 직접 확인: `fvm flutter run -d chrome`으로 기록 없는 상태, 어제 기록만 있는 상태의 홈과 기록하기 시트.
