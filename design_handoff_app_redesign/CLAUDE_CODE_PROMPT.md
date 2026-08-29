# Claude Code 붙여넣기용 프롬프트

아래 블록 전체를 복사해서 Claude Code에 붙여넣으세요.
`design_handoff_app_redesign/` 폴더를 저장소 루트에 함께 넣어두는 것이 전제입니다.

---

이 저장소(Flutter 앱 `rebalancing_app`)의 UI를 새 디자인으로 개편한다.

## 자료 위치

`design_handoff_app_redesign/` 폴더를 먼저 전부 읽어라.

- `README.md` — 화면별 레이아웃·색·타입·상호작용 명세 (가장 중요)
- `design_tokens.dart` — 그대로 붙여 쓸 색 토큰 (라이트/다크)
- `copy_ko_en.md` — 새로 필요한 문구의 한/영 대응표
- `메인화면.dc.html` — 디자인 원본. 59개 화면이 v1~v23으로 들어있고, 각 화면 아래에 결정 이유가 적혀 있다. 브라우저로 열어서 봐라(같은 폴더의 `support.js`가 필요).
- `현재 UI 재현.dc.html` — 개편 전 화면(비교용)
- `settlement-c.dc.html`, `period-picker.dc.html` — 결산 탭 기간 선택 메커니즘 원본

**중요:** HTML 파일은 구현 참조용 디자인 시안이다. 코드를 옮겨 붙이지 말고, 이 저장소의 Flutter 환경과 기존 패턴(Provider, `context` 확장 색 토큰, `AppLocalizations`)으로 **다시 만들어라**. 시안은 하이파이다 — 색·간격·글자 크기는 명세 값 그대로 맞춰라.

## 지켜야 할 기존 구조

- 상태: `provider`. 새 전역 상태도 `ChangeNotifier` + `MultiProvider`(main.dart)에 등록.
- 색: `main.dart`의 `extension AppColors on BuildContext`. 하드코딩 금지, 토큰만 사용. 다크 모드가 있으니 새 색도 반드시 라이트/다크 쌍으로 추가.
- 손익 색: **반드시** `PnlColorNotifier.positiveColor / negativeColor`를 통과시켜라. 사용자가 빨강/파랑 스킴을 쓸 수 있다. 시안의 초록/빨강은 greenRed 스킴 기준이다.
- 문구: 전부 `AppLocalizations`. `app_localizations_ko.dart`와 `_en.dart` 양쪽에 키를 추가한다. 하드코딩된 한글 금지.
- 폰트: 이미 `fontFamily: 'Pretendard'`. 시안과 동일.
- 시안의 px는 Flutter 논리 픽셀과 1:1이다(기준 폭 390).

## 작업 순서 (이 순서대로, 단계마다 멈추고 확인)

**1단계 — 토큰과 셸**
1. `design_tokens.dart`의 색을 `main.dart`의 `AppColors` 확장에 병합한다. 기존 이름(`scaffoldBg`, `cardBg`, `textPrimary` …)은 유지하고 값만 교체 + 새 토큰 추가. `ThemeData`의 `scaffoldBackgroundColor`, `appBarTheme`, `cardTheme`도 새 값으로.
2. `PnlColorNotifier`의 greenRed 값을 `#0E7A52 / #B85127`로 교체.
3. **하단 4탭 셸을 새로 만든다.** 지금은 `PortfolioListScreen` 하나에 AppBar TabBar(portfolio_list_screen.dart:649)로 되어 있다. 새 `MainShell`(IndexedStack + BottomNavigationBar 64px)을 만들고 탭을 `자산 / 리밸런싱 / 결산 / 더보기`로 둔다. 배너(`widgets/bottom_banner_ad.dart`, 50px)는 하단 탭바 **바로 위**에 고정한다. `main.dart`의 `home:`을 `MainShell`로 바꾼다.
4. 여기서 멈추고 스크린샷으로 확인받아라.

**2단계 — 자산 탭** (README §자산)
포트 카드 리스트, 총자산 헤더, 카드 행의 타입 규칙(이름 15 / 금액 15 / 수익률 12.5 / 전일대비 11)을 맞춘다. 기존 `portfolio_list_screen.dart`를 이 탭으로 옮긴다.

**3단계 — 리밸런싱 탭** (README §리밸런싱)
`utils/rebalancer.dart`를 **일괄 조정**으로 고친다. 지금은 종목별 순차 계산이라 한 종목을 조정하면 나머지 편차가 다시 어긋난다. 편차 초과 종목 전체를 한 번에 목표로 보내는 해를 구하고, 남는 현금은 계좌별로 처리한다(현금은 계좌 귀속이므로 포트 간 합산 금지). `Portfolio.rebalancingThreshold`가 이미 허용 편차 필드다 — 새로 만들지 말고 그걸 UI에 연결.

**4단계 — 결산 탭** (README §결산, v22)
`services/settlement_service.dart`에 이미 `SettlementService.calculate`(Modified Dietz), `PeriodKey`, `maxSub`, `earliestYear`가 있다. **재구현하지 말고 재사용**하되 두 개를 추가한다:
- 최근 N개 기간을 한 번에 계산하는 함수(차트 막대 6개용)
- 전체 결산에서 **포트폴리오별** 기여도(기존 `contributions`는 종목별이다)
UI는 차트가 기간 선택 컨트롤이다(막대 탭 = 기간 선택, 좌우 스크롤 = 과거). 달력 버튼은 점프 시트를 연다. 1~52 주차 목록 같은 UI는 만들지 말 것.

**5단계 — 더보기 탭 + 소수점 거래** (README §더보기, v23)
소수점 거래는 **전역 토글이 아니라 계좌(포트)별 설정**이다. `Portfolio`에 `fractionalEnabled`(bool)와 `fractionalRounding`(enum: minDeviation / floorCash)을 추가하고 `toJson/fromJson/copyWith`에 반영(기존 저장 데이터 호환 — 기본값 false).
`RebalanceItemResult.newShares`와 `delta`가 지금 `int`다. 소수점 지원을 위해 `double`로 바꾸고 호출부를 모두 고쳐라. 국내 상장 ETF/주식(`market == 'KR'`)은 소수점 매매가 불가하므로 토글을 켤 수 없게 하고 이유를 표시한다.

## 규칙

- 각 단계 끝에서 `flutter analyze`를 돌려 경고 0을 유지한다.
- 기존 저장 데이터(SharedPreferences)와 호환을 깨지 말 것. 모델 필드 추가 시 `fromJson`에 기본값을 준다.
- 시안에 없는 화면은 만들지 마라. 애매하면 물어봐라.
- 커밋은 단계별로 나눠라.

먼저 `design_handoff_app_redesign/README.md`를 읽고, 1단계 계획을 요약해서 보여줘라. 승인하면 시작한다.
