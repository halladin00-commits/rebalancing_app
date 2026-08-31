import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../services/excel_import_service.dart';
import '../services/import_plan.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';
import '../utils/share_format.dart';

/// 거래내역 업로드 (시안 v17b·v17c).
///
/// 두 단계다. 1단계는 파일을 고르고, 2단계는 **가져오기 전에 무엇이 들어가고
/// 무엇이 왜 빠지는지 보여준다.**
///
/// 가장 위험한 건 조용히 잘못 들어가는 것이다. 그래서 `38 / 42`를 먼저 크게
/// 말하고, 빠진 4건의 이유를 줄마다 하나씩 처리하게 했다.
class TransactionImportScreen extends StatefulWidget {
  final String portfolioId;
  const TransactionImportScreen({super.key, required this.portfolioId});

  @override
  State<TransactionImportScreen> createState() =>
      _TransactionImportScreenState();
}

class _TransactionImportScreenState extends State<TransactionImportScreen> {
  ImportPlan? _plan;
  bool _busy = false;

  /// 못 찾은 종목을 어디에 붙일지. 종목키 → itemId (또는 새로 만들기 표시).
  final _links = <String, String>{};

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  @override
  Widget build(BuildContext context) {
    final pf = context.watch<PortfolioProvider>().getPortfolio(widget.portfolioId);
    if (pf == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Center(child: Text(context.l10n.portfolioNotFound)),
      );
    }
    final plan = _plan;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _buildHeader(context, plan),
        Expanded(
          child: plan == null
              ? _buildPickStep(context, pf)
              : _buildReviewStep(context, pf, plan),
        ),
        if (plan != null) _buildCta(context, pf, plan),
      ]),
    );
  }

  // ── 헤더 ──

  Widget _buildHeader(BuildContext context, ImportPlan? plan) {
    final l10n = context.l10n;
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
          // 큰 글씨 설정(접근성)에서 제목+부제가 52px를 넘는다. 고정이면
          // `BOTTOM OVERFLOWED`가 뜬다 — 최소 높이만 정하고 늘어나게 둔다.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(children: [
              IconButton(
                tooltip: context.l10n.a11yClose,
              icon: Icon(plan == null ? Icons.close : Icons.arrow_back,
                    color: Colors.white, size: 22),
                onPressed: () {
                  // 2단계에서 뒤로 가면 고른 파일을 버리고 처음으로 돌아간다
                  if (plan != null) {
                    setState(() {
                      _plan = null;
                      _links.clear();
                    });
                  } else {
                    Navigator.pop(context, false);
                  }
                },
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.excelImportTitle,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white)),
                    const SizedBox(height: 1),
                    Text(
                        plan == null
                            ? l10n.importStep1
                            : l10n.importStep2(plan.fileName),
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

  // ── 1단계: 파일 고르기 ──

  Widget _buildPickStep(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      children: [
        _card(
          context,
          child: Row(children: [
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.targetPortfolio,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary)),
                const SizedBox(height: 4),
                Text(pf.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.textPrimary)),
              ]),
            ),
            Text(l10n.nRowsShort(pf.items.where((i) => !i.isCash).length),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary)),
          ]),
        ),
        const SizedBox(height: 13),
        _sectionTitle(context, l10n.uploadHow),
        const SizedBox(height: 7),
        _card(
          context,
          onTap: () => ExcelImportService.downloadTemplate(_isKo),
          child: Row(children: [
            Icon(Icons.download_outlined, size: 20, color: context.brand),
            const SizedBox(width: 11),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.downloadTemplateTitle,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
                const SizedBox(height: 3),
                Text(l10n.downloadTemplateDesc,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary)),
              ]),
            ),
            Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
          ]),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          decoration: BoxDecoration(
            color: context.subtleFill,
            borderRadius: BorderRadius.circular(DS.listCardRadius),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome, size: 16, color: context.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.brokerFileOk,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                      color: context.textSecondary)),
            ),
          ]),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          height: 62,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _pick(pf),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand,
              foregroundColor: Colors.white,
              disabledBackgroundColor: context.disabledFill,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.buttonRadius)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.upload_file, size: 18),
                            const SizedBox(width: 7),
                            Text(l10n.pickFile,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800)),
                          ]),
                      const SizedBox(height: 2),
                      Text(l10n.pickFileDesc,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 13),
        _sectionTitle(context, l10n.requiredColumns),
        const SizedBox(height: 7),
        _card(
          context,
          child: Text(l10n.requiredColumnsList,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: context.textSecondary)),
        ),
      ],
    );
  }

  Future<void> _pick(Portfolio pf) async {
    setState(() => _busy = true);
    final plan = await ExcelImportService.analyze(pf, _isKo);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _plan = plan;
    });
  }

  // ── 2단계: 가져오기 전 확인 ──

  Widget _buildReviewStep(BuildContext context, Portfolio pf, ImportPlan plan) {
    final l10n = context.l10n;
    final linked = plan.withLinks(_displayLinks());
    final range = linked.dateRange;

    String two(int n) => n.toString().padLeft(2, '0');
    final rangeText = range == null
        ? ''
        : '${range.from.year}.${two(range.from.month)}.${two(range.from.day)}'
            ' ~ ${two(range.to.month)}.${two(range.to.day)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      children: [
        // 결론 먼저 — 42건 중 38건이 들어간다
        _card(
          context,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.toImportLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textStrong)),
            const SizedBox(height: 6),
            Text(l10n.importCountOf(linked.importCount, linked.totalRows),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: linked.importCount > 0
                        ? context.textPrimary
                        : context.textTertiary)),
            if (range != null) ...[
              const SizedBox(height: 6),
              Text(
                  l10n.importSummaryLine(rangeText, linked.itemCount,
                      linked.buyCount, linked.sellCount),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: context.textSecondary)),
            ],
          ]),
        ),
        // 빠진 것들 — 줄마다 이유 하나씩
        if (linked.unmatchedItems.isNotEmpty) ...[
          const SizedBox(height: 9),
          _problemRow(
            context,
            icon: Icons.help_outline,
            title: l10n.itemNotFound,
            detail: '${linked.unmatchedItems.map((u) => u.label).join(' · ')}'
                ' · ${l10n.nRowsShort(linked.unlinked.length)}',
            action: l10n.linkAction,
            onTap: () => _openLinkSheet(context, pf, linked),
          ),
        ],
        if (plan.duplicates.isNotEmpty) ...[
          const SizedBox(height: 9),
          _problemRow(
            context,
            icon: Icons.content_copy_outlined,
            title: l10n.alreadyExists,
            detail: '${_firstDup(plan)} · '
                '${l10n.nRowsShort(plan.duplicates.length)} · ${l10n.skippedShort}',
          ),
        ],
        if (plan.skipped.isNotEmpty) ...[
          const SizedBox(height: 9),
          _problemRow(
            context,
            icon: Icons.error_outline,
            title: l10n.unreadableRows,
            detail: plan.skipped.take(2).map((s) => s.reason).join(' · '),
            danger: true,
          ),
        ],
        // 미리보기
        if (linked.ready.isNotEmpty) ...[
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(l10n.previewTitle,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: context.textPrimary)),
                const Spacer(),
                Text(l10n.newestNItems(linked.ready.length),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(DS.listCardRadius),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D16130F),
                    blurRadius: 2,
                    offset: Offset(0, 1)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final r in linked.previewNewestFirst.take(20))
                _previewRow(context, pf, r),
            ]),
          ),
        ],
      ],
    );
  }

  String _firstDup(ImportPlan plan) {
    final d = plan.duplicates.first;
    return '${d.date.month.toString().padLeft(2, '0')}'
        '.${d.date.day.toString().padLeft(2, '0')} '
        '${d.name.isNotEmpty ? d.name : d.ticker}';
  }

  /// 화면에 보여줄 때 쓸 연결 지도.
  ///
  /// `새 종목으로 만들기`는 아직 종목이 없어 진짜 id가 없다. 그렇다고 빼 두면
  /// **버튼은 6건인데 위에는 4건**이라고 적히는 일이 생긴다. 임시 id를 줘서
  /// 건수·미리보기·종목 수가 모두 같은 것을 말하게 한다.
  /// 실제 생성은 `가져오기`를 누른 뒤 commit이 한다.
  Map<String, String> _displayLinks() => {
        for (final e in _links.entries)
          e.key: e.value == createNewItemMarker
              ? '$createNewItemMarker:${e.key}'
              : e.value
      };

  Widget _previewRow(BuildContext context, Portfolio pf, ParsedRow r) {
    final l10n = context.l10n;
    final amount = r.qty * r.price;
    final cur = r.market == 'US' ? 'USD' : 'KRW';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.dividerColor)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          padding: const EdgeInsets.symmetric(vertical: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: r.isBuy ? context.pnlUpTint : context.pnlDownTint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(r.isBuy ? l10n.buy : l10n.sell,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: r.isBuy ? context.brandOnLight : context.danger)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name.isNotEmpty ? r.name : r.ticker,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
                '${r.date.month.toString().padLeft(2, '0')}'
                '.${r.date.day.toString().padLeft(2, '0')} · '
                '${fmtPrice(r.price, r.market)} · '
                '${formatShares(r.qty)}${l10n.unitShares}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(fmtMoney(amount, cur),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: context.textPrimary)),
      ]),
    );
  }

  // ── 종목 연결 ──

  Future<void> _openLinkSheet(
      BuildContext context, Portfolio pf, ImportPlan linked) async {
    final l10n = context.l10n;
    final target = linked.unmatchedItems.first;
    final choices = pf.items.where((i) => !i.isCash).toList();

    final picked = await showModalBottomSheet<String>(
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
              child: Text(l10n.linkItemTitle,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: ctx.textPrimary)),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.linkItemDesc(target.label, target.rowCount),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: ctx.textSecondary)),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45),
              child: SingleChildScrollView(
                child: Column(children: [
                  _linkOption(ctx, l10n.createNewItem,
                      subtitle: target.name.isNotEmpty
                          ? target.name
                          : target.ticker,
                      isNew: true,
                      onTap: () => Navigator.pop(ctx, createNewItemMarker)),
                  for (final i in choices)
                    _linkOption(ctx, i.name,
                        subtitle: i.ticker,
                        onTap: () => Navigator.pop(ctx, i.id)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _links[target.label] = picked);
  }

  Widget _linkOption(BuildContext context, String title,
      {String? subtitle, bool isNew = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.dividerColor)),
        ),
        child: Row(children: [
          Icon(isNew ? Icons.add_circle_outline : Icons.link,
              size: 18, color: isNew ? context.brand : context.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary)),
        ]),
      ),
    );
  }

  // ── 확정 ──

  Widget _buildCta(BuildContext context, Portfolio pf, ImportPlan plan) {
    final l10n = context.l10n;
    final count = plan.withLinks(_displayLinks()).importCount;

    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (_busy || count == 0) ? null : () => _commit(pf, plan),
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
              count == 0 ? l10n.nothingToImport : l10n.importNButton(count),
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Future<void> _commit(Portfolio pf, ImportPlan plan) async {
    setState(() => _busy = true);
    final provider = context.read<PortfolioProvider>();
    final result = await ExcelImportService.commit(plan, pf, provider,
        links: Map.of(_links));
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context, result);
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

  Widget _card(BuildContext context,
      {required Widget child, VoidCallback? onTap}) {
    final box = Container(
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
    if (onTap == null) return box;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }

  /// 빠진 이유 한 줄. 손볼 수 있는 것만 오른쪽에 동작을 붙인다.
  Widget _problemRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    String? action,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final row = Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: danger ? context.pnlDownTint : context.subtleFill,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
      ),
      child: Row(children: [
        Icon(icon,
            size: 17, color: danger ? context.danger : context.textSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: danger ? context.danger : context.textPrimary)),
            const SizedBox(height: 3),
            Text(detail,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: context.textSecondary)),
          ]),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          Text(action,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.brand)),
          Icon(Icons.chevron_right, size: 18, color: context.brand),
        ],
      ]),
    );
    if (onTap == null) return row;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }
}
