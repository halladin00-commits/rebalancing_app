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
  /// **'{name}은(는) 이미 담겨 있습니다'**
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

  /// No description provided for @atCurrentPrice.
  ///
  /// In ko, this message translates to:
  /// **'현재가 {price} 기준'**
  String atCurrentPrice(String price);

  /// No description provided for @driftAfterAdjust.
  ///
  /// In ko, this message translates to:
  /// **'조정 후 남는 편차'**
  String get driftAfterAdjust;

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

  /// No description provided for @recordAsTransactions.
  ///
  /// In ko, this message translates to:
  /// **'거래 내역으로 기록'**
  String get recordAsTransactions;

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

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @apply.
  ///
  /// In ko, this message translates to:
  /// **'적용'**
  String get apply;

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

  /// No description provided for @create.
  ///
  /// In ko, this message translates to:
  /// **'생성'**
  String get create;

  /// No description provided for @irrevocable.
  ///
  /// In ko, this message translates to:
  /// **'이 작업은 되돌릴 수 없습니다.'**
  String get irrevocable;

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

  /// No description provided for @editComplete.
  ///
  /// In ko, this message translates to:
  /// **'편집 완료'**
  String get editComplete;

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

  /// No description provided for @deletePortfolioContent.
  ///
  /// In ko, this message translates to:
  /// **'\'{name}\' 포트폴리오를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'**
  String deletePortfolioContent(String name);

  /// No description provided for @deleteItemContent.
  ///
  /// In ko, this message translates to:
  /// **'\'{name}\'을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'**
  String deleteItemContent(String name);

  /// No description provided for @appExitTitle.
  ///
  /// In ko, this message translates to:
  /// **'종료'**
  String get appExitTitle;

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

  /// No description provided for @updateSuccess.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 완료'**
  String get updateSuccess;

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

  /// No description provided for @additionalInvestment.
  ///
  /// In ko, this message translates to:
  /// **'투자금 추가 or 출금'**
  String get additionalInvestment;

  /// No description provided for @additionalInvestmentHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 1000000 또는 -500000'**
  String get additionalInvestmentHint;

  /// No description provided for @priceDelayNote.
  ///
  /// In ko, this message translates to:
  /// **'※ 주가 ~20분, 환율 ~1일까지 지연 가능'**
  String get priceDelayNote;

  /// No description provided for @totalAssetsLabel.
  ///
  /// In ko, this message translates to:
  /// **'전체 자산 합계 (원 환산)'**
  String get totalAssetsLabel;

  /// No description provided for @evaluationAmount.
  ///
  /// In ko, this message translates to:
  /// **'평가금액'**
  String get evaluationAmount;

  /// No description provided for @currentAssets.
  ///
  /// In ko, this message translates to:
  /// **'현재 평가금액'**
  String get currentAssets;

  /// No description provided for @rebalancingBase.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 기준금액'**
  String get rebalancingBase;

  /// No description provided for @remainingCash.
  ///
  /// In ko, this message translates to:
  /// **'잔여 현금'**
  String get remainingCash;

  /// No description provided for @estimatedFee.
  ///
  /// In ko, this message translates to:
  /// **'예상 수수료: {fee}'**
  String estimatedFee(String fee);

  /// No description provided for @exchangeRateLabel.
  ///
  /// In ko, this message translates to:
  /// **'환율: 1 USD = ₩{rate}'**
  String exchangeRateLabel(String rate);

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

  /// No description provided for @labelEdit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get labelEdit;

  /// No description provided for @labelGraph.
  ///
  /// In ko, this message translates to:
  /// **'그래프'**
  String get labelGraph;

  /// No description provided for @labelRebalanceApply.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 적용'**
  String get labelRebalanceApply;

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

  /// No description provided for @hold.
  ///
  /// In ko, this message translates to:
  /// **'유지'**
  String get hold;

  /// No description provided for @cash.
  ///
  /// In ko, this message translates to:
  /// **'현금'**
  String get cash;

  /// No description provided for @rebalanceApplyTitle.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 적용'**
  String get rebalanceApplyTitle;

  /// No description provided for @rebalanceBullet1.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 결과를 보유 수량에 반영'**
  String get rebalanceBullet1;

  /// No description provided for @rebalanceBullet2.
  ///
  /// In ko, this message translates to:
  /// **'잔여 현금은 추가 투자금으로 변환'**
  String get rebalanceBullet2;

  /// No description provided for @rebalanceBullet3.
  ///
  /// In ko, this message translates to:
  /// **'매수 종목 평단가 자동 업데이트'**
  String get rebalanceBullet3;

  /// No description provided for @rebalanceBullet3Note.
  ///
  /// In ko, this message translates to:
  /// **'* 현재가 기준 계산 — 실제 체결가와 다를 수 있음'**
  String get rebalanceBullet3Note;

  /// No description provided for @savePermissionRequired.
  ///
  /// In ko, this message translates to:
  /// **'저장 권한이 필요합니다'**
  String get savePermissionRequired;

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

  /// No description provided for @portfolio.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오'**
  String get portfolio;

  /// No description provided for @settlementTab.
  ///
  /// In ko, this message translates to:
  /// **'결산'**
  String get settlementTab;

  /// No description provided for @duplicatePortfolio.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 복사'**
  String get duplicatePortfolio;

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

  /// No description provided for @disclaimerDontShowAgain.
  ///
  /// In ko, this message translates to:
  /// **'위 내용을 확인하였으며, 다음부터 이 안내를 표시하지 않습니다'**
  String get disclaimerDontShowAgain;

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

  /// No description provided for @editStockTitle.
  ///
  /// In ko, this message translates to:
  /// **'종목 수정'**
  String get editStockTitle;

  /// No description provided for @addStockTitle.
  ///
  /// In ko, this message translates to:
  /// **'종목 추가'**
  String get addStockTitle;

  /// No description provided for @cashItem.
  ///
  /// In ko, this message translates to:
  /// **'현금 항목'**
  String get cashItem;

  /// No description provided for @searchStock.
  ///
  /// In ko, this message translates to:
  /// **'종목 검색'**
  String get searchStock;

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'종목명 또는 티커 입력'**
  String get searchHint;

  /// No description provided for @stockName.
  ///
  /// In ko, this message translates to:
  /// **'종목명'**
  String get stockName;

  /// No description provided for @cashNameHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 예수금'**
  String get cashNameHint;

  /// No description provided for @autoFillHint.
  ///
  /// In ko, this message translates to:
  /// **'검색으로 자동 입력'**
  String get autoFillHint;

  /// No description provided for @stockCodeTicker.
  ///
  /// In ko, this message translates to:
  /// **'종목 코드 / 티커'**
  String get stockCodeTicker;

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

  /// No description provided for @returnRate.
  ///
  /// In ko, this message translates to:
  /// **'수익률'**
  String get returnRate;

  /// No description provided for @currentPrice.
  ///
  /// In ko, this message translates to:
  /// **'현재가'**
  String get currentPrice;

  /// No description provided for @autoUpdate.
  ///
  /// In ko, this message translates to:
  /// **'자동 업데이트'**
  String get autoUpdate;

  /// No description provided for @autoUpdateHint.
  ///
  /// In ko, this message translates to:
  /// **'새로고침 시 자동으로 업데이트'**
  String get autoUpdateHint;

  /// No description provided for @targetWeightLabel.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중'**
  String get targetWeightLabel;

  /// No description provided for @holdingsAmount.
  ///
  /// In ko, this message translates to:
  /// **'보유 금액'**
  String get holdingsAmount;

  /// No description provided for @holdingsShares.
  ///
  /// In ko, this message translates to:
  /// **'보유 수량'**
  String get holdingsShares;

  /// No description provided for @unitUSD.
  ///
  /// In ko, this message translates to:
  /// **'USD'**
  String get unitUSD;

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

  /// No description provided for @portfolioExampleHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 연금저축, 미국주식'**
  String get portfolioExampleHint;

  /// No description provided for @editPortfolioTitle.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 수정'**
  String get editPortfolioTitle;

  /// No description provided for @createPortfolioTitle.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 생성'**
  String get createPortfolioTitle;

  /// No description provided for @portfolioName.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 이름'**
  String get portfolioName;

  /// No description provided for @iconLabel.
  ///
  /// In ko, this message translates to:
  /// **'아이콘'**
  String get iconLabel;

  /// No description provided for @createBtn.
  ///
  /// In ko, this message translates to:
  /// **'생성'**
  String get createBtn;

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

  /// No description provided for @amountDisplay.
  ///
  /// In ko, this message translates to:
  /// **'금액 표시'**
  String get amountDisplay;

  /// No description provided for @amountDisplayHint.
  ///
  /// In ko, this message translates to:
  /// **'현재 자산 / 리밸런싱 기준'**
  String get amountDisplayHint;

  /// No description provided for @fullDisplay.
  ///
  /// In ko, this message translates to:
  /// **'전체 표시'**
  String get fullDisplay;

  /// No description provided for @compactDisplay.
  ///
  /// In ko, this message translates to:
  /// **'축약 표시'**
  String get compactDisplay;

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

  /// No description provided for @autoRealtime.
  ///
  /// In ko, this message translates to:
  /// **'자동 (실시간)'**
  String get autoRealtime;

  /// No description provided for @exchangeRateInput.
  ///
  /// In ko, this message translates to:
  /// **'환율 (1 USD)'**
  String get exchangeRateInput;

  /// No description provided for @autoRateHint.
  ///
  /// In ko, this message translates to:
  /// **'새로고침 버튼으로 최신 환율을 가져옵니다'**
  String get autoRateHint;

  /// No description provided for @stockPriceSetting.
  ///
  /// In ko, this message translates to:
  /// **'주가'**
  String get stockPriceSetting;

  /// No description provided for @autoPriceHint.
  ///
  /// In ko, this message translates to:
  /// **'새로고침 시 종목코드/티커 기준으로 현재가를 가져옵니다'**
  String get autoPriceHint;

  /// No description provided for @language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get language;

  /// No description provided for @langKorean.
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get langKorean;

  /// No description provided for @langEnglish.
  ///
  /// In ko, this message translates to:
  /// **'English'**
  String get langEnglish;

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

  /// No description provided for @lightMode.
  ///
  /// In ko, this message translates to:
  /// **'라이트 모드'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In ko, this message translates to:
  /// **'다크 모드'**
  String get darkMode;

  /// No description provided for @currentPriceLabel.
  ///
  /// In ko, this message translates to:
  /// **'현재가'**
  String get currentPriceLabel;

  /// No description provided for @holdingsLabel.
  ///
  /// In ko, this message translates to:
  /// **'보유 수량'**
  String get holdingsLabel;

  /// No description provided for @targetWeightRow.
  ///
  /// In ko, this message translates to:
  /// **'목표 비중'**
  String get targetWeightRow;

  /// No description provided for @currentWeightRow.
  ///
  /// In ko, this message translates to:
  /// **'현재 비중'**
  String get currentWeightRow;

  /// No description provided for @finalWeightRow.
  ///
  /// In ko, this message translates to:
  /// **'최종 비중'**
  String get finalWeightRow;

  /// No description provided for @tradeRow.
  ///
  /// In ko, this message translates to:
  /// **'매매'**
  String get tradeRow;

  /// No description provided for @wonEquivalent.
  ///
  /// In ko, this message translates to:
  /// **'원화 환산가: {amount}'**
  String wonEquivalent(String amount);

  /// No description provided for @autoPriceUpdateInfo.
  ///
  /// In ko, this message translates to:
  /// **'주가 자동 업데이트 설정 중 — 새로고침으로 갱신'**
  String get autoPriceUpdateInfo;

  /// No description provided for @unitKrwSuffix.
  ///
  /// In ko, this message translates to:
  /// **'억'**
  String get unitKrwSuffix;

  /// No description provided for @unitKrwMan.
  ///
  /// In ko, this message translates to:
  /// **'만'**
  String get unitKrwMan;

  /// No description provided for @etfBadge.
  ///
  /// In ko, this message translates to:
  /// **'ETF'**
  String get etfBadge;

  /// No description provided for @totalPnl.
  ///
  /// In ko, this message translates to:
  /// **'종합손익'**
  String get totalPnl;

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

  /// No description provided for @settlementBasedOn.
  ///
  /// In ko, this message translates to:
  /// **'기준일: {date}'**
  String settlementBasedOn(String date);

  /// No description provided for @settlementStartValue.
  ///
  /// In ko, this message translates to:
  /// **'기준 평가금액'**
  String get settlementStartValue;

  /// No description provided for @settlementEndValue.
  ///
  /// In ko, this message translates to:
  /// **'현재 평가금액'**
  String get settlementEndValue;

  /// No description provided for @settlementReturn.
  ///
  /// In ko, this message translates to:
  /// **'기간 수익률'**
  String get settlementReturn;

  /// No description provided for @settlementNoData.
  ///
  /// In ko, this message translates to:
  /// **'데이터 수집 중'**
  String get settlementNoData;

  /// No description provided for @settlementNoDataDesc.
  ///
  /// In ko, this message translates to:
  /// **'새로고침 시 자동으로 스냅샷이 저장됩니다.'**
  String get settlementNoDataDesc;

  /// No description provided for @settlementViewWithApi.
  ///
  /// In ko, this message translates to:
  /// **'API 데이터로 대체 보기'**
  String get settlementViewWithApi;

  /// No description provided for @settlementApiFallbackWarning.
  ///
  /// In ko, this message translates to:
  /// **'Yahoo Finance 과거 데이터 기준 (수량 변동 미반영)'**
  String get settlementApiFallbackWarning;

  /// No description provided for @settlementContribution.
  ///
  /// In ko, this message translates to:
  /// **'기여도'**
  String get settlementContribution;

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

  /// No description provided for @notifEnableLabel.
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get notifEnableLabel;

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

  /// No description provided for @notifFrequency.
  ///
  /// In ko, this message translates to:
  /// **'알림 주기'**
  String get notifFrequency;

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

  /// No description provided for @notifSavedOn.
  ///
  /// In ko, this message translates to:
  /// **'알림이 설정됐습니다'**
  String get notifSavedOn;

  /// No description provided for @notifSavedOff.
  ///
  /// In ko, this message translates to:
  /// **'알림이 꺼졌습니다'**
  String get notifSavedOff;

  /// No description provided for @purchaseDateLabel.
  ///
  /// In ko, this message translates to:
  /// **'매수 일자'**
  String get purchaseDateLabel;

  /// No description provided for @holdingsFromTransactions.
  ///
  /// In ko, this message translates to:
  /// **'거래 내역에서 수정'**
  String get holdingsFromTransactions;

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

  /// No description provided for @deleteTransaction.
  ///
  /// In ko, this message translates to:
  /// **'거래 삭제'**
  String get deleteTransaction;

  /// No description provided for @settlementWeekNum.
  ///
  /// In ko, this message translates to:
  /// **'{week}주차'**
  String settlementWeekNum(int week);

  /// No description provided for @settlementMonthNum.
  ///
  /// In ko, this message translates to:
  /// **'{month}월'**
  String settlementMonthNum(int month);

  /// No description provided for @settlementQuarterNum.
  ///
  /// In ko, this message translates to:
  /// **'{q}분기'**
  String settlementQuarterNum(int q);

  /// No description provided for @settlementPeriodRange.
  ///
  /// In ko, this message translates to:
  /// **'{start} ~ {end}'**
  String settlementPeriodRange(String start, String end);

  /// No description provided for @settlementCurrentPeriod.
  ///
  /// In ko, this message translates to:
  /// **'진행 중'**
  String get settlementCurrentPeriod;

  /// No description provided for @settlementNoHoldings.
  ///
  /// In ko, this message translates to:
  /// **'해당 기간 보유 종목 없음'**
  String get settlementNoHoldings;

  /// No description provided for @settlementNetCashFlow.
  ///
  /// In ko, this message translates to:
  /// **'추가 투자금'**
  String get settlementNetCashFlow;

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

  /// No description provided for @excelDownloadTemplate.
  ///
  /// In ko, this message translates to:
  /// **'양식 다운로드'**
  String get excelDownloadTemplate;

  /// No description provided for @excelImportFile.
  ///
  /// In ko, this message translates to:
  /// **'파일 가져오기'**
  String get excelImportFile;

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

  /// No description provided for @excelTemplateHint.
  ///
  /// In ko, this message translates to:
  /// **'컬럼: 날짜 | 종목명 | 티커 | 시장 | 유형 | 수량 | 단가\n날짜: 2024.01.15  시장: KR / US  유형: 매수 / 매도'**
  String get excelTemplateHint;

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

  /// No description provided for @settlementNotifWeekly.
  ///
  /// In ko, this message translates to:
  /// **'주간 결산'**
  String get settlementNotifWeekly;

  /// No description provided for @settlementNotifMonthly.
  ///
  /// In ko, this message translates to:
  /// **'월간 결산'**
  String get settlementNotifMonthly;

  /// No description provided for @settlementNotifQuarterly.
  ///
  /// In ko, this message translates to:
  /// **'분기 결산'**
  String get settlementNotifQuarterly;

  /// No description provided for @settlementNotifYearly.
  ///
  /// In ko, this message translates to:
  /// **'연간 결산'**
  String get settlementNotifYearly;

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

  /// No description provided for @fractionalTradingToggle.
  ///
  /// In ko, this message translates to:
  /// **'소수점 단위로 매매'**
  String get fractionalTradingToggle;

  /// No description provided for @fractionalTradingHint.
  ///
  /// In ko, this message translates to:
  /// **'소수점 매매가 되는 계좌에서만 켜세요.\n끄면 1주 단위로만 계산합니다.'**
  String get fractionalTradingHint;

  /// No description provided for @rebalanceTransactionTitle.
  ///
  /// In ko, this message translates to:
  /// **'리밸런싱 거래 확인'**
  String get rebalanceTransactionTitle;

  /// No description provided for @rebalanceTransactionDesc.
  ///
  /// In ko, this message translates to:
  /// **'실제 거래 수량·가격으로 수정 후 완료를 누르세요.\n수량이 0이면 거래내역에 추가되지 않습니다.'**
  String get rebalanceTransactionDesc;
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
