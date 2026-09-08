import 'package:flutter/material.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../widgets/brand_header.dart';
import '../utils/share_format.dart';
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
  late bool _fracEnabled;
  late FractionalRounding _fracRounding;
  late final TextEditingController _exRateCtl;
  late final TextEditingController _commRateCtl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final pf = widget.portfolio;
    _currency = pf.currency;
    _priceAuto = pf.priceAuto;
    _exAuto = pf.exchangeAuto;
    _commEnabled = pf.commissionEnabled;
    _fracEnabled = pf.fractionalEnabled;
    _fracRounding = pf.fractionalRounding;
    _exRateCtl = TextEditingController(text: _trim(pf.exchangeRate));
    _commRateCtl = TextEditingController(text: _trim(pf.commissionRate));
  }

  @override
  void dispose() {
    for (final c in [_exRateCtl, _commRateCtl]) {
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
            tooltip: context.l10n.a11yBack,
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

              SectionTitle(title: l10n.tradingFee),
              const SizedBox(height: DS.cardGap),
              ListCard(rows: [
                _toggle(context, l10n.includeFee, _commEnabled,
                    (v) => setState(() => _commEnabled = v)),
                if (_commEnabled)
                  _numField(context, l10n.feeRate, _commRateCtl, suffix: '%'),
              ]),
              const SizedBox(height: 16),

              // 소수점 매매가 되는지는 **계좌마다 다르다.** 그래서 앱 전체
              // 설정이 아니라 이 계좌의 설정이다. 예전에는 더보기 탭에 있어서
              // 어느 계좌 이야기인지 화면에서 드러나지 않았다.
              SectionTitle(title: l10n.fractionalTrading),
              const SizedBox(height: DS.cardGap),
              ListCard(rows: [
                _toggle(context, l10n.fractionalUse, _fracEnabled,
                    (v) => setState(() => _fracEnabled = v)),
              ]),
              const SizedBox(height: 6),
              _hint(context, l10n.fractionalIntro),
              if (_fracEnabled) ...[
                const SizedBox(height: 16),
                SectionTitle(title: l10n.fractionalRoundingTitle),
                const SizedBox(height: DS.cardGap),
                _buildRoundingCard(context),
              ],

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

  /// 목록 아래에 붙는 설명 한 줄.
  Widget _hint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Text(text,
          style: TextStyle(
              fontSize: DS.caption,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: context.textTertiary)),
    );
  }

  /// 수량을 어떻게 맞출지.
  ///
  /// 예전에는 소수점을 켠 **모든** 계좌에 같은 규칙을 걸었다. 계좌마다
  /// 증권사가 다른데 규칙만 묶여 있을 이유가 없다 — 이 계좌 것만 정한다.
  Widget _buildRoundingCard(BuildContext context) {
    return ListCard(rows: [
      for (final r in FractionalRounding.values)
        InkWell(
          onTap: () => setState(() => _fracRounding = r),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_roundingLabel(context, r),
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary)),
                    const SizedBox(height: 3),
                    Text(_roundingDesc(context, r),
                        style: TextStyle(
                            fontSize: DS.caption,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: context.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                _fracRounding == r
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: _fracRounding == r
                    ? context.brand
                    : context.textTertiary,
              ),
            ]),
          ),
        ),
    ]);
  }

  String _roundingLabel(BuildContext context, FractionalRounding r) =>
      switch (r) {
        FractionalRounding.minDeviation => context.l10n.roundingMinDeviation,
        FractionalRounding.floorCash => context.l10n.roundingFloorCash,
      };

  String _roundingDesc(BuildContext context, FractionalRounding r) =>
      switch (r) {
        FractionalRounding.minDeviation =>
          context.l10n.roundingMinDeviationDesc(sharesDecimals),
        FractionalRounding.floorCash => context.l10n.roundingFloorCashDesc,
      };

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
    widget.onSave({
      'currency': _currency,
      'commissionEnabled': _commEnabled,
      'commissionRate': commRate ?? 0,
      'exchangeAuto': _exAuto,
      'exchangeRate': exRate ?? widget.portfolio.exchangeRate,
      'fractionalEnabled': _fracEnabled,
      'fractionalRounding': _fracRounding,
      'priceAuto': _priceAuto,
    });
    Navigator.pop(context);
  }
}
