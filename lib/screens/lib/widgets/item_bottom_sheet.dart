import 'package:flutter/material.dart';
import '../main.dart';
import '../models/portfolio.dart';

class ItemBottomSheet extends StatelessWidget {
  final PortfolioItem item;
  final Portfolio portfolio;
  final RebalanceResult? rb;
  const ItemBottomSheet(
      {super.key, required this.item, required this.portfolio, this.rb});

  String _fmt(double n, String cur) {
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtPrice(double n, String market) {
    if (market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _pct(double n) => '${n.toStringAsFixed(2)}%';

  @override
  Widget build(BuildContext context) {
    final r = rb?.results.where((x) => x.id == item.id).firstOrNull;
    final delta = r?.isCash == true ? r!.cashDelta.round() : (r?.delta ?? 0);
    String tradeText;
    if (r == null) {
      tradeText = '—';
    } else if (delta == 0) {
      tradeText = '유지';
    } else {
      tradeText =
          '${delta > 0 ? "매수 " : "매도 "}${item.isCash ? _fmt(delta.abs().toDouble(), portfolio.currency) : "${delta.abs()}주"}';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: context.cardBg,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _marketBadge(context),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.name,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (item.ticker.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(item.ticker,
                        style: TextStyle(
                            fontSize: 14, color: context.textHint)),
                  ],
                ]),
                const SizedBox(height: 16),
                _infoRow(context, '현재가',
                    item.isCash ? '—' : _fmtPrice(item.currentPrice, item.market)),
                _infoRow(
                    context,
                    '보유 수량',
                    item.isCash
                        ? _fmt(item.shares, portfolio.currency)
                        : '${item.shares.toInt()}주'),
                _infoRow(context, '목표 비중', _pct(item.targetWeight)),
                _infoRow(context, '현재 비중',
                    r != null ? _pct(r.currentWeight) : '—'),
                _infoRow(context, '최종 비중',
                    r != null ? _pct(r.finalWeight) : '—'),
                _infoRow(context, '매매', tradeText),
                if (item.market == 'US' &&
                    portfolio.currency == 'KRW' &&
                    !item.isCash) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: context.rowBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        '원화 환산가: ${_fmt(item.currentPrice * portfolio.exchangeRate, "KRW")}',
                        style: TextStyle(
                            fontSize: 13, color: context.textSecondary)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.rowBg,
                      foregroundColor: context.textSecondary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('닫기',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.infoBoxBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _marketBadge(BuildContext context) {
    Color color;
    String text;
    if (item.isCash) {
      text = '현금';
      color = const Color(0xFF65A30D);
    } else if (item.market == 'US') {
      text = 'US';
      color = const Color(0xFF7C3AED);
    } else {
      text = 'KR';
      color = const Color(0xFF0369A1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
