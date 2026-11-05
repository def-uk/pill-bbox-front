---
version: alpha
name: pillbbox-design-system
description: 알약 사진 한 장으로 복용 기록을 남기는 앱의 디자인 시스템. 로고의 블루바이올렛(#452AF8)과 크림(#FEF9EB) 두 색을 뼈대로, 크림 캔버스 위에 흰 카드를 얹고 상호작용은 브랜드 바이올렛 한 색으로만 표시한다. 로고의 둥근 획처럼 버튼·칩·입력은 알약(pill) 모양으로 둥글게 하고, 장식 그림자와 그라디언트는 쓰지 않는다. 그림자는 "기록하기" 버튼 하나에만 쓴다.

colors:
  # 브랜드 (로고에서 추출)
  primary: "#452AF8"
  primary-pressed: "#3418D6"
  primary-on-dark: "#8E7BFF"
  primary-soft: "#ECE8FF"
  on-primary: "#FFFFFF"
  cream: "#FEF9EB"
  # 텍스트
  ink: "#1B1830"
  ink-muted: "#6B6780"
  ink-disabled: "#A9A5B8"
  on-dark: "#FEF9EB"
  on-dark-muted: "#B9B4CC"
  # 면
  canvas: "#FEF9EB"
  surface: "#FFFFFF"
  surface-sunken: "#F6F0DF"
  surface-dark: "#17142B"
  surface-dark-raised: "#221E3A"
  surface-photo: "#000000"
  scrim: "#1B1830"
  # 선
  hairline: "#E9E3D2"
  divider-soft: "#F1EBDB"
  # 상태 (예외적으로 허용하는 색)
  review: "#C2410C"
  review-soft: "#FEF1E6"
  error: "#C9302C"
  # 다크 모드
  dark-canvas: "#121022"
  dark-surface: "#1E1B33"
  dark-hairline: "#2E2A47"

typography:
  large-title:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 32px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: -0.8px
  title:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 26px
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: -0.6px
  headline:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 21px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: -0.4px
  count-display:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 40px
    fontWeight: 700
    lineHeight: 1.0
    letterSpacing: -1.0px
    fontFeatures: tabular-nums
  body-strong:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: -0.3px
  body:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 17px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: -0.3px
  callout:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: -0.2px
  caption:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: -0.1px
  caption-strong:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 13px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: -0.1px
  button:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.0
    letterSpacing: -0.3px
  box-label:
    fontFamily: "Pretendard, Apple SD Gothic Neo, system-ui, sans-serif"
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.0
    letterSpacing: 0

rounded:
  none: 0px
  xs: 6px
  sm: 10px
  md: 14px
  lg: 20px
  xl: 28px
  pill: 9999px

spacing:
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  gutter: 20px
  lg: 24px
  xl: 32px
  xxl: 48px

components:
  app-bar:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.headline}"
    height: 56px
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    height: 52px
    padding: 0 24px
  button-primary-pressed:
    backgroundColor: "{colors.primary-pressed}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.pill}"
  button-primary-disabled:
    backgroundColor: "{colors.hairline}"
    textColor: "{colors.ink-disabled}"
    rounded: "{rounded.pill}"
  button-capture:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.cream}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    height: 60px
    padding: 0 28px
  button-tonal:
    backgroundColor: "{colors.primary-soft}"
    textColor: "{colors.primary}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    height: 44px
    padding: 0 18px
  button-text:
    backgroundColor: transparent
    textColor: "{colors.primary}"
    typography: "{typography.body-strong}"
  button-text-destructive:
    backgroundColor: transparent
    textColor: "{colors.error}"
    typography: "{typography.body-strong}"
  button-icon:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    size: 44px
  dose-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.lg}"
    padding: 20px
  dose-card-current:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: 20px
  dose-row:
    backgroundColor: transparent
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    height: 52px
  status-dot-taken:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.pill}"
    size: 24px
  status-dot-pending:
    backgroundColor: transparent
    textColor: "{colors.ink-muted}"
    rounded: "{rounded.pill}"
    size: 24px
  photo-frame:
    backgroundColor: "{colors.surface-photo}"
    rounded: "{rounded.lg}"
  detection-box:
    backgroundColor: transparent
    textColor: "{colors.primary}"
    rounded: "{rounded.xs}"
  detection-box-review:
    backgroundColor: transparent
    textColor: "{colors.review}"
    rounded: "{rounded.xs}"
  detection-box-unknown:
    backgroundColor: transparent
    textColor: "{colors.cream}"
    rounded: "{rounded.xs}"
  detection-label:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.box-label}"
    rounded: "{rounded.pill}"
    padding: 4px 8px
  compare-summary:
    backgroundColor: "{colors.primary-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.md}"
    padding: 16px
  compare-summary-review:
    backgroundColor: "{colors.review-soft}"
    textColor: "{colors.review}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.md}"
    padding: 16px
  result-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    height: 64px
    padding: 0 20px
  count-stepper:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.ink}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.pill}"
    height: 36px
  med-chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.callout}"
    rounded: "{rounded.pill}"
    padding: 8px 14px
  med-chip-selected:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.pill}"
  search-input:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    height: 48px
    padding: 0 20px
  text-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    height: 52px
    padding: 0 16px
  bottom-action-bar:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    padding: 12px 20px
  bottom-sheet:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    padding: 24px 20px
  calendar-day:
    backgroundColor: transparent
    textColor: "{colors.ink}"
    typography: "{typography.callout}"
    rounded: "{rounded.pill}"
    size: 40px
  calendar-day-selected:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.pill}"
    size: 40px
  empty-guide:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.ink}"
    typography: "{typography.callout}"
    rounded: "{rounded.lg}"
    padding: 24px
  snackbar:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.cream}"
    typography: "{typography.callout}"
    rounded: "{rounded.md}"
    padding: 14px 16px
---

## 개요

알약몬은 **한 손으로 찍고, 한눈에 확인하는** 앱입니다. 화면은 따뜻한 크림색 캔버스(`{colors.canvas}`)에 흰 카드(`{colors.surface}`)를 얹은 두 겹이고, 사용자가 누를 수 있는 것은 모두 로고의 블루바이올렛(`{colors.primary}`)으로 표시합니다. 버튼, 칩, 검색창은 로고의 둥근 획처럼 양 끝이 둥근 알약 모양(`{rounded.pill}`)입니다. 앱 이름과 다루는 대상이 모두 알약이니, 이 모양 자체가 브랜드입니다.

이 문서는 Apple 디자인 분석 문서의 구조를 따릅니다. 색은 하나만 강조하고, 장식은 걷어 내고, 그림자는 꼭 필요한 곳 한 군데에만 씁니다. 다만 Apple은 사진 속 제품을 보여 주는 쪽이고 이 앱은 **약을 빠짐없이 먹었는지 확인하는** 쪽이라, 다음 두 가지는 다르게 갑니다.

- 정보 밀도가 더 높습니다. 홈 화면은 시간대별 복용 예정과 완료 여부를 스크롤 없이 보여 주는 것이 목표입니다.
- 상태색이 있습니다. "확인 필요"(`{colors.review}`)와 "오류"(`{colors.error}`)는 강조색이 아니라 경고 신호라서 예외로 둡니다. 둘 다 버튼 색으로는 쓰지 않습니다.

**핵심 특징:**
- 로고 두 색이 뼈대: 블루바이올렛 `#452AF8`(상호작용), 크림 `#FEF9EB`(캔버스, 어두운 면 위 글자).
- 크림 캔버스 + 흰 카드. 카드와 캔버스의 밝기 차이가 구분선 역할을 해서 테두리를 거의 쓰지 않습니다.
- 강조색은 하나. 누를 수 있는 것, 선택된 것, 복용 완료 표시가 모두 `{colors.primary}`입니다.
- 둥근 모양 문법은 두 가지: 누르는 것은 알약(`{rounded.pill}`), 담는 것은 둥근 사각형(`{rounded.lg}`).
- 그림자는 "기록하기" 버튼(`{component.button-capture}`) 하나에만. 이 앱에서 가장 중요한 동작입니다.
- 사진은 검은 액자(`{component.photo-frame}`) 안에 넣고, 그 위의 탐지 박스만 색으로 말합니다.

## 색

> 로고(1254 × 1254)에서 직접 뽑았습니다. 배경은 `#452AF7`~`#452AF9`, 글자는 `#FEF9EB`로 고르게 칠해져 있어 `#452AF8`과 `#FEF9EB`로 정했습니다.

### 브랜드와 강조색
- **블루바이올렛** (`{colors.primary}` — #452AF8): 로고 배경색. 주 버튼, 기록하기 버튼, 텍스트 버튼, 선택된 칩·날짜, 복용 완료 체크, 탐지 박스에 씁니다. 흰 글자와 대비 7.1:1, 크림과 6.8:1이라 글자를 얹어도 됩니다.
- **눌림 바이올렛** (`{colors.primary-pressed}` — #3418D6): 주 버튼을 누르는 동안의 색. 눌림은 색 변화와 함께 `scale(0.97)`로 살짝 줄어듭니다.
- **밝은 바이올렛** (`{colors.primary-on-dark}` — #8E7BFF): 어두운 면(다크 모드, 사진 액자 주변) 위의 텍스트 버튼과 아이콘. 어두운 면에서 `{colors.primary}`는 묻힙니다. 밝은 면에는 쓰지 않습니다.
- **연한 바이올렛** (`{colors.primary-soft}` — #ECE8FF): 보조 버튼(`{component.button-tonal}`) 배경, 예정과 비교한 요약(`{component.compare-summary}`) 배경. 그 위의 `{colors.primary}` 글자는 대비 6.0:1입니다.
- **크림** (`{colors.cream}` — #FEF9EB): 로고의 글자색. 밝은 화면에서는 캔버스로, 어두운 면에서는 글자색(`{colors.on-dark}`)으로 씁니다. 기록하기 버튼 글자도 크림입니다. 로고를 그대로 옮긴 조합입니다.

### 면
- **캔버스** (`{colors.canvas}` — #FEF9EB): 모든 화면의 바탕. 순백보다 따뜻해서 약 앱 특유의 병원 느낌을 줄입니다.
- **카드** (`{colors.surface}` — #FFFFFF): 복용 카드, 결과 줄, 바텀 시트, 입력창. 크림 위에 흰색이 살짝 떠 보이는 것으로 구분합니다.
- **들어간 면** (`{colors.surface-sunken}` — #F6F0DF): 검색창, 수량 조절기, 아이콘 버튼, 빈 화면 가이드. 카드보다 한 단계 낮아 보이게 합니다.
- **어두운 면** (`{colors.surface-dark}` — #17142B, `{colors.surface-dark-raised}` — #221E3A): 카메라 화면 아래 영역처럼 사진 주변을 어둡게 둘 때. 순검정 대신 바이올렛 기운이 도는 검정입니다.
- **사진 액자** (`{colors.surface-photo}` — #000000): 사진 뒤 여백. 순검정은 여기에만 씁니다.
- **스크림** (`{colors.scrim}` — #1B1830): 바텀 시트·다이얼로그 뒤 가림막. 40% 불투명도로 씁니다.

### 텍스트
- **잉크** (`{colors.ink}` — #1B1830): 제목과 본문. 순검정 대신 로고 바이올렛을 아주 조금 섞은 검정입니다. 크림 위 대비 16:1.
- **흐린 잉크** (`{colors.ink-muted}` — #6B6780): 보조 정보(복용 시간, "1회 2정", 날짜 부제). 크림 위 대비 5.1:1이라 본문 크기 글자에도 씁니다.
- **비활성** (`{colors.ink-disabled}` — #A9A5B8): 비활성 버튼 글자, 지난 날짜. 정보를 담는 글자에는 쓰지 않습니다.
- **어두운 면 글자** (`{colors.on-dark}` — #FEF9EB, `{colors.on-dark-muted}` — #B9B4CC): 어두운 면과 다크 모드의 본문·보조 글자.

### 선
- **헤어라인** (`{colors.hairline}` — #E9E3D2): 카드 안 줄 사이 구분선, 입력창 테두리, 비활성 버튼 배경. 크림 기운이 있는 회색이라 캔버스와 어울립니다.
- **부드러운 구분선** (`{colors.divider-soft}` — #F1EBDB): 목록이 길어질 때 줄 구분. 선이라기보다 결입니다.

### 상태색 (예외)
- **확인 필요** (`{colors.review}` — #C2410C, 배경 `{colors.review-soft}` — #FEF1E6, 그 위 대비 4.7:1): 신뢰도가 애매한 탐지, 예정보다 적게 인식된 약("B 2정 중 1정 인식"), 다른 약과 더 비슷하다는 안내. 예전 `reviewColor`(#E65100)는 크림 위 대비가 3.6:1이라 작은 글자에 부족해서 한 단계 어둡게 했습니다(4.9:1).
- **오류** (`{colors.error}` — #C9302C): 삭제 버튼 글자, 저장 실패 같은 오류 문구. 크림 위 대비 5.1:1.
- 완료를 초록으로 표시하지 않습니다. **복용 완료는 브랜드 바이올렛 체크**입니다. 상태색이 늘어나면 강조색 하나 원칙이 무너집니다.

### 다크 모드
| 밝은 모드 | 다크 모드 |
|---|---|
| `{colors.canvas}` #FEF9EB | `{colors.dark-canvas}` #121022 |
| `{colors.surface}` #FFFFFF | `{colors.dark-surface}` #1E1B33 |
| `{colors.hairline}` #E9E3D2 | `{colors.dark-hairline}` #2E2A47 |
| `{colors.ink}` #1B1830 | `{colors.on-dark}` #FEF9EB |
| `{colors.ink-muted}` #6B6780 | `{colors.on-dark-muted}` #B9B4CC |
| 텍스트 버튼 `{colors.primary}` | `{colors.primary-on-dark}` #8E7BFF |

주 버튼과 기록하기 버튼은 다크 모드에서도 `{colors.primary}` 채움을 그대로 씁니다. 다크 모드의 카드 위 바이올렛 글자 대비는 5.1:1입니다.

### 그라디언트
**쓰지 않습니다.** 로고도 평면 두 색입니다.

## 글자

### 글꼴
- **Pretendard** (오픈 소스, SIL OFL): 한글과 라틴 모두 SF Pro와 비슷한 인상이고, 웹과 앱에서 같은 모양이 나옵니다. `assets/fonts/`에 넣어 `pubspec.yaml`에 등록합니다.
- 대체: iOS·macOS는 `Apple SD Gothic Neo`, Android는 시스템 기본(Noto Sans KR)으로 떨어집니다.
- 숫자: 개수·시간·날짜에는 고정폭 숫자(`FontFeature.tabularFigures()`)를 씁니다. 수량을 바꿀 때 글자가 흔들리지 않게 합니다.
- 단위: 이 문서의 `px`는 Flutter의 논리 픽셀입니다.

### 단계

| 토큰 | 크기 | 굵기 | 줄 높이 | 자간 | 쓰는 곳 |
|---|---|---|---|---|---|
| `{typography.large-title}` | 32 | 700 | 1.2 | -0.8 | 큰 화면 제목(스크롤 전 펼친 제목, 빈 화면 안내) |
| `{typography.title}` | 26 | 700 | 1.25 | -0.6 | 결과 화면 제목, 바텀 시트 제목 |
| `{typography.headline}` | 21 | 600 | 1.3 | -0.4 | 앱 바 제목, 시간대 이름("아침 8:00"), 다이얼로그 제목 |
| `{typography.count-display}` | 40 | 700 | 1.0 | -1.0 | 큰 숫자("3 / 5정") |
| `{typography.body-strong}` | 17 | 600 | 1.4 | -0.3 | 약 이름, 비교 요약 |
| `{typography.body}` | 17 | 400 | 1.5 | -0.3 | 본문 기본 |
| `{typography.callout}` | 15 | 400 | 1.45 | -0.2 | 보조 설명, 칩, 가이드 문구 |
| `{typography.caption}` | 13 | 400 | 1.4 | -0.1 | 시간, "1회 2정" 같은 부가 정보 |
| `{typography.caption-strong}` | 13 | 600 | 1.3 | -0.1 | 작은 강조(배지, "모델이 헷갈린 약") |
| `{typography.button}` | 17 | 600 | 1.0 | -0.3 | 모든 버튼 글자 |
| `{typography.box-label}` | 12 | 600 | 1.0 | 0 | 사진 위 탐지 박스 이름표 |

### 원칙
- **본문은 17.** Apple처럼 16이 아니라 17로 씁니다. 약 이름은 낯선 단어라 한 글자씩 읽히도록 크게 둡니다. 시력이 좋지 않은 사용자도 많이 쓰는 앱입니다.
- **한글은 자간을 살짝 좁힙니다.** 17 이상은 약 -0.02em, 제목은 -0.025em. 12 이하는 0입니다.
- **굵기는 400 / 600 / 700.** 500은 쓰지 않습니다. 중간 강조는 600입니다.
- **한글 본문 줄 높이는 1.5.** 라틴보다 글자가 꽉 차서 Apple(1.47)보다 조금 넉넉하게 둡니다.
- **시스템 글자 크기 설정을 따릅니다.** `MediaQuery.textScaler`를 막지 않습니다. 최대 1.6배까지 레이아웃이 깨지지 않아야 합니다.

## 레이아웃

### 간격
- **기본 단위:** 4. 구조는 8의 배수로 맞춥니다.
- **토큰:** `{spacing.xxs}` 4 · `{spacing.xs}` 8 · `{spacing.sm}` 12 · `{spacing.md}` 16 · `{spacing.gutter}` 20 · `{spacing.lg}` 24 · `{spacing.xl}` 32 · `{spacing.xxl}` 48
- **화면 좌우 여백:** `{spacing.gutter}` (20).
- **카드 안쪽 여백:** 20. 카드와 카드 사이 12.
- **섹션 사이:** 32. 화면 제목 아래 첫 카드까지 16.
- **하단 고정 영역:** 버튼 위아래 12, 좌우 20, 그 아래 SafeArea.

### 화면 틀
- **폭:** 휴대폰은 꽉 채웁니다. 웹·태블릿에서는 본문 최대 폭 560으로 가운데 둡니다. 결과 화면의 사진만 최대 720까지 넓힙니다.
- **단:** 한 단. 기록 화면의 달력만 7칸 격자입니다.
- **주 동작 위치:** 엄지가 닿는 아래쪽. 기록하기는 오른쪽 아래 떠 있는 버튼, 저장은 하단 고정 바입니다.

### 여백 원칙
홈 화면은 **지금 먹을 약**이 첫 화면에 보여야 합니다. 그래서 Apple보다 촘촘하게 쌓되, 시간대 카드 사이만은 32를 비워 아침·점심·저녁이 덩어리로 읽히게 합니다. 사진이 들어가는 결과 화면은 반대로 사진 주변을 비워 박스가 눈에 들어오게 합니다.

## 깊이

| 단계 | 처리 | 쓰는 곳 |
|---|---|---|
| 평면 | 그림자 없음, 테두리 없음 | 캔버스, 앱 바, 하단 고정 바 |
| 카드 | 흰 면 + 크림 캔버스의 밝기 차이 | 복용 카드, 결과 줄 |
| 헤어라인 | 1px `{colors.hairline}` | 입력창, 카드 안 줄 구분, 지금 시간대 카드 테두리(2px `{colors.primary}`) |
| 시트 | `{colors.scrim}` 40% 가림막 위에 흰 면 | 바텀 시트, 다이얼로그 |
| 브랜드 그림자 | `rgba(69, 42, 248, 0.28) 0 8px 24px` | **기록하기 버튼만** |

**그림자 원칙.** Apple이 제품 사진에만 그림자를 주듯, 이 앱은 그림자를 **기록하기 버튼 하나**에만 줍니다. 이 앱의 존재 이유가 그 버튼이기 때문입니다. 카드, 앱 바, 다른 버튼에는 그림자를 넣지 않습니다. Material 3의 `elevation`과 `surfaceTint`는 모두 0과 투명으로 끕니다.

## 모양

### 둥글기

| 토큰 | 값 | 쓰는 곳 |
|---|---|---|
| `{rounded.none}` | 0 | 화면 전체를 채우는 카메라 미리보기 |
| `{rounded.xs}` | 6 | 사진 위 탐지 박스 |
| `{rounded.sm}` | 10 | 약 썸네일, 작은 배지 |
| `{rounded.md}` | 14 | 입력창, 비교 요약 상자, 스낵바 |
| `{rounded.lg}` | 20 | 카드, 사진 액자, 빈 화면 가이드 |
| `{rounded.xl}` | 28 | 바텀 시트 위쪽 모서리, 다이얼로그 |
| `{rounded.pill}` | 9999 | 모든 버튼, 칩, 검색창, 수량 조절기, 상태 점, 선택된 날짜 |

**문법은 두 가지입니다.** 누르는 것은 알약, 담는 것은 둥근 사각형. 버튼을 둥근 사각형으로 만들거나 카드를 알약으로 만들지 않습니다.

### 로고와 아이콘
- 로고는 바이올렛 바탕에 크림 `m`이 기본입니다. 크림 바탕에 쓸 때는 색을 뒤집지 않고 바이올렛 정사각 타일(`{rounded.lg}`)째로 놓습니다.
- 아이콘은 Material Symbols **Rounded**, 굵기 400, 채움 없음. 선택된 탭 아이콘만 채움으로 바꿉니다. 로고의 둥근 끝과 맞추기 위해서입니다.

## 컴포넌트

### 앱 바
**`app-bar`** — 캔버스와 같은 크림 바탕, 그림자 없음, 스크롤해도 색이 변하지 않습니다(`scrolledUnderElevation: 0`). 제목은 왼쪽 정렬 `{typography.headline}`. 홈 제목에 날짜가 붙고 하위 화면에는 뒤로 가기 버튼이 있어서, 56 높이 안에 들어가는 크기로 둡니다. 오른쪽에 더 보기 같은 아이콘 버튼(`{component.button-icon}`)만 둡니다.

### 버튼

**`button-capture`** — "기록하기". 홈과 약 관리 화면 오른쪽 아래에 떠 있는 버튼(`FloatingActionButton.extended`). 바이올렛 채움에 크림 글자와 카메라 아이콘, 높이 60, 알약 모양. 이 시스템에서 **유일하게 그림자가 있는 요소**입니다. 누르면 사진 찍기·사진 올리기를 고르는 `{component.bottom-sheet}`가 올라옵니다.

**`button-primary`** — 화면의 주 동작("저장", "등록"). 바이올렛 채움에 흰 글자, 높이 52, 알약 모양. 하단 고정 바에서는 좌우를 꽉 채웁니다. 한 화면에 하나만 둡니다.
- 눌림: `{component.button-primary-pressed}` — `{colors.primary-pressed}` + `scale(0.97)`.
- 비활성: `{component.button-primary-disabled}` — 헤어라인 회색 바탕에 비활성 글자.

**`button-tonal`** — 보조 동작("약 추가", "사진 다시 찍기"). 연한 바이올렛 바탕에 바이올렛 글자, 높이 44.

**`button-text`** — 가장 가벼운 동작("모두 보기", "건너뛰기"). 바탕 없이 바이올렛 글자.

**`button-text-destructive`** — "삭제", "약이 아님". 바탕 없이 오류색 글자. 채운 빨간 버튼은 만들지 않습니다.

**`button-icon`** — 44 × 44 원. 들어간 면 바탕에 잉크색 아이콘. 사진 위에 놓일 때는 `{colors.scrim}` 60% 바탕에 크림 아이콘으로 바꿉니다.

### 홈(오늘)

**`dose-card`** — 시간대 하나("아침 8:00")를 담는 흰 카드. 위에 `{typography.headline}` 시간대 이름과 오른쪽 `{typography.caption}` 진행("2 / 3"), 아래에 `{component.dose-row}`가 약마다 한 줄.

**`dose-card-current`** — 지금 먹을 시간대. 같은 카드에 2px `{colors.primary}` 테두리만 더합니다. 배경색을 바꾸지 않습니다.

**`dose-row`** — 높이 52. 왼쪽 상태 점, 가운데 약 이름(`{typography.body-strong}`)과 "1회 2정"(`{typography.caption}`, 흐린 잉크), 오른쪽 기록 시각.
- **`status-dot-taken`** — 바이올렛 채운 원에 흰 체크. 복용 완료.
- **`status-dot-pending`** — 1.5px 흐린 잉크 테두리의 빈 원. 아직 안 먹음.
- 일부만 먹은 줄은 빈 원 옆에 "1 / 2정"을 `{colors.review}`로 씁니다.

**`empty-guide`** — 기록이 없을 때. 들어간 면 바탕의 둥근 상자에 샘플 사진 한 장과 가이드 세 줄("단색 배경에 놓기", "위에서 수직으로", "알약끼리 떨어지게"). 각 줄 앞에 바이올렛 아이콘.

### 결과 확인

**`photo-frame`** — 찍은 사진을 담는 검은 액자. 사진은 잘라 내지 않고 `contain`으로 넣습니다. 둥글기 `{rounded.lg}`. 핀치 확대를 허용합니다.

**`detection-box`** — 모델이 찾은 알약. 2px 바이올렛 테두리. 박스 위 왼쪽에 **`detection-label`**(바이올렛 알약 이름표, 흰 `{typography.box-label}`)로 약 이름. 사진 색과 겹쳐도 보이도록 테두리 바깥에 1px 흰 선을 한 겹 더 둡니다.

**`detection-box-review`** — 확인이 필요한 박스("○○과(와) 더 비슷해요"). 테두리와 이름표가 `{colors.review}`.

**`detection-box-unknown`** — 알 수 없는 물체. 2px **점선** 크림 테두리 + 바깥 1px 잉크 선, 이름표 대신 번호 원(①②③). 색이 아니라 점선으로 구분해서 색맹 사용자도 알아봅니다.

**`compare-summary`** — 사진 바로 아래, 예정과 비교한 한 줄 요약("A 1정 ✓, B 2정 중 1정 인식"). 다 맞으면 연한 바이올렛 바탕, 빠진 약이 있으면 **`compare-summary-review`**(연한 주황 바탕, 주황 글자)로 바뀝니다. **이 앱의 핵심 화면 요소**라 사진 다음으로 크게 둡니다.

**`result-row`** — 탐지된 약 한 줄. 높이 64, 흰 바탕, 줄 사이 `{colors.divider-soft}`. 왼쪽 박스와 같은 색의 점(번호), 약 이름, 오른쪽 **`count-stepper`**(들어간 면 알약 모양, −/숫자/+, 숫자는 고정폭). 줄을 누르면 약을 바꾸는 `{component.bottom-sheet}`가 열립니다.

**`bottom-action-bar`** — 화면 아래 고정. 크림 바탕, 위쪽에 1px 헤어라인, 꽉 찬 `{component.button-primary}`("저장").

### 약 고르기·약 관리

**`search-input`** — 들어간 면 바탕의 알약 모양 검색창, 높이 48, 왼쪽 돋보기 아이콘(흐린 잉크). 테두리는 없고 포커스 때만 2px 바이올렛 테두리.

**`med-chip`** — 복용 시간·최근 약 같은 선택지. 흰 바탕, 1px 헤어라인 테두리, 알약 모양. 선택되면 **`med-chip-selected`**로 바이올렛 채움에 흰 글자, 테두리 없음.

**`text-field`** — 약 이름, 1회 수량 입력. 흰 바탕, 1px 헤어라인, 둥글기 `{rounded.md}`, 높이 52. 포커스 2px 바이올렛, 오류 2px 오류색과 아래 `{typography.caption}` 오류 문구.

**`bottom-sheet`** — 사진 찍기/올리기 선택, 약 바꾸기. 위쪽 모서리 28, 맨 위 가운데 36 × 4 손잡이(`{colors.hairline}`). 약 바꾸기 시트에서는 추천("비슷한 약", "모델이 헷갈린 약")을 맨 위 섹션으로, 섹션 제목은 `{typography.caption-strong}` 흐린 잉크.

### 기록

**`calendar-day`** — 40 × 40 원. 기록이 있는 날은 숫자 아래 4px 바이올렛 점. 오늘은 바이올렛 글자. **`calendar-day-selected`**는 바이올렛 채운 원에 흰 숫자. 미래 날짜는 비활성 글자.

### 알림

**`snackbar`** — 저장 완료, 실행 취소. 잉크 바탕에 크림 글자, 둥글기 14, 하단 고정 바 위로 띄웁니다. 실행 취소 같은 동작은 `{colors.primary-on-dark}` 글자.

## 해야 할 것과 하지 말 것

### 해야 할 것
- 누를 수 있는 것은 모두 `{colors.primary}`(#452AF8)로 표시합니다. 버튼, 링크, 선택 상태, 포커스.
- 복용 완료는 바이올렛 체크로 표시합니다.
- 버튼·칩·검색창은 `{rounded.pill}`, 카드·액자는 `{rounded.lg}`로 둡니다.
- 본문은 17, 약 이름은 600으로 씁니다.
- 개수와 시간은 고정폭 숫자로 씁니다.
- 탐지 박스의 종류는 색과 함께 **선 모양(실선/점선)이나 번호**로도 구분합니다.
- 버튼을 누르면 `scale(0.97)`로 살짝 줄입니다. 모든 버튼에 똑같이.
- 터치 영역은 최소 44 × 44, 주 버튼은 높이 52 이상으로 둡니다.

### 하지 말 것
- 두 번째 강조색을 들이지 않습니다. 완료를 초록으로 칠하지 않습니다.
- 카드, 앱 바, 일반 버튼에 그림자를 넣지 않습니다. 그림자는 기록하기 버튼만.
- 그라디언트를 쓰지 않습니다.
- `{colors.review}`와 `{colors.error}`를 버튼 채움색으로 쓰지 않습니다. 글자와 테두리, 연한 배경까지만.
- `{colors.primary-on-dark}`를 밝은 면에 쓰지 않습니다.
- 순검정(#000000)을 사진 액자 밖에서 쓰지 않습니다. 글자는 `{colors.ink}`.
- 굵기 500을 쓰지 않습니다.
- 시스템 글자 크기 확대를 막지 않습니다.
- 버튼에 둥근 사각형, 카드에 알약 모양을 섞지 않습니다.

## 화면 크기별

| 이름 | 폭 | 바뀌는 것 |
|---|---|---|
| 작은 휴대폰 | ~359 | 좌우 여백 16, `{typography.large-title}` 28로 축소, 기록하기 버튼은 아이콘만 |
| 휴대폰 | 360~599 | 기본값 |
| 태블릿·웹 | 600~ | 본문 최대 폭 560 가운데 정렬, 결과 사진 최대 720, 바텀 시트는 최대 폭 560 |

### 터치 영역
- 최소 44 × 44. 상태 점(24)은 줄 전체가 눌리게 해서 영역을 채웁니다.
- 수량 조절기의 −/+ 버튼은 높이 36이지만 누르는 영역은 44로 넓힙니다.

### 사진
- 결과 사진은 원본 비율 그대로, 자르지 않습니다(박스 위치가 어긋나지 않게).
- 웹에서는 사진이 화면 높이의 60%를 넘지 않게 줄입니다.

## Flutter에 옮기기

`lib/ui/common/theme.dart`의 `AppColors`, `AppRadius`, `AppSpacing`, `AppLayout`, `AppTypography`, `appTheme`이 이 문서를 옮긴 것이고, 여러 화면이 같이 쓰는 컴포넌트는 `lib/ui/common/widgets.dart`에 있습니다. `ColorScheme.fromSeed`가 아니라 색을 직접 지정합니다. `fromSeed`는 톤을 자동으로 만들어서 로고 색과 정확히 맞지 않습니다.

| ColorScheme | 토큰 |
|---|---|
| `primary` / `onPrimary` | `{colors.primary}` / `{colors.on-primary}` |
| `primaryContainer` / `onPrimaryContainer` | `{colors.primary-soft}` / `{colors.primary}` |
| `secondary` / `onSecondary` | `{colors.primary}` / `{colors.on-primary}` (보조색 없음) |
| `tertiary` / `onTertiary` | `{colors.review}` / `{colors.on-primary}` (지금 코드가 알 수 없는 물체에 씀) |
| `error` / `onError` | `{colors.error}` / `{colors.on-primary}` |
| `surface` / `onSurface` | `{colors.canvas}` / `{colors.ink}` |
| `surfaceContainerLowest` | `{colors.surface}` |
| `surfaceContainerHighest` | `{colors.surface-sunken}` |
| `onSurfaceVariant` | `{colors.ink-muted}` |
| `outline` / `outlineVariant` | `{colors.ink-muted}` / `{colors.hairline}` |
| `scrim` | `{colors.scrim}` |
| `surfaceTint` | `Colors.transparent` |

- `reviewColor`는 `{colors.review}`(#C2410C)입니다.
- 모든 컴포넌트 테마의 `elevation`은 0입니다. 브랜드 그림자는 FAB 테마로 줄 수 없어서(색을 못 바꿈) 기록하기 버튼을 `captureShadow`가 있는 `DecoratedBox`로 감쌉니다.
- `filledButtonTheme`에는 색을 넣지 않습니다. 넣으면 `FilledButton.tonal`까지 바이올렛으로 칠해집니다. 색은 `ColorScheme`(`primary`, `secondaryContainer`)에서 옵니다.
- 버튼 테마의 `shape`는 `StadiumBorder()`, 카드는 `RoundedRectangleBorder(borderRadius: 20)`.
- 화면 코드에서 크기·간격 숫자를 직접 쓰지 않고 `AppSpacing`, `AppRadius`를 씁니다. 고정폭 숫자는 `AppTypography.tabular`.

| 컴포넌트 | Flutter |
|---|---|
| `button-capture` | 홈의 `_CaptureButton` (작은 휴대폰에서는 아이콘만) |
| `button-tonal` | `FilledButton.tonal` + `tonalButtonStyle` (하단 바 안에서는 높이 52) |
| `button-text-destructive` | `TextButton` + `destructiveTextButtonStyle` |
| `button-icon` | `IconButton` (테마가 들어간 면 원으로 칠함) |
| `dose-card`, `dose-card-current` | 홈의 `_DoseCard` (`GroupCard(highlighted:)`) |
| `status-dot-*` | `StatusDot` |
| `empty-guide` | 홈의 `_EmptyGuide`, 다른 화면은 `EmptyState` |
| `compare-summary(-review)` | 결과 화면의 `_CompareSummary` |
| `result-row`, `count-stepper` | `_ResultRow`, `CountStepper` |
| `detection-box(-review/-unknown)` | 결과 화면의 `_BoxPainter` (`_MarkKind`) |
| `bottom-action-bar` | `BottomActionBar` |
| `search-input` | `SearchField` |
| 본문 최대 폭 560 / 사진 720 | `pagePadding`, `ContentWidth` |

## 반복 작업 안내

1. 한 번에 컴포넌트 하나씩 바꿉니다. YAML 키로 부릅니다(`{component.dose-card}`, `{component.detection-box-unknown}`).
2. 변형(`-pressed`, `-selected`, `-review`)은 `components:`에 따로 둡니다.
3. 코드에서도 hex를 직접 쓰지 않고 토큰(Theme, 상수)을 통해 씁니다.
4. 강조가 더 필요하면 색을 늘리기 전에 크기·굵기·여백부터 조정합니다.
5. 상태가 하나 늘면 색보다 아이콘·선 모양으로 먼저 구분합니다.

## 아직 정하지 않은 것

- 로컬 알림(2차)의 알림 아이콘과 색. Android 알림 아이콘은 단색이라 따로 그려야 합니다.
- 앱 아이콘의 Android 적응형 아이콘 전경/배경 분리, iOS 다크·틴트 아이콘.
- 카메라 화면 안의 촬영 가이드 오버레이(지금은 시스템 카메라를 씁니다).
- 엑셀 내보내기·가져오기 화면의 진행 표시.
- Pretendard를 앱에 넣을지(약 1.5MB, 서브셋이면 더 작음) 시스템 글꼴로 갈지.
