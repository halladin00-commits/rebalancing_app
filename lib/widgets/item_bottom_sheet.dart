import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';

class ItemBottomSheet extends StatefulWidget {
  final PortfolioItem item;
  final Portfolio portfolio;
  final RebalanceResult? rb;
  const ItemBottomSheet(
      {super.key, required this.item, required this.portfolio, this.rb});

  @override
  State<ItemBottomSheet> createState() => _ItemBottomSheetState();
}

class _ItemBottomSheetState extends State<ItemBottomSheet> {
  bool _editMode = false;
  late TextEditingController _priceCtl;
  late TextEditingController _sharesCtl;
  late TextEditingController _weightCtl;

  @override
  void initState() {
    super.initState();
    _priceCtl = TextEditingController(
        text: widget.item.currentPrice > 0
            ? _cleanNum(widget.item.currentPrice)
            : '');
    _sharesCtl = TextEditingController(text: _cleanNum(widget.item.shares));
    _weightCtl =
        TextEditingController(text: _cleanNum(widget.item.targetWeight));
  }

  @override
  void dispose() {
    _priceCtl.dispose();
    _sharesCtl.dispose();
    _weightCtl.dispose();
    super.dispose();
  }

  String _cleanNum(double n) {
    if (n == n.roundToDouble() && n == n.toInt().toDouble()) {
      return n.toInt().toString();
    }
    return n.toString();
  }

  String _fmt(double n, String cur) {
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtPrice(double n, String market) {
    if (market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _pct(double n) => '${n.toStringAsFixed(2)}%';

  void _save() {
    final provider = context.read<PortfolioProvider>();
    final newItem = widget.item.copyWith(
      currentPrice: widget.portfolio.priceAuto
          ? widget.item.currentPrice
          : (double.tryParse(_priceCtl.text) ?? widget.item.currentPrice),
      shares:
          double.tryParse(_sharesCtl.text) ?? widget.item.shares,
      targetWeight:
          double.tryParse(_weightCtl.text) ?? widget.item.targetWeight,
    );
    provider.updateItem(widget.portfolio.id, newItem);
    setState(() => _editMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final portfolio = widget.portfolio;
    final rb = widget.rb;

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
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: context.cardBg,
          child: Column(
            children: [
              // ── 핸들 + 헤더 ──
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
                    _marketBadge(context, item),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.name,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (item.ticker.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(item.ticker,
                          style: TextStyle(fontSize: 13, color: context.textHint)),
                    ],
                  ]),
                  const SizedBox(height: 14),
                ]),
              ),

              // ── 내용 (스크롤 가능) ──
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _editMode
                      ? _buildEditContent(context, item, portfolio)
                      : _buildViewContent(context, item, portfolio, tradeText),
                ),
              ),

              // ── 하단 버튼 ──
              Container(
                color: context.cardBg,
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, MediaQuery.of(context).padding.bottom + 12),
                child: _editMode
                    ? _buildEditFooter(context)
                    : _buildViewFooter(context, item, portfolio),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 일반 모드 내용 ──
  Widget _buildViewContent(BuildContext context, PortfolioItem item,
      Portfolio portfolio, String tradeText) {
    final r = widget.rb?.results.where((x) => x.id == item.id).firstOrNull;
    return Column(children: [
      _infoRow(context, '현재가',
          item.isCash ? '—' : _fmtPrice(item.currentPrice, item.market)),
      _infoRow(context, '보유 수량',
          item.isCash ? _fmt(item.shares, portfolio.currency) : '${item.shares.toInt()}주'),
      _infoRow(context, '목표 비중', _pct(item.targetWeight)),
      _infoRow(context, '현재 비중', r != null ? _pct(r.currentWeight) : '—'),
      _infoRow(context, '최종 비중', r != null ? _pct(r.finalWeight) : '—'),
      _infoRow(context, '매매', tradeText),
      if (item.market == 'US' && portfolio.currency == 'KRW' && !item.isCash) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: context.rowBg, borderRadius: BorderRadius.circular(8)),
          child: Text(
              '원화 환산가: ${_fmt(item.currentPrice * portfolio.exchangeRate, "KRW")}',
              style: TextStyle(fontSize: 13, color: context.textSecondary)),
        ),
      ],
    ]);
  }

  // ── 편집 모드 내용 ──
  Widget _buildEditContent(
      BuildContext context, PortfolioItem item, Portfolio portfolio) {
    final priceEditable = !portfolio.priceAuto && !item.isCash;
    final priceSuffix = item.market == 'US' ? 'USD' : 'KRW';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!item.isCash) ...[
        _editLabel(context, '현재가'),
        _editField(
          context, _priceCtl,
          hint: portfolio.priceAuto ? '자동 업데이트' : '0',
          suffix: priceSuffix,
          enabled: priceEditable,
        ),
        if (portfolio.priceAuto)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('주가 자동 업데이트 설정 중 — 새로고침으로 갱신',
                style: TextStyle(fontSize: 11, color: Colors.blue[400])),
          ),
      ],
      _editLabel(context, item.isCash ? '보유 금액' : '보유 수량'),
      _editField(context, _sharesCtl,
          hint: '0',
          suffix: item.isCash
              ? (portfolio.currency == 'USD' ? 'USD' : '원')
              : '주'),
      _editLabel(context, '목표 비중'),
      _editField(context, _weightCtl, hint: '0', suffix: '%'),
    ]);
  }

  // ── 일반 모드 푸터: [편집] [닫기] ──
  Widget _buildViewFooter(
      BuildContext context, PortfolioItem item, Portfolio portfolio) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: item.isCash
              ? null
              : () => setState(() => _editMode = true),
          icon: Icon(Icons.edit_outlined, size: 16,
              color: item.isCash ? context.textHint : const Color(0xFF3B82F6)),
          label: Text('편집',
              style: TextStyle(
                  color: item.isCash ? context.textHint : const Color(0xFF3B82F6),
                  fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: item.isCash
                    ? context.borderColor
                    : const Color(0xFF3B82F6)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.borderColor),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('닫기',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ),
      ),
    ]);
  }

  // ── 편집 모드 푸터: [취소] [저장] ──
  Widget _buildEditFooter(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => setState(() => _editMode = false),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.borderColor),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('취소',
              style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: context.infoBoxBg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: context.textSecondary)),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _editLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
      );

  Widget _editField(BuildContext context, TextEditingController ctl,
      {required String hint, String? suffix, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: ctl,
        enabled: enabled,
        keyboardType: TextInputType.number,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _marketBadge(BuildContext context, PortfolioItem item) {
    Color color;
    String text;
    if (item.isCash) { text = '현금'; color = const Color(0xFF65A30D); }
    else if (item.market == 'US') { text = 'US'; color = const Color(0xFF7C3AED); }
    else { text = 'KR'; color = const Color(0xFF0369A1); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
