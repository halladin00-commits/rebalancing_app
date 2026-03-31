import 'package:flutter/material.dart';
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
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('설정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기준 통화
            _section('기준 통화'),
            Row(
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
                        backgroundColor:
                            sel ? const Color(0xFFEFF6FF) : Colors.white,
                        side: BorderSide(
                          color: sel
                              ? const Color(0xFF3B82F6)
                              : Colors.grey[300]!,
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
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // 거래 수수료
            _section('거래 수수료'),
            _toggleRow('수수료 반영', _commEnabled,
                (v) => setState(() => _commEnabled = v)),
            if (_commEnabled) ...[
              const SizedBox(height: 4),
              _labeledField('수수료율', _commRateCtl, '%'),
            ],

            // 환율
            _section('환율'),
            _toggleRow(
                '자동 (실시간)', _exAuto, (v) => setState(() => _exAuto = v)),
            if (!_exAuto) ...[
              const SizedBox(height: 4),
              _labeledField('환율 (1 USD)', _exRateCtl, '원'),
            ],
            if (_exAuto)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('새로고침 버튼으로 최신 환율을 가져옵니다',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600])),
              ),

            // 주가
            _section('주가'),
            _toggleRow(
                '자동 (실시간)', _prAuto, (v) => setState(() => _prAuto = v)),
            if (_prAuto)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('새로고침 시 종목코드/티커 기준으로 현재가를 가져옵니다',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600])),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 0.5)),
      );

  Widget _toggleRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _labeledField(
      String label, TextEditingController ctl, String suffix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
