import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import '../utils/share_format.dart';
import '../widgets/rebalance_transaction_dialog.dart';

/// 조정 제안 (시안 v18d).
///
/// 이 화면은 **주문을 내지 않는다.** 무엇을 얼마나 사고팔면 목표에 닿는지 보여주고,
/// 실제 체결 후 거래 내역으로 기록하게 한다.
///
/// 시안과 다른 점 하나 — 시안은 추가 입금액을 세그먼트로만 나눠 두었지만,
/// 금액을 받을 곳이 있어야 계산이 되므로 `추가 입금으로` 모드에서 입력칸을 펼친다.
class RebalanceProposalScreen extends StatefulWidget {
  final String portfolioId;
  const RebalanceProposalScreen({super.key, required this.portfolioId});

  @override
  State<RebalanceProposalScreen> createState() =>
      _RebalanceProposalScreenState();
}

class _RebalanceProposalScreenState extends State<RebalanceProposalScreen> {
  late final TextEditingController _investCtl;

  @override
  void initState() {
    super.initState();
    final pf = context.read<PortfolioProvider>().getPortfolio(widget.portfolioId);
    final add = pf?.additionalInvestment ?? 0;
    _investCtl =
        TextEditingController(text: add == 0 ? '' : add.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _investCtl.dispose();
    super.dispose();
  }

  bool get _addMode => (_investCtl.text.trim().isNotEmpty);

  // ── 서식 ──

  String _fmt(double n, String cur) {
    final prefix = n < 0 ? '−' : '';
    final abs = n.abs();
    if (cur == 'USD') return '$prefix\$${abs.toStringAsFixed(2)}';
    return '$prefix₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _pct(double n) => '${n.toStringAsFixed(2)}%';
  String _pp(double n) =>
      '${n >= 0 ? '+' : '−'}${n.abs().toStringAsFixed(2)}%p';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }
        final rb = Rebalancer.calculate(pf);
        final trades = rb == null
            ? <RebalanceItemResult>[]
            : rb.results.where((r) => !r.isCash && r.delta != 0).toList();

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              _buildHeader(context, pf, trades),
              Expanded(
                child: rb == null
                    ? _buildCannotCalculate(context, pf)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                        children: [
                          _buildModeSegment(context, pf),
                          const SizedBox(height: 9),
                          if (trades.isEmpty)
                            _buildNothingToDo(context)
                          else ...[
                            _buildProposalCard(context, pf, rb, trades),
                            const SizedBox(height: 9),
                            _buildRoundingNote(context, pf, rb, trades),
                          ],
                          const SizedBox(height: 9),
                          _buildDisclaimer(context),
                        ],
                      ),
              ),
              if (trades.isNotEmpty) _buildCta(context, pf, rb!),
            ],
          ),
        );
      },
    );
  }

  // ── 헤더 (라운드 없는 딥그린 · 제목 + 부제) ──

  Widget _buildHeader(
      BuildContext context, Portfolio pf, List<RebalanceItemResult> trades) {
    final l10n = context.l10n;
    final buys = trades.where((r) => r.delta > 0).length;
    final sells = trades.where((r) => r.delta < 0).length;
    final parts = <String>[
      if (buys > 0) '${l10n.buy} $buys',
      if (sells > 0) '${l10n.sell} $sells',
    ];

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
          child: SizedBox(
            height: 52,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.proposalTitle,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white)),
                    const SizedBox(height: 1),
                    Text(
                      parts.isEmpty
                          ? pf.name
                          : '${pf.name} · ${parts.join(' · ')}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.onBrandSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
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

  // ── 모드 세그먼트 ──

  Widget _buildModeSegment(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    final add = _addMode;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.trackBg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(children: [
            _segment(context, l10n.modeHoldings, !add, () {
              _investCtl.clear();
              context
                  .read<PortfolioProvider>()
                  .setAdditionalInvestment(pf.id, 0);
              setState(() {});
            }),
            const SizedBox(width: 6),
            _segment(context, l10n.modeAddCash, add, () => setState(() {})),
          ]),
        ),
        if (add) ...[
          const SizedBox(height: 9),
          _buildInvestField(context, pf),
        ] else if (_investCtl.text.isEmpty)
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _segment(
      BuildContext context, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? context.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  color: active ? Colors.white : context.textSecondary)),
        ),
      ),
    );
  }

  /// 시안에는 없지만 금액을 받을 곳이 필요하다 — `추가 입금으로`에서만 펼친다.
  Widget _buildInvestField(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    final sym = pf.currency == 'USD' ? '\$' : '₩';
    return TextField(
      controller: _investCtl,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        prefixText: '$sym ',
        prefixStyle:
            TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600),
        hintText: l10n.additionalInvestmentHint,
        hintStyle: TextStyle(color: context.textHint),
        filled: true,
        fillColor: context.cardBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DS.tileRadius),
            borderSide: BorderSide(color: context.borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DS.tileRadius),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DS.tileRadius),
            borderSide: BorderSide(color: context.brand, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v) ?? 0;
        context.read<PortfolioProvider>().setAdditionalInvestment(pf.id, parsed);
      },
    );
  }

  // ── 조정 카드 ──

  Widget _buildProposalCard(BuildContext context, Portfolio pf,
      RebalanceResult rb, List<RebalanceItemResult> trades) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final r in trades) _buildTradeBlock(context, pf, r),
        _buildDriftBlock(context, pf, rb),
      ]),
    );
  }

  Widget _buildTradeBlock(
      BuildContext context, Portfolio pf, RebalanceItemResult r) {
    final l10n = context.l10n;
    final item = pf.items.firstWhere((i) => i.id == r.id);
    final isBuy = r.delta > 0;

    // 기준통화 환산가 — 금액은 포트 통화로 보여준다
    double fx = 1.0;
    if (item.market == 'US' && pf.currency == 'KRW') {
      fx = pf.exchangeRate;
    } else if (item.market == 'KR' && pf.currency == 'USD') {
      fx = 1.0 / pf.exchangeRate;
    }
    final amount = r.delta.abs() * item.currentPrice * fx;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.dividerColor)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isBuy ? context.pnlUpTint : context.pnlDownTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isBuy ? l10n.buy : l10n.sell,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isBuy ? context.brandOnLight : context.danger)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Icon(Icons.check_circle, size: 20, color: context.brand),
        ]),
        const SizedBox(height: 11),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${formatShares(r.delta.abs())}${l10n.unitShares}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.1,
                      color: context.textPrimary)),
              const SizedBox(height: 4),
              Text(
                l10n.atCurrentPrice(_fmtPrice(item.currentPrice, item.market)),
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt(amount, pf.currency),
                style: TextStyle(
                    fontSize: DS.rowAmount,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: context.textPrimary)),
            const SizedBox(height: 4),
            Text('${_pct(r.currentWeight)} → ${_pct(r.finalWeight)}',
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ]),
        ]),
      ]),
    );
  }

  String _fmtPrice(double n, String market) {
    if (market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  /// 조정 후 남는 편차 — 지금 최대 편차와 조정 뒤 최대 편차를 나란히.
  Widget _buildDriftBlock(
      BuildContext context, Portfolio pf, RebalanceResult rb) {
    final l10n = context.l10n;
    final threshold = pf.rebalancingThreshold;

    double maxNow = 0, maxAfter = 0;
    for (final r in rb.results) {
      final item = pf.items.firstWhere((i) => i.id == r.id);
      final now = r.currentWeight - item.targetWeight;
      final after = r.finalWeight - item.targetWeight;
      if (now.abs() > maxNow.abs()) maxNow = now;
      if (after.abs() > maxAfter.abs()) maxAfter = after;
    }
    final within = threshold <= 0 || maxAfter.abs() < threshold;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(l10n.driftAfterAdjust,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.textStrong)),
            ),
            if (threshold > 0)
              Text(l10n.toleranceLabel(_trimZero(threshold)),
                  style: TextStyle(
                      fontSize: DS.body,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary)),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(_pp(maxNow),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: context.danger)),
            const SizedBox(width: 9),
            Icon(Icons.arrow_forward, size: 17, color: context.textHint),
            const SizedBox(width: 9),
            Text(_pp(maxAfter),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: within ? context.brandOnLight : context.danger)),
            const Spacer(),
            if (within && threshold > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.pnlUpTint,
                  borderRadius: BorderRadius.circular(DS.chipRadius),
                ),
                child: Text(l10n.withinTolerance,
                    style: TextStyle(
                        fontSize: DS.caption,
                        fontWeight: FontWeight.w800,
                        color: context.brandOnLight)),
              ),
          ],
        ),
      ]),
    );
  }

  String _trimZero(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);

  // ── 반올림 안내 ──

  Widget _buildRoundingNote(BuildContext context, Portfolio pf,
      RebalanceResult rb, List<RebalanceItemResult> trades) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.rule, size: 18, color: context.textSecondary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
                pf.fractionalEnabled
                    ? l10n.roundingFractional
                    : l10n.roundingWholeShares,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
          ),
        ]),
        const SizedBox(height: 7),
        Text(
          pf.fractionalEnabled
              ? l10n.roundingFractionalDesc(sharesDecimals)
              : l10n.roundingWholeSharesDesc,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: context.textSecondary),
        ),
      ]),
    );
  }

  // ── 안내 · 빈 상태 · CTA ──

  Widget _buildDisclaimer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 15, color: context.textTertiary),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(context.l10n.proposalDisclaimer,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                  color: context.textSecondary)),
        ),
      ]),
    );
  }

  Widget _buildNothingToDo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Row(children: [
        Icon(Icons.check_circle_outline, size: 20, color: context.brandOnLight),
        const SizedBox(width: 10),
        Expanded(
          child: Text(context.l10n.noAdjustmentNeeded,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textStrong)),
        ),
      ]),
    );
  }

  Widget _buildCannotCalculate(BuildContext context, Portfolio pf) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          (pf.weightSum - 100).abs() > 0.01
              ? context.l10n.weightWarning(_pct(pf.weightSum))
              : context.l10n.cannotCalculate,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: context.textSecondary),
        ),
      ),
    );
  }

  Widget _buildCta(BuildContext context, Portfolio pf, RebalanceResult rb) {
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => RebalanceTransactionDialog(pf: pf, rb: rb),
            );
            if (ok == true && context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.buttonRadius)),
          ),
          child: Text(context.l10n.recordAsTransactions,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
