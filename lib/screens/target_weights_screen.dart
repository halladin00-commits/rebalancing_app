import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import '../widgets/list_card.dart';

/// 목표 비중 · 허용 편차 설정 (시안 v18c).
///
/// 개편 전에는 종목을 하나씩 열어 목표 비중을 고쳐야 했다. 합계가 100이 됐는지는
/// 다 고치고 나서야 알 수 있었다. 한 화면에 모아 **합계를 보면서** 고친다.
class TargetWeightsScreen extends StatefulWidget {
  final String portfolioId;
  const TargetWeightsScreen({super.key, required this.portfolioId});

  @override
  State<TargetWeightsScreen> createState() => _TargetWeightsScreenState();
}

class _TargetWeightsScreenState extends State<TargetWeightsScreen> {
  final _ctls = <String, TextEditingController>{};
  late final TextEditingController _thresholdCtl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final pf = context.read<PortfolioProvider>().getPortfolio(widget.portfolioId);
    for (final item in pf?.items ?? const <PortfolioItem>[]) {
      _ctls[item.id] = TextEditingController(text: _trim(item.targetWeight))
        ..addListener(() => setState(() {}));
    }
    _thresholdCtl =
        TextEditingController(text: _trim(pf?.rebalancingThreshold ?? 0));
    _ready = true;
  }

  @override
  void dispose() {
    for (final c in _ctls.values) {
      c.dispose();
    }
    _thresholdCtl.dispose();
    super.dispose();
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double get _sum => _ctls.values
      .fold(0.0, (s, c) => s + (double.tryParse(c.text.trim()) ?? 0));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null || !_ready) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }
        // 현재 비중을 함께 보여준다 — 목표를 정할 때 지금 어떤지가 기준이 된다
        final drifts = {
          for (final d in Rebalancer.allDrifts(pf)) d.item.id: d.currentWeight
        };

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(children: [
            _buildHeader(context, pf),
            _buildSumBar(context, drifts),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                children: [
                  ListCard(rows: [
                    for (final item in pf.items)
                      _buildRow(context, item, drifts[item.id]),
                  ]),
                  const SizedBox(height: 18),
                  SectionTitle(title: l10n.rebalancingThresholdLabel),
                  const SizedBox(height: DS.cardGap),
                  ListCard(rows: [
                    _thresholdRow(context),
                  ]),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(l10n.thresholdNote,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.55,
                            color: context.textSecondary)),
                  ),
                ],
              ),
            ),
            _buildCta(context, pf),
          ]),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Portfolio pf) {
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
          // 큰 글씨 설정(접근성)에서 제목+부제가 52px를 넘는다. 고정이면
          // `BOTTOM OVERFLOWED`가 뜬다 — 최소 높이만 정하고 늘어나게 둔다.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(children: [
              IconButton(
                tooltip: context.l10n.a11yClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.targetWeightsTitle,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white)),
                    const SizedBox(height: 1),
                    Text(pf.name,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.onBrandSecondary),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ]),
          ),
        ),
      ),
    );
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  /// 전 종목에 100을 고르게 나눈다.
  ///
  /// 나눠떨어지지 않으면 **마지막 칸이 나머지를 받는다** — 소수점 둘째에서
  /// 반올림만 하면 합계가 99.99나 100.01이 되어 저장이 막힌다.
  void _distributeEvenly() {
    final ids = _ctls.keys.toList();
    if (ids.isEmpty) return;
    final each = (100 / ids.length * 100).floorToDouble() / 100;
    var assigned = 0.0;
    for (var i = 0; i < ids.length; i++) {
      final v = i == ids.length - 1
          ? (100 - assigned)
          : each;
      assigned += v;
      _ctls[ids[i]]!.text = _trim(double.parse(v.toStringAsFixed(2)));
    }
    setState(() {});
  }

  /// 합계 막대. 100이 아니면 저장할 수 없으므로 늘 보이게 위에 붙인다.
  Widget _buildSumBar(BuildContext context, Map<String, double> current) {
    final l10n = context.l10n;
    final sum = _sum;
    final ok = (sum - 100).abs() < 0.01;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: ok ? context.brandTint : context.warningBg,
      child: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.error_outline,
            size: 17, color: ok ? context.brandOnLight : context.warningText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l10n.targetSum,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ok ? context.onTintTitle : context.onWarningTitle)),
        ),
        Text('${_trim(sum)}%',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: ok ? context.brandOnLight : context.warningText)),
        // 열 칸을 손으로 채우는 대신 한 번에 맞추는 두 가지.
        //
        // **균등 배분** — 흔한 운용 방식이다(이 사용자의 ISA가 10종목 균등).
        // **현재 비중으로** — 「지금 구성이 마음에 든다, 이걸 유지하자」에
        //   답한다. 감으로 만든 포트를 앱이 그 자리에 붙들어 두게 하는 것이라
        //   어떤 포트에서든 쓸모가 있다. 시세를 못 받으면 현재 비중을 모르므로
        //   그때는 안 낸다.
        if (_ctls.length > 1) ...[
          const SizedBox(width: 8),
          if (current.isNotEmpty)
            _sumAction(context, _isKo ? '현재 비중으로' : 'Use current',
                () => _copyCurrent(current)),
          if (current.isNotEmpty) const SizedBox(width: 6),
          _sumAction(context, _isKo ? '균등 배분' : 'Split evenly',
              _distributeEvenly),
        ],
      ]),
    );
  }

  Widget _sumAction(BuildContext context, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(DS.chipRadius),
            border: Border.all(color: context.borderColor),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.brandOnLight)),
        ),
      );

  /// 지금 비중을 그대로 목표로 삼는다.
  ///
  /// 반올림하면 합계가 99.99나 100.01이 되어 저장이 막힌다.
  /// **가장 큰 종목이 나머지를 받는다** — 거기서 흡수하는 오차가 가장 작다.
  void _copyCurrent(Map<String, double> current) {
    final ids = _ctls.keys.where(current.containsKey).toList();
    if (ids.isEmpty) return;
    ids.sort((a, b) => current[b]!.compareTo(current[a]!));

    var assigned = 0.0;
    for (var i = 1; i < ids.length; i++) {
      final v = double.parse(current[ids[i]]!.toStringAsFixed(2));
      assigned += v;
      _ctls[ids[i]]!.text = _trim(v);
    }
    // 가장 큰 것이 마지막에 나머지를 받는다
    _ctls[ids.first]!.text =
        _trim(double.parse((100 - assigned).toStringAsFixed(2)));

    // 현재 비중을 못 구한 종목은 0으로 둔다 — 지어내지 않는다
    for (final id in _ctls.keys.where((k) => !current.containsKey(k))) {
      _ctls[id]!.text = '0';
    }
    setState(() {});
  }

  Widget _buildRow(BuildContext context, PortfolioItem item, double? current) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.displayName(context),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
            if (current != null) ...[
              const SizedBox(height: 3),
              // 현재값만 회색으로 적어 두면, 열 종목이 전부 `10`으로 똑같이
              // 보여 **어디가 얼마나 벌어져 있는지** 이 화면에서 알 수 없다.
              // 고쳐야 할 곳이 목록을 훑는 것만으로 보이게 차이를 적는다.
              Builder(builder: (_) {
                final target =
                    double.tryParse(_ctls[item.id]?.text.trim() ?? '') ?? 0;
                final gap = current - target;
                final big = gap.abs() >= 5;
                return Text(
                  '${l10n.currentWeightIs(current.toStringAsFixed(2))}'
                  '  ${fmtPp(gap, _isKo)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                      color: big
                          ? context.warningText
                          : context.textSecondary),
                );
              }),
            ],
          ]),
        ),
        SizedBox(
          width: 78,
          child: TextField(
            controller: _ctls[item.id],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: context.textPrimary),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              hintText: '0',
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text('%',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textSecondary)),
      ]),
    );
  }

  Widget _thresholdRow(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Text(l10n.rebalancingThresholdHint,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ),
        SizedBox(
          width: 78,
          child: TextField(
            controller: _thresholdCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
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
        const SizedBox(width: 3),
        Text(ppUnit(_isKo),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textSecondary)),
      ]),
    );
  }

  Widget _buildCta(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    final ok = (_sum - 100).abs() < 0.01;
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: DS.buttonHeight,
        child: ElevatedButton(
          // 합계가 100이 아니면 리밸런싱 계산 자체가 불가능하다. 막아 둔다.
          onPressed: ok ? () => _save(pf) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: context.disabledFill,
            disabledForegroundColor: context.textDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.buttonRadius)),
          ),
          child: Text(ok ? l10n.save : l10n.targetSumMustBe100,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Future<void> _save(Portfolio pf) async {
    final provider = context.read<PortfolioProvider>();
    for (final item in pf.items) {
      final v = double.tryParse(_ctls[item.id]?.text.trim() ?? '') ?? 0;
      if (v != item.targetWeight) {
        await provider.updateItem(pf.id, item.copyWith(targetWeight: v));
      }
    }
    final th = double.tryParse(_thresholdCtl.text.trim()) ?? 0;
    if (th >= 0 && th != pf.rebalancingThreshold) {
      await provider.updateSettings(pf.id, rebalancingThreshold: th);
    }
    if (mounted) Navigator.pop(context);
  }
}
