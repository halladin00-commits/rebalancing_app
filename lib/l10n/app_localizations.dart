import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @excludedShort.
  ///
  /// In ko, this message translates to:
  /// **'제외'**
  String get excludedShort;

  /// No description provided for @keepAsIs.
  ///
  /// In ko, this message translates to:
  /// **'그대로 둠'**
  String get keepAsIs;

  /// No description provided for @firstRunTitle.
  ///
  /// In ko, this message translates to:
  /// **'보유 종목을 어떻게 넣으시겠어요?'**
  String get firstRunTitle;

  /// No description provided for @settlementCannotCompute.
  ///
  /// In ko, this message translates to:
  /// **'시세를 받지 못해 계산할 수 없습니다'**
  String get settlementCannotCompute;

  /// No description provided for @settlementNoHoldings.
  ///
  /// In ko, this message translates to:
  /// **'해당 기간 보유 종목 없음'**
  String get settlementNoHoldings;

  /// No description provided for @targetWeightsTitle.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중 설정'**
  String get targetWeightsTitle;

  /// No description provided for @targetSum.
  ///
  /// In ko, this message translates to:
  /// **'목표 합계'**
  String get targetSum;

  /// No description provided for @targetSumMustBe100.
  ///
  /// In ko, this message translates to:
  /// **'합계를 100%로 맞춰 주세요'**
  String get targetSumMustBe100;

  /// No description provided for @currentWeightIs.
  ///
  /// In ko, this message translates to:
  /// **'현재 {pct}%'**
  String currentWeightIs(String pct);

  /// No description provided for @notifRebalanceSection.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 점검 알림'**
  String get notifRebalanceSection;

  /// No description provided for @settlementNotifNote.
  ///
  /// In ko, this message translates to:
  /// **'각 기간이 끝난 다음 날 아침에 알려줍니다. 결산 화면을 열어 확인하라는 알림입니다.'**
  String get settlementNotifNote;

  /// No description provided for @addPortfolioTitle.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 만들기'**
  String get addPortfolioTitle;

  /// No description provided for @renamePortfolio.
  ///
  /// In ko, this message translates to:
  /// **'이름 변경'**
  String get renamePortfolio;

  /// No description provided for @portfolioNameLabel.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get portfolioNameLabel;

  /// No description provided for @portfolioNameHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 연금저축 ETF'**
  String get portfolioNameHint;

  /// No description provided for @chooseEmoji.
  ///
  /// In ko, this message translates to:
  /// **'아이콘'**
  String get chooseEmoji;

  /// No description provided for @hintTargetsInRebalanceTab.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중은 종목을 담은 뒤 리밸런싱 탭에서 정합니다.'**
  String get hintTargetsInRebalanceTab;

  /// No description provided for @hintThenAddStocks.
  ///
  /// In ko, this message translates to:
  /// **'만들면 바로 종목 검색으로 넘어갑니다.'**
  String get hintThenAddStocks;

  /// No description provided for @createAndAddStocks.
  ///
  /// In ko, this message translates to:
  /// **'만들고 종목 담기'**
  String get createAndAddStocks;

  /// No description provided for @autoUpdateSection.
  ///
  /// In ko, this message translates to:
  /// **'자동 갱신'**
  String get autoUpdateSection;

  /// No description provided for @thresholdNote.
  ///
  /// In ko, this message translates to:
  /// **'편차가 이 값보다 작은 종목은 조정 제안에서 빠집니다. 0이면 모든 종목을 조정합니다.'**
  String get thresholdNote;

  /// No description provided for @itemEditNote.
  ///
  /// In ko, this message translates to:
  /// **'보유 수량은 거래 내역에서 계산됩니다. 바꾸려면 거래를 추가하거나 고치세요.'**
  String get itemEditNote;

  /// No description provided for @itemName.
  ///
  /// In ko, this message translates to:
  /// **'종목명'**
  String get itemName;

  /// No description provided for @itemNameHint.
  ///
  /// In ko, this message translates to:
  /// **'예: TIGER 미국S&P500'**
  String get itemNameHint;

  /// No description provided for @itemFormNote.
  ///
  /// In ko, this message translates to:
  /// **'수량을 넣으면 그 날짜의 매수 거래가 하나 만들어집니다. 결산은 거래를 기준으로 계산합니다.'**
  String get itemFormNote;

  /// No description provided for @cashFormNote.
  ///
  /// In ko, this message translates to:
  /// **'예수금은 계좌에 남은 현금입니다. 비중 계산에 함께 잡힙니다.'**
  String get cashFormNote;

  /// No description provided for @validationNameRequired.
  ///
  /// In ko, this message translates to:
  /// **'종목명을 입력해 주세요'**
  String get validationNameRequired;

  /// No description provided for @deleteLosesItems.
  ///
  /// In ko, this message translates to:
  /// **'종목 {items}개 · 거래 {txs}건이 함께 지워집니다.'**
  String deleteLosesItems(int items, int txs);

  /// No description provided for @deleteCannotUndo.
  ///
  /// In ko, this message translates to:
  /// **'되돌릴 수 없습니다.'**
  String get deleteCannotUndo;

  /// No description provided for @yearMonth.
  ///
  /// In ko, this message translates to:
  /// **'{year}년 {month}월'**
  String yearMonth(int year, int month);

  /// No description provided for @netBuy.
  ///
  /// In ko, this message translates to:
  /// **'순매수'**
  String get netBuy;

  /// No description provided for @netSell.
  ///
  /// In ko, this message translates to:
  /// **'순매도'**
  String get netSell;

  /// No description provided for @fractionalIntro.
  ///
  /// In ko, this message translates to:
  /// **'소수점 매매 가능 여부는 증권사·계좌마다 다릅니다. 되는 계좌만 켜세요.'**
  String get fractionalIntro;

  /// No description provided for @fractionalPerAccount.
  ///
  /// In ko, this message translates to:
  /// **'계좌별 설정'**
  String get fractionalPerAccount;

  /// No description provided for @fractionalReasonOverseas.
  ///
  /// In ko, this message translates to:
  /// **'해외주식 · 소수점 매매 가능'**
  String get fractionalReasonOverseas;

  /// No description provided for @fractionalReasonPartial.
  ///
  /// In ko, this message translates to:
  /// **'해외 종목 {count}개만 해당'**
  String fractionalReasonPartial(int count);

  /// No description provided for @fractionalReasonKrOnly.
  ///
  /// In ko, this message translates to:
  /// **'국내 종목만 있음 · 증권사에 따라 안 될 수 있습니다'**
  String get fractionalReasonKrOnly;

  /// No description provided for @fractionalRoundingTitle.
  ///
  /// In ko, this message translates to:
  /// **'수량 반올림'**
  String get fractionalRoundingTitle;

  /// No description provided for @fractionalRoundingDisabled.
  ///
  /// In ko, this message translates to:
  /// **'소수점 거래를 켠 계좌가 없습니다. 계좌를 먼저 켜면 반올림 규칙을 고를 수 있습니다.'**
  String get fractionalRoundingDisabled;

  /// No description provided for @roundingMinDeviation.
  ///
  /// In ko, this message translates to:
  /// **'편차가 가장 작아지는 수량'**
  String get roundingMinDeviation;

  /// No description provided for @roundingMinDeviationDesc.
  ///
  /// In ko, this message translates to:
  /// **'소수점 {digits}째 자리까지 반올림합니다. 목표에 가장 가깝지만 예산을 아주 조금 넘을 수 있습니다.'**
  String roundingMinDeviationDesc(int digits);

  /// No description provided for @roundingFloorCash.
  ///
  /// In ko, this message translates to:
  /// **'현금이 남는 쪽으로 내림'**
  String get roundingFloorCash;

  /// No description provided for @roundingFloorCashDesc.
  ///
  /// In ko, this message translates to:
  /// **'예산을 넘지 않습니다. 대신 아주 적은 현금이 남습니다.'**
  String get roundingFloorCashDesc;

  /// No description provided for @fractionalPreviewTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금 조정 제안이 이렇게 바뀝니다'**
  String get fractionalPreviewTitle;

  /// No description provided for @previewWholeShares.
  ///
  /// In ko, this message translates to:
  /// **'주 단위'**
  String get previewWholeShares;

  /// No description provided for @previewFractional.
  ///
  /// In ko, this message translates to:
  /// **'소수점'**
  String get previewFractional;

  /// No description provided for @noPortfolios.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오가 없습니다'**
  String get noPortfolios;

  /// No description provided for @refreshPartialFail.
  ///
  /// In ko, this message translates to:
  /// **'{count}종목 시세를 못 받았습니다 · 마지막 값 유지'**
  String refreshPartialFail(int count);

  /// No description provided for @refreshFailedNote.
  ///
  /// In ko, this message translates to:
  /// **'갱신 실패 · {time} 시세'**
  String refreshFailedNote(String time);

  /// No description provided for @refreshRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get refreshRetry;

  /// No description provided for @excludedFromSettlement.
  ///
  /// In ko, this message translates to:
  /// **'{count}종목 결산 제외 · {amount}'**
  String excludedFromSettlement(int count, String amount);

  /// No description provided for @excludedFixLink.
  ///
  /// In ko, this message translates to:
  /// **'자세히'**
  String get excludedFixLink;

  /// No description provided for @excludedSheetTitle.
  ///
  /// In ko, this message translates to:
  /// **'결산에서 빠진 종목'**
  String get excludedSheetTitle;

  /// No description provided for @excludedSheetBody.
  ///
  /// In ko, this message translates to:
  /// **'아래 종목은 지금 보유 중이지만, 이 기간까지의 거래 기록이 없어 결산 계산에 잡히지 않습니다.\n\n자산과 리밸런싱에는 아무 영향이 없습니다 — 결산만 계산할 수 없습니다. 늘어난 금액이 매수 때문인지 주가 상승 때문인지 구분할 방법이 없어서입니다.\n\n종목 상세에서 실제 매수 거래를 넣으면 그때부터 결산에 포함됩니다.'**
  String get excludedSheetBody;

  /// No description provided for @excludedNoHistory.
  ///
  /// In ko, this message translates to:
  /// **'거래 기록 없음'**
  String get excludedNoHistory;

  /// No description provided for @lastMonthReturn.
  ///
  /// In ko, this message translates to:
  /// **'전월 {rate}'**
  String lastMonthReturn(String rate);

  /// No description provided for @spark1w.
  ///
  /// In ko, this message translates to:
  /// **'1주'**
  String get spark1w;

  /// No description provided for @spark1m.
  ///
  /// In ko, this message translates to:
  /// **'1개월'**
  String get spark1m;

  /// No description provided for @spark3m.
  ///
  /// In ko, this message translates to:
  /// **'3개월'**
  String get spark3m;

  /// No description provided for @spark6m.
  ///
  /// In ko, this message translates to:
  /// **'6개월'**
  String get spark6m;

  /// No description provided for @spark1y.
  ///
  /// In ko, this message translates to:
  /// **'1년'**
  String get spark1y;

  /// No description provided for @sparklinePending.
  ///
  /// In ko, this message translates to:
  /// **'새로고침 {count}일치가 모이면\n여기에 자산 추이가 그려집니다'**
  String sparklinePending(int count);

  /// No description provided for @searchPrompt.
  ///
  /// In ko, this message translates to:
  /// **'종목명이나 티커를 입력해 주세요'**
  String get searchPrompt;

  /// No description provided for @searchNoResult.
  ///
  /// In ko, this message translates to:
  /// **'검색 결과가 없습니다.\n티커나 종목코드로도 찾아보세요'**
  String get searchNoResult;

  /// No description provided for @filterAll.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get filterAll;

  /// No description provided for @filterKr.
  ///
  /// In ko, this message translates to:
  /// **'국내'**
  String get filterKr;

  /// No description provided for @filterUs.
  ///
  /// In ko, this message translates to:
  /// **'해외'**
  String get filterUs;

  /// No description provided for @cashAddHint.
  ///
  /// In ko, this message translates to:
  /// **'예수금은 검색이 아니라 바로 만듭니다.\n계좌에 남은 현금을 한 항목으로 넣어 두면\n비중 계산에 함께 잡힙니다.'**
  String get cashAddHint;

  /// No description provided for @cashAddButton.
  ///
  /// In ko, this message translates to:
  /// **'예수금 추가'**
  String get cashAddButton;

  /// No description provided for @manualEntryHint.
  ///
  /// In ko, this message translates to:
  /// **'목록에 없으면 직접 등록'**
  String get manualEntryHint;

  /// No description provided for @alreadyInPortfolio.
  ///
  /// In ko, this message translates to:
  /// **'{name} 이미 담겨 있습니다'**
  String alreadyInPortfolio(String name);

  /// No description provided for @txCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{count}건'**
  String txCountLabel(int count);

  /// No description provided for @editTransaction.
  ///
  /// In ko, this message translates to:
  /// **'거래 수정'**
  String get editTransaction;

  /// No description provided for @transactionAmount.
  ///
  /// In ko, this message translates to:
  /// **'거래금액'**
  String get transactionAmount;

  /// No description provided for @saveTransaction.
  ///
  /// In ko, this message translates to:
  /// **'거래 저장'**
  String get saveTransaction;

  /// No description provided for @transactionAffectsAvg.
  ///
  /// In ko, this message translates to:
  /// **'저장하면 보유 수량과 평균 매수단가가 이 거래를 반영해 다시 계산됩니다.'**
  String get transactionAffectsAvg;

  /// No description provided for @validationQtyPositive.
  ///
  /// In ko, this message translates to:
  /// **'수량을 0보다 크게 입력해 주세요'**
  String get validationQtyPositive;

  /// No description provided for @validationPricePositive.
  ///
  /// In ko, this message translates to:
  /// **'단가를 0보다 크게 입력해 주세요'**
  String get validationPricePositive;

  /// No description provided for @validationSellExceeds.
  ///
  /// In ko, this message translates to:
  /// **'보유 수량({owned})보다 많이 팔 수 없습니다'**
  String validationSellExceeds(String owned);

  /// No description provided for @reorderPortfolios.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 순서 변경'**
  String get reorderPortfolios;

  /// No description provided for @reorderItems.
  ///
  /// In ko, this message translates to:
  /// **'종목 순서 변경'**
  String get reorderItems;

  /// No description provided for @holdingQty.
  ///
  /// In ko, this message translates to:
  /// **'보유 수량'**
  String get holdingQty;

  /// No description provided for @basedOnTransactions.
  ///
  /// In ko, this message translates to:
  /// **'거래 기준'**
  String get basedOnTransactions;

  /// No description provided for @enteredDirectly.
  ///
  /// In ko, this message translates to:
  /// **'직접 입력'**
  String get enteredDirectly;

  /// No description provided for @noTransactionsYet.
  ///
  /// In ko, this message translates to:
  /// **'아직 거래 내역이 없습니다'**
  String get noTransactionsYet;

  /// No description provided for @proposalTitle.
  ///
  /// In ko, this message translates to:
  /// **'조정 제안'**
  String get proposalTitle;

  /// No description provided for @modeHoldings.
  ///
  /// In ko, this message translates to:
  /// **'보유 안에서'**
  String get modeHoldings;

  /// No description provided for @modeAddCash.
  ///
  /// In ko, this message translates to:
  /// **'추가 입금으로'**
  String get modeAddCash;

  /// No description provided for @toleranceLabel.
  ///
  /// In ko, this message translates to:
  /// **'허용 ±{value}%p'**
  String toleranceLabel(String value);

  /// No description provided for @withinTolerance.
  ///
  /// In ko, this message translates to:
  /// **'허용 안'**
  String get withinTolerance;

  /// No description provided for @roundingWholeShares.
  ///
  /// In ko, this message translates to:
  /// **'단주는 반올림'**
  String get roundingWholeShares;

  /// No description provided for @roundingWholeSharesDesc.
  ///
  /// In ko, this message translates to:
  /// **'1주 단위로만 계산합니다. 목표 비중에 0에 가장 가까운 수량으로 맞춥니다.'**
  String get roundingWholeSharesDesc;

  /// No description provided for @roundingFractional.
  ///
  /// In ko, this message translates to:
  /// **'소수점 거래'**
  String get roundingFractional;

  /// No description provided for @roundingFractionalDesc.
  ///
  /// In ko, this message translates to:
  /// **'소수점 {digits}자리에서 버립니다. 예산을 넘지 않게 하려는 것이라 아주 적은 금액이 남습니다.'**
  String roundingFractionalDesc(int digits);

  /// No description provided for @proposalDisclaimer.
  ///
  /// In ko, this message translates to:
  /// **'이 제안은 주문을 내지 않습니다. 실제로 매매하신 뒤 아래 버튼으로 기록하세요.'**
  String get proposalDisclaimer;

  /// No description provided for @noAdjustmentNeeded.
  ///
  /// In ko, this message translates to:
  /// **'지금은 조정할 것이 없습니다'**
  String get noAdjustmentNeeded;

  /// No description provided for @cannotCalculate.
  ///
  /// In ko, this message translates to:
  /// **'계산할 수 없습니다. 현재가가 없는 종목이 있는지 확인해 주세요.'**
  String get cannotCalculate;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get edit;

  /// No description provided for @done.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get done;

  /// No description provided for @exit.
  ///
  /// In ko, this message translates to:
  /// **'종료'**
  String get exit;

  /// No description provided for @add.
  ///
  /// In ko, this message translates to:
  /// **'추가'**
  String get add;

  /// No description provided for @editExitTitle.
  ///
  /// In ko, this message translates to:
  /// **'편집 종료'**
  String get editExitTitle;

  /// No description provided for @editExitContent.
  ///
  /// In ko, this message translates to:
  /// **'편집 모드를 종료하시겠습니까?'**
  String get editExitContent;

  /// No description provided for @saveChanges.
  ///
  /// In ko, this message translates to:
  /// **'수정 완료'**
  String get saveChanges;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'삭제 확인'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteItemContent.
  ///
  /// In ko, this message translates to:
  /// **'{name} 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'**
  String deleteItemContent(String name);

  /// No description provided for @appExitContent.
  ///
  /// In ko, this message translates to:
  /// **'앱을 종료하시겠습니까?'**
  String get appExitContent;

  /// No description provided for @neverUpdated.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 전'**
  String get neverUpdated;

  /// No description provided for @toastAutoSettingRequired.
  ///
  /// In ko, this message translates to:
  /// **'설정에서 환율 또는 주가를 자동으로 변경해 주세요'**
  String get toastAutoSettingRequired;

  /// No description provided for @updateFailed.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 실패: {msg}'**
  String updateFailed(String msg);

  /// No description provided for @updateSuccessCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}건 업데이트 완료'**
  String updateSuccessCount(int count);

  /// No description provided for @portfolioNotFound.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오를 찾을 수 없습니다'**
  String get portfolioNotFound;

  /// No description provided for @additionalInvestmentHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 1000000 또는 -500000'**
  String get additionalInvestmentHint;

  /// No description provided for @evaluationAmount.
  ///
  /// In ko, this message translates to:
  /// **'평가금액'**
  String get evaluationAmount;

  /// No description provided for @weightWarning.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중 합계: {pct} (100%가 아닙니다)'**
  String weightWarning(String pct);

  /// No description provided for @labelSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get labelSettings;

  /// No description provided for @labelGraph.
  ///
  /// In ko, this message translates to:
  /// **'그래프'**
  String get labelGraph;

  /// No description provided for @addStock.
  ///
  /// In ko, this message translates to:
  /// **'종목 추가'**
  String get addStock;

  /// No description provided for @buy.
  ///
  /// In ko, this message translates to:
  /// **'매수'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In ko, this message translates to:
  /// **'매도'**
  String get sell;

  /// No description provided for @cash.
  ///
  /// In ko, this message translates to:
  /// **'현금'**
  String get cash;

  /// No description provided for @captureFailed.
  ///
  /// In ko, this message translates to:
  /// **'캡처 실패'**
  String get captureFailed;

  /// No description provided for @savedToGallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리에 저장됐어요'**
  String get savedToGallery;

  /// No description provided for @saveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패'**
  String get saveFailed;

  /// No description provided for @saveFailedError.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패: {error}'**
  String saveFailedError(String error);

  /// No description provided for @editCenterText.
  ///
  /// In ko, this message translates to:
  /// **'중앙 텍스트 수정'**
  String get editCenterText;

  /// No description provided for @editItem.
  ///
  /// In ko, this message translates to:
  /// **'항목 편집'**
  String get editItem;

  /// No description provided for @displayName.
  ///
  /// In ko, this message translates to:
  /// **'표시 이름'**
  String get displayName;

  /// No description provided for @colorLabel.
  ///
  /// In ko, this message translates to:
  /// **'색상'**
  String get colorLabel;

  /// No description provided for @portfolioEmpty.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 없음'**
  String get portfolioEmpty;

  /// No description provided for @portfolioGraph.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 그래프'**
  String get portfolioGraph;

  /// No description provided for @editCompleteTooltip.
  ///
  /// In ko, this message translates to:
  /// **'편집 완료'**
  String get editCompleteTooltip;

  /// No description provided for @editTooltip.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get editTooltip;

  /// No description provided for @editCompleteBeforeSave.
  ///
  /// In ko, this message translates to:
  /// **'편집 완료 후 저장 가능'**
  String get editCompleteBeforeSave;

  /// No description provided for @saveImage.
  ///
  /// In ko, this message translates to:
  /// **'이미지 저장'**
  String get saveImage;

  /// No description provided for @shareImage.
  ///
  /// In ko, this message translates to:
  /// **'이미지 공유'**
  String get shareImage;

  /// No description provided for @capture.
  ///
  /// In ko, this message translates to:
  /// **'캡처'**
  String get capture;

  /// No description provided for @notifPermissionDenied.
  ///
  /// In ko, this message translates to:
  /// **'알림 권한이 거부됐습니다. 설정에서 허용해 주세요.'**
  String get notifPermissionDenied;

  /// No description provided for @targetWeight.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중'**
  String get targetWeight;

  /// No description provided for @currentWeight.
  ///
  /// In ko, this message translates to:
  /// **'현재 비중'**
  String get currentWeight;

  /// No description provided for @noPriceInfo.
  ///
  /// In ko, this message translates to:
  /// **'현재가 정보가 없습니다. 새로고침 후 다시 시도해주세요.'**
  String get noPriceInfo;

  /// No description provided for @tapToEdit.
  ///
  /// In ko, this message translates to:
  /// **'탭하여 수정'**
  String get tapToEdit;

  /// No description provided for @dragToReorder.
  ///
  /// In ko, this message translates to:
  /// **'항목을 길게 눌러 드래그하면 순서를 바꿀 수 있습니다'**
  String get dragToReorder;

  /// No description provided for @disclaimerTitle.
  ///
  /// In ko, this message translates to:
  /// **'서비스 이용 안내 및 면책고지'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerSectionPurpose.
  ///
  /// In ko, this message translates to:
  /// **'목적'**
  String get disclaimerSectionPurpose;

  /// No description provided for @disclaimerTextPurpose.
  ///
  /// In ko, this message translates to:
  /// **'본 앱(Rebalancing)은 개인 투자자의 포트폴리오 리밸런싱 계산 및 거래 내역 기반 기간별 수익률 분석을 돕기 위한 참고용 도구입니다. 어떠한 경우에도 금융투자 조언, 투자 권유, 자산 운용 서비스를 제공하지 않습니다.'**
  String get disclaimerTextPurpose;

  /// No description provided for @disclaimerSectionData.
  ///
  /// In ko, this message translates to:
  /// **'데이터 정확성'**
  String get disclaimerSectionData;

  /// No description provided for @disclaimerTextData.
  ///
  /// In ko, this message translates to:
  /// **'앱이 제공하는 다음 정보는 외부 공개 API 및 데이터 소스를 기반으로 하며, 지연·오류·누락이 발생할 수 있습니다.\n\n• 종목 정보 (종목명, 티커, 시장 구분)\n• 실시간 주가 (Yahoo Finance 기반)\n• 실시간 환율 (공개 환율 API 기반)\n• ETF 분류 및 관련 정보\n• 리밸런싱 계산 결과 (수량, 비중, 잔여 현금 등)\n• 예상 수수료 계산값\n• 결산 기간 수익률 및 종목별 기여도 (사용자 입력 거래 내역 및 과거 주가 데이터 기반)\n\n실제 시장 데이터 및 금융기관 정보와 다를 수 있으므로, 반드시 직접 확인하시기 바랍니다.'**
  String get disclaimerTextData;

  /// No description provided for @disclaimerSectionRisk.
  ///
  /// In ko, this message translates to:
  /// **'투자 손실 책임'**
  String get disclaimerSectionRisk;

  /// No description provided for @disclaimerTextRisk.
  ///
  /// In ko, this message translates to:
  /// **'본 앱의 정보를 바탕으로 내린 투자 결정 및 그로 인한 손실·손해에 대해 개발자는 어떠한 법적 책임도 지지 않습니다. 모든 투자 결정은 사용자 본인의 판단과 책임 하에 이루어져야 합니다.'**
  String get disclaimerTextRisk;

  /// No description provided for @disclaimerSectionTax.
  ///
  /// In ko, this message translates to:
  /// **'세금 및 법적 사항'**
  String get disclaimerSectionTax;

  /// No description provided for @disclaimerTextTax.
  ///
  /// In ko, this message translates to:
  /// **'금융거래에 따른 세금 신고, 양도소득세, 금융소득 종합과세 등 법적 의무는 사용자가 직접 확인하고 이행해야 합니다. 본 앱은 세무·법률 조언을 제공하지 않습니다.'**
  String get disclaimerTextTax;

  /// No description provided for @disclaimerSectionService.
  ///
  /// In ko, this message translates to:
  /// **'서비스 변경 및 중단'**
  String get disclaimerSectionService;

  /// No description provided for @disclaimerTextService.
  ///
  /// In ko, this message translates to:
  /// **'앱의 기능, 데이터 소스, 서비스는 사전 고지 없이 변경되거나 중단될 수 있습니다.'**
  String get disclaimerTextService;

  /// No description provided for @disclaimerStartBtn.
  ///
  /// In ko, this message translates to:
  /// **'확인하고 시작하기'**
  String get disclaimerStartBtn;

  /// No description provided for @disclaimerConfirmBtn.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get disclaimerConfirmBtn;

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'종목명 또는 티커 입력'**
  String get searchHint;

  /// No description provided for @avgCost.
  ///
  /// In ko, this message translates to:
  /// **'평균 매수단가'**
  String get avgCost;

  /// No description provided for @profitLoss.
  ///
  /// In ko, this message translates to:
  /// **'평가손익'**
  String get profitLoss;

  /// No description provided for @currentPrice.
  ///
  /// In ko, this message translates to:
  /// **'현재가'**
  String get currentPrice;

  /// No description provided for @unitKRW.
  ///
  /// In ko, this message translates to:
  /// **'원'**
  String get unitKRW;

  /// No description provided for @unitShares.
  ///
  /// In ko, this message translates to:
  /// **'주'**
  String get unitShares;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @baseCurrency.
  ///
  /// In ko, this message translates to:
  /// **'기준 통화'**
  String get baseCurrency;

  /// No description provided for @currencyKRW.
  ///
  /// In ko, this message translates to:
  /// **'KRW (₩)'**
  String get currencyKRW;

  /// No description provided for @currencyUSD.
  ///
  /// In ko, this message translates to:
  /// **'USD (\$)'**
  String get currencyUSD;

  /// No description provided for @tradingFee.
  ///
  /// In ko, this message translates to:
  /// **'거래 수수료'**
  String get tradingFee;

  /// No description provided for @includeFee.
  ///
  /// In ko, this message translates to:
  /// **'수수료 반영'**
  String get includeFee;

  /// No description provided for @feeRate.
  ///
  /// In ko, this message translates to:
  /// **'수수료율'**
  String get feeRate;

  /// No description provided for @exchangeRateSetting.
  ///
  /// In ko, this message translates to:
  /// **'환율'**
  String get exchangeRateSetting;

  /// No description provided for @exchangeRateInput.
  ///
  /// In ko, this message translates to:
  /// **'환율 (1 USD)'**
  String get exchangeRateInput;

  /// No description provided for @stockPriceSetting.
  ///
  /// In ko, this message translates to:
  /// **'주가'**
  String get stockPriceSetting;

  /// No description provided for @language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get language;

  /// No description provided for @portfolioAddBtn.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 추가'**
  String get portfolioAddBtn;

  /// No description provided for @holdingsSection.
  ///
  /// In ko, this message translates to:
  /// **'구성 종목'**
  String get holdingsSection;

  /// No description provided for @cashIncluded.
  ///
  /// In ko, this message translates to:
  /// **'예수금 포함'**
  String get cashIncluded;

  /// No description provided for @itemCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 종목'**
  String itemCountLabel(int count);

  /// No description provided for @notice.
  ///
  /// In ko, this message translates to:
  /// **'공지사항'**
  String get notice;

  /// No description provided for @dayChange.
  ///
  /// In ko, this message translates to:
  /// **'전일대비'**
  String get dayChange;

  /// No description provided for @disclaimerAgreeCheckbox.
  ///
  /// In ko, this message translates to:
  /// **'위 내용을 전부 확인하였으며\n동의합니다.'**
  String get disclaimerAgreeCheckbox;

  /// No description provided for @validationNonNegative.
  ///
  /// In ko, this message translates to:
  /// **'0 이상의 값을 입력해주세요.'**
  String get validationNonNegative;

  /// No description provided for @validationPositive.
  ///
  /// In ko, this message translates to:
  /// **'0보다 큰 값을 입력해주세요.'**
  String get validationPositive;

  /// No description provided for @validationExchangeRatePositive.
  ///
  /// In ko, this message translates to:
  /// **'환율은 0보다 큰 값이어야 합니다.'**
  String get validationExchangeRatePositive;

  /// No description provided for @tabAssets.
  ///
  /// In ko, this message translates to:
  /// **'자산'**
  String get tabAssets;

  /// No description provided for @tabRebalancing.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱'**
  String get tabRebalancing;

  /// No description provided for @tabSettlement.
  ///
  /// In ko, this message translates to:
  /// **'결산'**
  String get tabSettlement;

  /// No description provided for @tabMore.
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get tabMore;

  /// No description provided for @settlementWeekly.
  ///
  /// In ko, this message translates to:
  /// **'주간'**
  String get settlementWeekly;

  /// No description provided for @settlementMonthly.
  ///
  /// In ko, this message translates to:
  /// **'월간'**
  String get settlementMonthly;

  /// No description provided for @settlementQuarterly.
  ///
  /// In ko, this message translates to:
  /// **'분기'**
  String get settlementQuarterly;

  /// No description provided for @settlementYearly.
  ///
  /// In ko, this message translates to:
  /// **'연간'**
  String get settlementYearly;

  /// No description provided for @backupData.
  ///
  /// In ko, this message translates to:
  /// **'백업'**
  String get backupData;

  /// No description provided for @restoreData.
  ///
  /// In ko, this message translates to:
  /// **'복원'**
  String get restoreData;

  /// No description provided for @backupNever.
  ///
  /// In ko, this message translates to:
  /// **'아직 없음'**
  String get backupNever;

  /// No description provided for @backupToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get backupToday;

  /// No description provided for @backupYesterday.
  ///
  /// In ko, this message translates to:
  /// **'어제'**
  String get backupYesterday;

  /// No description provided for @backupDaysAgo.
  ///
  /// In ko, this message translates to:
  /// **'{days}일 전'**
  String backupDaysAgo(int days);

  /// No description provided for @backupMonthsAgo.
  ///
  /// In ko, this message translates to:
  /// **'{months}개월 전'**
  String backupMonthsAgo(int months);

  /// No description provided for @backupYearsAgo.
  ///
  /// In ko, this message translates to:
  /// **'{years}년 전'**
  String backupYearsAgo(int years);

  /// No description provided for @backupFailed.
  ///
  /// In ko, this message translates to:
  /// **'백업 실패'**
  String get backupFailed;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'데이터 복원'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmContent.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 {count}개를 복원합니다.\n현재 데이터는 모두 교체됩니다.'**
  String restoreConfirmContent(int count);

  /// No description provided for @restoreSuccess.
  ///
  /// In ko, this message translates to:
  /// **'복원 완료: 포트폴리오 {count}개'**
  String restoreSuccess(int count);

  /// No description provided for @restoreFailed.
  ///
  /// In ko, this message translates to:
  /// **'복원 실패: 올바른 백업 파일이 아닙니다'**
  String get restoreFailed;

  /// No description provided for @notifReminder.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 알림'**
  String get notifReminder;

  /// No description provided for @notifEnableDesc.
  ///
  /// In ko, this message translates to:
  /// **'정기 리밸런싱 점검 알림'**
  String get notifEnableDesc;

  /// No description provided for @notifEnableHint.
  ///
  /// In ko, this message translates to:
  /// **'지정한 주기마다 앱 알림을 보내드립니다'**
  String get notifEnableHint;

  /// No description provided for @notifWeekly.
  ///
  /// In ko, this message translates to:
  /// **'매주 월요일 오전 9시'**
  String get notifWeekly;

  /// No description provided for @notifMonthly.
  ///
  /// In ko, this message translates to:
  /// **'매월 1일 오전 9시'**
  String get notifMonthly;

  /// No description provided for @purchaseDateLabel.
  ///
  /// In ko, this message translates to:
  /// **'매수 일자'**
  String get purchaseDateLabel;

  /// No description provided for @transactionHistory.
  ///
  /// In ko, this message translates to:
  /// **'거래 내역'**
  String get transactionHistory;

  /// No description provided for @addTransaction.
  ///
  /// In ko, this message translates to:
  /// **'거래 추가'**
  String get addTransaction;

  /// No description provided for @transactionBuy.
  ///
  /// In ko, this message translates to:
  /// **'매수'**
  String get transactionBuy;

  /// No description provided for @transactionSell.
  ///
  /// In ko, this message translates to:
  /// **'매도'**
  String get transactionSell;

  /// No description provided for @transactionDate.
  ///
  /// In ko, this message translates to:
  /// **'거래 일자'**
  String get transactionDate;

  /// No description provided for @transactionQty.
  ///
  /// In ko, this message translates to:
  /// **'수량'**
  String get transactionQty;

  /// No description provided for @transactionPrice.
  ///
  /// In ko, this message translates to:
  /// **'단가'**
  String get transactionPrice;

  /// No description provided for @settlementWeekNum.
  ///
  /// In ko, this message translates to:
  /// **'{week}주차'**
  String settlementWeekNum(int week);

  /// No description provided for @settlementQuarterNum.
  ///
  /// In ko, this message translates to:
  /// **'{q}분기'**
  String settlementQuarterNum(int q);

  /// No description provided for @settlementYearLabel.
  ///
  /// In ko, this message translates to:
  /// **'{year}년'**
  String settlementYearLabel(int year);

  /// No description provided for @excelImportTitle.
  ///
  /// In ko, this message translates to:
  /// **'거래내역 업로드'**
  String get excelImportTitle;

  /// No description provided for @excelImportDone.
  ///
  /// In ko, this message translates to:
  /// **'가져오기 완료'**
  String get excelImportDone;

  /// No description provided for @excelImportAdded.
  ///
  /// In ko, this message translates to:
  /// **'{count}건 거래 추가됨'**
  String excelImportAdded(int count);

  /// No description provided for @excelImportCreated.
  ///
  /// In ko, this message translates to:
  /// **'신규 종목 {count}개 생성됨'**
  String excelImportCreated(int count);

  /// No description provided for @excelImportSkipped.
  ///
  /// In ko, this message translates to:
  /// **'{count}행 건너뜀'**
  String excelImportSkipped(int count);

  /// No description provided for @excelImportNothingAdded.
  ///
  /// In ko, this message translates to:
  /// **'추가된 거래내역이 없습니다'**
  String get excelImportNothingAdded;

  /// No description provided for @settlementNotifHeader.
  ///
  /// In ko, this message translates to:
  /// **'결산 알림'**
  String get settlementNotifHeader;

  /// No description provided for @rebalancingThresholdLabel.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 임계값'**
  String get rebalancingThresholdLabel;

  /// No description provided for @rebalancingThresholdHint.
  ///
  /// In ko, this message translates to:
  /// **'편차가 이 값 미만이면 거래 권고 안 함'**
  String get rebalancingThresholdHint;

  /// No description provided for @fractionalTrading.
  ///
  /// In ko, this message translates to:
  /// **'소수점 거래'**
  String get fractionalTrading;

  /// No description provided for @maxDriftAfter.
  ///
  /// In ko, this message translates to:
  /// **'조정 후 최대 편차'**
  String get maxDriftAfter;

  /// No description provided for @planMustRunAll.
  ///
  /// In ko, this message translates to:
  /// **'아래 {count}건을 모두 실행해야 성립하는 결과입니다'**
  String planMustRunAll(int count);

  /// No description provided for @allItemsInRange.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 항목 전부 범위 안.'**
  String allItemsInRange(int count);

  /// No description provided for @togetherNTrades.
  ///
  /// In ko, this message translates to:
  /// **'함께 실행할 {count}건'**
  String togetherNTrades(int count);

  /// No description provided for @uncheckToRecalc.
  ///
  /// In ko, this message translates to:
  /// **'체크를 끄면 재계산'**
  String get uncheckToRecalc;

  /// No description provided for @cashLedgerTitle.
  ///
  /// In ko, this message translates to:
  /// **'예수금 하나로 매수 {count}건'**
  String cashLedgerTitle(int count);

  /// No description provided for @sellProceeds.
  ///
  /// In ko, this message translates to:
  /// **'매도 대금'**
  String get sellProceeds;

  /// No description provided for @buyCostN.
  ///
  /// In ko, this message translates to:
  /// **'매수 대금 {count}건'**
  String buyCostN(int count);

  /// No description provided for @cashAfterAdjust.
  ///
  /// In ko, this message translates to:
  /// **'조정 후 예수금'**
  String get cashAfterAdjust;

  /// No description provided for @cashSharedNote.
  ///
  /// In ko, this message translates to:
  /// **'매수가 같은 예수금을 나눠 씁니다 — 따로 계산하면 맞지 않습니다.'**
  String get cashSharedNote;

  /// No description provided for @sellFirstNote.
  ///
  /// In ko, this message translates to:
  /// **'매도 먼저 실행 — 해외 종목은 환전이 필요하면 하루 이틀 늦어질 수 있습니다.'**
  String get sellFirstNote;

  /// No description provided for @recordNTransactions.
  ///
  /// In ko, this message translates to:
  /// **'{count}건 거래 내역으로 기록'**
  String recordNTransactions(int count);

  /// No description provided for @shareProposal.
  ///
  /// In ko, this message translates to:
  /// **'제안 공유'**
  String get shareProposal;

  /// No description provided for @driftedTogether.
  ///
  /// In ko, this message translates to:
  /// **'이탈 {count}종목 함께'**
  String driftedTogether(int count);

  /// No description provided for @selectedExcluded.
  ///
  /// In ko, this message translates to:
  /// **'{sel}건 선택 · {exc}건 제외'**
  String selectedExcluded(int sel, int exc);

  /// No description provided for @nOutOfRange.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 남음'**
  String nOutOfRange(int count);

  /// No description provided for @excludedOnlyOutside.
  ///
  /// In ko, this message translates to:
  /// **'제외한 {name}만 허용 밖'**
  String excludedOnlyOutside(String name);

  /// No description provided for @whereToSendShare.
  ///
  /// In ko, this message translates to:
  /// **'{name} 몫 {amount} 어디로 보낼까요'**
  String whereToSendShare(String name, String amount);

  /// No description provided for @excludedNItems.
  ///
  /// In ko, this message translates to:
  /// **'제외한 {count}건'**
  String excludedNItems(int count);

  /// No description provided for @toRemainingItems.
  ///
  /// In ko, this message translates to:
  /// **'나머지 종목에'**
  String get toRemainingItems;

  /// No description provided for @keepInCash.
  ///
  /// In ko, this message translates to:
  /// **'예수금에 남김'**
  String get keepInCash;

  /// No description provided for @wouldExceedBy.
  ///
  /// In ko, this message translates to:
  /// **'{value}로 허용을 벗어납니다'**
  String wouldExceedBy(String value);

  /// No description provided for @recalculated.
  ///
  /// In ko, this message translates to:
  /// **'재계산'**
  String get recalculated;

  /// No description provided for @keptAsIsDrift.
  ///
  /// In ko, this message translates to:
  /// **'{weight} 그대로 · {drift}'**
  String keptAsIsDrift(String weight, String drift);

  /// No description provided for @recordNTradesTitle.
  ///
  /// In ko, this message translates to:
  /// **'거래 {count}건 기록'**
  String recordNTradesTitle(int count);

  /// No description provided for @fromProposal.
  ///
  /// In ko, this message translates to:
  /// **'조정 제안에서'**
  String get fromProposal;

  /// No description provided for @appliedToAllN.
  ///
  /// In ko, this message translates to:
  /// **'{count}건에 같이 적용됩니다'**
  String appliedToAllN(int count);

  /// No description provided for @commissionAutoSum.
  ///
  /// In ko, this message translates to:
  /// **'수수료 {rate}% 자동 · {count}건 합'**
  String commissionAutoSum(String rate, int count);

  /// No description provided for @followsPortfolioSettings.
  ///
  /// In ko, this message translates to:
  /// **'수수료·예수금은 이 포트 설정을 따릅니다.'**
  String get followsPortfolioSettings;

  /// No description provided for @priceIsProposalNote.
  ///
  /// In ko, this message translates to:
  /// **'단가는 제안 시점 현재가입니다 — 체결가로 고쳐야 다음 조정이 정확합니다.'**
  String get priceIsProposalNote;

  /// No description provided for @recordNButton.
  ///
  /// In ko, this message translates to:
  /// **'{count}건 기록하기'**
  String recordNButton(int count);

  /// No description provided for @fxConverted.
  ///
  /// In ko, this message translates to:
  /// **'환율 {rate} · 환산 {amount}'**
  String fxConverted(String rate, String amount);

  /// No description provided for @importStep1.
  ///
  /// In ko, this message translates to:
  /// **'1 / 2 · 파일 선택'**
  String get importStep1;

  /// No description provided for @importStep2.
  ///
  /// In ko, this message translates to:
  /// **'2 / 2 · {file}'**
  String importStep2(String file);

  /// No description provided for @targetPortfolio.
  ///
  /// In ko, this message translates to:
  /// **'담을 포트폴리오'**
  String get targetPortfolio;

  /// No description provided for @uploadHow.
  ///
  /// In ko, this message translates to:
  /// **'업로드 방법'**
  String get uploadHow;

  /// No description provided for @downloadTemplateTitle.
  ///
  /// In ko, this message translates to:
  /// **'표준 양식 내려받기'**
  String get downloadTemplateTitle;

  /// No description provided for @downloadTemplateDesc.
  ///
  /// In ko, this message translates to:
  /// **'XLSX · 옮겨 적으면 확실하게 들어갑니다'**
  String get downloadTemplateDesc;

  /// No description provided for @brokerFileOk.
  ///
  /// In ko, this message translates to:
  /// **'증권사에서 받은 파일을 그대로 올려도 됩니다 — 거래일 · 종목 · 구분 · 수량 · 단가 같은 열 이름을 자동으로 찾습니다.'**
  String get brokerFileOk;

  /// No description provided for @pickFile.
  ///
  /// In ko, this message translates to:
  /// **'파일 선택'**
  String get pickFile;

  /// No description provided for @pickFileDesc.
  ///
  /// In ko, this message translates to:
  /// **'CSV · XLSX · 최대 5MB'**
  String get pickFileDesc;

  /// No description provided for @requiredColumns.
  ///
  /// In ko, this message translates to:
  /// **'파일에 있어야 하는 열'**
  String get requiredColumns;

  /// No description provided for @requiredColumnsList.
  ///
  /// In ko, this message translates to:
  /// **'거래일 · 종목 · 매수/매도 · 수량 · 단가'**
  String get requiredColumnsList;

  /// No description provided for @toImportLabel.
  ///
  /// In ko, this message translates to:
  /// **'가져올 거래'**
  String get toImportLabel;

  /// No description provided for @importCountOf.
  ///
  /// In ko, this message translates to:
  /// **'{ready} / {total}건'**
  String importCountOf(int ready, int total);

  /// No description provided for @importSummaryLine.
  ///
  /// In ko, this message translates to:
  /// **'{range} · 종목 {items}개 · 매수 {buy} · 매도 {sell}'**
  String importSummaryLine(String range, int items, int buy, int sell);

  /// No description provided for @itemNotFound.
  ///
  /// In ko, this message translates to:
  /// **'종목을 못 찾았습니다'**
  String get itemNotFound;

  /// No description provided for @linkAction.
  ///
  /// In ko, this message translates to:
  /// **'연결'**
  String get linkAction;

  /// No description provided for @alreadyExists.
  ///
  /// In ko, this message translates to:
  /// **'이미 있는 거래'**
  String get alreadyExists;

  /// No description provided for @skippedShort.
  ///
  /// In ko, this message translates to:
  /// **'건너뜀'**
  String get skippedShort;

  /// No description provided for @unreadableRows.
  ///
  /// In ko, this message translates to:
  /// **'읽지 못한 줄'**
  String get unreadableRows;

  /// No description provided for @previewTitle.
  ///
  /// In ko, this message translates to:
  /// **'미리보기'**
  String get previewTitle;

  /// No description provided for @newestNItems.
  ///
  /// In ko, this message translates to:
  /// **'최근순 {count}건'**
  String newestNItems(int count);

  /// No description provided for @importNButton.
  ///
  /// In ko, this message translates to:
  /// **'{count}건 가져오기'**
  String importNButton(int count);

  /// No description provided for @nothingToImport.
  ///
  /// In ko, this message translates to:
  /// **'가져올 거래가 없습니다'**
  String get nothingToImport;

  /// No description provided for @linkItemTitle.
  ///
  /// In ko, this message translates to:
  /// **'종목 연결'**
  String get linkItemTitle;

  /// No description provided for @linkItemDesc.
  ///
  /// In ko, this message translates to:
  /// **'{label} 거래 {count}건을 어느 종목에 넣을까요'**
  String linkItemDesc(String label, int count);

  /// No description provided for @createNewItem.
  ///
  /// In ko, this message translates to:
  /// **'새 종목으로 만들기'**
  String get createNewItem;

  /// No description provided for @nRowsShort.
  ///
  /// In ko, this message translates to:
  /// **'{count}건'**
  String nRowsShort(int count);

  /// No description provided for @firstRunSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'나중에 바꾸거나 섞어 쓸 수 있습니다.'**
  String get firstRunSubtitle;

  /// No description provided for @firstRunUploadTitle.
  ///
  /// In ko, this message translates to:
  /// **'거래내역 파일 올리기'**
  String get firstRunUploadTitle;

  /// No description provided for @firstRunNeedsPc.
  ///
  /// In ko, this message translates to:
  /// **'PC 필요'**
  String get firstRunNeedsPc;

  /// No description provided for @firstRunUploadDesc.
  ///
  /// In ko, this message translates to:
  /// **'HTS·홈페이지에서 거래내역 파일을 받을 수 있다면 수십 건이 한 번에 들어옵니다.'**
  String get firstRunUploadDesc;

  /// No description provided for @firstRunUploadCta.
  ///
  /// In ko, this message translates to:
  /// **'파일로 시작'**
  String get firstRunUploadCta;

  /// No description provided for @firstRunRecordTitle.
  ///
  /// In ko, this message translates to:
  /// **'직접 거래 기록하기'**
  String get firstRunRecordTitle;

  /// No description provided for @firstRunRecommended.
  ///
  /// In ko, this message translates to:
  /// **'권장'**
  String get firstRunRecommended;

  /// No description provided for @firstRunRecordDesc.
  ///
  /// In ko, this message translates to:
  /// **'매수·매도를 수량 · 단가 · 날짜로 남기면 결산 탭의 기간별 손익까지 나옵니다.'**
  String get firstRunRecordDesc;

  /// No description provided for @firstRunRecordCta.
  ///
  /// In ko, this message translates to:
  /// **'기록하며 시작'**
  String get firstRunRecordCta;

  /// No description provided for @firstRunQuickTitle.
  ///
  /// In ko, this message translates to:
  /// **'보유 현황만 빠르게'**
  String get firstRunQuickTitle;

  /// No description provided for @firstRunQuickDesc.
  ///
  /// In ko, this message translates to:
  /// **'지금 가진 수량과 평단만 넣습니다. 자산·리밸런싱은 그대로 되지만 결산 탭의 기간별 손익은 안 나옵니다.'**
  String get firstRunQuickDesc;

  /// No description provided for @firstRunQuickCta.
  ///
  /// In ko, this message translates to:
  /// **'현재 보유만 입력'**
  String get firstRunQuickCta;

  /// No description provided for @hintThenUpload.
  ///
  /// In ko, this message translates to:
  /// **'만들면 바로 파일 올리기로 넘어갑니다.'**
  String get hintThenUpload;

  /// No description provided for @createAndUpload.
  ///
  /// In ko, this message translates to:
  /// **'만들고 파일 올리기'**
  String get createAndUpload;

  /// No description provided for @sortManual.
  ///
  /// In ko, this message translates to:
  /// **'직접 배치'**
  String get sortManual;

  /// No description provided for @sortByValue.
  ///
  /// In ko, this message translates to:
  /// **'금액순'**
  String get sortByValue;

  /// No description provided for @sortByReturn.
  ///
  /// In ko, this message translates to:
  /// **'수익률순'**
  String get sortByReturn;

  /// No description provided for @sortManualNote.
  ///
  /// In ko, this message translates to:
  /// **'직접 배치 후에는 금액이 바뀌어도 순서가 그대로입니다.'**
  String get sortManualNote;

  /// No description provided for @rename.
  ///
  /// In ko, this message translates to:
  /// **'이름 변경'**
  String get rename;

  /// No description provided for @duplicate.
  ///
  /// In ko, this message translates to:
  /// **'복제'**
  String get duplicate;

  /// No description provided for @copySuffix.
  ///
  /// In ko, this message translates to:
  /// **'(복사)'**
  String get copySuffix;

  /// No description provided for @feeLabel.
  ///
  /// In ko, this message translates to:
  /// **'수수료'**
  String get feeLabel;

  /// No description provided for @commissionAutoRate.
  ///
  /// In ko, this message translates to:
  /// **'수수료율 {rate}% 자동 적용'**
  String commissionAutoRate(String rate);

  /// No description provided for @noTransactionsNote.
  ///
  /// In ko, this message translates to:
  /// **'거래 내역 없이\n현재 보유만 입력한 종목입니다'**
  String get noTransactionsNote;

  /// No description provided for @weightSumNotice.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중 합계가 {pct}입니다. 100%가 되어야 조정 제안을 계산할 수 있습니다.'**
  String weightSumNotice(String pct);

  /// No description provided for @fixTargetWeights.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중 맞추기'**
  String get fixTargetWeights;

  /// No description provided for @needMoreItems.
  ///
  /// In ko, this message translates to:
  /// **'종목을 더 담아야 조정할 수 있습니다'**
  String get needMoreItems;

  /// No description provided for @itemAdded.
  ///
  /// In ko, this message translates to:
  /// **'{name} 담았습니다'**
  String itemAdded(String name);

  /// No description provided for @createPortfolioCta.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 만들기'**
  String get createPortfolioCta;

  /// No description provided for @partialSettlement.
  ///
  /// In ko, this message translates to:
  /// **'아직 다 받지 못한 값입니다 · {count}종목 남음'**
  String partialSettlement(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
