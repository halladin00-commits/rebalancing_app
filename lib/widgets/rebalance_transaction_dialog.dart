import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../services/review_service.dart';
import '../utils/share_format.dart';

/// 리밸런싱 제안을 실제 거래로 기록하는 다이얼로그.
///
/// 제안은 주문을 내지 않는다 — 사용자가 증권사에서 실제로 체결한 수량·단가로
/// 고쳐 넣으면 그대로 거래 내역에 쌓인다.
///
/// 포트 상세와 조정 제안(v18d) 두 곳에서 쓰므로 별도 파일로 둔다.
class RebalanceTransactionDialog extends StatefulWidget {
  final Portfolio pf;
  final RebalanceResult rb;

  const RebalanceTransactionDialog({super.key, required this.pf, required this.rb});

  @override
  State<RebalanceTransactionDialog> createState() => _RebalanceTransactionDialogState();
}

class _RebalanceTransactionDialogState extends State<RebalanceTransactionDialog> {
  late final List<RebalanceItemResult> _tradeable;
  late final Map<String, TextEditingController> _qtyCtrl;
  late final Map<String, TextEditingController> _priceCtrl;
  late final Map<String, bool> _isBuyMap;

  @override
  void initState() {
    super.initState();
    _tradeable = widget.rb.results.where((r) => !r.isCash && r.delta != 0).toList();
    _qtyCtrl = {
      for (final r in _tradeable)
        r.id: TextEditingController(text: formatShares(r.delta.abs()))
    };
    _priceCtrl = {
      for (final r in _tradeable)
        r.id: TextEditingController(text: _priceStr(
          widget.pf.items.firstWhere((i) => i.id == r.id).currentPrice,
        ))
    };
    _isBuyMap = {
      for (final r in _tradeable) r.id: r.delta > 0
    };
  }

  @override
  void dispose() {
    for (final c in _qtyCtrl.values) c.dispose();
    for (final c in _priceCtrl.values) c.dispose();
    super.dispose();
  }

  String _priceStr(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(l10n.rebalanceTransactionTitle,
          style: TextStyle(color: context.textPrimary)),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(l10n.rebalanceTransactionDesc,
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _tradeable.map((r) {
                    final item = widget.pf.items.firstWhere((i) => i.id == r.id);
                    final isBuy = _isBuyMap[r.id]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.infoBoxBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor),
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _segmentChip(r.id, isBuy),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(item.name,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimary),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: _field(l10n.transactionQty, _qtyCtrl[r.id]!,
                                  isInt: !widget.pf.fractionalEnabled)),
                              const SizedBox(width: 8),
                              Expanded(child: _field(l10n.transactionPrice, _priceCtrl[r.id]!)),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel)),
        TextButton(
            onPressed: _submit,
            child: Text(l10n.done)),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctl, {bool isInt = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
      const SizedBox(height: 3),
      TextField(
        controller: ctl,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 13, color: context.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: context.fieldFill,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: context.borderColor)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _segmentChip(String id, bool isBuy) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentBtn(id, true, isBuy, l10n.transactionBuy, context.brand),
          Container(width: 1, color: context.borderColor),
          _segmentBtn(id, false, isBuy, l10n.transactionSell, Colors.red),
        ],
      ),
    );
  }

  Widget _segmentBtn(String id, bool targetBuy, bool currentBuy, String label, Color color) {
    final selected = targetBuy == currentBuy;
    return GestureDetector(
      onTap: () => setState(() => _isBuyMap[id] = targetBuy),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: targetBuy
              ? const BorderRadius.horizontal(left: Radius.circular(3))
              : const BorderRadius.horizontal(right: Radius.circular(3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? color : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final provider = context.read<PortfolioProvider>();
    final now = DateTime.now();

    for (var i = 0; i < _tradeable.length; i++) {
      final r = _tradeable[i];
      final qty = double.tryParse(_qtyCtrl[r.id]!.text) ?? 0;
      final price = double.tryParse(_priceCtrl[r.id]!.text) ?? 0;
      if (qty <= 0 || price <= 0) continue;
      final tx = StockTransaction(
        id: '${now.millisecondsSinceEpoch}_$i',
        date: now,
        quantity: qty * (_isBuyMap[r.id]! ? 1.0 : -1.0),
        price: price,
      );
      await provider.upsertTransaction(widget.pf.id, r.id, tx);
    }

    final cashItems = widget.rb.results
        .where((r) => r.isCash)
        .map((r) => {'id': r.id, 'newShares': r.newCashAmount})
        .toList();
    await provider.updateCashAndResidual(widget.pf.id, cashItems, widget.rb.cash);

    if (!mounted) return;
    ReviewService.onRebalancingApplied();
    Navigator.pop(context, true);
  }
}
