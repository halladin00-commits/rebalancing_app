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
  late TextEditingController _thresholdCtl;
  String? _errorText;

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
    _thresholdCtl = TextEditingController(text: pf.rebalancingThreshold.toString());
  }

  @override
  void dispose() {
    _commRateCtl.dispose();
    _exRateCtl.dispose();
    _thresholdCtl.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;

    final commRate = double.tryParse(_commRateCtl.text);
    if (_commEnabled && (commRate == null || commRate < 0)) {
      setState(() => _errorText = l10n.validationNonNegative);
      return;
    }

    if (!_exAuto) {
      final exRate = double.tryParse(_exRateCtl.text);
      if (exRate == null || exRate <= 0) {
        setState(() => _errorText = l10n.validationExchangeRatePositive);
        return;
      }
    }

    widget.onSave({
      'currency': _currency,
      'commissionEnabled': _commEnabled,
      'commissionRate': commRate ?? 0,
      'exchangeAuto': _exAuto,
      'exchangeRate': double.tryParse(_exRateCtl.text) ?? 0,
      'priceAuto': _prAuto,
      'rebalancingThreshold': double.tryParse(_thresholdCtl.text) ?? 0.0,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(l10n.settings, style: TextStyle(color: context.textPrimary)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 기준 통화 ──
              _sectionHeader(context, l10n.baseCurrency),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    _segBtn(context, l10n.currencyKRW, _currency == 'KRW',
                        () => setState(() => _currency = 'KRW')),
                    _segBtn(context, l10n.currencyUSD, _currency == 'USD',
                        () => setState(() => _currency = 'USD')),
                  ]),
                ),
              ),

              // ── 주가 ──
              _sectionHeader(context, l10n.stockPriceSetting),
              _toggleRow(context, l10n.autoRealtime, _prAuto,
                  (v) => setState(() => _prAuto = v)),

              // ── 환율 ──
              _sectionHeader(context, l10n.exchangeRateSetting),
              _toggleRow(context, l10n.autoRealtime, _exAuto,
                  (v) => setState(() => _exAuto = v)),
              if (!_exAuto)
                _inputField(context, l10n.exchangeRateInput, _exRateCtl, l10n.unitKRW),

              // ── 리밸런싱 임계값 ──
              _sectionHeader(context, l10n.rebalancingThresholdLabel),
              _inputField(context, l10n.rebalancingThresholdHint, _thresholdCtl, '%'),

              // ── 거래 수수료 ──
              _sectionHeader(context, l10n.tradingFee),
              _toggleRow(context, l10n.includeFee, _commEnabled,
                  (v) => setState(() => _commEnabled = v)),
              if (_commEnabled)
                _inputField(context, l10n.feeRate, _commRateCtl, '%'),

              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      color: context.brandTint,
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
            style: TextStyle(fontSize: 12, color: context.textSecondary)),
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

  Widget _segBtn(BuildContext context, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1D4ED8) : Colors.transparent,
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
