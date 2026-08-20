import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../services/settlement_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_header.dart';
import '../widgets/speed_dial_fab.dart';

/// 결산 탭 — 전체 포트폴리오 합산 결산.
class AllSettlementScreen extends StatefulWidget {
  final List<Portfolio> portfolios;
  const AllSettlementScreen({super.key, required this.portfolios});
  @override
  State<AllSettlementScreen> createState() => _AllSettlementScreenState();
}

class _AllSettlementScreenState extends State<AllSettlementScreen> {
  SettlementPeriod _period = SettlementPeriod.monthly;
  late int _year;
  late int _sub;
  bool _loading = false;

  double? _startValue;
  double? _endValue;
  double? _absoluteReturn;
  double? _returnRate;
  double _netCashFlow = 0.0;
  bool _isCurrentPeriod = false;
  List<Map<String, dynamic>> _portfolioResults = [];

  bool _saving = false;
  bool _sharing = false;
  final _screenshotCtrl = ScreenshotController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _sub = SettlementService.currentSub(_period);
    _load();
  }

  @override
  void didUpdateWidget(AllSettlementScreen old) {
    super.didUpdateWidget(old);
    if (old.portfolios != widget.portfolios) _load();
  }

  Future<void> _load() async {
    if (widget.portfolios.isEmpty) return;
    setState(() { _loading = true; _startValue = null; _portfolioResults = []; });

    double start = 0, end = 0, absReturn = 0, netCashFlow = 0;
    bool isCurrentPeriod = false;
    final key = PeriodKey(_year, _sub);
    final results = <Map<String, dynamic>>[];

    final rates = widget.portfolios.where((p) => p.exchangeRate > 0).map((p) => p.exchangeRate).toList();
    final avgRate = rates.isNotEmpty ? rates.reduce((a, b) => a + b) / rates.length : 1370.0;

    await Future.wait(widget.portfolios.map((pf) async {
      final r = await SettlementService.calculate(pf, _period, key);
      if (r == null) return;
      final fx = pf.currency == 'USD' ? avgRate : 1.0;
      final pfStart = r.startValue * fx;
      final pfEnd = r.endValue * fx;
      final pfAbs = r.absoluteReturn * fx;
      start += pfStart;
      end += pfEnd;
      absReturn += pfAbs;
      netCashFlow += r.netCashFlow * fx;
      if (r.isCurrentPeriod) isCurrentPeriod = true;
      results.add({
        'emoji': pf.emoji,
        'name': pf.name,
        'startValue': pfStart,
        'endValue': pfEnd,
        'absoluteReturn': pfAbs,
        'returnRate': pfStart > 0 ? pfAbs / pfStart * 100 : 0.0,
      });
    }));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _startValue = start;
      _endValue = end;
      _absoluteReturn = absReturn;
      _returnRate = start > 0 ? absReturn / start * 100 : 0;
      _netCashFlow = netCashFlow;
      _isCurrentPeriod = isCurrentPeriod;
      _portfolioResults = results;
    });
  }

  void _onPeriodChanged(SettlementPeriod p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      _year = DateTime.now().year;
      _sub = SettlementService.currentSub(p);
    });
    _load();
  }

  void _onYearChanged(int y) {
    final maxSub = SettlementService.maxSub(_period, y);
    setState(() {
      _year = y;
      if (_sub > maxSub) _sub = maxSub;
    });
    _load();
  }

  void _onSubChanged(int s) {
    setState(() => _sub = s);
    _load();
  }

  String _fmt(double n) {
    final prefix = n < 0 ? '-' : '';
    final abs = n.abs();
    return '$prefix₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  void _showCaptureSheet() {
    final l10n = context.l10n;
    final ctx = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: ctx.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(l10n.capture,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _saveImage(); },
                  icon: const Icon(Icons.save_alt_rounded, size: 16),
                  label: Text(l10n.saveImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ctx.textPrimary,
                    side: BorderSide(color: ctx.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _shareImage(); },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(l10n.shareImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage() async {
    if (_saving) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildCapture(),
        pixelRatio: 3.0,
        context: context,
      );
      final r = await ImageGallerySaverPlus.saveImage(
        bytes,
        name: 'settlement_all_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final ok = r['isSuccess'] == true || r['filePath'] != null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l10n.savedToGallery : l10n.saveFailed),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.saveFailedError(e.toString())),
        duration: const Duration(seconds: 2),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    final l10n = context.l10n;
    setState(() => _sharing = true);
    try {
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildCapture(),
        pixelRatio: 3.0,
        context: context,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/settlement_all_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.saveFailedError(e.toString())),
        duration: const Duration(seconds: 2),
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _buildCapture() {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final pnlColors = context.read<PnlColorNotifier>();
    final retColor = (_returnRate ?? 0) >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;
    final absColor = (_absoluteReturn ?? 0) >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;

    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isKo ? '전체 결산' : 'All Settlement',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
            AppLogo(iconSize: 22, textColor: context.textPrimary),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _captureValueBox(isKo ? '기준 평가금액' : 'Base Value', _fmt(_startValue ?? 0))),
                const SizedBox(width: 10),
                Expanded(child: _captureValueBox(isKo ? '현재 평가금액' : 'Current Value', _fmt(_endValue ?? 0))),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isKo ? '기간 손익' : 'Period P&L',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${(_returnRate ?? 0) >= 0 ? '+' : ''}${(_returnRate ?? 0).toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: retColor),
                  ),
                  Text(
                    '${(_absoluteReturn ?? 0) >= 0 ? '+' : ''}${_fmt(_absoluteReturn ?? 0)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: absColor),
                  ),
                ]),
              ]),
            ]),
          ),
          if (_portfolioResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._portfolioResults.map((r) {
              final ret = (r['returnRate'] as double);
              final abs = (r['absoluteReturn'] as double);
              final color = ret >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${r['emoji']} ${r['name']}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
                    const Spacer(),
                    Text('${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(isKo ? '기준 ${_fmt(r['startValue'] as double)}' : 'Base ${_fmt(r['startValue'] as double)}',
                        style: TextStyle(fontSize: 10, color: context.textHint)),
                    const Spacer(),
                    Text(isKo ? '현재 ${_fmt(r['endValue'] as double)}' : 'Now ${_fmt(r['endValue'] as double)}',
                        style: TextStyle(fontSize: 10, color: context.textHint)),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${isKo ? '손익' : 'P&L'}  ${abs >= 0 ? '+' : ''}${_fmt(abs)}',
                        style: TextStyle(fontSize: 10, color: color)),
                  ]),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _captureValueBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: context.infoBoxBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.textHint)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final pnlColors = context.watch<PnlColorNotifier>();
    final maxSub = SettlementService.maxSub(_period, _year);
    final now = DateTime.now();
    final earliestYear = widget.portfolios.isEmpty ? now.year
        : widget.portfolios.map((p) => SettlementService.earliestYear(p)).reduce((a, b) => a < b ? a : b);
    final years = List.generate(now.year - earliestYear + 1, (i) => earliestYear + i).reversed.toList();

    final content = Column(children: [
      // 기간 선택
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SegmentedButton<SettlementPeriod>(
          segments: [
            ButtonSegment(value: SettlementPeriod.weekly,    label: Text(l10n.settlementWeekly,    style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: SettlementPeriod.monthly,   label: Text(l10n.settlementMonthly,   style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: SettlementPeriod.quarterly, label: Text(l10n.settlementQuarterly, style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: SettlementPeriod.yearly,    label: Text(l10n.settlementYearly,    style: const TextStyle(fontSize: 12))),
          ],
          selected: {_period},
          onSelectionChanged: (s) => _onPeriodChanged(s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ),
      // 연도/세부 선택
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          DropdownButton<int>(
            value: years.contains(_year) ? _year : years.first,
            isDense: true,
            underline: Container(height: 1, color: context.borderColor),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
            dropdownColor: context.cardBg,
            items: years.map((y) => DropdownMenuItem(value: y, child: Text(l10n.settlementYearLabel(y)))).toList(),
            onChanged: (v) { if (v != null) _onYearChanged(v); },
          ),
          if (_period != SettlementPeriod.yearly) ...[
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _sub.clamp(1, maxSub),
              isDense: true,
              underline: Container(height: 1, color: context.borderColor),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
              dropdownColor: context.cardBg,
              items: List.generate(maxSub, (i) => i + 1).map((s) {
                final label = switch (_period) {
                  SettlementPeriod.weekly    => l10n.settlementWeekNum(s),
                  SettlementPeriod.monthly   => l10n.settlementMonthNum(s),
                  SettlementPeriod.quarterly => l10n.settlementQuarterNum(s),
                  SettlementPeriod.yearly    => '',
                };
                return DropdownMenuItem(value: s, child: Text(label));
              }).toList(),
              onChanged: (v) { if (v != null) _onSubChanged(v); },
            ),
          ],
          if (_isCurrentPeriod) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.settlementCurrentPeriod,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
            ),
          ],
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : widget.portfolios.isEmpty
                ? Center(child: Text(l10n.settlementNoHoldings,
                    style: TextStyle(color: context.textSecondary)))
                : _startValue == null
                    ? Center(child: Text(l10n.settlementNoHoldings,
                        style: TextStyle(color: context.textSecondary)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        children: [
                          // ── 합산 결과 카드 ──
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              IntrinsicHeight(
                                child: Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(l10n.settlementReturn,
                                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_returnRate! >= 0 ? '+' : ''}${_returnRate!.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w700,
                                        color: _returnRate! >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor,
                                      ),
                                    ),
                                  ])),
                                  VerticalDivider(color: context.borderColor, width: 24, thickness: 1),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text(isKo ? '기간 손익' : 'Period P&L',
                                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_absoluteReturn! >= 0 ? '+' : ''}${_fmt(_absoluteReturn!)}',
                                      style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w700,
                                        color: _absoluteReturn! >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor,
                                      ),
                                    ),
                                  ])),
                                ]),
                              ),
                              if (_netCashFlow.abs() > 0) ...[
                                const SizedBox(height: 6),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(
                                    _netCashFlow >= 0
                                        ? (isKo ? '추가 투자금' : 'Capital Added')
                                        : (isKo ? '자본 회수' : 'Capital Withdrawn'),
                                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                                  ),
                                  Text(
                                    '${_netCashFlow >= 0 ? '+' : ''}${_fmt(_netCashFlow)}',
                                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                                  ),
                                ]),
                              ],
                              Divider(height: 20, color: context.borderColor),
                              Row(children: [
                                Expanded(child: _valueBox(context, l10n.settlementStartValue, _fmt(_startValue!))),
                                const SizedBox(width: 10),
                                Expanded(child: _valueBox(context, l10n.settlementEndValue, _fmt(_endValue!))),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Text(isKo ? '* 모든 포트폴리오 합산, KRW 기준' : '* All portfolios combined, KRW basis',
                              style: TextStyle(fontSize: 11, color: context.textHint)),
                          // ── 기여도 ──
                          if (_portfolioResults.isNotEmpty && (_startValue ?? 0) > 0) ...[
                            const SizedBox(height: 16),
                            Text(l10n.settlementContribution,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
                            const SizedBox(height: 8),
                            ...() {
                              final totalStart = _startValue!;
                              final contributions = _portfolioResults.map((r) => {
                                ...r,
                                'contribution': (r['absoluteReturn'] as double) / totalStart * 100,
                              }).toList();
                              final sumAbs = contributions.fold(
                                  0.0, (s, r) => s + (r['contribution'] as double).abs());
                              return contributions.map((r) =>
                                  _buildPortfolioContributionRow(r, pnlColors, sumAbs)).toList();
                            }(),
                          ],
                        ],
                      ),
      ),
    ]);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        BrandHeader(title: l10n.tabSettlement),
        Expanded(
          child: Stack(children: [
            content,
            if (_startValue != null)
              Positioned.fill(
                child: SpeedDialFab(
                  key: const ValueKey('settlement_fab'),
                  items: [
                    SpeedDialItem(
                      icon: Icons.camera_alt_outlined,
                      label: context.l10n.capture,
                      onTap: _showCaptureSheet,
                    ),
                  ],
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPortfolioContributionRow(Map<String, dynamic> r, PnlColorNotifier pnlColors, double sumAbsContrib) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final contribution = r['contribution'] as double;
    final isPos = contribution >= 0;
    final color = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '';
    final relWeight = sumAbsContrib > 0 ? contribution.abs() / sumAbsContrib * 100 : 0.0;
    final barRatio = sumAbsContrib > 0 ? (contribution.abs() / sumAbsContrib).clamp(0.0, 1.0) : 0.0;
    final itemReturnPct = r['returnRate'] as double;
    final itemAbsReturn = r['absoluteReturn'] as double;
    final itemReturnIsPos = itemReturnPct >= 0;

    final returnColor = itemReturnIsPos ? pnlColors.positiveColor : pnlColors.negativeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text('${r['emoji']} ${r['name']}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            RichText(text: TextSpan(children: [
              TextSpan(text: '${isKo ? '수익률' : 'Return'} ',
                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
              TextSpan(text: '${itemReturnIsPos ? '+' : ''}${itemReturnPct.toStringAsFixed(2)}%  ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: returnColor)),
              TextSpan(text: '${isKo ? '손익' : 'P&L'} ',
                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
              TextSpan(text: '${itemReturnIsPos ? '+' : ''}${_fmt(itemAbsReturn)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: returnColor)),
            ])),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
            return Stack(children: [
              Container(height: 4, width: constraints.maxWidth,
                  decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              Container(height: 4, width: constraints.maxWidth * barRatio,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            ]);
          })),
          const SizedBox(width: 8),
          Text(
            '${isKo ? '기여' : 'Contrib'} ${relWeight.toStringAsFixed(1)}% ($sign${contribution.toStringAsFixed(2)}%p)',
            style: TextStyle(fontSize: 11, color: context.textSecondary),
          ),
        ]),
      ]),
    );
  }

  Widget _valueBox(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: context.infoBoxBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.textHint)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
        ),
      ]),
    );
  }
}
