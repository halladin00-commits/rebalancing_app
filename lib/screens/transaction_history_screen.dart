import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/share_format.dart';
import '../widgets/brand_header.dart';
import '../widgets/list_card.dart';
import 'transaction_form_screen.dart';

/// 포트폴리오 전체 거래 내역 (시안 v16a).
///
/// 종목 상세는 그 종목의 거래만 보여준다. 여기는 **포트 전체를 시간순으로**
/// 훑는 자리다 — "지난달에 뭘 샀더라"를 종목을 하나씩 열지 않고 답한다.
class TransactionHistoryScreen extends StatefulWidget {
  final String portfolioId;
  const TransactionHistoryScreen({super.key, required this.portfolioId});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

enum _Filter { all, buy, sell }

/// 거래 한 건 + 그게 어느 종목의 것인지.
typedef TxEntry = ({PortfolioItem item, StockTransaction tx});

/// 포트의 모든 거래를 한 줄로 펴서 최신순으로. 현금은 거래가 없다.
List<TxEntry> collectTransactions(Portfolio pf) {
  final out = <TxEntry>[];
  for (final item in pf.items) {
    if (item.isCash) continue;
    for (final tx in item.transactions) {
      out.add((item: item, tx: tx));
    }
  }
  out.sort((a, b) => b.tx.date.compareTo(a.tx.date));
  return out;
}

/// 거래가 실제로 있는 연도만, 최신순으로.
///
/// 없는 해를 칸으로 만들면 눌러도 빈 목록만 나온다.
List<int> transactionYears(List<TxEntry> all) {
  final years = <int>{for (final e in all) e.tx.date.year}.toList();
  years.sort((a, b) => b.compareTo(a));
  return years;
}

/// 종목·연도로 거른다. 둘 다 null이면 그대로 돌려준다.
///
/// 1년쯤 쓰면 거래가 수백 건이 된다. "작년에 엔비디아 언제 샀더라"를
/// 스크롤로 찾게 두지 않으려고 있다.
List<TxEntry> filterTransactions(
  List<TxEntry> all, {
  String? itemId,
  int? year,
}) =>
    [
      for (final e in all)
        if ((itemId == null || e.item.id == itemId) &&
            (year == null || e.tx.date.year == year))
          e,
    ];

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  _Filter _filter = _Filter.all;

  /// 고른 종목 (null이면 전체)
  String? _itemId;

  /// 고른 연도 (null이면 전체)
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }

        final all = collectTransactions(pf);

        // 고른 종목이 지워졌으면 필터를 놓는다 — 안 그러면 영영 빈 목록이다
        if (_itemId != null && !pf.items.any((i) => i.id == _itemId)) {
          _itemId = null;
        }
        // 연도 칸은 **고른 종목 기준**으로 만든다. 그 종목이 없던 해를
        // 눌러 빈 목록을 보게 두지 않는다.
        final byItem = filterTransactions(all, itemId: _itemId);
        final years = transactionYears(byItem);
        if (_year != null && !years.contains(_year)) _year = null;

        final filtered = filterTransactions(all, itemId: _itemId, year: _year);
        final shown = switch (_filter) {
          _Filter.buy => filtered.where((e) => e.tx.quantity > 0).toList(),
          _Filter.sell => filtered.where((e) => e.tx.quantity < 0).toList(),
          _ => filtered,
        };

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(children: [
            BrandHeader(
              title: l10n.transactionHistory,
              titleSize: 17,
              titleWeight: FontWeight.w700,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              childPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Text('${pf.name} · ${l10n.txCountLabel(all.length)}',
                  style: TextStyle(
                      fontSize: DS.body,
                      fontWeight: FontWeight.w600,
                      color: context.onBrandSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
            _buildFilters(context, pf, years),
            Expanded(
              child: shown.isEmpty
                  ? _buildEmpty(context, filtered: all.isNotEmpty)
                  : _buildGroups(context, pf, shown),
            ),
          ]),
        );
      },
    );
  }

  // ── 필터 ──

  /// 눌러서 켜고 끄는 칸 하나. 목록 전체가 이 모양이라 한 군데서 만든다.
  Widget _chip(
    BuildContext context, {
    required String label,
    required bool on,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? context.brand : context.cardBg,
          borderRadius: BorderRadius.circular(DS.chipRadius),
          border:
              Border.all(color: on ? context.brand : context.borderColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // 종목명이 길면 칸이 화면을 넘어간다 — 최대 폭을 두고 줄인다
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : context.textSecondary)),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 3),
            Icon(trailingIcon,
                size: 15, color: on ? Colors.white : context.textSecondary),
          ],
        ]),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, Portfolio pf, List<int> years) {
    final l10n = context.l10n;
    final items = <(_Filter, String)>[
      (_Filter.all, l10n.filterAll),
      (_Filter.buy, l10n.buy),
      (_Filter.sell, l10n.sell),
    ];
    final picked =
        _itemId == null ? null : pf.items.where((i) => i.id == _itemId);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
        child: Row(children: [
          for (final (f, label) in items) ...[
            _chip(context,
                label: label,
                on: _filter == f,
                onTap: () => setState(() => _filter = f)),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          // 종목이 열 개가 넘을 수 있어 칸으로 늘어놓지 않고 시트로 고른다
          _chip(context,
              label: (picked == null || picked.isEmpty)
                  ? l10n.filterByItem
                  : picked.first.name,
              on: _itemId != null,
              trailingIcon: _itemId == null
                  ? Icons.keyboard_arrow_down
                  : Icons.close,
              onTap: () => _itemId == null
                  ? _pickItem(pf)
                  : setState(() => _itemId = null)),
        ]),
      ),
      // 해가 하나뿐이면 고를 게 없다
      if (years.length > 1)
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 0),
            children: [
              _chip(context,
                  label: l10n.filterAll,
                  on: _year == null,
                  onTap: () => setState(() => _year = null)),
              for (final y in years) ...[
                const SizedBox(width: 6),
                _chip(context,
                    label: '$y',
                    on: _year == y,
                    onTap: () => setState(() => _year = y)),
              ],
            ],
          ),
        ),
    ]);
  }

  /// 종목을 시트로 고른다. 거래가 있는 종목만, 건수와 함께.
  Future<void> _pickItem(Portfolio pf) async {
    final l10n = context.l10n;
    final counts = <String, int>{};
    for (final e in collectTransactions(pf)) {
      counts[e.item.id] = (counts[e.item.id] ?? 0) + 1;
    }
    final choices = pf.items.where((i) => counts.containsKey(i.id)).toList()
      ..sort((a, b) => counts[b.id]!.compareTo(counts[a.id]!));

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
      ),
      builder: (sheetCtx) => ConstrainedBox(
        // 종목이 많으면 시트가 화면을 넘는다
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
            child: Row(children: [
              Text(l10n.filterByItem,
                  style: TextStyle(
                      fontSize: DS.rowName,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              // 시트 맨 아래 항목이 네비게이션 바에 가리지 않게 한다
              padding: EdgeInsets.fromLTRB(
                  10, 0, 10, MediaQuery.of(sheetCtx).padding.bottom + 16),
              children: [
                for (final i in choices)
                  ListTile(
                    title: Text(i.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: DS.rowName,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary)),
                    trailing: Text(l10n.txCountLabel(counts[i.id]!),
                        style: TextStyle(
                            fontSize: DS.caption,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary)),
                    onTap: () => Navigator.pop(sheetCtx, i.id),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
    if (picked != null && mounted) setState(() => _itemId = picked);
  }

  // ── 월별 묶음 ──

  Widget _buildGroups(BuildContext context, Portfolio pf, List<TxEntry> shown) {
    // 같은 달끼리 묶는다 — 시간순으로 훑을 때 달이 기준선이 된다
    final groups = <String, List<TxEntry>>{};
    for (final e in shown) {
      final k = '${e.tx.date.year}-${e.tx.date.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(k, () => []).add(e);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        for (final k in keys) ...[
          _buildGroupTitle(context, pf, k, groups[k]!),
          const SizedBox(height: DS.cardGap),
          ListCard(rows: [
            for (final e in groups[k]!) _buildRow(context, pf, e),
          ]),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildGroupTitle(
      BuildContext context, Portfolio pf, String key, List<TxEntry> entries) {
    final l10n = context.l10n;
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // 순매수 = 매수 금액 − 매도 금액. 그 달에 돈이 들어갔는지 나왔는지.
    double net = 0;
    for (final e in entries) {
      var v = e.tx.quantity * e.tx.price;
      if (e.item.market == 'US' && pf.currency == 'KRW') {
        v *= pf.exchangeRate;
      } else if (e.item.market == 'KR' && pf.currency == 'USD') {
        v /= pf.exchangeRate;
      }
      net += v;
    }

    return SectionTitle(
      title: l10n.yearMonth(year, month),
      trailing: '${l10n.txCountLabel(entries.length)} · '
          '${net >= 0 ? l10n.netBuy : l10n.netSell} ${fmtMoney(net.abs(), pf.currency)}',
    );
  }

  Widget _buildRow(BuildContext context, Portfolio pf, TxEntry e) {
    final l10n = context.l10n;
    final isBuy = e.tx.quantity >= 0;
    final qty = e.tx.quantity.abs();
    final amount = qty * e.tx.price;
    final d = e.tx.date;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionFormScreen(
              portfolio: pf, item: e.item, transaction: e.tx),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(
            width: 32,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isBuy ? context.pnlUpTint : context.pnlDownTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isBuy ? l10n.buy : l10n.sell,
                style: TextStyle(
                    fontSize: DS.caption,
                    fontWeight: FontWeight.w800,
                    color: isBuy ? context.brandOnLight : context.danger)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.item.name,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}'
                  ' · ${fmtPrice(e.tx.price, e.item.market)}'
                  ' · ${formatShares(qty)}${l10n.unitShares}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(fmtPrice(amount, e.item.market),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: context.textPrimary)),
        ]),
      ),
    );
  }

  /// [filtered]가 true면 거래는 있는데 조건에 걸린 것이다.
  ///
  /// 이때 "아직 거래가 없습니다"라고 하면 **기록이 사라진 줄 안다.**
  Widget _buildEmpty(BuildContext context, {required bool filtered}) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              filtered
                  ? Icons.filter_alt_off_outlined
                  : Icons.receipt_long_outlined,
              size: 30,
              color: context.textDisabled),
          const SizedBox(height: 10),
          Text(filtered ? l10n.noMatchingTransactions : l10n.noTransactionsYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary)),
          if (filtered) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() {
                _filter = _Filter.all;
                _itemId = null;
                _year = null;
              }),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: context.brand,
                  borderRadius: BorderRadius.circular(DS.chipRadius),
                ),
                child: Text(l10n.clearFilters,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── 서식 ──

}
