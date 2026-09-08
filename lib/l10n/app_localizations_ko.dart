// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get excludedShort => '제외';

  @override
  String get keepAsIs => '그대로 둠';

  @override
  String get firstRunTitle => '보유 종목을 어떻게 넣으시겠어요?';

  @override
  String get settlementCannotCompute => '시세를 받지 못해 계산할 수 없습니다';

  @override
  String get settlementNoHoldings => '해당 기간 보유 종목 없음';

  @override
  String get targetWeightsTitle => '목표 비중 설정';

  @override
  String get targetSum => '목표 합계';

  @override
  String get targetSumMustBe100 => '합계를 100%로 맞춰 주세요';

  @override
  String currentWeightIs(String pct) {
    return '현재 $pct%';
  }

  @override
  String get notifRebalanceSection => '리밸런싱 점검 알림';

  @override
  String get settlementNotifNote => '각 기간이 끝나면 알려드립니다.';

  @override
  String get addPortfolioTitle => '포트폴리오 만들기';

  @override
  String get renamePortfolio => '이름 변경';

  @override
  String get portfolioNameLabel => '이름';

  @override
  String get portfolioNameHint => '예: 연금저축 ETF';

  @override
  String get hintTargetsInRebalanceTab => '목표 비중은 종목을 담은 뒤 리밸런싱 탭에서 정합니다.';

  @override
  String get hintThenAddStocks => '만들면 바로 종목 검색으로 넘어갑니다.';

  @override
  String get createAndAddStocks => '만들고 종목 담기';

  @override
  String get autoUpdateSection => '자동 새로고침';

  @override
  String get thresholdNote =>
      '편차가 이 값보다 작은 종목은 조정 제안에서 빠집니다. 0이면 모든 종목을 조정합니다.';

  @override
  String get itemEditNote => '보유 수량은 거래 내역에서 계산됩니다. 바꾸려면 거래를 추가하거나 고치세요.';

  @override
  String get itemName => '종목명';

  @override
  String get itemNameHint => '예: TIGER 미국S&P500';

  @override
  String get itemFormNote => '수량을 넣으면 그 날짜의 매수 거래가 하나 만들어집니다.';

  @override
  String get cashFormNoteOff => '예수금은 계좌에 남은 현금입니다. 비중 계산에서는 빠집니다.';

  @override
  String get cashFormNote => '예수금은 계좌에 남은 현금입니다. 비중 계산에 함께 잡힙니다.';

  @override
  String get validationNameRequired => '종목명을 입력해 주세요';

  @override
  String deleteLosesItems(int items, int txs) {
    return '종목 $items개 · 거래 $txs건이 함께 지워집니다.';
  }

  @override
  String get deleteCannotUndo => '되돌릴 수 없습니다.';

  @override
  String yearMonth(int year, int month) {
    return '$year년 $month월';
  }

  @override
  String get netBuy => '순매수';

  @override
  String get netSell => '순매도';

  @override
  String get fractionalIntro => '소수점 매매 가능 여부는 증권사·계좌마다 다릅니다. 되는 계좌만 켜세요.';

  @override
  String get fractionalPerAccount => '계좌별 설정';

  @override
  String get fractionalReasonOverseas => '해외주식 · 소수점 매매 가능';

  @override
  String fractionalReasonPartial(int count) {
    return '해외 종목 $count개만 해당';
  }

  @override
  String get fractionalReasonKrOnly => '국내 종목만 있음 · 증권사에 따라 안 될 수 있습니다';

  @override
  String get fractionalRoundingTitle => '수량 반올림';

  @override
  String get fractionalRoundingDisabled =>
      '소수점 거래를 켠 계좌가 없습니다. 계좌를 먼저 켜면 반올림 규칙을 고를 수 있습니다.';

  @override
  String get roundingMinDeviation => '편차가 가장 작아지는 수량';

  @override
  String roundingMinDeviationDesc(int digits) {
    return '소수점 $digits째 자리까지 반올림합니다. 목표에 가장 가깝지만 예산을 아주 조금 넘을 수 있습니다.';
  }

  @override
  String get roundingFloorCash => '예수금이 남는 쪽으로 내림';

  @override
  String get roundingFloorCashDesc => '예산을 넘지 않습니다. 대신 아주 적은 예수금이 남습니다.';

  @override
  String get fractionalPreviewTitle => '지금 조정 제안이 이렇게 바뀝니다';

  @override
  String get previewWholeShares => '주 단위';

  @override
  String get previewFractional => '소수점';

  @override
  String get noPortfolios => '포트폴리오가 없습니다';

  @override
  String refreshPartialFail(int count) {
    return '$count종목은 예전 시세 그대로입니다';
  }

  @override
  String refreshFailedNote(String time) {
    return '새로고침 실패 · $time 시세';
  }

  @override
  String get refreshRetry => '다시 시도';

  @override
  String excludedFromSettlement(int count, String amount) {
    return '$count종목 결산 제외 · $amount';
  }

  @override
  String get excludedFixLink => '자세히';

  @override
  String get excludedSheetTitle => '결산에서 빠진 종목';

  @override
  String get excludedSheetBody =>
      '아래 종목은 이 기간의 거래 기록이 없어 결산에만 안 잡힙니다. 자산과 리밸런싱에는 그대로 들어갑니다.\n\n종목 상세에서 매수 거래를 넣으면 결산에도 들어갑니다.';

  @override
  String get excludedNoHistory => '거래 기록 없음';

  @override
  String lastMonthReturn(String rate) {
    return '전월 $rate';
  }

  @override
  String get spark1w => '1주';

  @override
  String get spark1m => '1개월';

  @override
  String get spark3m => '3개월';

  @override
  String get spark6m => '6개월';

  @override
  String get spark1y => '1년';

  @override
  String sparklinePending(int count) {
    return '$count일치는 모여야 자산 추이가 그려집니다';
  }

  @override
  String get searchPrompt => '종목명이나 티커를 입력해 주세요';

  @override
  String get searchNoResult => '검색 결과가 없습니다.\n티커나 종목코드로도 찾아보세요';

  @override
  String get filterAll => '전체';

  @override
  String get filterKr => '국내';

  @override
  String get filterUs => '해외';

  @override
  String get cashAddHint => '계좌에 남은 현금을 예수금으로 넣어 두면 비중 계산에 함께 잡힙니다.';

  @override
  String get cashAddButton => '예수금 추가';

  @override
  String get manualEntryHint => '직접 입력해서 추가';

  @override
  String alreadyInPortfolio(String name) {
    return '$name 이미 담겨 있습니다';
  }

  @override
  String txCountLabel(int count) {
    return '$count건';
  }

  @override
  String get editTransaction => '거래 수정';

  @override
  String get transactionAmount => '거래금액';

  @override
  String get saveTransaction => '거래 저장';

  @override
  String get transactionAffectsAvg => '저장하면 보유 수량과 평단도 같이 바뀝니다.';

  @override
  String get validationQtyPositive => '수량을 0보다 크게 입력해 주세요';

  @override
  String get validationPricePositive => '단가를 0보다 크게 입력해 주세요';

  @override
  String validationSellExceeds(String owned) {
    return '보유 수량($owned)보다 많이 팔 수 없습니다';
  }

  @override
  String get addPortfolio => '포트폴리오 추가';

  @override
  String get menuGroupView => '보기';

  @override
  String get menuGroupSetup => '설정';

  @override
  String get menuGroupData => '데이터';

  @override
  String get menuGroupThisPortfolio => '이 포트폴리오';

  @override
  String get editPortfolios => '포트폴리오 목록 편집';

  @override
  String get editPortfoliosHint => '끌어서 순서를 바꾸고, ⋮에서 이름·복제·삭제를 합니다';

  @override
  String get reorderPortfolios => '포트폴리오 순서 변경';

  @override
  String get reorderItems => '종목 목록 편집';

  @override
  String get holdingQty => '보유 수량';

  @override
  String get basedOnTransactions => '거래 기준';

  @override
  String get enteredDirectly => '직접 입력';

  @override
  String get noTransactionsYet => '아직 거래 내역이 없습니다';

  @override
  String get proposalTitle => '조정 제안';

  @override
  String get modeHoldings => '보유 안에서';

  @override
  String get modeAddCash => '추가 입금으로';

  @override
  String toleranceLabel(String value) {
    return '허용 ±$value%p';
  }

  @override
  String get withinTolerance => '허용 안';

  @override
  String get calcBasisTitle => '계산 기준';

  @override
  String get roundingWholeShares => '단주는 반올림';

  @override
  String get roundingWholeSharesDesc =>
      '1주 단위로만 계산합니다. 목표 비중에 0에 가장 가까운 수량으로 맞춥니다.';

  @override
  String get roundingFractional => '소수점 거래';

  @override
  String roundingFractionalDesc(int digits) {
    return '소수점 $digits자리에서 버립니다. 예산을 넘지 않게 하려는 것이라 아주 적은 금액이 남습니다.';
  }

  @override
  String get tradeMoneyTitle => '거래 대금';

  @override
  String get tradeMoneyLeft => '남는 돈';

  @override
  String get tradeMoneyNeeded => '더 필요';

  @override
  String get proposalBasisTitle => '시세 기준';

  @override
  String proposalBasisAt(String time) {
    return '$time 시세로 계산했습니다';
  }

  @override
  String get proposalBasisNote => '주문할 때 가격이 달라져 있으면 수량도 달라집니다.';

  @override
  String get proposalBasisNever => '아직 시세를 받지 못했습니다';

  @override
  String get proposalCostTitle => '수수료 · 세금';

  @override
  String proposalCostWith(String rate) {
    return '수수료 $rate%는 반영했습니다. 세금이 빠져 있어 실제 체결액과 조금 다릅니다.';
  }

  @override
  String get proposalCostWithout => '수수료·세금이 빠져 있어 실제 체결액과 조금 다릅니다.';

  @override
  String get proposalDisclaimer => '주문은 증권사에서 직접 하세요. 체결한 뒤 아래 버튼으로 기록합니다.';

  @override
  String get noAdjustmentNeeded => '지금은 조정할 것이 없습니다';

  @override
  String get cannotCalculate => '시세를 못 받은 종목이 있어 계산할 수 없습니다';

  @override
  String get lastRebalancedNever => '조정 기록 없음';

  @override
  String get lastRebalancedToday => '오늘 조정';

  @override
  String get lastRebalancedYesterday => '어제 조정';

  @override
  String lastRebalancedDaysAgo(int days) {
    return '$days일 전 조정';
  }

  @override
  String lastRebalancedMonthsAgo(int months) {
    return '$months개월 전 조정';
  }

  @override
  String lastRebalancedYearsAgo(int years) {
    return '$years년 전 조정';
  }

  @override
  String get undoLastTitle => '마지막 기록 되돌리기';

  @override
  String undoFromProposal(int count, String when) {
    return '조정 제안 $count건 · $when';
  }

  @override
  String undoFromImport(int count, String when) {
    return '업로드 $count건 · $when';
  }

  @override
  String get undoConfirmTitle => '되돌릴까요?';

  @override
  String undoConfirmTrades(int count) {
    return '거래 $count건을 지웁니다.';
  }

  @override
  String undoConfirmItems(int count) {
    return '이 업로드가 만든 종목 $count개도 함께 지웁니다.';
  }

  @override
  String get undoConfirmCash => '예수금도 기록 전으로 돌아갑니다.';

  @override
  String undoDone(int count) {
    return '$count건을 되돌렸습니다';
  }

  @override
  String undoKeptItems(String names) {
    return '$names은(는) 그 뒤에 넣은 거래가 있어 남겼습니다';
  }

  @override
  String get undoAction => '되돌리기';

  @override
  String get a11yBack => '뒤로';

  @override
  String get a11yClose => '닫기';

  @override
  String get a11yRefresh => '새로고침';

  @override
  String get a11yMenu => '메뉴 열기';

  @override
  String get a11yClearInput => '입력 지우기';

  @override
  String get a11yRemove => '빼기';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get confirm => '확인';

  @override
  String get delete => '삭제';

  @override
  String get edit => '편집';

  @override
  String get done => '완료';

  @override
  String get exit => '종료';

  @override
  String get add => '추가';

  @override
  String get editExitTitle => '편집 종료';

  @override
  String get editExitContent => '편집 모드를 종료하시겠습니까?';

  @override
  String get saveChanges => '수정 완료';

  @override
  String get deleteConfirmTitle => '삭제 확인';

  @override
  String deleteItemContent(String name) {
    return '$name 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get appExitContent => '앱을 종료하시겠습니까?';

  @override
  String get neverUpdated => '아직 안 받음';

  @override
  String get toastAutoSettingRequired => '포트 설정에서 환율·시세 자동 조회를 켜 주세요';

  @override
  String updateFailed(String msg) {
    return '시세를 받지 못했습니다: $msg';
  }

  @override
  String updateSuccessCount(int count) {
    return '$count종목 새로고침했습니다';
  }

  @override
  String get portfolioNotFound => '포트폴리오를 찾을 수 없습니다';

  @override
  String get additionalInvestmentHint => '더 넣을 돈. 뺄 돈은 −를 붙이세요';

  @override
  String get evaluationAmount => '평가금액';

  @override
  String weightWarning(String pct) {
    return '목표 비중 합계: $pct (100%가 아닙니다)';
  }

  @override
  String get labelSettings => '설정';

  @override
  String get labelGraph => '그래프';

  @override
  String get addStock => '종목 추가';

  @override
  String get buy => '매수';

  @override
  String get sell => '매도';

  @override
  String get cash => '예수금';

  @override
  String get captureFailed => '캡처 실패';

  @override
  String get savedToGallery => '갤러리에 저장됐어요';

  @override
  String get saveFailed => '저장 실패';

  @override
  String saveFailedError(String error) {
    return '저장 실패: $error';
  }

  @override
  String get editCenterText => '중앙 텍스트 수정';

  @override
  String get editItem => '종목 편집';

  @override
  String get displayName => '표시 이름';

  @override
  String get colorLabel => '색상';

  @override
  String get portfolioEmpty => '포트폴리오 없음';

  @override
  String get portfolioGraph => '포트폴리오 그래프';

  @override
  String get editCompleteTooltip => '편집 완료';

  @override
  String get editTooltip => '편집';

  @override
  String get editCompleteBeforeSave => '편집 완료 후 저장 가능';

  @override
  String get saveImage => '이미지 저장';

  @override
  String get shareImage => '이미지 공유';

  @override
  String get capture => '캡처';

  @override
  String get notifPermissionDenied => '휴대폰 설정에서 이 앱의 알림을 켜 주세요';

  @override
  String get targetWeight => '목표 비중';

  @override
  String get currentWeight => '현재 비중';

  @override
  String get noPriceInfo => '아직 시세를 받지 못했습니다. 새로고침해 주세요';

  @override
  String get tapToEdit => '탭하여 수정';

  @override
  String get dragToReorder => '길게 눌러 끌면 순서가 바뀝니다';

  @override
  String get disclaimerTitle => '서비스 이용 안내 및 면책고지';

  @override
  String get disclaimerSectionPurpose => '목적';

  @override
  String get disclaimerTextPurpose =>
      '본 앱(Rebalancing)은 개인 투자자의 포트폴리오 리밸런싱 계산 및 거래 내역 기반 기간별 수익률 분석을 돕기 위한 참고용 도구입니다. 어떠한 경우에도 금융투자 조언, 투자 권유, 자산 운용 서비스를 제공하지 않습니다.';

  @override
  String get disclaimerSectionData => '데이터 정확성';

  @override
  String get disclaimerTextData =>
      '앱이 제공하는 다음 정보는 외부 공개 API 및 데이터 소스를 기반으로 하며, 지연·오류·누락이 발생할 수 있습니다.\n\n• 종목 정보 (종목명, 티커, 시장 구분)\n• 실시간 주가 (Yahoo Finance 기반)\n• 실시간 환율 (공개 환율 API 기반)\n• ETF 분류 및 관련 정보\n• 리밸런싱 계산 결과 (수량, 비중, 잔여 현금 등)\n• 예상 수수료 계산값\n• 결산 기간 수익률 및 종목별 기여도 (사용자 입력 거래 내역 및 과거 주가 데이터 기반)\n\n실제 시장 데이터 및 금융기관 정보와 다를 수 있으므로, 반드시 직접 확인하시기 바랍니다.';

  @override
  String get disclaimerSectionRisk => '투자 손실 책임';

  @override
  String get disclaimerTextRisk =>
      '본 앱의 정보를 바탕으로 내린 투자 결정 및 그로 인한 손실·손해에 대해 개발자는 어떠한 법적 책임도 지지 않습니다. 모든 투자 결정은 사용자 본인의 판단과 책임 하에 이루어져야 합니다.';

  @override
  String get disclaimerSectionTax => '세금 및 법적 사항';

  @override
  String get disclaimerTextTax =>
      '금융거래에 따른 세금 신고, 양도소득세, 금융소득 종합과세 등 법적 의무는 사용자가 직접 확인하고 이행해야 합니다. 본 앱은 세무·법률 조언을 제공하지 않습니다.';

  @override
  String get disclaimerSectionService => '서비스 변경 및 중단';

  @override
  String get disclaimerTextService =>
      '앱의 기능, 데이터 소스, 서비스는 사전 고지 없이 변경되거나 중단될 수 있습니다.';

  @override
  String get disclaimerStartBtn => '확인하고 시작하기';

  @override
  String get disclaimerConfirmBtn => '확인';

  @override
  String get searchHint => '종목명 또는 티커 입력';

  @override
  String get avgCost => '평균 매수단가';

  @override
  String get profitLoss => '평가손익';

  @override
  String get currentPrice => '현재가';

  @override
  String get unitKRW => '원';

  @override
  String get unitShares => '주';

  @override
  String get settings => '설정';

  @override
  String get baseCurrency => '기준 통화';

  @override
  String get currencyKRW => 'KRW (₩)';

  @override
  String get currencyUSD => 'USD (\$)';

  @override
  String get tradingFee => '거래 수수료';

  @override
  String get includeFee => '수수료 반영';

  @override
  String get feeRate => '수수료율';

  @override
  String get exchangeRateSetting => '환율';

  @override
  String get exchangeRateInput => '환율 (1 USD)';

  @override
  String get stockPriceSetting => '시세';

  @override
  String get language => '언어';

  @override
  String get portfolioAddBtn => '포트폴리오 추가';

  @override
  String get holdingsSection => '구성 종목';

  @override
  String get cashExcluded => '예수금 비중 제외';

  @override
  String get cashIncluded => '예수금 포함';

  @override
  String itemCountLabel(int count) {
    return '$count개 종목';
  }

  @override
  String get notice => '공지사항';

  @override
  String get dayChange => '전일대비';

  @override
  String get disclaimerAgreeCheckbox => '위 내용을 모두 확인했으며 동의합니다.';

  @override
  String get validationNonNegative => '0 이상으로 입력해 주세요';

  @override
  String get validationPositive => '0보다 크게 입력해 주세요';

  @override
  String get validationExchangeRatePositive => '환율은 0보다 큰 값이어야 합니다.';

  @override
  String get tabAssets => '자산';

  @override
  String get tabRebalancing => '리밸런싱';

  @override
  String get tabSettlement => '결산';

  @override
  String get tabMore => '더보기';

  @override
  String get settlementWeekly => '주간';

  @override
  String get settlementMonthly => '월간';

  @override
  String get settlementQuarterly => '분기';

  @override
  String get settlementYearly => '연간';

  @override
  String get backupData => '백업';

  @override
  String get restoreData => '복원';

  @override
  String get noMatchingTransactions => '조건에 맞는 거래가 없습니다';

  @override
  String get clearFilters => '필터 해제';

  @override
  String get filterByItem => '종목';

  @override
  String get backupNever => '아직 없음';

  @override
  String get backupToday => '오늘';

  @override
  String get backupYesterday => '어제';

  @override
  String backupDaysAgo(int days) {
    return '$days일 전';
  }

  @override
  String backupMonthsAgo(int months) {
    return '$months개월 전';
  }

  @override
  String backupYearsAgo(int years) {
    return '$years년 전';
  }

  @override
  String get backupFailed => '백업 실패';

  @override
  String get restoreConfirmTitle => '데이터 복원';

  @override
  String restoreConfirmContent(int count) {
    return '포트폴리오 $count개를 복원합니다.\n현재 데이터는 모두 교체됩니다.';
  }

  @override
  String restoreSuccess(int count) {
    return '포트폴리오 $count개를 복원했습니다';
  }

  @override
  String get restoreFailed => '올바른 백업 파일이 아닙니다';

  @override
  String get notifReminder => '리밸런싱 알림';

  @override
  String get notifEnableDesc => '정기 리밸런싱 점검 알림';

  @override
  String get notifEnableHint => '지정한 주기마다 앱 알림을 보내드립니다';

  @override
  String get purchaseDateLabel => '매수 일자';

  @override
  String get transactionHistory => '거래 내역';

  @override
  String get deleteTransactionTitle => '이 거래를 지울까요?';

  @override
  String get deleteTransactionBody => '수량과 평균 단가가 이 거래를 뺀 값으로 다시 계산됩니다.';

  @override
  String get transactionDeleted => '거래를 지웠습니다';

  @override
  String get addTransaction => '거래 추가';

  @override
  String get transactionBuy => '매수';

  @override
  String get transactionSell => '매도';

  @override
  String get transactionDate => '거래 일자';

  @override
  String get transactionQty => '수량';

  @override
  String get transactionPrice => '단가';

  @override
  String settlementWeekNum(int week) {
    return '$week주차';
  }

  @override
  String settlementQuarterNum(int q) {
    return '$q분기';
  }

  @override
  String settlementYearLabel(int year) {
    return '$year년';
  }

  @override
  String get excelImportTitle => '거래내역 업로드';

  @override
  String get excelImportDone => '가져오기 완료';

  @override
  String excelImportAdded(int count) {
    return '$count건 거래 추가됨';
  }

  @override
  String excelImportCreated(int count) {
    return '신규 종목 $count개 생성됨';
  }

  @override
  String excelImportSkipped(int count) {
    return '$count행 건너뜀';
  }

  @override
  String get excelImportNothingAdded => '추가된 거래내역이 없습니다';

  @override
  String get settlementNotifHeader => '결산 알림';

  @override
  String get rebalancingThresholdLabel => '리밸런싱 임계값';

  @override
  String get rebalancingThresholdHint => '편차가 이 값 미만이면 거래 권고 안 함';

  @override
  String get fractionalTrading => '소수점 거래';

  @override
  String get maxDriftAfter => '조정 후 최대 편차';

  @override
  String planMustRunAll(int count) {
    return '$count건을 모두 주문했을 때';
  }

  @override
  String allItemsInRange(int count) {
    return '$count종목 전부 허용 편차 안.';
  }

  @override
  String togetherNTrades(int count) {
    return '함께 실행할 $count건';
  }

  @override
  String get uncheckToRecalc => '체크를 끄면 다시 계산';

  @override
  String cashLedgerTitle(int count) {
    return '예수금 하나로 매수 $count건';
  }

  @override
  String get sellProceeds => '매도 대금';

  @override
  String buyCostN(int count) {
    return '매수 대금 $count건';
  }

  @override
  String get cashCheckAtBroker =>
      '증권사 앱에서 예수금을 확인해 그대로 적어 주세요. 앱이 대신 계산하지 않습니다.';

  @override
  String get cashInWeightTitle => '비중에 포함';

  @override
  String get cashInWeightOn => '예수금도 목표 비중을 갖고, 조정 대상에 들어갑니다.';

  @override
  String get cashInWeightOff =>
      '비중에서 빠집니다. 조정할 때 쓰지도 않습니다 — 쓰려면 조정 제안에서 «추가 입금으로»에 넣으세요.';

  @override
  String get cashCheckAfterTrade =>
      '예수금은 앱이 계산하지 않습니다. 체결 뒤 증권사에서 확인해 직접 고쳐 주세요.';

  @override
  String get cashAfterAdjust => '조정 후 예수금';

  @override
  String get cashSharedNote => '매수가 같은 예수금을 나눠 씁니다 — 따로 계산하면 맞지 않습니다.';

  @override
  String get sellFirstNote => '매도 먼저 실행 — 해외 종목은 환전이 필요하면 하루 이틀 늦어질 수 있습니다.';

  @override
  String recordNTransactions(int count) {
    return '$count건 거래 내역으로 기록';
  }

  @override
  String get shareProposal => '제안 공유';

  @override
  String driftedTogether(int count) {
    return '이탈 $count종목 함께';
  }

  @override
  String selectedExcluded(int sel, int exc) {
    return '$sel건 선택 · $exc건 제외';
  }

  @override
  String nOutOfRange(int count) {
    return '$count개 남음';
  }

  @override
  String excludedOnlyOutside(String name) {
    return '제외한 $name만 허용 밖';
  }

  @override
  String whereToSendShare(String name, String amount) {
    return '$name 몫 $amount 어디로 보낼까요';
  }

  @override
  String excludedNItems(int count) {
    return '제외한 $count건';
  }

  @override
  String get toRemainingItems => '나머지 종목에';

  @override
  String get keepInCash => '예수금에 남김';

  @override
  String wouldExceedBy(String value) {
    return '$value로 허용을 벗어납니다';
  }

  @override
  String get recalculated => '재계산';

  @override
  String keptAsIsDrift(String weight, String drift) {
    return '$weight 그대로 · $drift';
  }

  @override
  String recordNTradesTitle(int count) {
    return '거래 $count건 기록';
  }

  @override
  String get fromProposal => '조정 제안에서';

  @override
  String appliedToAllN(int count) {
    return '$count건에 같이 적용됩니다';
  }

  @override
  String commissionAutoSum(String rate, int count) {
    return '수수료 $rate% 자동 · $count건 합';
  }

  @override
  String get followsPortfolioSettings => '수수료·예수금은 이 포트 설정을 따릅니다.';

  @override
  String get priceIsProposalNote => '단가는 제안 시점 현재가입니다 — 체결가로 고쳐야 다음 조정이 정확합니다.';

  @override
  String recordNButton(int count) {
    return '$count건 기록하기';
  }

  @override
  String fxConverted(String rate, String amount) {
    return '환율 $rate · 환산 $amount';
  }

  @override
  String get importStep1 => '1 / 2 · 파일 선택';

  @override
  String importStep2(String file) {
    return '2 / 2 · $file';
  }

  @override
  String get targetPortfolio => '담을 포트폴리오';

  @override
  String get uploadHow => '업로드 방법';

  @override
  String get downloadTemplateTitle => '표준 양식 내려받기';

  @override
  String get downloadTemplateDesc => 'XLSX · 옮겨 적으면 확실하게 들어갑니다';

  @override
  String get brokerFileOk =>
      '증권사에서 받은 파일을 그대로 올려도 됩니다 — 거래일 · 종목 · 구분 · 수량 · 단가 같은 열 이름을 자동으로 찾습니다.';

  @override
  String get pickFile => '파일 선택';

  @override
  String get pickFileDesc => 'CSV · XLSX · 최대 5MB';

  @override
  String get requiredColumns => '파일에 있어야 하는 열';

  @override
  String get requiredColumnsList => '거래일 · 종목 · 매수/매도 · 수량 · 단가';

  @override
  String get toImportLabel => '가져올 거래';

  @override
  String importCountOf(int ready, int total) {
    return '$ready / $total건';
  }

  @override
  String importSummaryLine(String range, int items, int buy, int sell) {
    return '$range · 종목 $items개 · 매수 $buy · 매도 $sell';
  }

  @override
  String get itemNotFound => '종목을 못 찾았습니다';

  @override
  String get linkAction => '연결';

  @override
  String get alreadyExists => '이미 있는 거래';

  @override
  String get skippedShort => '건너뜀';

  @override
  String get unreadableRows => '읽지 못한 줄';

  @override
  String get previewTitle => '미리보기';

  @override
  String newestNItems(int count) {
    return '최근순 $count건';
  }

  @override
  String importNButton(int count) {
    return '$count건 가져오기';
  }

  @override
  String get nothingToImport => '가져올 거래가 없습니다';

  @override
  String get linkItemTitle => '종목 연결';

  @override
  String linkItemDesc(String label, int count) {
    return '$label 거래 $count건을 어느 종목에 넣을까요';
  }

  @override
  String get createNewItem => '새 종목으로 만들기';

  @override
  String nRowsShort(int count) {
    return '$count건';
  }

  @override
  String get firstRunSubtitle => '나중에 바꾸거나 섞어 쓸 수 있습니다.';

  @override
  String get firstRunUploadTitle => '거래내역 파일 올리기';

  @override
  String get firstRunNeedsPc => 'PC 필요';

  @override
  String get firstRunUploadDesc =>
      'HTS·홈페이지에서 거래내역 파일을 받을 수 있다면 수십 건이 한 번에 들어옵니다.';

  @override
  String get firstRunUploadCta => '파일로 시작';

  @override
  String get firstRunRecordTitle => '직접 거래 기록하기';

  @override
  String get firstRunRecommended => '권장';

  @override
  String get firstRunRecordDesc =>
      '매수·매도를 수량 · 단가 · 날짜로 남기면 결산 탭의 기간별 손익까지 나옵니다.';

  @override
  String get firstRunRecordCta => '기록하며 시작';

  @override
  String get firstRunQuickTitle => '보유 현황만 빠르게';

  @override
  String get firstRunQuickDesc =>
      '지금 가진 수량과 평단만 넣습니다. 자산·리밸런싱은 그대로 되지만 결산 탭의 기간별 손익은 안 나옵니다.';

  @override
  String get firstRunQuickCta => '현재 보유만 입력';

  @override
  String get hintThenUpload => '만들면 바로 파일 올리기로 넘어갑니다.';

  @override
  String get createAndUpload => '만들고 파일 올리기';

  @override
  String get sortManual => '직접 배치';

  @override
  String get sortByValue => '금액순';

  @override
  String get sortByReturn => '수익률순';

  @override
  String get sortManualNote => '직접 배치 후에는 금액이 바뀌어도 순서가 그대로입니다.';

  @override
  String get rename => '이름 변경';

  @override
  String duplicatedTo(String name) {
    return '$name (으)로 복제했습니다';
  }

  @override
  String get duplicate => '복제';

  @override
  String get copySuffix => '(복사)';

  @override
  String get feeLabel => '수수료';

  @override
  String commissionAutoRate(String rate) {
    return '수수료율 $rate% 자동 적용';
  }

  @override
  String get noTransactionsNote => '거래 내역 없이 현재 보유만 입력한 종목입니다';

  @override
  String weightSumNotice(String pct) {
    return '목표 비중 합계가 $pct입니다. 100%가 되어야 조정 제안을 계산할 수 있습니다.';
  }

  @override
  String get fixTargetWeights => '목표 비중 맞추기';

  @override
  String get needMoreItems => '종목을 더 담아야 조정할 수 있습니다';

  @override
  String itemAdded(String name) {
    return '$name 담았습니다';
  }

  @override
  String get createPortfolioCta => '포트폴리오 만들기';

  @override
  String partialSettlement(int count) {
    return '아직 다 받지 못한 값입니다 · $count종목 남음';
  }

  @override
  String get notifSystemOff => '휴대폰에서 알림이 꺼져 있습니다';

  @override
  String get notifSystemOffHint => '켜야 아래 설정이 동작합니다';

  @override
  String get notifOpenSettings => '설정 열기';

  @override
  String get notifPermissionTitle => '알림 권한이 필요합니다';

  @override
  String get notifPermissionBody => '휴대폰 설정에서 이 앱의 알림을 켜 주세요.';

  @override
  String get notifFrequencyLabel => '주기';

  @override
  String get notifWeekdayLabel => '요일';

  @override
  String get notifDayLabel => '일자';

  @override
  String get notifTimeLabel => '시간';

  @override
  String get notifEveryWeek => '매주';

  @override
  String get notifEveryMonth => '매월';

  @override
  String notifDayOfMonth(int day) {
    return '$day일';
  }

  @override
  String get notifDayCapHint => '29~31일은 없는 달이 있습니다';

  @override
  String get settlementNotifTime => '알림 시간';

  @override
  String get settlementNotifTimeHint => '모든 결산 알림에 적용됩니다';
}
