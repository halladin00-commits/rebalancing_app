import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import '../utils/share_format.dart';
import '../widgets/brand_header.dart';
import '../widgets/list_card.dart';

/// 소수점 거래 설정 (시안 v23b).
///
/// 소수점 매매 가능 여부는 **증권사·계좌마다 다르다.** 그래서 앱 전역이 아니라
/// 계좌별 설정이고, 이 화면은 그 사실이 목록에서 바로 드러나게 한다.
class FractionalSettingsScreen extends StatelessWidget {
  const FractionalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final portfolios = provider.portfolios;
        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(children: [
            BrandHeader(
              title: l10n.fractionalTrading,
              titleSize: 17,
              titleWeight: FontWeight.w700,
              leading: IconButton(
                tooltip: context.l10n.a11yBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              childPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Text(l10n.fractionalIntro,
                  style: TextStyle(
                      fontSize: DS.body,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: context.onBrandSecondary)),
            ),
            Expanded(
              child: portfolios.isEmpty
                  ? Center(
                      child: Text(l10n.noPortfolios,
                          style: TextStyle(color: context.textTertiary)))
                  : ListView(
                      padding: EdgeInsets.fromLTRB(16, 14, 16,
                          24 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        SectionTitle(title: l10n.fractionalPerAccount),
                        const SizedBox(height: DS.cardGap),
                        ListCard(rows: [
                          for (final pf in portfolios)
                            _AccountRow(portfolio: pf),
                        ]),
                        const SizedBox(height: 16),
                        SectionTitle(title: l10n.fractionalRoundingTitle),
                        const SizedBox(height: DS.cardGap),
                        _buildRoundingCard(context, portfolios),
                        const SizedBox(height: 16),
                        _buildPreview(context, portfolios),
                      ],
                    ),
            ),
          ]),
        );
      },
    );
  }

  // ── 반올림 규칙 ──

  /// 규칙은 소수점을 켠 계좌에만 의미가 있다. 켠 계좌가 없으면 감춘다.
  Widget _buildRoundingCard(BuildContext context, List<Portfolio> portfolios) {
    final l10n = context.l10n;
    final on = portfolios.where((p) => p.fractionalEnabled).toList();
    if (on.isEmpty) {
      return _note(context, l10n.fractionalRoundingDisabled);
    }
    // 계좌마다 다를 수 있지만 규칙까지 나누면 고를 게 너무 많아진다.
    // 켠 계좌 전체에 같은 규칙을 적용한다.
    final current = on.first.fractionalRounding;
    final mixed = on.any((p) => p.fractionalRounding != current);

    void pick(FractionalRounding r) {
      final provider = context.read<PortfolioProvider>();
      for (final pf in on) {
        provider.updateSettings(pf.id, fractionalRounding: r);
      }
    }

    return ListCard(rows: [
      _radio(context,
          selected: !mixed && current == FractionalRounding.minDeviation,
          title: l10n.roundingMinDeviation,
          sub: l10n.roundingMinDeviationDesc(sharesDecimals),
          onTap: () => pick(FractionalRounding.minDeviation)),
      _radio(context,
          selected: !mixed && current == FractionalRounding.floorCash,
          title: l10n.roundingFloorCash,
          sub: l10n.roundingFloorCashDesc,
          onTap: () => pick(FractionalRounding.floorCash)),
    ]);
  }

  Widget _radio(BuildContext context,
      {required bool selected,
      required String title,
      required String sub,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? context.brand : context.textDisabled,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary)),
              const SizedBox(height: 3),
              Text(sub,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: context.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── 미리보기 ──

  /// 규칙을 바꾸면 실제 제안이 어떻게 달라지는지 그 자리에서 보여준다.
  Widget _buildPreview(BuildContext context, List<Portfolio> portfolios) {
    final l10n = context.l10n;
    // **소수점이 실제로 적용되는 종목**을 골라야 한다. 국내 종목을 고르면
    // 두 칸에 같은 수가 들어가 `2819주 → 2819주`가 되고, 그걸
    // "이렇게 바뀝니다"라고 말하게 된다.
    Portfolio? pf;
    RebalanceItemResult? trade;
    PortfolioItem? item;
    for (final p in portfolios.where((p) => p.fractionalEnabled)) {
      final rb = Rebalancer.calculate(p);
      if (rb == null) continue;
      for (final r in rb.results) {
        if (r.isCash || r.delta == 0) continue;
        final it = p.items.where((i) => i.id == r.id).firstOrNull;
        if (it == null || !Rebalancer.allowsFractional(p, it)) continue;
        pf = p;
        trade = r;
        item = it;
        break;
      }
      if (trade != null) break;
    }
    if (pf == null || trade == null || item == null) {
      return const SizedBox.shrink();
    }
    final whole = trade.delta.abs().truncateToDouble();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(title: l10n.fractionalPreviewTitle),
      const SizedBox(height: DS.cardGap),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${pf.name} · ${item.name}',
              style: TextStyle(
                  fontSize: DS.body,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(
              child: _previewBox(context,
                  bg: context.subtleFill,
                  label: l10n.previewWholeShares,
                  value: '${formatShares(whole)}${l10n.unitShares}',
                  fg: context.textSecondary),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 17, color: context.textHint),
            ),
            Expanded(
              child: _previewBox(context,
                  bg: context.brandTint,
                  label: l10n.previewFractional,
                  value:
                      '${formatShares(trade.delta.abs())}${l10n.unitShares}',
                  fg: context.brandOnLight),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Widget _previewBox(BuildContext context,
      {required Color bg,
      required String label,
      required String value,
      required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: context.textPrimary)),
        ),
      ]),
    );
  }

  Widget _note(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(DS.tileRadius),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: context.textSecondary)),
    );
  }
}

/// 계좌 한 줄 — 토글 + 왜 되는지/안 되는지 한 줄.
class _AccountRow extends StatelessWidget {
  final Portfolio portfolio;
  const _AccountRow({required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pf = portfolio;
    final hasUs = pf.items.any((i) => i.market == 'US');
    final usCount = pf.items.where((i) => i.market == 'US').length;
    final stockCount = pf.items.where((i) => !i.isCash).length;

    // 시안은 국내 전용 계좌의 토글을 아예 잠근다. 하지만 국내 상장 ETF도
    // 증권사에 따라 소수점 매매가 되는 곳이 있어, 잠그면 되는 사람이 못 켠다.
    // 잠그지 않고 사실만 적는다.
    final String reason;
    if (!hasUs) {
      reason = l10n.fractionalReasonKrOnly;
    } else if (usCount < stockCount) {
      reason = l10n.fractionalReasonPartial(usCount);
    } else {
      reason = l10n.fractionalReasonOverseas;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${pf.emoji} ${pf.name}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(reason,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: hasUs ? context.textSecondary : context.warningText)),
          ]),
        ),
        const SizedBox(width: 10),
        Switch(
          value: pf.fractionalEnabled,
          onChanged: (v) => context
              .read<PortfolioProvider>()
              .updateSettings(pf.id, fractionalEnabled: v),
        ),
      ]),
    );
  }
}
