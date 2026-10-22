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
  List<String> _unreadable = const [];

  /// 고른 줄 — 줄의 순번.
  final _picked = <int>{};

  bool _busy = false;
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
        SizedBox(
          width: double.infinity,
          height: 62,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _pick(pf),
            style: ElevatedButton.styleFrom(
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
                    Text(l10n.holdingsReading(_done, _total),
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
    if (!mounted) return;

    final rows = error == null
        ? buildHoldingRows(shots, pf, stocks)
        : const <HoldingRow>[];
    if (error == null && rows.isEmpty) error = l10n.holdingsNoneFound;

    if (error != null) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() {
      _busy = false;
      _rows = rows;
      _shotCount = paths.length;
      _skippedShots = shots.where((s) => s.notHoldingsScreen).length;
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
        .where((i) => rows[i].existing == null && rows[i].issue == null)
        .toList();
    final check = idx
        .where((i) => rows[i].existing == null && rows[i].issue != null)
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
        if (_unreadable.isNotEmpty) ...[
          const SizedBox(height: 9),
          _note(context, Icons.error_outline,
              l10n.holdingsUnreadable(_unreadable.join(' · ')),
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
    final issue = r.issue;
    final picked = _picked.contains(i);
    final qty = formatShares(r.scan.qty);

    String? issueText;
    switch (issue) {
      case HoldingIssue.numbersOff:
        issueText = l10n.issueNumbersOff;
      case HoldingIssue.nameGuessed:
        issueText = l10n.issueNameGuessed(r.scan.name);
      case HoldingIssue.nameAmbiguous:
        issueText = l10n.issueNameAmbiguous;
      case HoldingIssue.notFound:
        issueText = l10n.issueNotFound;
      case HoldingIssue.foreign:
        issueText = l10n.issueForeign;
      case null:
        issueText = null;
    }

    Widget? trailing;
    if (r.existing != null) {
      final same = r.sameQty == true;
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: same ? context.subtleFill : context.warningBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
            same
                ? l10n.holdingsSameQty
                : l10n.holdingsQtyDiff(
                    formatShares(r.existing!.shares), qty),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: same ? context.textSecondary : context.warningText)),
      );
    }

    final canPick = r.addable;
    final ambiguous = issue == HoldingIssue.nameAmbiguous;
    VoidCallback? onTap;
    if (ambiguous) {
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
                  ambiguous
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
            Text(l10n.holdingsQtyLine(qty, fmtMoney(r.scan.value, 'KRW')),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
            // 있는 종목도 검산이 틀리면 알린다 — 「차이」가 잘못 읽은 탓일 수 있다
            if (issueText != null) ...[
              const SizedBox(height: 3),
              Text(issueText,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: context.warningText)),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ]),
    );
    if (onTap == null) return row;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }

  /// 그렇게 시작하는 종목이 여럿일 때 — 후보 중에서 고른다.
  Future<void> _chooseStock(BuildContext context, Portfolio pf,
      List<HoldingRow> rows, int i) async {
    final l10n = context.l10n;
    final r = rows[i];
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
              child: Text(l10n.issueNameGuessed(r.scan.name),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ctx.textSecondary)),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45),
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final c in r.lookup.candidates)
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, c),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: ctx.dividerColor)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(c.name,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: ctx.textPrimary),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(c.ticker,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: ctx.textTertiary)),
                        ]),
                      ),
                    ),
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
      if (updated.addable) _picked.add(i);
    });
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
        kind: UndoBatch.kindImport,
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
