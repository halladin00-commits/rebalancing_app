import 'package:flutter/material.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../widgets/brand_header.dart';
import '../widgets/list_card.dart';

/// 포트폴리오 설정.
///
/// 다이얼로그 안에 섹션 헤더 다섯 개를 쌓고 있었다. 화면 절반에 그걸 다 넣으니
/// 스크롤이 생기고, 값을 고치려 키보드를 올리면 아래가 잘렸다.
/// 다른 입력 화면들과 같은 골격으로 옮긴다.
class PortfolioSettingsScreen extends StatefulWidget {
  final Portfolio portfolio;
  final void Function(Map<String, dynamic>) onSave;

  const PortfolioSettingsScreen({
    super.key,
    required this.portfolio,
    required this.onSave,
  });

  @override
  State<PortfolioSettingsScreen> createState() =>
      _PortfolioSettingsScreenState();
}

class _PortfolioSettingsScreenState extends State<PortfolioSettingsScreen> {
  late String _currency;
  late bool _priceAuto;
  late bool _exAuto;
  late bool _commEnabled;
  late final TextEditingController _exRateCtl;
  late final TextEditingController _commRateCtl;
  late final TextEditingController _thresholdCtl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final pf = widget.portfolio;
    _currency = pf.currency;
    _priceAuto = pf.priceAuto;
    _exAuto = pf.exchangeAuto;
    _commEnabled = pf.commissionEnabled;
    _exRateCtl = TextEditingController(text: _trim(pf.exchangeRate));
    _commRateCtl = TextEditingController(text: _trim(pf.commissionRate));
    _thresholdCtl = TextEditingController(text: _trim(pf.rebalancingThreshold));
  }

  @override
  void dispose() {
    for (final c in [_exRateCtl, _commRateCtl, _thresholdCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        BrandHeader(
          title: l10n.settings,
          titleSize: 17,
          titleWeight: FontWeight.w700,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          childPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Text(widget.portfolio.name,
              style: TextStyle(
                  fontSize: DS.body,
                  fontWeight: FontWeight.w600,
                  color: context.onBrandSecondary),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              SectionTitle(title: l10n.baseCurrency),
              const SizedBox(height: DS.cardGap),
              _buildCurrencySegment(context),
              const SizedBox(height: 16),

              SectionTitle(title: l10n.autoUpdateSection),
              const SizedBox(height: DS.cardGap),
              ListCard(rows: [
                _toggle(context, l10n.stockPriceSetting, _priceAuto,
                    (v) => setState(() => _priceAuto = v)),
                _toggle(context, l10n.exchangeRateSetting, _exAuto,
                    (v) => setState(() => _exAuto = v)),
                if (!_exAuto)
                  _numField(context, l10n.exchangeRateInput, _exRateCtl,
                      suffix: l10n.unitKRW),
              ]),
              const SizedBox(height: 16),

              SectionTitle(title: l10n.rebalancingThresholdLabel),
              const SizedBox(height: DS.cardGap),
              ListCard(rows: [
                _numField(context, l10n.rebalancingThresholdHint,
                    _thresholdCtl,
                    suffix: '%p'),
              ]),
              const SizedBox(height: 6),
              _note(context, l10n.thresholdNote),
              const SizedBox(height: 16),

              SectionTitle(title: l10n.tradingFee),
              const SizedBox(height: DS.cardGap),
              ListCard(rows: [
                _toggle(context, l10n.includeFee, _commEnabled,
                    (v) => setState(() => _commEnabled = v)),
                if (_commEnabled)
                  _numField(context, l10n.feeRate, _commRateCtl, suffix: '%'),
              ]),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.danger)),
              ],
            ],
          ),
        ),
        _buildCta(context),
      ]),
    );
  }

  Widget _buildCurrencySegment(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.trackBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        for (final (code, label) in [
          ('KRW', l10n.currencyKRW),
          ('USD', l10n.currencyUSD),
        ]) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currency = code),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _currency == code ? context.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _currency == code
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: _currency == code
                            ? Colors.white
                            : context.textSecondary)),
              ),
            ),
          ),
          if (code == 'KRW') const SizedBox(width: 6),
        ],
      ]),
    );
  }

  Widget _toggle(BuildContext context, String label, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

  Widget _numField(BuildContext context, String label,
      TextEditingController ctl,
      {String? suffix}) {
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
        SizedBox(
          width: 110,
          child: TextField(
            controller: ctl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimary),
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

  Widget _note(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: context.textSecondary)),
    );
  }

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
          child: Text(l10n.save,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  void _save() {
    final l10n = context.l10n;
    final commRate = double.tryParse(_commRateCtl.text.trim());
    if (_commEnabled && (commRate == null || commRate < 0)) {
      setState(() => _error = l10n.validationNonNegative);
      return;
    }
    final exRate = double.tryParse(_exRateCtl.text.trim());
    if (!_exAuto && (exRate == null || exRate <= 0)) {
      setState(() => _error = l10n.validationExchangeRatePositive);
      return;
    }
    final threshold = double.tryParse(_thresholdCtl.text.trim()) ?? 0.0;
    if (threshold < 0) {
      setState(() => _error = l10n.validationNonNegative);
      return;
    }

    widget.onSave({
      'currency': _currency,
      'commissionEnabled': _commEnabled,
      'commissionRate': commRate ?? 0,
      'exchangeAuto': _exAuto,
      'exchangeRate': exRate ?? widget.portfolio.exchangeRate,
      'priceAuto': _priceAuto,
      'rebalancingThreshold': threshold,
    });
    Navigator.pop(context);
  }
}
