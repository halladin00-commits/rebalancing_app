import 'package:flutter/material.dart';
import '../main.dart';
import '../models/portfolio.dart';

class SettingsDialog extends StatefulWidget {
  final Portfolio portfolio;
  final Function(Map<String, dynamic>) onSave;

  const SettingsDialog({
    super.key,
    required this.portfolio,
    required this.onSave,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late String _currency;
  late bool _commEnabled;
  late TextEditingController _commRateCtl;
  late bool _exAuto;
  late TextEditingController _exRateCtl;
  late bool _prAuto;
  late bool _compactAmount;

  @override
  void initState() {
    super.initState();
    final pf = widget.portfolio;
    _currency = pf.currency;
    _commEnabled = pf.commissionEnabled;
    _commRateCtl = TextEditingController(text: pf.commissionRate.toString());
    _exAuto = pf.exchangeAuto;
    _exRateCtl = TextEditingController(text: pf.exchangeRate.toString());
    _prAuto = pf.priceAuto;
    _compactAmount = pf.compactAmount;
  }

  @override
  void dispose() {
    _commRateCtl.dispose();
    _exRateCtl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave({
      'currency': _currency,
      'commissionEnabled': _commEnabled,
      'commissionRate': double.tryParse(_commRateCtl.text) ?? 0,
      'exchangeAuto': _exAuto,
      'exchangeRate': double.tryParse(_exRateCtl.text) ?? 0,
      'priceAuto': _prAuto,
      'compactAmount': _compactAmount,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text('설정', style: TextStyle(color: context.textPrimary)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 기준 통화 ──
              _sectionHeader(context, '기준 통화'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: ['KRW', 'USD'].map((c) {
                    final sel = _currency == c;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: c == 'KRW' ? 4 : 0,
                            left: c == 'USD' ? 4 : 0),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currency = c),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: sel
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                                : Colors.transparent,
                            side: BorderSide(
                              color: sel
                                  ? const Color(0xFF3B82F6)
                                  : context.borderColor,
                              width: sel ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            c == 'KRW' ? '₩ 원화' : '\$ 달러',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? const Color(0xFF3B82F6)
                                  : context.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── 금액 표시 ──
              _sectionHeader(context, '금액 표시'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('현재 자산 / 리밸런싱 기준',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    _segBtn(context, '전체 표시', !_compactAmount,
                        () => setState(() => _compactAmount = false)),
                    _segBtn(context, '축약 표시', _compactAmount,
                        () => setState(() => _compactAmount = true)),
                  ]),
                ),
              ),

              // ── 거래 수수료 ──
              _sectionHeader(context, '거래 수수료'),
              _toggleRow(context, '수수료 반영', _commEnabled,
                  (v) => setState(() => _commEnabled = v)),
              if (_commEnabled)
                _inputField(context, '수수료율', _commRateCtl, '%'),

              // ── 환율 ──
              _sectionHeader(context, '환율'),
              _toggleRow(context, '자동 (실시간)', _exAuto,
                  (v) => setState(() => _exAuto = v)),
              if (!_exAuto)
                _inputField(context, '환율 (1 USD)', _exRateCtl, '원')
              else
                _hintText(context, '새로고침 버튼으로 최신 환율을 가져옵니다'),

              // ── 주가 ──
              _sectionHeader(context, '주가'),
              _toggleRow(context, '자동 (실시간)', _prAuto,
                  (v) => setState(() => _prAuto = v)),
              if (_prAuto)
                _hintText(
                    context, '새로고침 시 종목코드/티커 기준으로 현재가를 가져옵니다'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }

  // ── 섹션 헤더 (파란 배너) ──
  Widget _sectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3B82F6).withValues(alpha: context.isDark ? 0.15 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3B82F6),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _toggleRow(BuildContext context, String label, bool value,
      Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _inputField(
      BuildContext context, String label, TextEditingController ctl, String suffix) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                TextStyle(fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: TextStyle(color: context.textSecondary),
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
        ),
      ]),
    );
  }

  Widget _hintText(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6))),
    );
  }

  Widget _segBtn(BuildContext context, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF1D4ED8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active
                      ? const Color(0xFF93C5FD)
                      : context.textSecondary)),
        ),
      ),
    );
  }
}
