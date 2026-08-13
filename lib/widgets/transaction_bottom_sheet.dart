import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import 'custom_date_picker.dart';

class TransactionBottomSheet extends StatefulWidget {
  final PortfolioItem item;
  final Portfolio portfolio;
  const TransactionBottomSheet(
      {super.key, required this.item, required this.portfolio});

  @override
  State<TransactionBottomSheet> createState() => _TransactionBottomSheetState();
}

class _TransactionBottomSheetState extends State<TransactionBottomSheet> {
  // 현재 편집/추가 중인 거래 ID. null이면 폼 닫힘, '' = 신규 추가
  String? _editingId;

  late DateTime _formDate;
  bool _formIsBuy = true;
  late TextEditingController _qtyCtl;
  late TextEditingController _priceCtl;

  @override
  void initState() {
    super.initState();
    _formDate = DateTime.now();
    _qtyCtl = TextEditingController();
    _priceCtl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      DateTime.now().microsecond.toRadixString(36);

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _fmtPrice(double n) {
    if (widget.item.market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  void _openForm({StockTransaction? tx}) {
    setState(() {
      _editingId = tx?.id ?? '';
      _formDate = tx?.date ?? DateTime.now();
      _formIsBuy = tx == null ? true : tx.quantity > 0;
      _qtyCtl.text = tx != null ? tx.quantity.abs().toString() : '';
      _priceCtl.text = tx != null && tx.price > 0 ? tx.price.toString() : '';
    });
  }

  void _closeForm() => setState(() => _editingId = null);

  Future<void> _saveForm() async {
    final qty = double.tryParse(_qtyCtl.text);
    if (qty == null || qty <= 0) return;
    final price = double.tryParse(_priceCtl.text) ?? 0.0;
    final finalQty = _formIsBuy ? qty : -qty;

    final tx = StockTransaction(
      id: (_editingId == null || _editingId!.isEmpty) ? _uid() : _editingId!,
      date: _formDate,
      quantity: finalQty,
      price: price,
    );

    await context.read<PortfolioProvider>().upsertTransaction(
        widget.portfolio.id, widget.item.id, tx);
    _closeForm();
  }

  Future<void> _deleteFromForm() async {
    if (_editingId == null || _editingId!.isEmpty) return;
    await context.read<PortfolioProvider>().deleteTransaction(
        widget.portfolio.id, widget.item.id, _editingId!);
    _closeForm();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 최신 item 데이터 가져오기
    final provider = context.watch<PortfolioProvider>();
    final pf = provider.getPortfolio(widget.portfolio.id);
    final item = pf?.items.where((i) => i.id == widget.item.id).firstOrNull
        ?? widget.item;
    final txs = [...item.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    final priceSuffix = item.market == 'US' ? 'USD' : 'KRW';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtl) {
        return Container(
          color: context.cardBg,
          child: Column(children: [
            // 핸들 + 제목
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Text(item.name,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(l10n.transactionHistory,
                      style: TextStyle(fontSize: 14, color: context.textSecondary)),
                ]),
                const SizedBox(height: 14),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtl,
                padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
                child: Column(children: [
                  // 거래 목록
                  if (txs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(l10n.addTransaction,
                          style: TextStyle(color: context.textHint)),
                    ),
                  ...txs.map((tx) => _buildTxRow(context, tx, priceSuffix, l10n)),

                  const SizedBox(height: 8),

                  // 추가 폼 또는 버튼
                  if (_editingId == null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 16,
                            color: Color(0xFF3B82F6)),
                        label: Text(l10n.addTransaction,
                            style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    )
                  else if (_editingId == '')
                    _buildForm(context, priceSuffix, l10n, isNew: true),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildTxRow(BuildContext context, StockTransaction tx,
      String priceSuffix, dynamic l10n) {
    final isBuy = tx.quantity > 0;
    final color = isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final label = isBuy ? l10n.transactionBuy : l10n.transactionSell;
    final qtyStr = '${tx.quantity.abs().toStringAsFixed(tx.quantity.abs() == tx.quantity.abs().roundToDouble() ? 0 : 2)}${l10n.unitShares}';

    // 편집 중인 행인지 확인
    final isEditing = _editingId == tx.id;

    return Column(children: [
      InkWell(
        onTap: isEditing ? _closeForm : () => _openForm(tx: tx),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isEditing
                ? const Color(0xFF3B82F6).withValues(alpha: 0.08)
                : context.infoBoxBg,
            borderRadius: BorderRadius.circular(8),
            border: isEditing
                ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4))
                : null,
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
            const SizedBox(width: 8),
            Text(_fmtDate(tx.date),
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const Spacer(),
            Text(qtyStr,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            if (tx.price > 0) ...[
              const SizedBox(width: 8),
              Text(_fmtPrice(tx.price),
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ],
            const SizedBox(width: 6),
            Icon(isEditing ? Icons.expand_less : Icons.edit_outlined,
                size: 14, color: context.textHint),
          ]),
        ),
      ),
      if (isEditing)
        _buildForm(context, priceSuffix, l10n, isNew: false),
    ]);
  }

  Widget _buildForm(BuildContext context, String priceSuffix, dynamic l10n,
      {required bool isNew}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 매수/매도 선택
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l10n.transactionBuy, style: const TextStyle(fontSize: 13))),
            ButtonSegment(value: false, label: Text(l10n.transactionSell, style: const TextStyle(fontSize: 13))),
          ],
          selected: {_formIsBuy},
          onSelectionChanged: (s) => setState(() => _formIsBuy = s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 10),

        // 날짜 선택
        _formLabel(context, l10n.transactionDate),
        InkWell(
          onTap: () async {
            final picked = await showCustomDatePicker(
              context,
              initialDate: _formDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _formDate = picked);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: context.textHint),
              const SizedBox(width: 8),
              Text(_fmtDate(_formDate),
                  style: TextStyle(fontSize: 14, color: context.textPrimary)),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // 수량
        _formLabel(context, l10n.transactionQty),
        _formTextField(context, _qtyCtl, suffix: l10n.unitShares),
        const SizedBox(height: 4),

        // 단가
        _formLabel(context, l10n.transactionPrice),
        _formTextField(context, _priceCtl, suffix: priceSuffix),
        const SizedBox(height: 12),

        // 버튼
        Row(children: [
          if (!isNew)
            Expanded(
              child: OutlinedButton(
                onPressed: _deleteFromForm,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(l10n.deleteTransaction,
                    style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          if (!isNew) const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _closeForm,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(l10n.cancel,
                  style: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _saveForm,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3B82F6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(l10n.save,
                  style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _formLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondary)),
      );

  Widget _formTextField(BuildContext context, TextEditingController ctl,
      {String? suffix}) {
    return TextField(
      controller: ctl,
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 14, color: context.textPrimary),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: TextStyle(color: context.textSecondary),
        filled: true,
        fillColor: context.cardBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.borderColor)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
    );
  }
}
