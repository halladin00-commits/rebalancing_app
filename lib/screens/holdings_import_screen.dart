import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../services/holdings_ocr_service.dart';
import '../services/holdings_scan.dart';
import '../services/stock_search_service.dart';
import '../services/undo_service.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';
import '../utils/share_format.dart';

/// 잔고 캡처 불러오기를 **눈에 띄는 자리**(첫 화면·종목 추가)에 내놓을까.
///
/// 처음에는 한국 증권사 앱만 읽어서 한국어 화면에서만 내놨다. 2026-11
/// 영어 앱(미국 증권사)도 읽게 되어 언어를 가리지 않는다.
bool holdingsCaptureOffered(BuildContext context) => true;

/// 잔고 캡처로 불러오기.
///
/// 거래내역 업로드와 같은 두 단계다 — 캡처를 고르고, **넣기 전에 무엇이
/// 들어가는지 보여 준다.** 글자를 읽어서 넣는 것이라, 조용히 잘못 들어가는
/// 것이 가장 위험하다. 그래서
///
/// - 새 종목만 넣는다. 이미 있는 종목은 **차이만 보여 주고 건드리지 않는다**
///   (거래 내역이 수량의 근거다 — 캡처로 덮어쓰면 그 근거가 사라진다)
/// - 수량 × 현재가 = 평가금액이 맞지 않거나 이름을 짐작한 종목은 골라 두지
///   않는다. 사용자가 보고 고른다
class HoldingsImportScreen extends StatefulWidget {
  final String portfolioId;
  const HoldingsImportScreen({super.key, required this.portfolioId});

  @override
  State<HoldingsImportScreen> createState() => _HoldingsImportScreenState();
}

class _HoldingsImportScreenState extends State<HoldingsImportScreen> {
  List<HoldingRow>? _rows;
  int _shotCount = 0;
  int _skippedShots = 0;
  int _noQtyShots = 0;
  int _foreignSkipped = 0;
  List<String> _unreadable = const [];

  /// 고른 줄 — 줄의 순번.
  final _picked = <int>{};

  bool _busy = false;
  bool _checkingPrices = false;
  bool _priceCheckFailed = false;
  int _done = 0;
  int _total = 0;

  @override
  Widget build(BuildContext context) {
    final pf =
        context.watch<PortfolioProvider>().getPortfolio(widget.portfolioId);
    if (pf == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Center(child: Text(context.l10n.portfolioNotFound)),
      );
    }
    final rows = _rows;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: rows == null
              ? _buildPickStep(context, pf)
              : _buildReviewStep(context, pf, rows),
        ),
        if (rows != null) _buildCta(context, pf, rows),
      ]),
    );
  }

  // ── 헤더 ──

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    final reviewing = _rows != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: context.appBarBg,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(children: [
              IconButton(
                tooltip: l10n.a11yClose,
                icon: Icon(reviewing ? Icons.arrow_back : Icons.close,
                    color: Colors.white, size: 22),
                onPressed: () {
                  // 2단계에서 뒤로 가면 읽은 것을 버리고 처음으로
                  if (reviewing) {
                    setState(() {
                      _rows = null;
                      _picked.clear();
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.holdingsImportTitle,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white)),
                    const SizedBox(height: 1),
                    Text(
                        reviewing
                            ? l10n.holdingsStep2(_shotCount)
                            : l10n.holdingsStep1,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.onBrandSecondary),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 1단계: 캡처 고르기 ──

  Widget _buildPickStep(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      children: [
        _sectionTitle(context, l10n.holdingsHowTitle),
        const SizedBox(height: 7),
        _card(
          context,
          child: Text(l10n.holdingsHowBody,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: context.textSecondary)),
        ),
        const SizedBox(height: 9),
        _note(context, Icons.lock_outline, l10n.holdingsPrivacyNote),
        const SizedBox(height: 9),
        _note(context, Icons.info_outline, l10n.holdingsSupportNote),
        const SizedBox(height: 13),
        // 높이를 못박지 않는다 — 큰 글씨에서 둘째 줄이 잘렸다. 최소만 정한다.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _pick(pf),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(62),
              padding: const EdgeInsets.symmetric(vertical: 10),
              backgroundColor: context.brand,
              foregroundColor: Colors.white,
              disabledBackgroundColor: context.disabledFill,
              disabledForegroundColor: context.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.buttonRadius)),
            ),
            child: _busy
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: context.textSecondary)),
                    const SizedBox(width: 10),
                    Text(
                        _checkingPrices
                            ? l10n.holdingsCheckingPrices
                            : l10n.holdingsReading(_done, _total),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ])
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 18),
                            const SizedBox(width: 7),
                            Text(l10n.pickScreenshots,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800)),
                          ]),
                      const SizedBox(height: 2),
                      Text(l10n.pickScreenshotsDesc,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(Portfolio pf) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final paths = await HoldingsOcrService.pickScreenshots();
    if (paths.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _done = 0;
      _total = paths.length;
    });

    String? error;
    List<HoldingsShot> shots = const [];
    try {
      shots = await HoldingsOcrService.read(paths,
          onProgress: (n) => mounted ? setState(() => _done = n) : null);
    } on OcrModelNotReady {
      error = l10n.holdingsModelNotReady;
    } catch (_) {
      error = l10n.holdingsReadFailed;
    }
    final stocks = error == null
        ? await StockSearchService.krStocks()
        : const <StockSearchResult>[];
    // 달러로 적힌 줄이 있을 때만 미국 종목 목록을 편다 (만 개가 넘는다)
    final usStocks = error == null &&
            shots.any((s) => s.holdings.any((h) => h.currency == 'USD'))
        ? await StockSearchService.usStocks()
        : const <StockSearchResult>[];
    if (!mounted) return;

    var rows = error == null
        ? buildHoldingRows(shots, pf, stocks, usStocks: usStocks)
        : const <HoldingRow>[];
    // 해외 종목은 넣지 못한다. 줄마다 「못 불러와요」를 달아 늘어놓으면
    // 해외 주식이 많은 사람은 넣을 수 있는 종목을 그 사이에서 찾아야 한다
    // (토스 캡처 한 장에 열두 줄이 그랬다) — 빼고 몇 개였는지만 알린다.
    final foreign = rows.where((r) => r.scan.foreign).length;
    rows = rows.where((r) => !r.scan.foreign).toList();
    if (error == null && rows.isEmpty && foreign > 0) {
      error = l10n.holdingsForeignSkipped(foreign);
    }
    if (error == null && rows.isEmpty) {
      // 잔고 표는 있는데 수량 칸이 없는 화면이었으면 그렇다고 말한다 —
      // 「잔고 화면인지 확인」이라고 하면 잔고 화면을 찍은 사람은 막힌다
      final noQty = shots.where((s) => s.noQuantity).length;
      error = noQty > 0
          ? l10n.holdingsNoQuantity(noQty)
          : l10n.holdingsNoneFound;
    }

    if (error != null) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // 이름으로 찾은 종목이 맞는지 **시세로 한 번 더** 대 본다. 수량 검산은
    // 숫자를 잘못 읽은 것만 잡는다 — 이름이 잘려 다른 종목으로 찾아진 것은
    // 숫자가 멀쩡해서 못 잡는다.
    setState(() => _checkingPrices = true);
    // 목록에 없는 티커(뮤추얼펀드 등)도 함께 묻는다 — 시세가 오면 있는 종목이다
    final tickers = {...priceTickers(rows), ...unlistedUsTickers(rows)};
    final live = tickers.isEmpty
        ? const <String, double>{}
        : await HoldingsOcrService.livePrices(tickers);
    if (!mounted) return;
    rows = adoptQuotedTickers(rows, live, pf);
    rows = [for (final r in rows) r.withLive(live)];

    setState(() {
      _busy = false;
      _checkingPrices = false;
      _priceCheckFailed = tickers.isNotEmpty && live.isEmpty;
      _rows = rows;
      _shotCount = paths.length;
      _skippedShots = shots.where((s) => s.notHoldingsScreen).length;
      _noQtyShots =
          shots.where((s) => s.noQuantity && s.holdings.isEmpty).length;
      _foreignSkipped = foreign;
      _unreadable = [for (final s in shots) ...s.unreadable];
      _picked
        ..clear()
        ..addAll([
          for (var i = 0; i < rows.length; i++)
            if (rows[i].preselected) i
        ]);
    });
  }

  // ── 2단계: 넣기 전 확인 ──

  Widget _buildReviewStep(
      BuildContext context, Portfolio pf, List<HoldingRow> rows) {
    final l10n = context.l10n;
    final idx = List.generate(rows.length, (i) => i);
    final fresh = idx
        .where((i) => rows[i].existing == null && rows[i].issues.isEmpty)
        .toList();
    final check = idx
        .where((i) => rows[i].existing == null && rows[i].issues.isNotEmpty)
        .toList();
    final existing = idx.where((i) => rows[i].existing != null).toList();
    final same = existing.where((i) => rows[i].sameQty == true).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      children: [
        // 결론 먼저
        _card(
          context,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.holdingsSummaryTitle,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textStrong)),
            const SizedBox(height: 6),
            Text(l10n.holdingsSummaryCount(rows.length),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: context.textPrimary)),
            const SizedBox(height: 6),
            Text(
                l10n.holdingsSummaryLine(fresh.length + check.length, same,
                    existing.length - same),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: context.textSecondary)),
          ]),
        ),
        if (_skippedShots > 0) ...[
          const SizedBox(height: 9),
          _note(context, Icons.image_not_supported_outlined,
              l10n.holdingsSkippedShots(_skippedShots)),
        ],
        if (_noQtyShots > 0) ...[
          const SizedBox(height: 9),
          _note(context, Icons.image_not_supported_outlined,
              l10n.holdingsNoQuantity(_noQtyShots),
              warn: true),
        ],
        if (_foreignSkipped > 0) ...[
          const SizedBox(height: 9),
          _note(context, Icons.public_off_outlined,
              l10n.holdingsForeignSkipped(_foreignSkipped)),
        ],
        if (_unreadable.isNotEmpty) ...[
          const SizedBox(height: 9),
          _note(
              context,
              Icons.error_outline,
              l10n.holdingsUnreadable(_unreadable
                  .map((n) => n.isEmpty ? l10n.holdingsNameUnknown : n)
                  .join(' · ')),
              warn: true),
        ],
        if (_priceCheckFailed) ...[
          const SizedBox(height: 9),
          _note(context, Icons.wifi_off, l10n.holdingsPriceCheckFailed,
              warn: true),
        ],
        if (fresh.isNotEmpty || check.isNotEmpty) ...[
          const SizedBox(height: 9),
          _note(context, Icons.event_outlined, l10n.holdingsBuyNote),
        ],
        if (fresh.isNotEmpty)
          ..._section(context, l10n.holdingsNewSection,
              [for (final i in fresh) _row(context, pf, rows, i)]),
        if (check.isNotEmpty)
          ..._section(context, l10n.holdingsCheckSection,
              [for (final i in check) _row(context, pf, rows, i)]),
        if (existing.isNotEmpty) ...[
          ..._section(context, l10n.holdingsExistingSection,
              [for (final i in existing) _row(context, pf, rows, i)]),
          const SizedBox(height: 9),
          _note(context, Icons.info_outline, l10n.holdingsExistingNote),
        ],
      ],
    );
  }

  List<Widget> _section(
          BuildContext context, String title, List<Widget> children) =>
      [
        const SizedBox(height: 13),
        _sectionTitle(context, title),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(DS.listCardRadius),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ];

  Widget _row(
      BuildContext context, Portfolio pf, List<HoldingRow> rows, int i) {
    final l10n = context.l10n;
    final r = rows[i];
    final picked = _picked.contains(i);
    final qty = formatShares(r.scan.qty);

    String issueText(HoldingIssue issue) => switch (issue) {
          HoldingIssue.foreign => l10n.issueForeign,
          HoldingIssue.notFound => l10n.issueNotFound,
          HoldingIssue.nameAmbiguous => l10n.issueNameAmbiguous,
          HoldingIssue.qtyConflict => l10n.issueQtyConflict(r.conflictQtys
              .map((q) => '${formatShares(q)}${l10n.unitShares}')
              .join(' · ')),
          HoldingIssue.numbersOff => l10n.issueNumbersOff,
          HoldingIssue.numbersUnchecked => l10n.issueNumbersUnchecked,
          HoldingIssue.nameGuessed => l10n.issueNameGuessed(r.scan.name),
          HoldingIssue.priceOff => l10n.issuePriceOff(
              fmtMoney(r.scan.currentPrice, r.scan.currency),
              fmtMoney(r.live[r.stock!.ticker]!, r.scan.currency)),
          HoldingIssue.noPrice => l10n.issueNoPrice,
          HoldingIssue.similarNames => l10n.issueSimilarNames,
        };

    // 있는 종목은 수량만 맞대 본다. 오른쪽 꼬리표로 두면 큰 글씨에서 이름을
    // 밀어내고 넘친다 — 이름 밑 한 줄로 둔다.
    final same = r.sameQty == true;
    final existingLine = r.existing == null || r.conflictQtys.isNotEmpty
        ? null
        : same
            ? l10n.holdingsSameQty
            : l10n.holdingsQtyDiff(formatShares(r.existing!.shares), qty);

    final canPick = r.addable;
    final mustChoose =
        r.existing == null && r.lookup.kind == NameMatch.ambiguous;
    final canChange = r.existing == null && !mustChoose && r.choices.isNotEmpty;
    VoidCallback? onTap;
    if (mustChoose) {
      onTap = () => _chooseStock(context, pf, rows, i);
    } else if (canPick) {
      onTap = () => setState(() => picked ? _picked.remove(i) : _picked.add(i));
    }

    final row = Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.dividerColor)),
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: canPick
              ? Checkbox(
                  value: picked,
                  activeColor: context.brand,
                  onChanged: (_) => onTap?.call(),
                )
              : Icon(
                  mustChoose
                      ? Icons.touch_app_outlined
                      : (r.existing != null
                          ? Icons.inventory_2_outlined
                          : Icons.block),
                  size: 18,
                  color: context.textTertiary),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.displayName,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
                r.value == null
                    ? l10n.holdingsQtyOnly(qty)
                    : l10n.holdingsQtyLine(
                        qty, fmtMoney(r.value!, r.scan.currency)),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
            // 이 값이 그대로 매수 단가로 기록된다 — 넣기 전에 눈으로 본다
            if (r.existing == null && canPick) ...[
              const SizedBox(height: 2),
              Text(
                  r.scan.avgPrice > 0
                      ? l10n.holdingsAvgLine(
                          fmtMoney(r.scan.avgPrice, r.scan.currency))
                      : l10n.holdingsNoAvg,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: r.scan.avgPrice > 0
                          ? context.textSecondary
                          : context.warningText)),
            ],
            if (existingLine != null) ...[
              const SizedBox(height: 3),
              Text(existingLine,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          same ? context.textSecondary : context.warningText)),
            ],
            // 걸리는 것은 전부 적는다. 있는 종목도 검산이 틀리면 알린다 —
            // 「차이」가 잘못 읽은 탓일 수 있다
            for (final issue in r.issues) ...[
              const SizedBox(height: 3),
              Text(issueText(issue),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: context.warningText)),
            ],
            if (canChange) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _chooseStock(context, pf, rows, i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${l10n.holdingsChooseOther} ›',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: context.brand)),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
    if (onTap == null) return row;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }

  /// 후보 중에서 종목을 고른다 — 그렇게 시작하는 종목이 여럿이거나, 이름이
  /// 비슷한 종목이 있을 때.
  ///
  /// 시세가 캡처의 현재가와 가까운 것부터 보여 준다. 다른 줄이 이미 고른
  /// 종목은 못 고르게 한다 — 같은 종목이 둘 생긴다.
  Future<void> _chooseStock(BuildContext context, Portfolio pf,
      List<HoldingRow> rows, int i) async {
    final l10n = context.l10n;
    final r = rows[i];
    final taken = {
      for (var j = 0; j < rows.length; j++)
        if (j != i && rows[j].stock != null) rows[j].stock!.ticker,
    };
    double gap(StockSearchResult c) {
      final p = r.live[c.ticker];
      if (p == null || r.scan.currentPrice <= 0) return double.infinity;
      return (p / r.scan.currentPrice - 1).abs();
    }

    final choices = [...r.choices]..sort((a, b) => gap(a).compareTo(gap(b)));
    final chosen = await showModalBottomSheet<StockSearchResult>(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 16 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: ctx.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.holdingsPickStock,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: ctx.textPrimary)),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '${l10n.issueNameGuessed(r.scan.name)}\n'
                  '${l10n.holdingsShotPrice(fmtMoney(r.scan.currentPrice, r.scan.currency))}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: ctx.textSecondary)),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45),
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final c in choices)
                    _choiceRow(ctx, c,
                        currency: r.scan.currency,
                        price: r.live[c.ticker],
                        near: r.live[c.ticker] != null &&
                            r.nearShot(r.live[c.ticker]!),
                        taken: taken.contains(c.ticker)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      final updated = r.withStock(chosen, findExisting(pf, chosen, chosen.name));
      _rows = [...rows]..[i] = updated;
      if (updated.addable) {
        _picked.add(i);
      } else {
        _picked.remove(i);
      }
    });
  }

  Widget _choiceRow(BuildContext context, StockSearchResult c,
      {double? price,
      required String currency,
      required bool near,
      required bool taken}) {
    final l10n = context.l10n;
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.dividerColor)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: taken ? context.textTertiary : context.textPrimary),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
                [
                  c.ticker,
                  if (price != null) fmtMoney(price, currency),
                  if (taken) l10n.holdingsInList,
                ].join(' · '),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: near ? FontWeight.w800 : FontWeight.w600,
                    color: near && !taken ? context.brand : context.textTertiary)),
          ]),
        ),
      ]),
    );
    if (taken) return row;
    return GestureDetector(
        onTap: () => Navigator.pop(context, c),
        behavior: HitTestBehavior.opaque,
        child: row);
  }

  // ── 확정 ──

  Widget _buildCta(BuildContext context, Portfolio pf, List<HoldingRow> rows) {
    final l10n = context.l10n;
    final count = _picked.where((i) => rows[i].addable).length;
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed:
              (_busy || count == 0) ? null : () => _commit(pf, rows),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: context.disabledFill,
            disabledForegroundColor: context.textDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.buttonRadius)),
          ),
          child: Text(
              count == 0 ? l10n.holdingsNothingToAdd : l10n.holdingsAddN(count),
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Future<void> _commit(Portfolio pf, List<HoldingRow> rows) async {
    setState(() => _busy = true);
    final provider = context.read<PortfolioProvider>();
    final now = DateTime.now();
    final createdIds = <String>[];
    final undoTx = <({String itemId, String txId})>[];
    var seq = 0;
    for (final i in _picked.toList()..sort()) {
      final r = rows[i];
      if (!r.addable) continue;
      final id = '${now.millisecondsSinceEpoch.toRadixString(36)}_s${seq++}';
      final item = newItemFromScan(r, id, now);
      await provider.addItem(pf.id, item);
      createdIds.add(id);
      undoTx.add((itemId: id, txId: item.transactions.single.id));
    }
    // 한 번에 여러 종목이 들어간다 — 잘못 넣었으면 메뉴에서 통째로 되돌린다
    if (createdIds.isNotEmpty) {
      await UndoService.save(UndoBatch(
        portfolioId: pf.id,
        kind: UndoBatch.kindScan,
        at: now.millisecondsSinceEpoch,
        transactions: undoTx,
        createdItemIds: createdIds,
      ));
    }
    if (!mounted) return;
    Navigator.pop(context, createdIds.length);
  }

  // ── 부품 ──

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: context.textPrimary)),
      );

  Widget _card(BuildContext context, {required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: child,
      );

  Widget _note(BuildContext context, IconData icon, String text,
          {bool warn = false}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        decoration: BoxDecoration(
          color: warn ? context.warningBg : context.subtleFill,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon,
              size: 16, color: warn ? context.warningText : context.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                    color:
                        warn ? context.warningText : context.textSecondary)),
          ),
        ]),
      );
}
