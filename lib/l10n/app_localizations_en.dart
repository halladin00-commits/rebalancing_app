// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get excludedShort => 'Skip';

  @override
  String get keepAsIs => 'Leave as is';

  @override
  String get firstRunTitle => 'How do you want to enter your holdings?';

  @override
  String get settlementCannotCompute =>
      'Could not fetch prices to compute this';

  @override
  String get settlementNoHoldings => 'No holdings in this period';

  @override
  String get targetWeightsTitle => 'Target weights';

  @override
  String get targetSum => 'Total';

  @override
  String get targetSumMustBe100 => 'Total must be 100%';

  @override
  String currentWeightIs(String pct) {
    return 'now $pct%';
  }

  @override
  String get notifRebalanceSection => 'Rebalancing reminders';

  @override
  String get settlementNotifNote => 'Sent when each period ends.';

  @override
  String get addPortfolioTitle => 'New portfolio';

  @override
  String get renamePortfolio => 'Rename';

  @override
  String get portfolioNameLabel => 'Name';

  @override
  String get portfolioNameHint => 'e.g. Retirement ETFs';

  @override
  String get hintTargetsInRebalanceTab =>
      'Set target weights in the Rebalance tab after adding holdings.';

  @override
  String get hintThenAddStocks => 'You will go straight to stock search.';

  @override
  String get createAndAddStocks => 'Create & add holdings';

  @override
  String get autoUpdateSection => 'Auto refresh';

  @override
  String get thresholdNote =>
      'Holdings drifting less than this are left alone. Set 0 to adjust everything.';

  @override
  String get itemEditNote =>
      'Quantity is computed from transactions. Add or edit a transaction to change it.';

  @override
  String get itemName => 'Name';

  @override
  String get itemNameHint => 'e.g. Vanguard S&P 500';

  @override
  String get itemFormNote =>
      'Entering a quantity creates one buy transaction on that date.';

  @override
  String get cashFormNoteOff =>
      'Cash is what is left in the account. It is excluded from your weights.';

  @override
  String get cashFormNote =>
      'Cash is what is left in the account. It counts toward your weights.';

  @override
  String get validationNameRequired => 'Enter a name';

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
    return '$count holdings still show older prices';
  }

  @override
  String refreshFailedNote(String time) {
    return 'Refresh failed · prices from $time';
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
      'These holdings have no trades in this period, so they\'re left out of Returns only. Assets and Rebalance still include them.\n\nAdd a buy transaction from the holding\'s page to include it.';

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
    return 'Your trend appears once $count days are recorded';
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
      'Add the cash sitting in your account so it counts toward weights.';

  @override
  String get cashAddButton => 'Add cash';

  @override
  String get manualEntryHint => 'Add manually';

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
      'Saving updates your quantity and average cost too.';

  @override
  String get validationQtyPositive => 'Enter a quantity greater than 0';

  @override
  String get validationPricePositive => 'Enter a price greater than 0';

  @override
  String validationSellExceeds(String owned) {
    return 'You cannot sell more than you hold ($owned)';
  }

  @override
  String get addPortfolio => 'Add portfolio';

  @override
  String get menuGroupView => 'View';

  @override
  String get menuGroupSetup => 'Setup';

  @override
  String get menuGroupData => 'Data';

  @override
  String get menuGroupThisPortfolio => 'This portfolio';

  @override
  String get editPortfolios => 'Edit portfolios';

  @override
  String get editPortfoliosHint =>
      'Drag to reorder; use ⋮ to rename, duplicate, or delete';

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
  String toleranceLabel(String value) {
    return '±${value}pp allowed';
  }

  @override
  String get withinTolerance => 'Within';

  @override
  String get calcBasisTitle => 'How this was calculated';

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
  String get tradeMoneyTitle => 'Trade amounts';

  @override
  String get tradeMoneyLeft => 'Left over';

  @override
  String get tradeMoneyNeeded => 'Need more';

  @override
  String get proposalBasisTitle => 'Price basis';

  @override
  String proposalBasisAt(String time) {
    return 'Calculated with prices as of $time';
  }

  @override
  String get proposalBasisNote =>
      'If prices move before you order, the quantities change too.';

  @override
  String get proposalBasisNever => 'No prices fetched yet';

  @override
  String get proposalCostTitle => 'Fees & taxes';

  @override
  String proposalCostWith(String rate) {
    return 'A $rate% fee is deducted. Taxes are not included, so your fills will differ slightly.';
  }

  @override
  String get proposalCostWithout =>
      'Fees and taxes are excluded, so your fills will differ slightly.';

  @override
  String get proposalDisclaimer =>
      'Place the orders with your broker. Record them below once filled.';

  @override
  String get noAdjustmentNeeded => 'Nothing to adjust right now';

  @override
  String get cannotCalculate => 'Can\'t calculate — some prices are missing';

  @override
  String get lastRebalancedNever => 'Never rebalanced';

  @override
  String get lastRebalancedToday => 'Rebalanced today';

  @override
  String get lastRebalancedYesterday => 'Rebalanced yesterday';

  @override
  String lastRebalancedDaysAgo(int days) {
    return 'Rebalanced ${days}d ago';
  }

  @override
  String lastRebalancedMonthsAgo(int months) {
    return 'Rebalanced ${months}mo ago';
  }

  @override
  String lastRebalancedYearsAgo(int years) {
    return 'Rebalanced ${years}y ago';
  }

  @override
  String get undoLastTitle => 'Undo last record';

  @override
  String undoFromProposal(int count, String when) {
    return 'Proposal · $count trades · $when';
  }

  @override
  String undoFromImport(int count, String when) {
    return 'Import · $count trades · $when';
  }

  @override
  String get undoConfirmTitle => 'Undo this?';

  @override
  String undoConfirmTrades(int count) {
    return '$count transactions will be removed.';
  }

  @override
  String undoConfirmItems(int count) {
    return '$count holdings created by this import will also be removed.';
  }

  @override
  String get undoConfirmCash => 'Cash returns to what it was.';

  @override
  String undoDone(int count) {
    return 'Undid $count transactions';
  }

  @override
  String undoKeptItems(String names) {
    return 'Kept $names — they have transactions added since';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yClose => 'Close';

  @override
  String get a11yRefresh => 'Refresh';

  @override
  String get a11yMenu => 'Open menu';

  @override
  String get a11yClearInput => 'Clear';

  @override
  String get a11yRemove => 'Remove';

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
  String get exit => 'Exit';

  @override
  String get add => 'Add';

  @override
  String get editExitTitle => 'Exit Edit Mode';

  @override
  String get editExitContent => 'Exit edit mode?';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get deleteConfirmTitle => 'Delete';

  @override
  String deleteItemContent(String name) {
    return 'Delete \'$name\'?\nThis action cannot be undone.';
  }

  @override
  String get appExitContent => 'Exit the app?';

  @override
  String get neverUpdated => 'Not fetched yet';

  @override
  String get toastAutoSettingRequired =>
      'Turn on auto price and FX in portfolio settings';

  @override
  String updateFailed(String msg) {
    return 'Couldn\'t get prices: $msg';
  }

  @override
  String updateSuccessCount(int count) {
    return 'Refreshed $count holdings';
  }

  @override
  String get portfolioNotFound => 'Portfolio not found';

  @override
  String get additionalInvestmentHint =>
      'Money to add. Use − to take money out';

  @override
  String get evaluationAmount => 'Evaluation Amount';

  @override
  String weightWarning(String pct) {
    return 'Target weight: $pct (not 100%)';
  }

  @override
  String get labelSettings => 'Settings';

  @override
  String get labelGraph => 'Graph';

  @override
  String get addStock => 'Add Stock';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get cash => 'Cash';

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
  String get editItem => 'Edit holding';

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
  String get notifPermissionDenied =>
      'Turn on notifications for this app in your phone settings';

  @override
  String get targetWeight => 'Target Weight';

  @override
  String get currentWeight => 'Current Weight';

  @override
  String get noPriceInfo => 'No prices yet. Pull to refresh';

  @override
  String get tapToEdit => 'Tap to edit';

  @override
  String get dragToReorder => 'Press and hold, then drag to reorder';

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
  String get disclaimerStartBtn => 'Confirm & Start';

  @override
  String get disclaimerConfirmBtn => 'Confirm';

  @override
  String get searchHint => 'Enter name or ticker';

  @override
  String get avgCost => 'Avg. Cost';

  @override
  String get profitLoss => 'P&L';

  @override
  String get currentPrice => 'Current Price';

  @override
  String get unitKRW => 'KRW';

  @override
  String get unitShares => 'shares';

  @override
  String get settings => 'Settings';

  @override
  String get baseCurrency => 'Base Currency';

  @override
  String get currencyKRW => 'KRW (₩)';

  @override
  String get currencyUSD => 'USD (\$)';

  @override
  String get tradingFee => 'Trading Fee';

  @override
  String get includeFee => 'Include Fee';

  @override
  String get feeRate => 'Fee Rate';

  @override
  String get exchangeRateSetting => 'Exchange Rate';

  @override
  String get exchangeRateInput => 'Rate (1 USD)';

  @override
  String get stockPriceSetting => 'Prices';

  @override
  String get language => 'Language';

  @override
  String get portfolioAddBtn => 'Add Portfolio';

  @override
  String get holdingsSection => 'Holdings';

  @override
  String get cashExcluded => 'cash excl. from weights';

  @override
  String get cashIncluded => 'incl. cash';

  @override
  String itemCountLabel(int count) {
    return '$count stocks';
  }

  @override
  String get notice => 'Notice';

  @override
  String get dayChange => 'Day Change';

  @override
  String get disclaimerAgreeCheckbox =>
      'I have read and agree to all of the above.';

  @override
  String get validationNonNegative => 'Enter 0 or more';

  @override
  String get validationPositive => 'Enter more than 0';

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
  String get backupData => 'Backup';

  @override
  String get restoreData => 'Restore';

  @override
  String get noMatchingTransactions => 'No transactions match';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get filterByItem => 'Item';

  @override
  String get backupNever => 'Never';

  @override
  String get backupToday => 'Today';

  @override
  String get backupYesterday => 'Yesterday';

  @override
  String backupDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String backupMonthsAgo(int months) {
    return '$months months ago';
  }

  @override
  String backupYearsAgo(int years) {
    return '$years years ago';
  }

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
    return 'Restored $count portfolios';
  }

  @override
  String get restoreFailed => 'That\'s not a valid backup file';

  @override
  String get notifReminder => 'Rebalancing Reminders';

  @override
  String get notifEnableDesc => 'Periodic rebalancing reminders';

  @override
  String get notifEnableHint =>
      'We\'ll send you a reminder at the set interval';

  @override
  String get purchaseDateLabel => 'Purchase Date';

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
  String settlementWeekNum(int week) {
    return 'Week $week';
  }

  @override
  String settlementQuarterNum(int q) {
    return 'Q$q';
  }

  @override
  String settlementYearLabel(int year) {
    return '$year';
  }

  @override
  String get excelImportTitle => 'Upload Transactions';

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
  String get excelImportNothingAdded => 'No transactions were added';

  @override
  String get settlementNotifHeader => 'Settlement Reminders';

  @override
  String get rebalancingThresholdLabel => 'Rebalancing Threshold';

  @override
  String get rebalancingThresholdHint =>
      'No trade recommended below this deviation';

  @override
  String get fractionalTrading => 'Fractional Shares';

  @override
  String get maxDriftAfter => 'Max drift after';

  @override
  String planMustRunAll(int count) {
    return 'If you place all $count orders';
  }

  @override
  String allItemsInRange(int count) {
    return 'All $count holdings are within tolerance.';
  }

  @override
  String togetherNTrades(int count) {
    return '$count trades together';
  }

  @override
  String get uncheckToRecalc => 'Uncheck to recalculate';

  @override
  String cashLedgerTitle(int count) {
    return '$count buys share one cash balance';
  }

  @override
  String get sellProceeds => 'Sale proceeds';

  @override
  String buyCostN(int count) {
    return 'Purchases ($count)';
  }

  @override
  String get cashCheckAtBroker =>
      'Copy the balance from your broker. The app does not calculate it for you.';

  @override
  String get cashInWeightTitle => 'Count toward weights';

  @override
  String get cashInWeightOn =>
      'Cash gets a target weight and takes part in rebalancing.';

  @override
  String get cashInWeightOff =>
      'Excluded from weights, and never spent when rebalancing — use «Add cash» in the plan to spend it.';

  @override
  String get cashCheckAfterTrade =>
      'Cash is not calculated for you. Check your broker after the fills and update it.';

  @override
  String get cashAfterAdjust => 'Cash after adjusting';

  @override
  String get cashSharedNote =>
      'The buys draw on the same cash — computing them separately does not add up.';

  @override
  String get sellFirstNote =>
      'Sell first — foreign holdings can take a day or two if FX conversion is needed.';

  @override
  String recordNTransactions(int count) {
    return 'Record $count trades';
  }

  @override
  String get shareProposal => 'Share proposal';

  @override
  String driftedTogether(int count) {
    return '$count drifted holdings together';
  }

  @override
  String selectedExcluded(int sel, int exc) {
    return '$sel selected · $exc excluded';
  }

  @override
  String nOutOfRange(int count) {
    return '$count left';
  }

  @override
  String excludedOnlyOutside(String name) {
    return 'Only the excluded $name is out of range';
  }

  @override
  String whereToSendShare(String name, String amount) {
    return 'Where should $name\'s $amount go?';
  }

  @override
  String excludedNItems(int count) {
    return 'the $count excluded';
  }

  @override
  String get toRemainingItems => 'To the other holdings';

  @override
  String get keepInCash => 'Leave it in cash';

  @override
  String wouldExceedBy(String value) {
    return 'Goes out of range at $value';
  }

  @override
  String get recalculated => 'recalculated';

  @override
  String keptAsIsDrift(String weight, String drift) {
    return '$weight unchanged · $drift';
  }

  @override
  String recordNTradesTitle(int count) {
    return 'Record $count trades';
  }

  @override
  String get fromProposal => 'from the proposal';

  @override
  String appliedToAllN(int count) {
    return 'Applies to all $count';
  }

  @override
  String commissionAutoSum(String rate, int count) {
    return 'Commission $rate% auto · $count trades';
  }

  @override
  String get followsPortfolioSettings =>
      'Commission and cash follow this portfolio\'s settings.';

  @override
  String get priceIsProposalNote =>
      'Prices are the current prices at proposal time — correct them to your fills so the next adjustment is accurate.';

  @override
  String recordNButton(int count) {
    return 'Record $count';
  }

  @override
  String fxConverted(String rate, String amount) {
    return 'FX $rate · converts to $amount';
  }

  @override
  String get importStep1 => '1 / 2 · Pick a file';

  @override
  String importStep2(String file) {
    return '2 / 2 · $file';
  }

  @override
  String get targetPortfolio => 'Import into';

  @override
  String get uploadHow => 'How to upload';

  @override
  String get downloadTemplateTitle => 'Download the template';

  @override
  String get downloadTemplateDesc => 'XLSX · copying into it always works';

  @override
  String get brokerFileOk =>
      'You can upload your broker\'s own export as-is — column names like date, item, side, quantity and price are detected automatically.';

  @override
  String get pickFile => 'Pick a file';

  @override
  String get pickFileDesc => 'CSV · XLSX · up to 5MB';

  @override
  String get requiredColumns => 'Columns the file needs';

  @override
  String get requiredColumnsList => 'Date · Item · Buy/Sell · Quantity · Price';

  @override
  String get toImportLabel => 'Trades to import';

  @override
  String importCountOf(int ready, int total) {
    return '$ready / $total';
  }

  @override
  String importSummaryLine(String range, int items, int buy, int sell) {
    return '$range · $items items · $buy buys · $sell sells';
  }

  @override
  String get itemNotFound => 'Item not found';

  @override
  String get linkAction => 'Link';

  @override
  String get alreadyExists => 'Already recorded';

  @override
  String get skippedShort => 'skipped';

  @override
  String get unreadableRows => 'Rows we could not read';

  @override
  String get previewTitle => 'Preview';

  @override
  String newestNItems(int count) {
    return '$count, newest first';
  }

  @override
  String importNButton(int count) {
    return 'Import $count';
  }

  @override
  String get nothingToImport => 'Nothing to import';

  @override
  String get linkItemTitle => 'Link item';

  @override
  String linkItemDesc(String label, int count) {
    return 'Which holding should $count $label trades go to?';
  }

  @override
  String get createNewItem => 'Create as a new holding';

  @override
  String nRowsShort(int count) {
    return '$count';
  }

  @override
  String get firstRunSubtitle => 'You can change this later, or mix them.';

  @override
  String get firstRunUploadTitle => 'Upload a transaction file';

  @override
  String get firstRunNeedsPc => 'needs a PC';

  @override
  String get firstRunUploadDesc =>
      'If you can export a transaction file from your broker, dozens of trades come in at once.';

  @override
  String get firstRunUploadCta => 'Start from a file';

  @override
  String get firstRunRecordTitle => 'Record trades yourself';

  @override
  String get firstRunRecommended => 'recommended';

  @override
  String get firstRunRecordDesc =>
      'Recording buys and sells with quantity, price and date gives you period P&L in the Settlement tab.';

  @override
  String get firstRunRecordCta => 'Start by recording';

  @override
  String get firstRunQuickTitle => 'Just current holdings';

  @override
  String get firstRunQuickDesc =>
      'Enter what you hold now and your average price. Assets and rebalancing work the same, but the Settlement tab\'s period P&L will not.';

  @override
  String get firstRunQuickCta => 'Enter holdings only';

  @override
  String get hintThenUpload => 'You\'ll go straight to uploading a file.';

  @override
  String get createAndUpload => 'Create and upload';

  @override
  String get sortManual => 'Manual';

  @override
  String get sortByValue => 'By value';

  @override
  String get sortByReturn => 'By return';

  @override
  String get sortManualNote =>
      'Once you arrange them yourself, the order stays even when values change.';

  @override
  String get rename => 'Rename';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get copySuffix => '(copy)';

  @override
  String get feeLabel => 'Fee';

  @override
  String commissionAutoRate(String rate) {
    return '$rate% commission applied automatically';
  }

  @override
  String get noTransactionsNote =>
      'Holdings entered directly, without any transactions';

  @override
  String weightSumNotice(String pct) {
    return 'Target weights add up to $pct. They need to total 100% before an adjustment plan can be calculated.';
  }

  @override
  String get fixTargetWeights => 'Set target weights';

  @override
  String get needMoreItems => 'Add another holding before you can rebalance';

  @override
  String itemAdded(String name) {
    return 'Added $name';
  }

  @override
  String get createPortfolioCta => 'Create a portfolio';

  @override
  String partialSettlement(int count) {
    return 'Not fully loaded yet · $count holdings missing';
  }

  @override
  String get notifSystemOff => 'Notifications are off for this app';

  @override
  String get notifSystemOffHint =>
      'Turn them on for the settings below to work';

  @override
  String get notifOpenSettings => 'Open settings';

  @override
  String get notifPermissionTitle => 'Notification permission needed';

  @override
  String get notifPermissionBody =>
      'Turn on notifications for this app in your phone settings.';

  @override
  String get notifFrequencyLabel => 'Repeat';

  @override
  String get notifWeekdayLabel => 'Day';

  @override
  String get notifDayLabel => 'Date';

  @override
  String get notifTimeLabel => 'Time';

  @override
  String get notifEveryWeek => 'Weekly';

  @override
  String get notifEveryMonth => 'Monthly';

  @override
  String notifDayOfMonth(int day) {
    return 'Day $day';
  }

  @override
  String get notifDayCapHint => 'Some months don\'t have days 29-31';

  @override
  String get settlementNotifTime => 'Reminder time';

  @override
  String get settlementNotifTimeHint => 'Applies to all settlement reminders';
}
