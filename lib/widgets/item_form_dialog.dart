import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../services/stock_search_service.dart';
import 'custom_date_picker.dart';

class ItemFormDialog extends StatefulWidget {
  final PortfolioItem? item;
  final bool priceAuto;
  final String currency;
  final Function(PortfolioItem) onSave;

  const ItemFormDialog({
    super.key,
    this.item,
    this.priceAuto = false,
    this.currency = 'KRW',
    required this.onSave,
  });

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  late TextEditingController _searchCtl;
  late TextEditingController _nameCtl;
  late TextEditingController _priceCtl;
  late TextEditingController _avgPriceCtl;
  late TextEditingController _weightCtl;
  late TextEditingController _sharesCtl;
  late bool _isCash;
  String _detectedMarket = 'KR';
  String _ticker = '';
  DateTime _purchaseDate = DateTime.now();

  final _avgPriceFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _sharesFocus = FocusNode();

  List<StockSearchResult> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;
  Timer? _debounce;
  String? _errorText;

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);

  String _cleanNum(double n) {
    if (n == n.roundToDouble() && n == n.toInt().toDouble()) {
      return n.toInt().toString();
    }
    return n.toString();
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _searchCtl = TextEditingController();
    _nameCtl = TextEditingController(text: item?.name ?? '');
    _ticker = item?.ticker ?? '';
    _priceCtl = TextEditingController(
        text: item != null && !item.isCash ? _cleanNum(item.currentPrice) : '');
    _avgPriceCtl = TextEditingController(
        text: item != null && !item.isCash && item.avgPrice > 0 ? _cleanNum(item.avgPrice) : '');
    _weightCtl = TextEditingController(
        text: item != null ? _cleanNum(item.targetWeight) : '');
    _sharesCtl = TextEditingController(
        text: item != null ? _cleanNum(item.shares) : '');
    _isCash = item?.isCash ?? false;
    if (item != null && item.market != 'CASH') {
      _detectedMarket = item.market;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    _nameCtl.dispose();
    _priceCtl.dispose();
    _avgPriceCtl.dispose();
    _weightCtl.dispose();
    _sharesCtl.dispose();
    _avgPriceFocus.dispose();
    _weightFocus.dispose();
    _sharesFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await StockSearchService.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _showResults = results.isNotEmpty;
          _searching = false;
        });
      }
    });
  }

  void _selectStock(StockSearchResult stock) {
    setState(() {
      _nameCtl.text = stock.name;
      _ticker = stock.ticker;
      _detectedMarket = stock.market;
      _searchCtl.clear();
      _searchResults = [];
      _showResults = false;
    });
  }

  void _clearStock() {
    setState(() {
      _nameCtl.clear();
      _ticker = '';
    });
  }

  void _save() {
    if (_nameCtl.text.trim().isEmpty) return;
    final l10n = context.l10n;

    final weight = double.tryParse(_weightCtl.text);
    final shares = double.tryParse(_sharesCtl.text);
    final price = _isCash ? 1.0 : double.tryParse(_priceCtl.text);

    if (weight == null || weight < 0) {
      setState(() => _errorText = l10n.validationNonNegative);
      return;
    }
    if (shares == null || shares < 0) {
      setState(() => _errorText = l10n.validationNonNegative);
      return;
    }
    if (!_isCash && !widget.priceAuto && (price == null || price <= 0)) {
      setState(() => _errorText = l10n.validationPositive);
      return;
    }

    final avgPrice = _isCash ? 0.0 : (double.tryParse(_avgPriceCtl.text) ?? 0.0);
    final isAdd = widget.item == null;

    List<StockTransaction> transactions = widget.item?.transactions ?? [];
    if (isAdd && !_isCash && shares > 0) {
      transactions = [
        StockTransaction(
          id: _uid(),
          date: _purchaseDate,
          quantity: shares,
          price: avgPrice,
        ),
      ];
    }

    widget.onSave(PortfolioItem(
      id: widget.item?.id ?? _uid(),
      name: _nameCtl.text.trim(),
      ticker: _isCash ? '' : _ticker,
      market: _isCash ? 'CASH' : _detectedMarket,
      isCash: _isCash,
      targetWeight: weight,
      shares: shares,
      currentPrice: _isCash ? 1.0 : (price ?? 0.0),
      avgPrice: avgPrice < 0 ? 0.0 : avgPrice,
      transactions: transactions,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEdit = widget.item != null;
    final marketLabel = _detectedMarket == 'US' ? '🇺🇸 US' : '🇰🇷 KR';
    final priceSuffix = _detectedMarket == 'US' ? 'USD' : 'KRW';
    final isUS = _detectedMarket == 'US';

    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(isEdit ? l10n.editStockTitle : l10n.addStockTitle,
          style: TextStyle(color: context.textPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.cashItem,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary)),
                  Switch(value: _isCash, onChanged: (v) => setState(() => _isCash = v)),
                ],
              ),

              if (!_isCash) ...[
                _label(context, l10n.searchStock),
                TextField(
                  controller: _searchCtl,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    hintStyle: TextStyle(color: context.textHint),
                    prefixIcon: Icon(Icons.search, size: 20, color: context.textHint),
                    suffixIcon: _searching
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: context.textSecondary)))
                        : null,
                    filled: true,
                    fillColor: context.fieldFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.borderColor)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                ),

                if (_showResults)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: context.dividerColor),
                      itemBuilder: (ctx, idx) {
                        final s = _searchResults[idx];
                        final isUSStock = s.market == 'US';
                        return InkWell(
                          onTap: () => _selectStock(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isUSStock
                                      ? const Color(0xFF7C3AED).withValues(alpha: context.isDark ? 0.25 : 0.08)
                                      : const Color(0xFF0369A1).withValues(alpha: context.isDark ? 0.25 : 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(s.market,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isUSStock
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFF0369A1))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                    Text(s.name,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: context.textPrimary),
                                        overflow: TextOverflow.ellipsis),
                                    Text(s.ticker,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: context.textSecondary)),
                                  ])),
                              if (s.isEtf)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(l10n.etfBadge,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber)),
                                ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                if (!_showResults) const SizedBox(height: 8),
              ],

              _label(context, l10n.stockName),
              _textField(context, _nameCtl, _isCash ? l10n.cashNameHint : l10n.autoFillHint),

              if (!_isCash) ...[
                _label(context, l10n.stockCodeTicker),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.disabledFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _ticker.isNotEmpty ? _ticker : l10n.autoFillHint,
                        style: TextStyle(
                          fontSize: 15,
                          color: _ticker.isNotEmpty ? context.textPrimary : context.textHint,
                        ),
                      ),
                    ),
                    if (_ticker.isNotEmpty)
                      GestureDetector(
                        onTap: _clearStock,
                        child: Icon(Icons.close, size: 18, color: context.textHint),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),

                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUS
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                          : const Color(0xFF0369A1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: isUS
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                              : const Color(0xFF0369A1).withValues(alpha: 0.5)),
                    ),
                    child: Text(marketLabel,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isUS
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF0369A1))),
                  ),
                ),

                _label(context, l10n.currentPrice),
                _textField(context, _priceCtl,
                    widget.priceAuto ? l10n.autoUpdate : '0',
                    suffix: priceSuffix,
                    number: true,
                    enabled: !widget.priceAuto),
                if (widget.priceAuto)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l10n.autoUpdateHint,
                        style: TextStyle(fontSize: 12, color: Colors.blue[400])),
                  ),

                _label(context, l10n.avgCost),
                _textField(context, _avgPriceCtl, '0',
                    suffix: priceSuffix, number: true,
                    focusNode: _avgPriceFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: () => _weightFocus.requestFocus()),
              ],

              _label(context, l10n.targetWeightLabel),
              _textField(context, _weightCtl, '0', suffix: '%', number: true,
                  focusNode: _weightFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: () => _sharesFocus.requestFocus()),

              if (!_isCash && widget.item == null) ...[
                _label(context, l10n.purchaseDateLabel),
                _datePicker(context),
              ],

              _label(context, _isCash ? l10n.holdingsAmount : l10n.holdingsShares),
              if (!_isCash && widget.item != null) ...[
                _textField(context, _sharesCtl, '0',
                    suffix: l10n.unitShares,
                    number: true,
                    enabled: false),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 2),
                  child: Text(l10n.holdingsFromTransactions,
                      style: TextStyle(fontSize: 12, color: Colors.blue[400])),
                ),
              ] else
                _textField(context, _sharesCtl, '0',
                    suffix: _isCash
                        ? (widget.currency == 'USD' ? l10n.unitUSD : l10n.unitKRW)
                        : l10n.unitShares,
                    number: true,
                    focusNode: _sharesFocus,
                    textInputAction: TextInputAction.done),
            ],
          ),
        ),
      ),
      if (_errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _errorText!,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
        ),
    ],
  ),
),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(
            onPressed: _nameCtl.text.trim().isEmpty ? null : _save,
            child: Text(isEdit ? l10n.saveChanges : l10n.add)),
      ],
    );
  }

  Widget _datePicker(BuildContext context) {
    final fmt = '${_purchaseDate.year}.${_purchaseDate.month.toString().padLeft(2, '0')}.${_purchaseDate.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () async {
          final picked = await showCustomDatePicker(
            context,
            initialDate: _purchaseDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _purchaseDate = picked);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: context.fieldFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: context.textHint),
            const SizedBox(width: 8),
            Text(fmt, style: TextStyle(fontSize: 15, color: context.textPrimary)),
          ]),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimary)));

  Widget _textField(
      BuildContext context, TextEditingController ctl, String hint,
      {String? suffix, bool number = false, bool enabled = true,
      FocusNode? focusNode, TextInputAction? textInputAction, VoidCallback? onSubmitted}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: ctl,
        enabled: enabled,
        focusNode: focusNode,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        textInputAction: textInputAction,
        style: TextStyle(
            color: enabled ? context.textPrimary : context.textSecondary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textHint),
          suffixText: suffix,
          suffixStyle: TextStyle(color: context.textSecondary),
          filled: true,
          fillColor: enabled ? context.fieldFill : context.disabledFill,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      ),
    );
  }
}
