import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/share_format.dart';
import '../widgets/custom_date_picker.dart';
import '../widgets/list_card.dart';

/// 종목 직접 등록 · 편집.
///
/// 개편 전에는 다이얼로그 안에 검색창까지 들어 있었다. 검색은 이제
/// `ItemSearchScreen`이 맡으므로 여기는 **입력만** 한다.
/// 거래 추가 화면(v15a)과 같은 골격을 쓴다 — 두 입력이 같은 문법이어야 한다.
class ItemFormScreen extends StatefulWidget {
  /// 편집할 종목. 없으면 새로 만든다.
  final PortfolioItem? item;

  /// 미리 채워 둘 값 (검색 결과에서 넘어올 때).
  final PortfolioItem? preset;

  final bool priceAuto;
  final String currency;
  final void Function(PortfolioItem) onSave;

  const ItemFormScreen({
    super.key,
    this.item,
    this.preset,
    this.priceAuto = false,
    this.currency = 'KRW',
    required this.onSave,
  });

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _weightCtl;
  late final TextEditingController _sharesCtl;
  late final TextEditingController _avgCtl;
  late final TextEditingController _priceCtl;

  late bool _isCash;
  late String _market;
  late String _ticker;
  DateTime _purchaseDate = DateTime.now();
  String? _error;

  bool get _isEdit => widget.item != null;

  /// 편집일 때 수량은 잠근다 — 보유 수량은 거래 내역에서 계산되는 결과다.
  /// 여기서 직접 고치면 거래와 어긋난다.
  bool get _sharesLocked => _isEdit && widget.item!.transactions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final src = widget.item ?? widget.preset;
    _isCash = src?.isCash ?? false;
    _market = src?.market ?? 'KR';
    _ticker = src?.ticker ?? '';
    _nameCtl = TextEditingController(text: src?.name ?? '');
    _weightCtl = TextEditingController(
        text: (src?.targetWeight ?? 0) == 0 ? '' : _trim(src!.targetWeight));
    _sharesCtl = TextEditingController(
        text: (src?.shares ?? 0) == 0 ? '' : formatShares(src!.shares));
    _avgCtl = TextEditingController(
        text: (src?.avgPrice ?? 0) == 0 ? '' : _trim(src!.avgPrice));
    _priceCtl = TextEditingController(
        text: (src?.currentPrice ?? 0) == 0 ? '' : _trim(src!.currentPrice));
  }

  @override
  void dispose() {
    for (final c in [_nameCtl, _weightCtl, _sharesCtl, _avgCtl, _priceCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      DateTime.now().microsecond.toRadixString(36);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
            children: [
              if (!_isEdit) _buildKindSegment(context),
              if (!_isEdit) const SizedBox(height: 9),
              ListCard(rows: [
                _textRow(context, l10n.itemName, _nameCtl,
                    hint: l10n.itemNameHint),
                _numRow(context, l10n.targetWeight, _weightCtl, suffix: '%'),
                if (!_isCash) ...[
                  _numRow(context, l10n.holdingQty, _sharesCtl,
                      suffix: l10n.unitShares,
                      enabled: !_sharesLocked,
                      note: _sharesLocked ? l10n.basedOnTransactions : null),
                  _numRow(context, l10n.avgCost, _avgCtl, prefix: _sym),
                  if (!widget.priceAuto)
                    _numRow(context, l10n.currentPrice, _priceCtl,
                        prefix: _sym),
                ] else
                  _numRow(context, l10n.evaluationAmount, _sharesCtl,
                      prefix: _sym),
                if (!_isEdit && !_isCash) _dateRow(context),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.danger)),
              ],
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 15, color: context.textTertiary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _isCash ? l10n.cashFormNote : l10n.itemFormNote,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        color: context.textSecondary),
                  ),
                ),
              ]),
            ],
          ),
        ),
        _buildCta(context),
      ]),
    );
  }

  // ── 헤더 ──

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
          child: SizedBox(
            height: 52,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(_isEdit ? l10n.editItem : l10n.addStock,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Colors.white)),
              ),
              if (!_isCash && _ticker.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(DS.chipRadius),
                  ),
                  child: Text(_ticker,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              const SizedBox(width: 14),
            ]),
          ),
        ),
      ),
    );
  }

  String get _sym => _isCash
      ? (widget.currency == 'USD' ? '\$' : '₩')
      : (_market == 'US' ? '\$' : '₩');

  // ── 종류 (국내 / 해외 / 현금) ──

  Widget _buildKindSegment(BuildContext context) {
    final l10n = context.l10n;
    final kinds = <(String, String)>[
      ('KR', l10n.filterKr),
      ('US', l10n.filterUs),
      ('CASH', l10n.cash),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.trackBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        for (final (code, label) in kinds) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isCash = code == 'CASH';
                if (!_isCash) _market = code;
                _error = null;
              }),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (_isCash ? 'CASH' : _market) == code
                      ? context.brand
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: (_isCash ? 'CASH' : _market) == code
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: (_isCash ? 'CASH' : _market) == code
                            ? Colors.white
                            : context.textSecondary)),
              ),
            ),
          ),
          if (code != 'CASH') const SizedBox(width: 6),
        ],
      ]),
    );
  }

  // ── 입력 행 ──

  Widget _textRow(BuildContext context, String label,
      TextEditingController ctl,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ),
        Expanded(
          flex: 3,
          child: TextField(
            controller: ctl,
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: hint,
              hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textHint),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _numRow(BuildContext context, String label,
      TextEditingController ctl,
      {String? prefix,
      String? suffix,
      bool enabled = true,
      String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
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
        if (prefix != null)
          Text(prefix,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? context.textPrimary : context.textDisabled)),
        SizedBox(
          width: 120,
          child: TextField(
            controller: ctl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: enabled ? context.textPrimary : context.textDisabled),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              hintText: '0',
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 3),
          Text(suffix,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ],
      ]),
    );
  }

  Widget _dateRow(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () async {
        final picked =
            await showCustomDatePicker(context, initialDate: _purchaseDate);
        if (picked != null) setState(() => _purchaseDate = picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(
            child: Text(l10n.purchaseDateLabel,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ),
          Text(
            '${_purchaseDate.year}.${_purchaseDate.month.toString().padLeft(2, '0')}.${_purchaseDate.day.toString().padLeft(2, '0')}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimary),
          ),
          const SizedBox(width: 8),
          Icon(Icons.calendar_month, size: 18, color: context.brand),
        ]),
      ),
    );
  }

  // ── 저장 ──

  Widget _buildCta(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: DS.buttonHeight,
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.buttonRadius)),
          ),
          child: Text(_isEdit ? l10n.saveChanges : l10n.add,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  void _save() {
    final l10n = context.l10n;
    if (_nameCtl.text.trim().isEmpty) {
      setState(() => _error = l10n.validationNameRequired);
      return;
    }
    final weight = double.tryParse(_weightCtl.text.trim()) ?? 0;
    final shares = double.tryParse(_sharesCtl.text.trim()) ?? 0;
    final price = _isCash ? 1.0 : (double.tryParse(_priceCtl.text.trim()) ?? 0);
    final avg = _isCash ? 0.0 : (double.tryParse(_avgCtl.text.trim()) ?? 0);

    if (weight < 0 || shares < 0 || avg < 0) {
      setState(() => _error = l10n.validationNonNegative);
      return;
    }
    if (!_isCash && !widget.priceAuto && price <= 0) {
      setState(() => _error = l10n.validationPositive);
      return;
    }

    // 새로 만들면서 수량을 넣으면 그만큼의 매수 거래를 하나 만들어 둔다.
    // 그래야 결산이 이 종목을 계산에 넣을 수 있다.
    var txs = widget.item?.transactions ?? const <StockTransaction>[];
    if (!_isEdit && !_isCash && shares > 0) {
      txs = [
        StockTransaction(
            id: _uid(), date: _purchaseDate, quantity: shares, price: avg),
      ];
    }

    widget.onSave(PortfolioItem(
      id: widget.item?.id ?? _uid(),
      name: _nameCtl.text.trim(),
      ticker: _isCash ? '' : _ticker,
      market: _isCash ? 'CASH' : _market,
      isCash: _isCash,
      targetWeight: weight,
      shares: shares,
      currentPrice: _isCash ? 1.0 : price,
      avgPrice: avg,
      transactions: List.of(txs),
    ));
    Navigator.pop(context);
  }
}
