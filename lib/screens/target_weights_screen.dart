import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
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
            _buildSumBar(context),
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
          child: SizedBox(
            height: 52,
            child: Row(children: [
              IconButton(
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

  /// 합계 막대. 100이 아니면 저장할 수 없으므로 늘 보이게 위에 붙인다.
  Widget _buildSumBar(BuildContext context) {
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
      ]),
    );
  }

  Widget _buildRow(BuildContext context, PortfolioItem item, double? current) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
            if (current != null) ...[
              const SizedBox(height: 3),
              Text(l10n.currentWeightIs(current.toStringAsFixed(2)),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary)),
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
        Text('%p',
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
