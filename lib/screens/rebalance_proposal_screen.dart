import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import '../utils/share_format.dart';
import '../widgets/rebalance_transaction_dialog.dart';

/// 조정 제안 (시안 v20a·v20b).
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

  /// 체크를 끈 종목. 이 종목들은 건드리지 않고 나머지만 다시 맞춘다 (시안 v20).
  final _excluded = <String>{};

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
        final rb = Rebalancer.calculate(pf, excludeIds: _excluded);
        final trades = rb == null
            ? <RebalanceItemResult>[]
            : rb.results.where((r) => !r.isCash && r.delta != 0).toList();

        // 체크를 끈 종목은 delta가 0이 되어 trades에서 빠진다. 목록에서까지 없어지면
        // 다시 켤 수가 없으므로 회색으로 남겨 두되, **원래 자리에** 남긴다.
        // 맨 뒤로 보내면 방금 누른 행이 화면 밖으로 밀려 사라진 것과 같아진다.
        final shown = rb == null
            ? <RebalanceItemResult>[]
            : rb.results
                .where((r) =>
                    !r.isCash && (r.delta != 0 || _excluded.contains(r.id)))
                .toList();

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
                          if (shown.isEmpty)
                            _buildNothingToDo(context)
                          else ...[
                            _buildHeadline(context, pf, rb, trades),
                            const SizedBox(height: 9),
                            _buildSectionTitle(context, trades.length),
                            const SizedBox(height: 7),
                            _buildProposalCard(context, pf, shown),
                            const SizedBox(height: 9),
                            ...?_buildCashLedger(context, pf, rb, trades),
                            _buildRoundingNote(context, pf, rb, trades),
                            ...?_buildOrderNote(context, pf, trades),
                          ],
                          const SizedBox(height: 9),
                          _buildDisclaimer(context),
                        ],
                      ),
              ),
              if (trades.isNotEmpty) _buildCta(context, pf, rb!, trades),
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
    // 시안 v20a/v20b — 뺀 것이 없으면 몇 종목을 함께 다루는지,
    // 빼둔 것이 있으면 몇 건을 하고 몇 건을 빼는지 보여준다.
    final subtitle = _excluded.isEmpty
        ? l10n.driftedTogether(trades.length)
        : l10n.selectedExcluded(trades.length, _excluded.length);

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
                      trades.isEmpty && _excluded.isEmpty
                          ? pf.name
                          : '${pf.name} · $subtitle',
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

  Widget _buildProposalCard(
      BuildContext context, Portfolio pf, List<RebalanceItemResult> shown) {
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
        for (final r in shown) _buildTradeBlock(context, pf, r),
      ]),
    );
  }

  /// 이 화면의 결론 (시안 v20a).
  ///
  /// v18d에서는 남는 편차가 맨 아래 작게 있고 개별 수량이 가장 큰 글자였다.
  /// 여러 종목을 한 번에 조정하는 화면에서 사용자가 알아야 할 건
  /// "이걸 다 하면 포트가 어디에 서는가" 하나이므로 맨 위로 올리고 키웠다.
  Widget _buildHeadline(BuildContext context, Portfolio pf, RebalanceResult rb,
      List<RebalanceItemResult> trades) {
    final l10n = context.l10n;
    final threshold = pf.rebalancingThreshold;

    double maxNow = 0, maxAfter = 0;
    var inRange = 0;
    for (final r in rb.results) {
      final item = pf.items.firstWhere((i) => i.id == r.id);
      final now = r.currentWeight - item.targetWeight;
      final after = r.finalWeight - item.targetWeight;
      if (now.abs() > maxNow.abs()) maxNow = now;
      if (after.abs() > maxAfter.abs()) maxAfter = after;
      if (threshold <= 0 || after.abs() < threshold) inRange++;
    }
    final within = threshold <= 0 || maxAfter.abs() < threshold;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(l10n.maxDriftAfter,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.textStrong)),
            ),
            if (threshold > 0)
              Text(l10n.toleranceLabel(_trimZero(threshold)),
                  style: TextStyle(
                      fontSize: 11.5,
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: context.brandOnLight)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          within
              ? '${l10n.planMustRunAll(trades.length)} — '
                  '${l10n.allItemsInRange(inRange)}'
              : l10n.planMustRunAll(trades.length),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: context.textSecondary),
        ),
      ]),
    );
  }

  /// `함께 실행할 3건` · 우측에 `체크를 끄면 재계산`
  Widget _buildSectionTitle(BuildContext context, int count) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(l10n.togetherNTrades(count),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: context.textPrimary)),
          const Spacer(),
          Text(l10n.uncheckToRecalc,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ],
      ),
    );
  }

  /// 종목 통화 → 포트 통화 환산 금액.
  double _amountOf(Portfolio pf, PortfolioItem item, double delta) {
    double fx = 1.0;
    if (item.market == 'US' && pf.currency == 'KRW') {
      fx = pf.exchangeRate;
    } else if (item.market == 'KR' && pf.currency == 'USD') {
      fx = 1.0 / pf.exchangeRate;
    }
    return delta.abs() * item.currentPrice * fx;
  }

  /// 거래 한 줄 (시안 v20a).
  ///
  /// v18d는 수량을 24px로 크게 뽑았지만, 결론이 편차로 옮겨간 이상 줄마다
  /// 수량을 크게 둘 이유가 없다. 17px로 나란히 두고 한 줄에 담는다.
  Widget _buildTradeBlock(
      BuildContext context, Portfolio pf, RebalanceItemResult r) {
    final l10n = context.l10n;
    final item = pf.items.firstWhere((i) => i.id == r.id);
    final off = _excluded.contains(r.id);
    final isBuy = r.delta > 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.dividerColor)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: off
                ? context.subtleFill
                : (isBuy ? context.pnlUpTint : context.pnlDownTint),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(off ? l10n.excludedShort : (isBuy ? l10n.buy : l10n.sell),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: off
                      ? context.textTertiary
                      : (isBuy ? context.brandOnLight : context.danger))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: off ? context.textTertiary : context.textPrimary),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
                off
                    ? '${_pct(r.currentWeight)} ${l10n.keepAsIs}'
                    : '${_pct(r.currentWeight)} → ${_pct(r.finalWeight)}',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
              off
                  ? l10n.keepAsIs
                  : '${formatShares(r.delta.abs())}${l10n.unitShares}',
              style: TextStyle(
                  fontSize: off ? 13 : 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: off ? context.textTertiary : context.textPrimary)),
          if (!off) ...[
            const SizedBox(height: 2),
            Text(fmtMoney(_amountOf(pf, item, r.delta), pf.currency),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ],
        ]),
        const SizedBox(width: 8),
        // 끄면 그 종목을 빼고 나머지를 다시 계산한다
        GestureDetector(
          onTap: () => setState(() {
            if (!_excluded.remove(r.id)) _excluded.add(r.id);
          }),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
                off ? Icons.radio_button_unchecked : Icons.check_circle,
                size: 21,
                color: off ? context.textDisabled : context.brand),
          ),
        ),
      ]),
    );
  }

  /// 예수금 가계부 (시안 v20a).
  ///
  /// 매수가 여러 건이면 **같은 예수금을 나눠 쓴다.** 종목별로 따로 보면 왜
  /// 이 금액인지 알 수 없다. 이 화면이 왜 한 장이어야 하는지를 숫자로 보이는 자리다.
  /// 매수가 한 건뿐이면 나눠 쓸 일이 없으므로 내지 않는다.
  List<Widget>? _buildCashLedger(BuildContext context, Portfolio pf,
      RebalanceResult rb, List<RebalanceItemResult> trades) {
    final l10n = context.l10n;

    PortfolioItem? cash;
    for (final i in pf.items) {
      if (i.isCash) {
        cash = i;
        break;
      }
    }
    if (cash == null) return null;

    final buyCount = trades.where((r) => r.delta > 0).length;
    if (buyCount < 2) return null;

    double proceeds = 0, cost = 0;
    for (final r in trades) {
      final item = pf.items.firstWhere((i) => i.id == r.id);
      final amt = _amountOf(pf, item, r.delta);
      if (r.delta > 0) {
        cost += amt;
      } else {
        proceeds += amt;
      }
    }
    final after = cash.shares + proceeds - cost;

    RebalanceItemResult? cashResult;
    for (final r in rb.results) {
      if (r.id == cash.id) {
        cashResult = r;
        break;
      }
    }

    Widget line(String label, String value, {Color? color, bool bold = false}) =>
        Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    color: bold ? context.textPrimary : context.textSecondary)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? context.textPrimary)),
        ]);

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(l10n.cashLedgerTitle(buyCount),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
              ),
              if (cashResult != null)
                Text(
                    '${_pct(cashResult.currentWeight)} → '
                    '${_pct(cashResult.finalWeight)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary)),
            ],
          ),
          const SizedBox(height: 9),
          line(l10n.sellProceeds, '+${fmtMoney(proceeds, pf.currency)}',
              color: context.brandOnLight),
          const SizedBox(height: 5),
          line(l10n.buyCostN(buyCount), '−${fmtMoney(cost, pf.currency)}',
              color: context.danger),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: context.dividerColor),
          ),
          line(l10n.cashAfterAdjust, fmtMoney(after, pf.currency), bold: true),
          const SizedBox(height: 9),
          Text(l10n.cashSharedNote,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                  color: context.textSecondary)),
        ]),
      ),
      const SizedBox(height: 9),
    ];
  }

  /// 실행 순서 안내 (시안 v20a). 해외 종목이 섞였을 때만 낸다 —
  /// 환전이 하루 이틀 걸릴 수 있어 매도를 먼저 해야 매수 대금이 맞는다.
  List<Widget>? _buildOrderNote(
      BuildContext context, Portfolio pf, List<RebalanceItemResult> trades) {
    final hasSell = trades.any((r) => r.delta < 0);
    final hasBuy = trades.any((r) => r.delta > 0);
    if (!hasSell || !hasBuy) return null;

    final crossesFx = trades.any((r) {
      final item = pf.items.firstWhere((i) => i.id == r.id);
      return (item.market == 'US' && pf.currency == 'KRW') ||
          (item.market == 'KR' && pf.currency == 'USD');
    });
    if (!crossesFx) return null;

    return [
      const SizedBox(height: 9),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.schedule, size: 15, color: context.textTertiary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(context.l10n.sellFirstNote,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                    color: context.textSecondary)),
          ),
        ]),
      ),
    ];
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

  Widget _buildCta(BuildContext context, Portfolio pf, RebalanceResult rb,
      List<RebalanceItemResult> trades) {
    final count = trades.length;
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        Expanded(
          child: SizedBox(
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
          child: Text(context.l10n.recordNTransactions(count),
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
          ),
        ),
        const SizedBox(width: 8),
        // 사와야 할 것을 그대로 옮겨 적을 수 있게 글로 내보낸다
        Tooltip(
          message: context.l10n.shareProposal,
          child: GestureDetector(
            onTap: () => _shareProposal(context, pf, trades),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(DS.buttonRadius),
                border: Border.all(color: context.borderColor, width: 1.5),
              ),
              child: Icon(Icons.share, size: 21, color: context.brand),
            ),
          ),
        ),
      ]),
    );
  }

  /// 제안을 글로 내보낸다. 증권사 앱에 옮겨 적을 때 쓰라고.
  void _shareProposal(
      BuildContext context, Portfolio pf, List<RebalanceItemResult> trades) {
    final l10n = context.l10n;
    final lines = <String>['${pf.name} · ${l10n.proposalTitle}'];
    for (final r in trades) {
      final item = pf.items.firstWhere((i) => i.id == r.id);
      final side = r.delta > 0 ? l10n.buy : l10n.sell;
      lines.add('$side ${item.name} '
          '${formatShares(r.delta.abs())}${l10n.unitShares} · '
          '${fmtMoney(_amountOf(pf, item, r.delta), pf.currency)}');
    }
    Share.share(lines.join('\n'));
  }
}
