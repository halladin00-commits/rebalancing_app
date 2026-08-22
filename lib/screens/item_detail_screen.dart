import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/share_format.dart';
import '../widgets/brand_header.dart';
import '../widgets/list_card.dart';
import '../widgets/item_form_dialog.dart';
import 'transaction_form_screen.dart';

/// 종목 상세 (시안 v12c).
///
/// 개편 전에는 바텀시트에 `라벨 — 값` 여섯 줄을 쌓고 아래가 잘렸다.
/// 시안은 포트 상세와 같은 골격의 **전용 화면**이다 —
/// 딥그린 헤더(평가금액 + 손익 타일) + 요약 카드 + 거래 내역.
class ItemDetailScreen extends StatelessWidget {
  final String portfolioId;
  final String itemId;

  const ItemDetailScreen(
      {super.key, required this.portfolioId, required this.itemId});

  // ── 서식 ──

  String _fmt(double n, String cur) {
    final sign = n < 0 ? '−' : '';
    final abs = n.abs();
    if (cur == 'USD') return '$sign\$${abs.toStringAsFixed(2)}';
    return '$sign₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtPrice(double n, String market) {
    if (market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(portfolioId);
        final item = pf?.items.where((i) => i.id == itemId).firstOrNull;
        if (pf == null || item == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              _buildHeader(context, pf, item),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 24),
                  children: [
                    _buildSummaryCard(context, pf, item),
                    const SizedBox(height: 13),
                    SectionTitle(
                      title: l10n.transactionHistory,
                      trailing: item.transactions.isEmpty
                          ? null
                          : l10n.txCountLabel(item.transactions.length),
                    ),
                    const SizedBox(height: DS.cardGap),
                    _buildTransactions(context, pf, item),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 헤더 ──

  Widget _buildHeader(BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    final pnlColors = context.watch<PnlColorNotifier>();

    double fx = 1.0;
    if (item.market == 'US' && pf.currency == 'KRW') {
      fx = pf.exchangeRate;
    } else if (item.market == 'KR' && pf.currency == 'USD') {
      fx = 1.0 / pf.exchangeRate;
    }
    final value =
        item.isCash ? item.shares : item.shares * item.currentPrice * fx;

    double? pnl, pnlPct, day, dayPct;
    if (!item.isCash && item.avgPrice > 0 && item.currentPrice > 0) {
      pnl = (item.currentPrice - item.avgPrice) * item.shares * fx;
      pnlPct = (item.currentPrice - item.avgPrice) / item.avgPrice * 100;
    }
    if (!item.isCash && item.previousClose > 0 && item.currentPrice > 0) {
      day = (item.currentPrice - item.previousClose) * item.shares * fx;
      dayPct = (item.currentPrice - item.previousClose) / item.previousClose * 100;
    }

    return BrandHeader(
      titleSize: 15,
      titleWeight: FontWeight.w700,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleWidget: Row(children: [
        if (!item.isCash) ...[
          MarketChip(market: item.market, label: item.market),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(item.name,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Colors.white),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () => _showMenu(context, pf, item),
        ),
      ],
      childPadding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l10n.evaluationAmount,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.onBrandSecondary)),
          const Spacer(),
          // 어느 포트에서 왔는지 알려주는 이름표
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DS.chipRadius),
            ),
            child: Text(pf.name,
                style: TextStyle(
                    fontSize: DS.caption,
                    fontWeight: FontWeight.w700,
                    color: context.onBrandSecondary)),
          ),
        ]),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_fmt(value, pf.currency),
              style: const TextStyle(
                  fontSize: DS.displayAmount,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.5,
                  height: 1.08)),
        ),
        if (!item.isCash) ...[
          const SizedBox(height: 13),
          Row(children: [
            _tile(context, l10n.profitLoss, pnl, pnlPct, pf.currency, pnlColors),
            const SizedBox(width: 9),
            _tile(context, l10n.dayChange, day, dayPct, pf.currency, pnlColors),
          ]),
        ],
      ]),
    );
  }

  Widget _tile(BuildContext context, String label, double? amount, double? pct,
      String currency, PnlColorNotifier pnlColors) {
    final has = amount != null && pct != null;
    final pos = (amount ?? 0) >= 0;
    final color = !has
        ? context.onBrandSecondary
        : (pos ? pnlColors.onBrandPositive : pnlColors.onBrandNegative);
    final sign = pos ? '+' : '−';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: DS.body,
                  fontWeight: FontWeight.w600,
                  color: context.onBrandSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(has ? '$sign${_fmt(amount.abs(), currency)}' : '—',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: color)),
          ),
          const SizedBox(height: 2),
          Text(has ? '$sign${pct.abs().toStringAsFixed(2)}%' : '—',
              style: TextStyle(
                  fontSize: DS.body, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  // ── 요약 카드 (보유 수량 · 평균 매입가 · 현재가) ──

  Widget _buildSummaryCard(
      BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    if (item.isCash) {
      return ListCard(rows: [
        _kv(context, l10n.evaluationAmount, _fmt(item.shares, pf.currency)),
      ]);
    }
    // 평균 매입가가 거래에서 계산된 값인지 직접 입력인지 밝힌다
    final fromTx = item.transactions.isNotEmpty;
    return ListCard(rows: [
      _kv(context, l10n.holdingQty,
          '${formatShares(item.shares)}${l10n.unitShares}'),
      _kv(context, l10n.avgCost, _fmtPrice(item.avgPrice, item.market),
          note: fromTx ? l10n.basedOnTransactions : l10n.enteredDirectly),
      _kv(context, l10n.currentPrice, _fmtPrice(item.currentPrice, item.market)),
    ]);
  }

  Widget _kv(BuildContext context, String label, String value, {String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ),
          if (note != null) ...[
            Text(note,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary)),
            const SizedBox(width: 8),
          ],
          Text(value,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
        ],
      ),
    );
  }

  // ── 거래 내역 ──

  Widget _buildTransactions(
      BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    if (item.transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Center(
          child: Text(l10n.noTransactionsYet,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary)),
        ),
      );
    }

    final txs = [...item.transactions]..sort((a, b) => b.date.compareTo(a.date));
    return ListCard(
      rows: [
        for (final t in txs) _buildTxRow(context, pf, item, t),
      ],
    );
  }

  Widget _buildTxRow(BuildContext context, Portfolio pf, PortfolioItem item,
      StockTransaction t) {
    final l10n = context.l10n;
    final isBuy = t.quantity >= 0;
    final qty = t.quantity.abs();
    final amount = qty * t.price;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionFormScreen(
              portfolio: pf, item: item, transaction: t),
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
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.textPrimary),
                    children: [
                      TextSpan(text: _fmtPrice(t.price, item.market)),
                      TextSpan(
                        text: ' · ${formatShares(qty)}${l10n.unitShares}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${t.date.year}.${t.date.month.toString().padLeft(2, '0')}.${t.date.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_fmtPrice(amount, item.market),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: context.textPrimary)),
        ]),
      ),
    );
  }

  // ── more_vert 메뉴 ──

  void _showMenu(BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD6CFBC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: context.textStrong),
            title: Text(l10n.edit,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            onTap: () {
              Navigator.pop(sheetCtx);
              showDialog(
                context: context,
                builder: (_) => ItemFormDialog(
                  item: item,
                  priceAuto: pf.priceAuto,
                  currency: pf.currency,
                  onSave: (updated) => context
                      .read<PortfolioProvider>()
                      .updateItem(pf.id, updated),
                ),
              );
            },
          ),
          if (!item.isCash)
            ListTile(
              leading: Icon(Icons.receipt_long_outlined,
                  color: context.textStrong),
              title: Text(l10n.addTransaction,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary)),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionFormScreen(portfolio: pf, item: item),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
