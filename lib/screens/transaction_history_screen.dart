import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
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
typedef _Entry = ({PortfolioItem item, StockTransaction tx});

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }

        final all = _collect(pf);
        final shown = switch (_filter) {
          _Filter.buy => all.where((e) => e.tx.quantity > 0).toList(),
          _Filter.sell => all.where((e) => e.tx.quantity < 0).toList(),
          _ => all,
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
            _buildFilters(context),
            Expanded(
              child: shown.isEmpty
                  ? _buildEmpty(context)
                  : _buildGroups(context, pf, shown),
            ),
          ]),
        );
      },
    );
  }

  /// 전 종목의 거래를 한 줄로 펴서 최신순으로.
  List<_Entry> _collect(Portfolio pf) {
    final out = <_Entry>[];
    for (final item in pf.items) {
      if (item.isCash) continue;
      for (final tx in item.transactions) {
        out.add((item: item, tx: tx));
      }
    }
    out.sort((a, b) => b.tx.date.compareTo(a.tx.date));
    return out;
  }

  // ── 필터 ──

  Widget _buildFilters(BuildContext context) {
    final l10n = context.l10n;
    final items = <(_Filter, String)>[
      (_Filter.all, l10n.filterAll),
      (_Filter.buy, l10n.buy),
      (_Filter.sell, l10n.sell),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Row(children: [
        for (final (f, label) in items) ...[
          GestureDetector(
            onTap: () => setState(() => _filter = f),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _filter == f ? context.brand : context.cardBg,
                borderRadius: BorderRadius.circular(DS.chipRadius),
                border: Border.all(
                    color: _filter == f ? context.brand : context.borderColor),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _filter == f
                          ? Colors.white
                          : context.textSecondary)),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ]),
    );
  }

  // ── 월별 묶음 ──

  Widget _buildGroups(BuildContext context, Portfolio pf, List<_Entry> shown) {
    // 같은 달끼리 묶는다 — 시간순으로 훑을 때 달이 기준선이 된다
    final groups = <String, List<_Entry>>{};
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
      BuildContext context, Portfolio pf, String key, List<_Entry> entries) {
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
          '${net >= 0 ? l10n.netBuy : l10n.netSell} ${_fmt(net.abs(), pf.currency)}',
    );
  }

  Widget _buildRow(BuildContext context, Portfolio pf, _Entry e) {
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
                  ' · ${_fmtPrice(e.tx.price, e.item.market)}'
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
          Text(_fmtPrice(amount, e.item.market),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: context.textPrimary)),
        ]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined,
              size: 30, color: context.textDisabled),
          const SizedBox(height: 10),
          Text(context.l10n.noTransactionsYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary)),
        ]),
      ),
    );
  }

  // ── 서식 ──

  String _fmt(double n, String cur) {
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtPrice(double n, String market) {
    if (market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}
