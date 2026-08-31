import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';

/// 포트폴리오 순서 변경 (시안 v16c).
///
/// 정렬 규칙 셋 중 **직접 배치를 한 축으로** 뒀다. 금액순·수익률순은 편하지만
/// 값이 바뀔 때마다 자리가 움직여서, 어느 포트가 어디 있는지 외울 수가 없다.
/// 직접 배치를 고르면 끌어다 놓은 자리가 그대로 남는다.
class PortfolioReorderScreen extends StatelessWidget {
  const PortfolioReorderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<PortfolioProvider>();
    final sorter = context.watch<PortfolioSortNotifier>();
    final sort = sorter.sort;
    final ordered = sortPortfolios(provider.portfolios, sort);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _buildHeader(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.trackBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(children: [
              _segment(context, l10n.sortManual, sort == PortfolioSort.manual,
                  () => sorter.setSort(PortfolioSort.manual)),
              const SizedBox(width: 6),
              _segment(context, l10n.sortByValue, sort == PortfolioSort.value,
                  () => sorter.setSort(PortfolioSort.value)),
              const SizedBox(width: 6),
              _segment(
                  context,
                  l10n.sortByReturn,
                  sort == PortfolioSort.returnRate,
                  () => sorter.setSort(PortfolioSort.returnRate)),
            ]),
          ),
        ),
        Expanded(
          child: sort == PortfolioSort.manual
              ? ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                  itemCount: ordered.length,
                  onReorder: (o, n) {
                    if (n > o) n--;
                    final list = List<Portfolio>.from(ordered);
                    list.insert(n, list.removeAt(o));
                    provider.reorderPortfolios(list);
                  },
                  proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    child: child,
                  ),
                  itemBuilder: (ctx, i) => _row(context, ordered[i],
                      key: ValueKey(ordered[i].id), draggable: true),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                  children: [
                    for (final pf in ordered)
                      _row(context, pf, key: ValueKey(pf.id), draggable: false),
                  ],
                ),
        ),
        // 직접 배치를 고른 이유를 그 자리에서 말해 준다
        if (sort == PortfolioSort.manual)
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, 14 + MediaQuery.of(context).padding.bottom),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 15, color: context.textTertiary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(l10n.sortManualNote,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        color: context.textSecondary)),
              ),
            ]),
          )
        else
          SizedBox(height: 14 + MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(l10n.reorderPortfolios,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.done,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
            ]),
          ),
        ),
      ),
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

  Widget _row(BuildContext context, Portfolio pf,
      {required Key key, required bool draggable}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(children: [
        Icon(Icons.drag_indicator,
            size: 20,
            color: draggable ? context.textTertiary : context.textDisabled),
        const SizedBox(width: 10),
        Text(pf.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(pf.name,
              style: TextStyle(
                  fontSize: DS.rowName,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: context.textPrimary),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(fmtMoney(pf.totalValue, pf.currency),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: context.textPrimary)),
      ]),
    );
  }
}

/// 정렬 규칙대로 줄 세운다. 자산 탭 목록도 이걸 쓴다.
///
/// 금액은 원화로 환산해 견준다 — 통화가 다른 포트를 액면으로 비교하면
/// 달러 포트가 늘 아래로 간다.
List<Portfolio> sortPortfolios(List<Portfolio> portfolios, PortfolioSort sort) {
  double krw(Portfolio pf) =>
      pf.currency == 'USD' ? pf.totalValue * pf.exchangeRate : pf.totalValue;

  /// 평가 수익률(%). 원금을 모르면 견줄 수 없으므로 맨 뒤로 보낸다.
  double? rate(Portfolio pf) {
    if (!pf.hasAvgData) return null;
    final total = pf.totalValue;
    final pnl = pf.unrealizedPnL;
    final cost = total - pnl;
    if (cost <= 0) return null;
    return pnl / cost * 100;
  }

  final list = List<Portfolio>.from(portfolios);
  switch (sort) {
    case PortfolioSort.manual:
      return list;
    case PortfolioSort.value:
      list.sort((a, b) => krw(b).compareTo(krw(a)));
      return list;
    case PortfolioSort.returnRate:
      list.sort((a, b) {
        final ra = rate(a), rb = rate(b);
        if (ra == null && rb == null) return 0;
        if (ra == null) return 1;
        if (rb == null) return -1;
        return rb.compareTo(ra);
      });
      return list;
  }
}
