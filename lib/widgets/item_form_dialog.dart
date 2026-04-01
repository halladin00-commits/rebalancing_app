import 'dart:async';
import 'package:flutter/material.dart';
import '../models/portfolio.dart';
import '../services/stock_search_service.dart';

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
  late TextEditingController _weightCtl;
  late TextEditingController _sharesCtl;
  late bool _isCash;
  String _detectedMarket = 'KR';
  String _ticker = '';

  List<StockSearchResult> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;
  Timer? _debounce;

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
    _weightCtl.dispose();
    _sharesCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _showResults = false; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await StockSearchService.search(query);
      if (mounted) {
        setState(() { _searchResults = results; _showResults = results.isNotEmpty; _searching = false; });
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
    widget.onSave(PortfolioItem(
      id: widget.item?.id ?? _uid(),
      name: _nameCtl.text.trim(),
      ticker: _isCash ? '' : _ticker,
      market: _isCash ? 'CASH' : _detectedMarket,
      isCash: _isCash,
      targetWeight: double.tryParse(_weightCtl.text) ?? 0,
      shares: double.tryParse(_sharesCtl.text) ?? 0,
      currentPrice: _isCash ? 1 : (double.tryParse(_priceCtl.text) ?? 0),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final marketLabel = _detectedMarket == 'US' ? '🇺🇸 미국' : '🇰🇷 한국';
    final priceSuffix = _detectedMarket == 'US' ? 'USD' : 'KRW';

    return AlertDialog(
      title: Text(isEdit ? '종목 수정' : '종목 추가'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 현금 토글
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('현금 항목',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Switch(value: _isCash, onChanged: (v) => setState(() => _isCash = v)),
                ],
              ),

              if (!_isCash) ...[
                // ── 종목 검색 ──
                _label('종목 검색'),
                TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: '종목명, ETF명 또는 티커 입력',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                ),

                // 검색 결과
                if (_showResults)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                      itemBuilder: (ctx, idx) {
                        final s = _searchResults[idx];
                        return InkWell(
                          onTap: () => _selectStock(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: s.market == 'US' ? const Color(0xFFF5F3FF) : const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(s.market, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                    color: s.market == 'US' ? const Color(0xFF7C3AED) : const Color(0xFF0369A1))),
                              ),
                              if (s.isEtf) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('ETF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                      color: Color(0xFF92400E))),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                Text(s.ticker, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                              ])),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                if (!_showResults) const SizedBox(height: 8),
              ],

              // ── 종목명 ──
              _label('종목명'),
              _textField(_nameCtl, _isCash ? '예: 예수금' : '검색으로 자동 입력'),

              if (!_isCash) ...[
                // ── 종목 코드 / 티커 (읽기 전용) ──
                _label('종목 코드 / 티커'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _ticker.isNotEmpty ? _ticker : '검색으로 자동 입력',
                          style: TextStyle(
                            fontSize: 15,
                            color: _ticker.isNotEmpty ? Colors.black87 : Colors.grey[400],
                          ),
                        ),
                      ),
                      if (_ticker.isNotEmpty)
                        GestureDetector(
                          onTap: _clearStock,
                          child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // 시장 뱃지
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _detectedMarket == 'US' ? const Color(0xFFF5F3FF) : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _detectedMarket == 'US' ? const Color(0xFF7C3AED) : const Color(0xFF0369A1)),
                    ),
                    child: Text(marketLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: _detectedMarket == 'US' ? const Color(0xFF7C3AED) : const Color(0xFF0369A1))),
                  ),
                ),

                // ── 현재가 ──
                _label('현재가'),
                _textField(_priceCtl, widget.priceAuto ? '자동 업데이트' : '0',
                    suffix: priceSuffix, number: true, enabled: !widget.priceAuto),
                if (widget.priceAuto)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('새로고침 시 자동으로 업데이트',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600])),
                  ),
              ],

              // ── 목표 비중 ──
              _label('목표 비중'),
              _textField(_weightCtl, '0', suffix: '%', number: true),

              // ── 보유 수량 ──
              _label(_isCash ? '보유 금액' : '보유 수량'),
              _textField(_sharesCtl, '0',
                  suffix: _isCash ? (widget.currency == 'USD' ? 'USD' : '원') : '주',
                  number: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
            onPressed: _nameCtl.text.trim().isEmpty ? null : _save,
            child: Text(isEdit ? '수정 완료' : '추가')),
      ],
    );
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));

  Widget _textField(TextEditingController ctl, String hint,
      {String? suffix, bool number = false, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: ctl,
        enabled: enabled,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          suffixText: suffix,
          filled: true,
          fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFE5E7EB),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
