# Handoff: 포트폴리오 앱 UI 개편 (자산 · 리밸런싱 · 결산 · 더보기)

## Overview

Flutter 앱 `halladin00-commits/rebalancing_app`의 화면 전체를 개편한다. 세 가지가 핵심이다.

1. **탭 구조 변경** — AppBar TabBar 한 화면에서 **하단 4탭**(자산 / 리밸런싱 / 결산 / 더보기)으로.
2. **결산 탭 재설계** — 차트가 기간 선택 컨트롤이 된다. 기간 칩·주차 드롭다운 없음.
3. **리밸런싱 일괄 조정 + 소수점 거래** — 계좌별 소수점 설정, 편차 최소화 반올림.

시각적으로는 슬레이트/블루(#1E293B · #3B82F6)에서 **크림/딥그린**(#FBF8F1 · #0E4F49)으로 전면 리스킨.

## About the Design Files

이 폴더의 `.dc.html` 파일은 **HTML로 만든 디자인 시안**이다. 의도한 모습과 동작을 보여주는 프로토타입이며, 그대로 옮겨 쓸 프로덕션 코드가 아니다. 할 일은 이 시안을 **저장소의 기존 Flutter 환경**(Provider, `context` 확장 색 토큰, `AppLocalizations`, Pretendard)으로 다시 만드는 것이다.

브라우저로 열어 보려면 같은 폴더의 `support.js`가 필요하다.

| 파일 | 내용 |
| --- | --- |
| `메인화면.dc.html` | **주 시안.** 59개 화면, v1~v23. 각 화면 아래에 왜 그렇게 했는지 적혀 있다 |
| `현재 UI 재현.dc.html` | 개편 전 화면 재현 (비교용) |
| `settlement-c.dc.html` | 결산 탭 방향 탐색 (C안 = 확정안) |
| `period-picker.dc.html` | 기간 선택 메커니즘 (레일 vs 시트) 실험 |

시안 안의 버전 번호는 화면 옆 배지(`v22a` 등)로 표시되어 있고, 이 문서도 같은 번호로 참조한다. **최신 확정본만 구현하면 된다:**

- 자산 = v12a, v12b, v12c, v12d(간편입력), v13a(종목 검색), v13b(거래 추가), v14a(해외 거래), v15a/v15b(거래 설정), v16a~v16e(거래 내역·예수금), v17a~v17d(수수료·업로드·첫 진입)
- 리밸런싱 = v18a~v18d, v20 (일괄 조정)
- 결산 = **v22a(전체), v22b(포트별), v22c(점프 시트)** ← v19·v21은 폐기
- 더보기 = **v23a, v23b**

## Fidelity

**High-fidelity.** 색·글자 크기·간격·라운드가 모두 확정값이다. 시안의 px는 Flutter 논리 픽셀과 1:1로 쓴다(기준 폭 390 = iPhone 논리 폭). 아래 명세와 `design_tokens.dart`의 값을 그대로 넣어라.

다만 시안은 **라이트 모드만** 그렸다. 앱에는 다크 테마가 있으므로 `design_tokens.dart`의 다크 대응값을 쓰고, 구현 후 다크 화면을 따로 확인받아야 한다.

---

## 기존 코드와의 접점 (먼저 읽을 것)

| 붙일 곳 | 파일 | 지금 상태 |
| --- | --- | --- |
| 색 토큰 | `lib/main.dart` — `extension AppColors on BuildContext` | 슬레이트/블루. **값만 교체**하고 이름은 유지 → 호출부 수정 불필요 |
| 손익 색 | `lib/main.dart` — `PnlColorNotifier` | greenRed(#16A34A/#DC2626) · redBlue(#DC2626/#2563EB) 두 스킴. **모든 손익 색은 이 notifier를 통과해야 한다** |
| 테마 | `lib/main.dart` — `ThemeData` | `fontFamily: 'Pretendard'` (시안과 동일), scaffold #F1F5F9, appBar #1E293B |
| 탭 구조 | `lib/screens/portfolio_list_screen.dart:649` · `portfolio_detail_screen.dart:755` | AppBar 하단 `TabBar`. 하단 탭바는 아직 없음 |
| 배너 | `lib/widgets/bottom_banner_ad.dart` | 이미 있음. 새 탭바 **바로 위**에 고정 |
| 결산 계산 | `lib/services/settlement_service.dart` | `calculate()`가 Modified Dietz로 기간 손익·종목별 기여도까지 이미 계산. `PeriodKey`, `periodRange`, `maxSub`, `earliestYear`, `currentSub` 모두 존재 → **재사용** |
| 리밸런싱 계산 | `lib/utils/rebalancer.dart` | 최대잉여(largest remainder)로 정수 주 배분. `RebalanceItemResult.newShares`/`delta`가 **int** |
| 허용 편차 | `lib/models/portfolio.dart` — `Portfolio.rebalancingThreshold` | 이미 존재 (기본 0.0). 새로 만들지 말고 연결 |
| 모델 | `lib/models/portfolio.dart` | `PortfolioItem.shares`는 이미 `double`. `market`은 `'KR' | 'US' | 'CASH'` |
| 문구 | `lib/l10n/app_localizations_ko.dart` · `_en.dart` | 한/영 2개 로케일. 새 문구는 양쪽에 키 추가 (`copy_ko_en.md` 참조) |

---

## Design Tokens

전체 값은 `design_tokens.dart`에 Dart로 정리되어 있다. 요약:

**색**
| 역할 | 값 |
| --- | --- |
| 화면 배경 | `#FBF8F1` |
| 카드 | `#FFFFFF` · 그림자 `0 1px 2px rgba(22,19,15,.05)` |
| 트랙 · 배너 배경 | `#F2EDE1` |
| 카드 안 구분선 | `#EFEADC` / 카드 밖 경계 `#E4DECF` |
| 텍스트 | `#16130F` → `#4A443B` → `#726B5F` → `#8A8478` → `#A39B8C` → `#C3BCAC`(비활성) |
| 브랜드 | `#0E4F49` (AppBar·CTA·선택) / 밝은 배경 위 텍스트 `#3D5C58` / 옅은 배경 `#E6EEEC` |
| 딥그린 위 강조 | `#8FE7B0` (숫자), `#F2C36B` (주의) |
| 손익 | `+#0E7A52` / `−#B85127`, 배지 배경 `+#E6EEEC` / `−#F7E4DA` |
| 주의 | 배경 `#F5EEDF`, 텍스트 `#9C4A16`, 진행중 점 `#C08A3E` |
| 시장 칩 | KR `#1E4E6B`/`#DCE9F0`, US `#4C2A72`/`#EBE4F3`, 현금 `#3F5218`/`#E9EFDC` |
| 결산 차트 | 확정 `#BFE3CF`, 선택 `#0E4F49`, 손실 `#EED4C6`, 진행중 점선 `#A9CBBB` |

**타입 (Pretendard)** — 행 컴포넌트 규칙이 가장 중요하다. 자산·결산 어느 탭이든 "이름 + 금액 + 수익률" 행은 같은 값을 쓴다.

| 용도 | 크기 / 굵기 / 자간 |
| --- | --- |
| 헤더 총액 | 35 / 800 / −1.5 |
| 카드 총액 | 32 / 800 / −1.4 |
| 합계 행 | 17 / 800 / −0.4 |
| **행 이름** | **15 / 700 / −0.2** |
| **행 금액** | **15 / 700 / −0.3** |
| **수익률(누적·기간)** | **12.5 / 700** |
| **전일대비** | **11 / 700** (배지형 10.5 / 700) |
| 섹션 제목 | 13 / 800 / −0.2 |
| 그룹 라벨 | 11.5 / 800 (`#8A8478`) |
| 부가 설명 | 11.5 / 500 (`#726B5F`) |
| 최소 크기 | **10.5** — 이보다 작게 쓰지 말 것 |
| 탭바 라벨 / 아이콘 | 10.5 / 600·700 · 아이콘 23 |

**치수** — 화면 좌우 패딩 16, 카드 좌우 패딩 18, 카드 사이 간격 9, 카드 라운드 20(목록 카드 18, 작은 타일 16), 칩 pill 20, 배지 5~6, 버튼 높이 48/라운드 14, 바텀시트 상단 24, AppBar 하단 라운드 28, 진행 막대 트랙 5px(라운드 3), 토글 44×26(썸 20), 하단 탭바 64 + 배너 50, 최소 터치 44.

---

## Screens / Views

### 셸 (모든 탭 공통)

- **레이아웃**: `Scaffold` > `IndexedStack`(탭 4개) / 하단에 배너 50 + `BottomNavigationBar` 64(하단 패딩 6).
- AppBar는 `#0E4F49`, 하단 좌우 라운드 28, 상태바 영역 44 + 타이틀 행 46.
- 탭 아이콘(Material Symbols): `account_balance_wallet` 자산 / `balance` 리밸런싱 / `bar_chart` 결산 / `more_horiz` 더보기. 선택 `#0E4F49` w700, 비선택 `#726B5F` w600.
- 리밸런싱 탭 아이콘에는 **조정 필요 개수 배지**(원형 16, 배경 `#B85127`, 흰 숫자 10.5/800, 아이콘 우상단 오프셋 `left: 50%+8, top: -1`).
- 배너는 탭 루트 화면에만. 입력·업로드 단계 화면은 탭바와 배너를 **둘 다** 내린다. 첫 진입(v17d)만 예외로 탭바만 남기고 배너 없음 — 선택 카드 3장이 들어가야 해서다.

### 자산 탭 (v12a)

- **목적**: 총자산과 포트폴리오별 현황을 한 화면에서.
- **헤더**(딥그린): 총자산 35/800/−1.5 `#8FE7B0`, 아래 누적 수익률 13/700 + 부가 11.5/600 `rgba(255,255,255,.7)`, 갱신 시각 표기.
- **포트 카드**(흰 카드, 라운드 20, 패딩 18): 1행 = 이름 15/700 + 조정 배지(`조정 4`, 10/800, `#9C4A16` on `#F7E4DA`, pill) + 금액 15/700/−0.3. 2행 = 누적 수익률 12.5/700(손익색) + 전일대비 배지 10.5/700. 3행 = 비중 막대(트랙 5px `#F2EDE1`) + `비중 34.5%` 11.5/600.
- **상태**: 갱신 중 / 완료 / 실패 3상태(v13e). **실패해도 숫자를 비우지 않는다** — 마지막 시세를 유지하고 기준 시각만 정직하게 표기(`갱신 실패 · 09:38 시세`, 아이콘 `cloud_off` `#F2C36B`, "다시 시도" pill).
- 종목 행에는 시장 칩(KR/US/현금) 10.5/800, 라운드 5, 패딩 3×5.

### 리밸런싱 탭 (v18a~v18d, v20)

- **진단 카드**: 포트별로 허용 편차(±%p)와 초과 종목 수를 보여준다. `Portfolio.rebalancingThreshold` 사용.
- **종목별 진행 막대**: 목표 대비 현재 비중. 초과는 `#B85127`, 이내는 `#0E7A52`.
- **조정 제안(v18d)**: 종목별 매수/매도 **수량까지** 제시.
- **핵심 로직 변경 — 일괄 조정(v20)**: 현재 `rebalancer.dart`는 종목을 순차로 맞춘다. 그래서 한 종목을 조정하면 총액이 바뀌어 나머지 편차가 다시 어긋난다. **편차를 초과한 종목 전체를 한 번에** 목표로 보내는 해를 구해야 한다. 남는 현금 처리는 계좌별로 — **현금은 계좌에 귀속되므로 포트 간 합산은 금지**.
- 다중 포트 조정은 포트별로 분리해 제안한다.

### 결산 탭 — 전체 (v22a)

- **목적**: 이번 기간에 얼마 벌었는지, 어느 포트가 기여했는지.
- **헤더**: 기간 단위 얇은 탭(주간/월간/분기/연간, 12/700~800, 활성 아래 2.5px 흰 바) → 기간 손익 35/800 `#8FE7B0` → 수익률 13/700 + `순입금 ₩500,000은 제외` 11.5/600 → **손익 구성 한 줄** `실현 +20.7만 · 평가 +36.1만 · 수수료 −2.7만` 11.5/600. (구성은 카드 3장이 아니라 헤더 한 줄이다.)
- **차트 카드 = 기간 선택 컨트롤**:
  - 상단 좌측에 선택 기간 `2026.07.01 – 07.31` 12.5/700, 아래 상태 한 줄(`마감 · 막대를 눌러 기간 선택` 10.5/600 `#726B5F`), 우측에 달력 버튼(32×32, 라운드 10, `#F2EDE1`, 아이콘 `calendar_month` 18 `#0E4F49`).
  - 막대 6칸, 높이 83(양수 영역 60 + 기준선 1 + 음수 영역 22), 간격 7, 라운드 5(음수는 아래쪽 라운드). 확정 `#BFE3CF`, 선택 `#0E4F49`(기준선도 `#16130F`로 진하게), 음수 `#EED4C6`, **진행 중 기간은 점선 테두리 막대**(`1.5px dashed #A9CBBB`, 배경 흰색) — 확정 손익과 섞이지 않게.
  - 막대 아래 라벨 10.5/600, 선택된 것만 11/800 `#16130F`. 진행 중 라벨 옆에 4px 점 `#C08A3E`.
  - **상호작용**: 막대 탭 = 그 기간 선택. 좌우 스크롤 = 과거로 계속 이어짐(연속 레일). 6칸을 넘는 점프는 달력 버튼 → 점프 시트.
  - 분기·연간 차트는 **연도 경계에 점선 + 연도 라벨**(10/700 `#C3BCAC`)을 넣어 2025년 분기와 섞이지 않게 한다.
- **포트별 기여** 섹션 제목 13/800 + 카드. 행 = 이름 15/700(+`2종목 제외` 배지) / 부가 11.5/500(`매도 2건 · 배당 1건`) / 금액 15/700/−0.3 / 수익률 12.5/700(손익색) / `chevron_right`. 아래 기여 막대 + `기여 53% (+1.65%p)` 10.5/600 `#8A8478` — **기여도는 무채색**, 손익만 색을 쓴다.
- **결산 제외 띠**: 한 줄(`error` 16 `#9C4A16`, `2종목 결산 제외 · ₩1,860,000`, "전환" 링크). 배경 `#F5EEDF`, 라운드 12.

### 결산 탭 — 포트별 (v22b)

- 전체와 **독립된 기간 상태**를 갖는다(전체=월간이어도 이 포트는 분기).
- 헤더에 `이 포트는 입출금 없음`처럼 계산 근거만 한 줄.
- 차트 아래 **손익 구성 표**(매도 실현손익 / 배당 / 평가손익 변동 / 수수료·세금 / 합계). 라벨 13/600 `#4A443B`, 건수 11/600 `#8A8478`, 금액 14.5/700 우측 정렬(min-width 86), 합계는 17/800 손익색.
- **종목별 기여**: 이름 15/700 + 금액 15/700 + 수익률 12.5/700(min-width 46, 우측 정렬), 아래 기여 막대 + `기여 58% (+3.73%p)`. 섹션 우측에 `수수료 전 값` 11/600 주석.
- 진행 중 기간은 날짜 범위 옆에 경과 일수만(`3분기 진행 중 · 50일 경과` `#9C4A16`).

### 결산 탭 — 기간 점프 시트 (v22c)

- 바텀시트(상단 라운드 24, 배경 `#FBF8F1`, 상단 핸들 38×4 `#D6CFBC`), 뒤 배경 `rgba(22,19,15,.5)`.
- 제목 `기간 선택` 15.5/800 + **범위 표시** `연금저축 ETF 기준` 11.5/600 — 시트가 **어느 범위로 열렸는지** 반드시 밝힌다.
- 단위 세그먼트(주간/월간/분기/연간, 배경 `#F2EDE1` 라운드 12, 활성 `#0E4F49` 라운드 9).
- 연도 칩 행(가로 스크롤, 선택 `#0E4F49`, 미선택 흰 배경 + `#E4DECF` 테두리, 데이터 없는 연도는 텍스트 `#A39B8C`). 우측에 페이드 그라데이션.
- 기간 칸 2열 그리드(높이 64, 라운드 13): 이름 13/700 + 날짜 범위 10.5/600 + **그 범위의 손익** 11/700(손익색). 선택 = `#0E4F49` 채움. 진행 중 = 흰 배경 + `1.5px #C08A3E` 테두리 + 점. 미래 = `#F4F0E6` 배경, 텍스트 `#C3BCAC`, 손익 없음(비활성).
- 하단 주석 `칸의 손익은 이 포트만의 값입니다 — 전체 결산의 기간은 그대로 유지됩니다` + CTA 버튼 48/라운드 14 `#0E4F49`.
- **하지 말 것**: 1~52 주차 목록/드롭다운. 주간도 연도 → 월 → 주 순서로 좁혀 고른다.

### 더보기 탭 (v23a)

- 이 탭만 포트 리스트 없이 시작하고, 헤더는 제목 한 줄(19/800)로 낮춘다.
- 그룹 라벨(11.5/800 `#8A8478`) + 카드(라운드 18, 패딩 18, 행 높이 44). 그룹: 포트폴리오 / 거래·계산 / 결산·알림 / 데이터·앱.
- **모든 행에 현재 값을 오른쪽에 적는다** (`3개`, `±3%p`, `매매 0.015% · 배당세 15.4%`, `엑셀 · CSV`, `08.14`, `월 ₩1,900`). 눌러야 확인되는 설정은 목록의 의미가 없다.
- 소수점 거래 행은 스위치가 아니라 **`2개 계좌`** 값 + `chevron_right`. 계좌별 설정이라는 게 목록에서 드러나야 한다.

### 소수점 거래 설정 (v23b)

- **계좌별 토글**: 44×26, 켜짐 `#0E4F49`, 꺼짐 `#EFEADC`. 각 행에 이유 한 줄(`해외주식 · 소수점 매매 가능`).
- **켤 수 없는 계좌는 숨기지 않는다.** 이름을 `#A39B8C`로 낮추고 `국내 상장 ETF는 소수점 매매 불가`(`#9C4A16`)를 적고 토글은 꺼진 상태로 비활성.
- **수량 반올림 규칙 2개**(라디오): `편차가 가장 작아지는 수량`(소수점 넷째 자리까지) / `현금이 남는 쪽으로 내림`(예산 초과 방지). 목적이 다르므로 둘 다 남긴다.
- **결과 미리보기**: 같은 조정 제안을 주 단위 vs 소수점으로 나란히. 좌 `#F7F3EA` 블록(`28주`, `편차 +0.42%p 남음` `#B85127`), 화살표 `arrow_forward` `#A39B8C`, 우 `#E6EEEC` 블록(`28.4312주`, `편차 0.00%p` `#0E7A52`). 아래 `연금저축 ETF는 계속 주 단위로 계산합니다`.

---

## Interactions & Behavior

- **탭 이동**: `IndexedStack`으로 각 탭 상태를 보존한다(결산 탭의 기간 선택이 탭을 옮겨도 유지돼야 한다).
- **결산 기간 선택**: 막대 탭 = 즉시 계산·반영. 가로 스크롤 = 과거 기간 로드(연속). 달력 = 점프 시트. 전체 결산과 각 포트 결산은 **독립 상태**로 저장한다(스코프별 `{period, PeriodKey}`).
- **진행 중 기간**: 확정 기간과 시각적으로 구분(점선 막대 + 점). 종료일은 오늘로 계산(`SettlementService`의 `isCurrentPeriod`/`effectiveEnd` 로직 그대로).
- **시세 갱신 3상태**: 갱신 중(이전 값 흐리게, `rgba(255,255,255,.55)`) → 완료 → 실패(마지막 값 유지 + 기준 시각 + 다시 시도). 값을 `0`이나 `—`로 바꾸지 말 것.
- **리밸런싱 조정**: 제안 → 확인 → 적용. 적용은 기존 `PortfolioProvider.applyRebalancing` 경로 사용.
- **소수점 토글**: 켜는 즉시 미리보기 수치가 갱신된다. `market == 'KR'`인 종목만 있는 포트는 토글 비활성.
- **애니메이션**: 기본 Material 전환. 막대 선택은 색 전환 150ms 정도. 과한 모션 없음.

## State Management

새로 필요한 상태 (모두 `ChangeNotifier` + `main.dart`의 `MultiProvider`에 등록):

| 상태 | 내용 |
| --- | --- |
| `MainShellIndex` (또는 셸 내부 `setState`) | 선택된 탭 인덱스 0~3 |
| `SettlementScopeState` | 스코프별(전체 / 포트 id) `SettlementPeriod` + `PeriodKey`. 앱 재시작 시 마지막 선택 복원(SharedPreferences) |
| 결산 차트 시리즈 캐시 | `(scope, period)` → 최근 N개 `SettlementResult`. API 재호출 최소화 |

**모델 추가** (`lib/models/portfolio.dart`, `toJson`/`fromJson`/`copyWith` 모두 반영, 기존 저장 데이터 호환을 위해 기본값 필수):

```dart
bool fractionalEnabled = false;                 // 계좌별 소수점 거래
FractionalRounding fractionalRounding =         // 수량 반올림 규칙
    FractionalRounding.minDeviation;            // minDeviation | floorCash
```

**시그니처 변경**: `RebalanceItemResult.newShares`와 `delta`가 `int` → **`double`**. `rebalancer.dart`의 `ideal.floor()` 경로와 `portfolio_detail_screen.dart`의 호출부를 모두 고쳐야 한다.

**데이터 요구**
- 결산 차트는 최근 6개 기간이 필요하다 → `SettlementService`에 다중 기간 계산 함수를 추가한다(기간별로 `calculate`를 호출하되 가격 조회를 묶어 API 호출을 줄인다. `ApiService.fetchWeekPrices` 사용 중).
- 전체 결산의 **포트폴리오별 기여도**는 아직 없다(기존 `contributions`는 종목별). 포트별 `absoluteReturn`을 전체 분모로 나눠 `%p`를 만든다.

## Assets

- 아이콘: **Material Symbols** 이름을 시안에 그대로 썼다(`account_balance_wallet`, `balance`, `bar_chart`, `more_horiz`, `calendar_month`, `chevron_right`, `arrow_back`, `arrow_forward`, `cloud_off`, `refresh`, `error`, `search_off`, `upload_file`, `tune`, `help`, `ios_share`, `check_circle`, `radio_button_checked/unchecked`, `close`). Flutter `Icons`의 대응 아이콘을 쓴다.
- 폰트: Pretendard — 이미 앱에 설정되어 있다.
- 브랜드 마크: 기존 `widgets/app_logo.dart`의 원형 마크를 그대로 유지(시안의 conic 그라데이션은 기존 마크 재현이다).
- 새로 만들 이미지 없음.

## Files

이 폴더에 든 시안 파일 → 수정할 저장소 파일 대응:

| 디자인 | 저장소 파일 |
| --- | --- |
| 셸 · 탭바 · 배너 | `lib/main.dart`(home), 신규 `lib/screens/main_shell.dart`, `lib/widgets/bottom_banner_ad.dart` |
| 색 토큰 · 테마 · 손익색 | `lib/main.dart` (`AppColors` 확장, `ThemeData`, `PnlColorNotifier`) |
| 자산 탭 (v12·v13·v16·v17) | `lib/screens/portfolio_list_screen.dart`, `lib/screens/portfolio_detail_screen.dart`, `lib/widgets/transaction_bottom_sheet.dart`, `item_form_dialog.dart`, `item_bottom_sheet.dart`, `lib/services/excel_import_service.dart` |
| 리밸런싱 탭 (v18·v20) | `lib/utils/rebalancer.dart`, `lib/screens/portfolio_detail_screen.dart`, `lib/models/portfolio.dart` |
| 결산 탭 (v22) | `lib/services/settlement_service.dart`, `portfolio_list_screen.dart`(전체 결산), `portfolio_detail_screen.dart`(포트 결산), 신규 위젯(차트·점프 시트) |
| 더보기 탭 (v23) | 신규 `lib/screens/more_screen.dart`, `lib/widgets/app_settings_dialog.dart`, `settings_dialog.dart`, `notification_settings_dialog.dart` |
| 문구 | `lib/l10n/app_localizations_ko.dart`, `_en.dart` (`copy_ko_en.md` 참조) |

## 확인이 필요한 사항

1. **다크 모드** — 시안에 없다. `design_tokens.dart`의 다크 값으로 구현한 뒤 스크린샷 확인이 필요하다.
2. **영문 문구** — `copy_ko_en.md`의 영문은 초안이다. 검수 필요.
3. **아직 안 그린 화면** — 업로드 후 종목 연결(매칭) 화면, 프리셋 없는 파일의 열 직접 매핑. 업로드에 붙는 부속이라 나머지 구현 뒤에 진행.
