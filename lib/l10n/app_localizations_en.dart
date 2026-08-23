// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String deleteLosesItems(int items, int txs) {
    return '$items holdings and $txs transactions go with it.';
  }

  @override
  String get deleteCannotUndo => 'This cannot be undone.';

  @override
  String yearMonth(int year, int month) {
    return '$month/$year';
  }

  @override
  String get netBuy => 'net buy';

  @override
  String get netSell => 'net sell';

  @override
  String get fractionalIntro =>
      'Fractional trading depends on your broker and account. Turn it on only where it works.';

  @override
  String get fractionalPerAccount => 'Per account';

  @override
  String get fractionalReasonOverseas => 'Overseas · fractional supported';

  @override
  String fractionalReasonPartial(int count) {
    return 'Applies to $count overseas holdings';
  }

  @override
  String get fractionalReasonKrOnly => 'Domestic only · may not be supported';

  @override
  String get fractionalRoundingTitle => 'Quantity rounding';

  @override
  String get fractionalRoundingDisabled =>
      'No account has fractional trading on yet. Turn one on to choose a rounding rule.';

  @override
  String get roundingMinDeviation => 'Closest to target';

  @override
  String roundingMinDeviationDesc(int digits) {
    return 'Rounds at $digits decimal places. Closest to target, but may exceed your budget slightly.';
  }

  @override
  String get roundingFloorCash => 'Round down, keep cash';

  @override
  String get roundingFloorCashDesc =>
      'Never exceeds your budget. A tiny amount of cash is left over.';

  @override
  String get fractionalPreviewTitle => 'How your proposal changes';

  @override
  String get previewWholeShares => 'Whole shares';

  @override
  String get previewFractional => 'Fractional';

  @override
  String get noPortfolios => 'No portfolios yet';

  @override
  String refreshPartialFail(int count) {
    return 'Could not update $count holdings · last prices kept';
  }

  @override
  String refreshFailedNote(String time) {
    return 'Update failed · prices from $time';
  }

  @override
  String get refreshRetry => 'Retry';

  @override
  String excludedFromSettlement(int count, String amount) {
    return '$count excluded · $amount';
  }

  @override
  String get excludedFixLink => 'Details';

  @override
  String get excludedSheetTitle => 'Excluded from returns';

  @override
  String get excludedSheetBody =>
      'You hold these now, but there are no transactions covering this period, so they are not counted in returns.\n\nYour assets and rebalancing are unaffected — only returns cannot be computed, because there is no way to tell a purchase apart from a price rise.\n\nAdd the actual buy transaction on the holding page and it will be included from then on.';

  @override
  String get excludedNoHistory => 'no transactions';

  @override
  String lastMonthReturn(String rate) {
    return 'Last month $rate';
  }

  @override
  String get spark1w => '1W';

  @override
  String get spark1m => '1M';

  @override
  String get spark3m => '3M';

  @override
  String get spark6m => '6M';

  @override
  String get spark1y => '1Y';

  @override
  String sparklinePending(int count) {
    return 'Your trend appears here once\n$count days of refreshes are recorded';
  }

  @override
  String get searchPrompt => 'Type a name or ticker to search';

  @override
  String get searchNoResult => 'No results.\nTry the ticker or stock code';

  @override
  String get filterAll => 'All';

  @override
  String get filterKr => 'Korea';

  @override
  String get filterUs => 'Overseas';

  @override
  String get cashAddHint =>
      'Cash is not searched — you add it directly.\nRecording your account cash as one item\nlets it count toward your weights.';

  @override
  String get cashAddButton => 'Add cash';

  @override
  String get manualEntryHint => 'Not listed? Add it manually';

  @override
  String alreadyInPortfolio(String name) {
    return '$name is already in this portfolio';
  }

  @override
  String txCountLabel(int count) {
    return '$count trades';
  }

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get transactionAmount => 'Amount';

  @override
  String get saveTransaction => 'Save transaction';

  @override
  String get transactionAffectsAvg =>
      'Saving recalculates your quantity and average cost from this transaction.';

  @override
  String get validationQtyPositive => 'Enter a quantity greater than 0';

  @override
  String get validationPricePositive => 'Enter a price greater than 0';

  @override
  String validationSellExceeds(String owned) {
    return 'You cannot sell more than you hold ($owned)';
  }

  @override
  String get reorderPortfolios => 'Reorder portfolios';

  @override
  String get reorderItems => 'Reorder holdings';

  @override
  String get holdingQty => 'Quantity';

  @override
  String get basedOnTransactions => 'from transactions';

  @override
  String get enteredDirectly => 'entered directly';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get proposalTitle => 'Adjustment';

  @override
  String get modeHoldings => 'Within holdings';

  @override
  String get modeAddCash => 'With new cash';

  @override
  String atCurrentPrice(String price) {
    return 'at $price';
  }

  @override
  String get driftAfterAdjust => 'Drift after adjusting';

  @override
  String toleranceLabel(String value) {
    return '±${value}pp allowed';
  }

  @override
  String get withinTolerance => 'Within';

  @override
  String get roundingWholeShares => 'Whole shares only';

  @override
  String get roundingWholeSharesDesc =>
      'Quantities stay in whole shares, picked to land closest to the target weight.';

  @override
  String get roundingFractional => 'Fractional shares';

  @override
  String roundingFractionalDesc(int digits) {
    return 'Rounded down at $digits decimal places so the total never exceeds your budget, leaving a tiny remainder.';
  }

  @override
  String get proposalDisclaimer =>
      'This does not place any orders. Record your trades below once you have actually executed them.';

  @override
  String get noAdjustmentNeeded => 'Nothing to adjust right now';

  @override
  String get cannotCalculate =>
      'Cannot calculate. Check whether any holding is missing a current price.';

  @override
  String get recordAsTransactions => 'Record as transactions';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get apply => 'Apply';

  @override
  String get exit => 'Exit';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get irrevocable => 'This action cannot be undone.';

  @override
  String get editExitTitle => 'Exit Edit Mode';

  @override
  String get editExitContent => 'Exit edit mode?';

  @override
  String get editComplete => 'Done';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get deleteConfirmTitle => 'Delete';

  @override
  String deletePortfolioContent(String name) {
    return 'Delete portfolio \'$name\'?\nThis action cannot be undone.';
  }

  @override
  String deleteItemContent(String name) {
    return 'Delete \'$name\'?\nThis action cannot be undone.';
  }

  @override
  String get appExitTitle => 'Exit';

  @override
  String get appExitContent => 'Exit the app?';

  @override
  String get neverUpdated => 'Never updated';

  @override
  String get toastAutoSettingRequired =>
      'Please enable auto exchange rate or price in Settings';

  @override
  String updateFailed(String msg) {
    return 'Update failed: $msg';
  }

  @override
  String get updateSuccess => 'Updated';

  @override
  String updateSuccessCount(int count) {
    return '$count updated';
  }

  @override
  String get portfolioNotFound => 'Portfolio not found';

  @override
  String get additionalInvestment => 'Add Investment or Withdraw';

  @override
  String get additionalInvestmentHint => 'e.g. 1000000 or -500000';

  @override
  String get priceDelayNote => '※ Prices ~20min, rate ~1day delayed';

  @override
  String get totalAssetsLabel => 'Total Assets (KRW equiv.)';

  @override
  String get evaluationAmount => 'Evaluation Amount';

  @override
  String get currentAssets => 'Current Value';

  @override
  String get rebalancingBase => 'Rebalancing Base';

  @override
  String get remainingCash => 'Remaining Cash';

  @override
  String estimatedFee(String fee) {
    return 'Est. fee: $fee';
  }

  @override
  String exchangeRateLabel(String rate) {
    return 'Rate: 1 USD = ₩$rate';
  }

  @override
  String weightWarning(String pct) {
    return 'Target weight: $pct (not 100%)';
  }

  @override
  String get labelSettings => 'Settings';

  @override
  String get labelEdit => 'Edit';

  @override
  String get labelGraph => 'Graph';

  @override
  String get labelRebalanceApply => 'Apply Rebalancing';

  @override
  String get addStock => 'Add Stock';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get hold => 'Hold';

  @override
  String get cash => 'Cash';

  @override
  String get rebalanceApplyTitle => 'Apply Rebalancing';

  @override
  String get rebalanceBullet1 => 'Apply results to current holdings';

  @override
  String get rebalanceBullet2 => 'Remaining cash becomes additional investment';

  @override
  String get rebalanceBullet3 => 'Avg. cost auto-updates for buy orders';

  @override
  String get rebalanceBullet3Note =>
      '* Based on current price — may differ from actual execution price';

  @override
  String get savePermissionRequired => 'Storage permission required';

  @override
  String get captureFailed => 'Capture failed';

  @override
  String get savedToGallery => 'Saved to gallery';

  @override
  String get saveFailed => 'Save failed';

  @override
  String saveFailedError(String error) {
    return 'Save failed: $error';
  }

  @override
  String get editCenterText => 'Edit Center Text';

  @override
  String get editItem => 'Edit Item';

  @override
  String get displayName => 'Display Name';

  @override
  String get colorLabel => 'Color';

  @override
  String get portfolioEmpty => 'No Portfolio';

  @override
  String get portfolioGraph => 'Portfolio Graph';

  @override
  String get editCompleteTooltip => 'Done';

  @override
  String get editTooltip => 'Edit';

  @override
  String get editCompleteBeforeSave => 'Finish editing before saving';

  @override
  String get saveImage => 'Save Image';

  @override
  String get shareImage => 'Share Image';

  @override
  String get capture => 'Capture';

  @override
  String get portfolio => 'Portfolio';

  @override
  String get settlementTab => 'Settlement';

  @override
  String get duplicatePortfolio => 'Duplicate Portfolio';

  @override
  String get notifPermissionDenied =>
      'Notification permission denied. Please allow it in Settings.';

  @override
  String get targetWeight => 'Target Weight';

  @override
  String get currentWeight => 'Current Weight';

  @override
  String get noPriceInfo => 'No price data. Refresh and try again.';

  @override
  String get tapToEdit => 'Tap to edit';

  @override
  String get dragToReorder => 'Long-press and drag to reorder';

  @override
  String get disclaimerTitle => 'Terms of Use & Disclaimer';

  @override
  String get disclaimerSectionPurpose => 'Purpose';

  @override
  String get disclaimerTextPurpose =>
      'This app (Rebalancing) is a reference tool to help individual investors calculate portfolio rebalancing and analyze period-based returns from transaction history. It does not provide financial investment advice, investment recommendations, or asset management services under any circumstances.';

  @override
  String get disclaimerSectionData => 'Data Accuracy';

  @override
  String get disclaimerTextData =>
      'The following information provided by the app is based on external public APIs and data sources, and may be subject to delays, errors, or omissions.\n\n• Stock information (name, ticker, market)\n• Real-time stock prices (Yahoo Finance)\n• Real-time exchange rates (public API)\n• ETF classification and related info\n• Rebalancing results (quantity, weight, remaining cash)\n• Estimated trading fees\n• Period returns and per-asset contribution (based on user-entered transactions and historical price data)\n\nPlease verify directly, as this may differ from actual market data.';

  @override
  String get disclaimerSectionRisk => 'Investment Risk';

  @override
  String get disclaimerTextRisk =>
      'The developer bears no legal responsibility for investment decisions made based on this app\'s information, or any resulting losses. All investment decisions must be made at the user\'s own judgment and risk.';

  @override
  String get disclaimerSectionTax => 'Tax & Legal';

  @override
  String get disclaimerTextTax =>
      'Users are responsible for fulfilling legal obligations such as tax reporting, capital gains tax, and financial income tax related to financial transactions. This app does not provide tax or legal advice.';

  @override
  String get disclaimerSectionService => 'Service Changes';

  @override
  String get disclaimerTextService =>
      'Features, data sources, and services may be changed or discontinued without prior notice.';

  @override
  String get disclaimerDontShowAgain =>
      'I have read and understood. Don\'t show this again.';

  @override
  String get disclaimerStartBtn => 'Confirm & Start';

  @override
  String get disclaimerConfirmBtn => 'Confirm';

  @override
  String get editStockTitle => 'Edit Stock';

  @override
  String get addStockTitle => 'Add Stock';

  @override
  String get cashItem => 'Cash';

  @override
  String get searchStock => 'Search Stock';

  @override
  String get searchHint => 'Enter name or ticker';

  @override
  String get stockName => 'Stock Name';

  @override
  String get cashNameHint => 'e.g. Cash Balance';

  @override
  String get autoFillHint => 'Auto-filled by search';

  @override
  String get stockCodeTicker => 'Stock Code / Ticker';

  @override
  String get avgCost => 'Avg. Cost';

  @override
  String get profitLoss => 'P&L';

  @override
  String get returnRate => 'Return';

  @override
  String get currentPrice => 'Current Price';

  @override
  String get autoUpdate => 'Auto Update';

  @override
  String get autoUpdateHint => 'Auto-updated on refresh';

  @override
  String get targetWeightLabel => 'Target Weight';

  @override
  String get holdingsAmount => 'Holdings (Amount)';

  @override
  String get holdingsShares => 'Holdings (Shares)';

  @override
  String get unitUSD => 'USD';

  @override
  String get unitKRW => 'KRW';

  @override
  String get unitShares => 'shares';

  @override
  String get portfolioExampleHint => 'e.g. Pension, US Stocks';

  @override
  String get editPortfolioTitle => 'Edit Portfolio';

  @override
  String get createPortfolioTitle => 'New Portfolio';

  @override
  String get portfolioName => 'Portfolio Name';

  @override
  String get iconLabel => 'Icon';

  @override
  String get createBtn => 'Create';

  @override
  String get settings => 'Settings';

  @override
  String get baseCurrency => 'Base Currency';

  @override
  String get currencyKRW => 'KRW (₩)';

  @override
  String get currencyUSD => 'USD (\$)';

  @override
  String get amountDisplay => 'Amount Display';

  @override
  String get amountDisplayHint => 'Current Assets / Base Amount';

  @override
  String get fullDisplay => 'Full';

  @override
  String get compactDisplay => 'Compact';

  @override
  String get tradingFee => 'Trading Fee';

  @override
  String get includeFee => 'Include Fee';

  @override
  String get feeRate => 'Fee Rate';

  @override
  String get exchangeRateSetting => 'Exchange Rate';

  @override
  String get autoRealtime => 'Auto (Real-time)';

  @override
  String get exchangeRateInput => 'Rate (1 USD)';

  @override
  String get autoRateHint => 'Use refresh button to get the latest rate';

  @override
  String get stockPriceSetting => 'Stock Price';

  @override
  String get autoPriceHint => 'Price is fetched on refresh by ticker';

  @override
  String get language => 'Language';

  @override
  String get langKorean => '한국어';

  @override
  String get langEnglish => 'English';

  @override
  String get portfolioAddBtn => 'Add Portfolio';

  @override
  String get holdingsSection => 'Holdings';

  @override
  String get cashIncluded => 'incl. cash';

  @override
  String itemCountLabel(int count) {
    return '$count stocks';
  }

  @override
  String get notice => 'Notice';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get currentPriceLabel => 'Price';

  @override
  String get holdingsLabel => 'Holdings';

  @override
  String get targetWeightRow => 'Target Weight';

  @override
  String get currentWeightRow => 'Current Weight';

  @override
  String get finalWeightRow => 'Final Weight';

  @override
  String get tradeRow => 'Trade';

  @override
  String wonEquivalent(String amount) {
    return 'KRW equiv: $amount';
  }

  @override
  String get autoPriceUpdateInfo => 'Auto price update on — refresh to update';

  @override
  String get unitKrwSuffix => '';

  @override
  String get unitKrwMan => '';

  @override
  String get etfBadge => 'ETF';

  @override
  String get totalPnl => 'Total P&L';

  @override
  String get dayChange => 'Day Change';

  @override
  String get disclaimerAgreeCheckbox =>
      'I have read and agree\nto all of the above.';

  @override
  String get validationNonNegative => 'Please enter a value of 0 or greater.';

  @override
  String get validationPositive => 'Please enter a value greater than 0.';

  @override
  String get validationExchangeRatePositive =>
      'Exchange rate must be greater than 0.';

  @override
  String get tabAssets => 'Assets';

  @override
  String get tabRebalancing => 'Rebalance';

  @override
  String get tabSettlement => 'Returns';

  @override
  String get tabMore => 'More';

  @override
  String get settlementWeekly => 'Weekly';

  @override
  String get settlementMonthly => 'Monthly';

  @override
  String get settlementQuarterly => 'Quarterly';

  @override
  String get settlementYearly => 'Yearly';

  @override
  String settlementBasedOn(String date) {
    return 'Based on: $date';
  }

  @override
  String get settlementStartValue => 'Base Value';

  @override
  String get settlementEndValue => 'Current Value';

  @override
  String get settlementReturn => 'Period Return';

  @override
  String get settlementNoData => 'Collecting data';

  @override
  String get settlementNoDataDesc =>
      'Snapshots are saved automatically on refresh.';

  @override
  String get settlementViewWithApi => 'View with API data';

  @override
  String get settlementApiFallbackWarning =>
      'Based on Yahoo Finance historical data (holdings changes not reflected)';

  @override
  String get settlementContribution => 'Contribution';

  @override
  String get backupData => 'Backup';

  @override
  String get restoreData => 'Restore';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get restoreConfirmTitle => 'Restore Data';

  @override
  String restoreConfirmContent(int count) {
    return 'Restore $count portfolios?\nAll current data will be replaced.';
  }

  @override
  String restoreSuccess(int count) {
    return 'Restored: $count portfolios';
  }

  @override
  String get restoreFailed => 'Restore failed: invalid backup file';

  @override
  String get notifReminder => 'Rebalancing Reminders';

  @override
  String get notifEnableLabel => 'Notifications';

  @override
  String get notifEnableDesc => 'Periodic rebalancing reminders';

  @override
  String get notifEnableHint =>
      'We\'ll send you a reminder at the set interval';

  @override
  String get notifFrequency => 'Frequency';

  @override
  String get notifWeekly => 'Every Monday at 9 AM';

  @override
  String get notifMonthly => '1st of each month at 9 AM';

  @override
  String get notifSavedOn => 'Reminders enabled';

  @override
  String get notifSavedOff => 'Reminders disabled';

  @override
  String get purchaseDateLabel => 'Purchase Date';

  @override
  String get holdingsFromTransactions => 'Modify via transactions';

  @override
  String get transactionHistory => 'Transactions';

  @override
  String get addTransaction => 'Add Transaction';

  @override
  String get transactionBuy => 'Buy';

  @override
  String get transactionSell => 'Sell';

  @override
  String get transactionDate => 'Date';

  @override
  String get transactionQty => 'Quantity';

  @override
  String get transactionPrice => 'Price';

  @override
  String get deleteTransaction => 'Delete';

  @override
  String settlementWeekNum(int week) {
    return 'Week $week';
  }

  @override
  String settlementMonthNum(int month) {
    return '$month';
  }

  @override
  String settlementQuarterNum(int q) {
    return 'Q$q';
  }

  @override
  String settlementPeriodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get settlementCurrentPeriod => 'In Progress';

  @override
  String get settlementNoHoldings => 'No holdings in this period';

  @override
  String get settlementNetCashFlow => 'Capital Added';

  @override
  String settlementYearLabel(int year) {
    return '$year';
  }

  @override
  String get excelImportTitle => 'Upload Transactions';

  @override
  String get excelDownloadTemplate => 'Download Template';

  @override
  String get excelImportFile => 'Import File';

  @override
  String get excelImportDone => 'Import Complete';

  @override
  String excelImportAdded(int count) {
    return '$count transactions added';
  }

  @override
  String excelImportCreated(int count) {
    return '$count new items created';
  }

  @override
  String excelImportSkipped(int count) {
    return '$count rows skipped';
  }

  @override
  String get excelTemplateHint =>
      'Columns: Date | Name | Ticker | Market | Type | Qty | Price\nDate: 2024.01.15  Market: KR / US  Type: Buy / Sell';

  @override
  String get excelImportNothingAdded => 'No transactions were added';

  @override
  String get settlementNotifHeader => 'Settlement Reminders';

  @override
  String get settlementNotifWeekly => 'Weekly Settlement';

  @override
  String get settlementNotifMonthly => 'Monthly Settlement';

  @override
  String get settlementNotifQuarterly => 'Quarterly Settlement';

  @override
  String get settlementNotifYearly => 'Yearly Settlement';

  @override
  String get rebalancingThresholdLabel => 'Rebalancing Threshold';

  @override
  String get rebalancingThresholdHint =>
      'No trade recommended below this deviation';

  @override
  String get fractionalTrading => 'Fractional Shares';

  @override
  String get fractionalTradingToggle => 'Allow fractional quantities';

  @override
  String get fractionalTradingHint =>
      'Turn on only if your broker supports fractional trading.\nOtherwise quantities stay in whole shares.';

  @override
  String get rebalanceTransactionTitle => 'Confirm Trades';

  @override
  String get rebalanceTransactionDesc =>
      'Edit qty/price to match your actual trades.\nItems with qty 0 will be skipped.';
}
