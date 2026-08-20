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
import '../theme/design_system.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_header.dart';
import '../widgets/period_jump_sheet.dart';
import '../widgets/settlement_chart.dart';

/// 결산 탭 — 전체 포트폴리오 합산 (v22a).
///
/// 기간 칩과 주차 드롭다운 대신 **차트가 기간 선택 컨트롤**이다.
/// 어떤 기간을 왜 골랐는지가 이웃 기간과 함께 화면에 남는다.
class AllSettlementScreen extends StatefulWidget {
  final List<Portfolio> portfolios;
  const AllSettlementScreen({super.key, required this.portfolios});

  @override
  State<AllSettlementScreen> createState() => _AllSettlementScreenState();
}

class _AllSettlementScreenState extends State<AllSettlementScreen> {
  static const _barCount = 6;

  SettlementPeriod _period = SettlementPeriod.monthly;

  /// 차트 오른쪽 끝 기간
  late PeriodKey _endKey;

  /// 선택된 기간
  late PeriodKey _selected;

  List<CombinedSettlement?> _series = const [];
  bool _loading = false;

  bool _saving = false;
  bool _sharing = false;
  final _screenshotCtrl = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _endKey = SettlementService.currentKey(_period);
    _selected = _endKey;
    _load();
  }

  @override
  void didUpdateWidget(AllSettlementScreen old) {
    super.didUpdateWidget(old);
    if (old.portfolios != widget.portfolios) _load();
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  CombinedSettlement? get _current {
    for (final r in _series) {
      if (r != null && r.key == _selected) return r;
    }
    return null;
  }

  // ── 데이터 ──

  Future<void> _load() async {
    if (widget.portfolios.isEmpty) {
      setState(() => _series = const []);
      return;
    }
    setState(() => _loading = true);

    final series = await SettlementService.calculateCombinedSeries(
      widget.portfolios,
      _period,
      _endKey,
      count: _barCount,
    );

    if (!mounted) return;
    setState(() {
      _series = series;
      _loading = false;
    });
  }

  void _changePeriod(SettlementPeriod p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      _endKey = SettlementService.currentKey(p);
      _selected = _endKey;
    });
    _load();
  }

  void _selectKey(PeriodKey key) {
    // 차트 안의 기간은 이미 계산돼 있으므로 다시 불러오지 않는다
    setState(() => _selected = key);
  }

  /// 차트 창을 [offset]만큼 옮긴다. 음수면 과거.
  void _shiftWindow(int offset) {
    final next = SettlementService.shiftKey(_period, _endKey, offset);
    // 미래로는 현재 기간까지만
    if (offset > 0 && SettlementService.isFuture(_period, next)) return;
    setState(() {
      _endKey = next;
      // 선택이 창 밖으로 나가면 가장 가까운 칸으로 끌어온다
      final keys = _windowKeys(next);
      if (!keys.contains(_selected)) _selected = keys.last;
    });
    _load();
  }

  List<PeriodKey> _windowKeys(PeriodKey endKey) => [
        for (var i = _barCount - 1; i >= 0; i--)
          SettlementService.shiftKey(_period, endKey, -i),
      ];

  Future<void> _openJumpSheet() async {
    final earliest = widget.portfolios.isEmpty
        ? DateTime.now().year
        : widget.portfolios
            .map(SettlementService.earliestYear)
            .reduce((a, b) => a < b ? a : b);

    final picked = await PeriodJumpSheet.show(
      context,
      period: _period,
      selected: _selected,
      earliestYear: earliest,
      scopeName: _isKo ? '전체' : 'all portfolios',
      amountOf: (k) {
        for (final r in _series) {
          if (r != null && r.key == k) return r.absoluteReturn;
        }
        return null;
      },
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selected = picked;
      _endKey = picked;
    });
    _load();
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(
        children: [
          BrandHeader(
            title: l10n.tabSettlement,
            childPadding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
            actions: [
              if (_current != null)
                IconButton(
                  icon: const Icon(Icons.ios_share, color: Colors.white),
                  tooltip: l10n.capture,
                  onPressed: _showCaptureSheet,
                ),
            ],
            child: _buildHeaderBody(context, l10n),
          ),
          Expanded(
            child: widget.portfolios.isEmpty
                ? _buildEmpty(context)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      _buildChartCard(context, l10n),
                      const SizedBox(height: 14),
                      _buildContributions(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBody(BuildContext context, dynamic l10n) {
    final pnlColors = context.watch<PnlColorNotifier>();
    final r = _current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기간 단위 얇은 탭
        Row(
          children: [
            for (final p in SettlementPeriod.values)
              Expanded(child: _unitTab(context, p, l10n)),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  r == null
                      ? '—'
                      : '${r.absoluteReturn >= 0 ? '+' : '−'}${_fmt(r.absoluteReturn.abs())}',
                  style: TextStyle(
                    fontSize: DS.displayAmount,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1.08,
                    color: r == null
                        ? context.onBrandSecondary
                        : (r.absoluteReturn >= 0
                            ? pnlColors.onBrandPositive
                            : pnlColors.onBrandNegative),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (r != null)
                    Text(
                      '${r.returnRate >= 0 ? '+' : '−'}${r.returnRate.abs().toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: DS.sectionTitle,
                        fontWeight: FontWeight.w700,
                        color: r.absoluteReturn >= 0
                            ? pnlColors.onBrandPositive
                            : pnlColors.onBrandNegative,
                      ),
                    ),
                  if (r != null && r.netCashFlow.abs() > 1) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isKo
                            ? '순입금 ${_fmt(r.netCashFlow.abs())}은 제외'
                            : 'Excludes ${_fmt(r.netCashFlow.abs())} net deposits',
                        style: TextStyle(
                            fontSize: DS.body,
                            fontWeight: FontWeight.w600,
                            color: context.onBrandSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _unitTab(BuildContext context, SettlementPeriod p, dynamic l10n) {
    final active = _period == p;
    return GestureDetector(
      onTap: () => _changePeriod(p),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              _unitName(p, l10n),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                color: active ? Colors.white : context.onBrandSecondary,
              ),
            ),
          ),
          Container(
            height: 2.5,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: active ? Colors.white : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // ── 차트 카드 (기간 선택 컨트롤) ──

  Widget _buildChartCard(BuildContext context, dynamic l10n) {
    final r = _current;
    final range = SettlementService.periodRange(_period, _selected);
    final inProgress = r?.isCurrentPeriod ??
        !range.end.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullRangeLabel(range.start, range.end),
                      style: TextStyle(
                          fontSize: DS.returnPct,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inProgress
                          ? (_isKo
                              ? '진행 중 · 막대를 눌러 기간 선택'
                              : 'In progress · tap a bar to pick')
                          : (_isKo
                              ? '마감 · 막대를 눌러 기간 선택'
                              : 'Closed · tap a bar to pick'),
                      style: TextStyle(
                          fontSize: DS.caption,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openJumpSheet,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.trackBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month,
                      size: 18, color: context.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading && _series.isEmpty)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GestureDetector(
              // 좌우로 밀면 과거·현재 기간으로 창이 이어진다
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 200) {
                  _shiftWindow(-1);
                } else if (v < -200) {
                  _shiftWindow(1);
                }
              },
              child: SettlementChart(
                bars: _buildBars(l10n),
                selected: _selected,
                onSelect: _selectKey,
                showYearBoundary: _period == SettlementPeriod.quarterly ||
                    _period == SettlementPeriod.weekly,
              ),
            ),
        ],
      ),
    );
  }

  List<SettlementBar> _buildBars(dynamic l10n) {
    final keys = _windowKeys(_endKey);
    final today = DateTime.now();

    return [
      for (final k in keys)
        () {
          CombinedSettlement? found;
          for (final r in _series) {
            if (r != null && r.key == k) found = r;
          }
          final range = SettlementService.periodRange(_period, k);
          final isFuture = range.start.isAfter(today);
          return SettlementBar(
            key: k,
            label: _subLabel(k, l10n),
            amount: isFuture ? null : found?.absoluteReturn,
            inProgress: !isFuture && !range.end.isBefore(today),
          );
        }(),
    ];
  }

  // ── 포트별 기여 ──

  Widget _buildContributions(BuildContext context) {
    final r = _current;
    if (r == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            _loading
                ? (_isKo ? '계산 중…' : 'Calculating…')
                : context.l10n.settlementNoHoldings,
            style: TextStyle(fontSize: DS.rowName, color: context.textHint),
          ),
        ),
      );
    }

    final sumAbs = r.contributions
        .fold(0.0, (s, c) => s + c.absoluteReturn.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            _isKo ? '포트별 기여' : 'Contribution by portfolio',
            style: TextStyle(
                fontSize: DS.sectionTitle,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: context.textPrimary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(DS.cardRadius),
            border: Border.all(color: context.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DS.cardPaddingH),
          child: Column(
            children: [
              for (var i = 0; i < r.contributions.length; i++)
                _contributionRow(context, r.contributions[i], sumAbs,
                    isLast: i == r.contributions.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contributionRow(
      BuildContext context, PortfolioContribution c, double sumAbs,
      {required bool isLast}) {
    final pnlColors = context.watch<PnlColorNotifier>();
    final isPos = c.absoluteReturn >= 0;
    final color = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '−';
    final share = sumAbs > 0 ? c.absoluteReturn.abs() / sumAbs : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: context.dividerColor))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: TextStyle(
                      fontSize: DS.rowName,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: context.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$sign${_fmt(c.absoluteReturn.abs())}',
                style: TextStyle(
                    fontSize: DS.rowAmount,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: color),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Text(
                  '${c.returnRate >= 0 ? '+' : '−'}${c.returnRate.abs().toStringAsFixed(2)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: DS.returnPct,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DS.barTrackRadius),
                  child: SizedBox(
                    height: DS.barTrackHeight,
                    // Stack + FractionallySizedBox를 쓰면 자식 없는 ColoredBox의
                    // 세로 크기가 0이 되어 막대가 안 보인다. flex로 나눈다.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: (share.clamp(0.0, 1.0) * 1000).round(),
                          child: ColoredBox(color: color),
                        ),
                        Expanded(
                          flex: ((1 - share.clamp(0.0, 1.0)) * 1000).round(),
                          child: ColoredBox(color: context.trackBg),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 기여도는 무채색 — 손익만 색을 쓴다
              Text(
                _isKo
                    ? '기여 ${(share * 100).toStringAsFixed(0)}% (${c.contribution >= 0 ? '+' : '−'}${c.contribution.abs().toStringAsFixed(2)}%p)'
                    : '${(share * 100).toStringAsFixed(0)}% (${c.contribution >= 0 ? '+' : '−'}${c.contribution.abs().toStringAsFixed(2)}pp)',
                style: TextStyle(
                    fontSize: DS.caption,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _isKo
              ? '포트폴리오를 만들고 거래를 기록하면\n기간별 손익을 계산해 드립니다'
              : 'Create a portfolio and log trades\nto see period returns',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: DS.rowName,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: context.textHint),
        ),
      ),
    );
  }

  // ── 라벨 ──

  String _unitName(SettlementPeriod p, dynamic l10n) {
    switch (p) {
      case SettlementPeriod.weekly:
        return l10n.settlementWeekly;
      case SettlementPeriod.monthly:
        return l10n.settlementMonthly;
      case SettlementPeriod.quarterly:
        return l10n.settlementQuarterly;
      case SettlementPeriod.yearly:
        return l10n.settlementYearly;
    }
  }

  String _subLabel(PeriodKey key, dynamic l10n) {
    switch (_period) {
      case SettlementPeriod.weekly:
        return _isKo ? '${key.sub}주' : 'W${key.sub}';
      case SettlementPeriod.monthly:
        return _isKo ? '${key.sub}월' : _monthAbbr(key.sub);
      case SettlementPeriod.quarterly:
        return _isKo ? '${key.sub}분기' : 'Q${key.sub}';
      case SettlementPeriod.yearly:
        return '${key.year}';
    }
  }

  static String _monthAbbr(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

  String _fullRangeLabel(DateTime a, DateTime b) =>
      '${a.year}.${a.month.toString().padLeft(2, '0')}.${a.day.toString().padLeft(2, '0')}'
      ' – '
      '${b.month.toString().padLeft(2, '0')}.${b.day.toString().padLeft(2, '0')}';

  String _fmt(double n) {
    final prefix = n < 0 ? '−' : '';
    final abs = n.abs();
    return '$prefix₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  // ── 이미지 저장 · 공유 ──

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
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(l10n.capture,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ctx.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _saveImage();
                  },
                  icon: const Icon(Icons.save_alt_rounded, size: 16),
                  label: Text(l10n.saveImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ctx.textPrimary,
                    side: BorderSide(color: ctx.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _shareImage();
                  },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(l10n.shareImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brand,
                    side: BorderSide(color: context.brand),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.saveFailedError(e.toString())),
          duration: const Duration(seconds: 2),
        ));
      }
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
      final file = File(
          '${dir.path}/settlement_all_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.saveFailedError(e.toString())),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _buildCapture() {
    final r = _current;
    final pnlColors = context.read<PnlColorNotifier>();
    final range = SettlementService.periodRange(_period, _selected);
    final color = (r?.absoluteReturn ?? 0) >= 0
        ? pnlColors.positiveColor
        : pnlColors.negativeColor;

    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isKo ? '전체 결산' : 'All portfolios',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary)),
              AppLogo(iconSize: 22, textColor: context.textPrimary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _fullRangeLabel(range.start, range.end),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isKo ? '기간 손익' : 'Period P&L',
                    style: TextStyle(
                        fontSize: 12, color: context.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  r == null
                      ? '—'
                      : '${r.absoluteReturn >= 0 ? '+' : '−'}${_fmt(r.absoluteReturn.abs())}',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: color),
                ),
                if (r != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${r.returnRate >= 0 ? '+' : '−'}${r.returnRate.abs().toStringAsFixed(2)}%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ],
              ],
            ),
          ),
          if (r != null && r.contributions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...r.contributions.map((c) {
              final cc = c.absoluteReturn >= 0
                  ? pnlColors.positiveColor
                  : pnlColors.negativeColor;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${c.emoji} ${c.name}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${c.absoluteReturn >= 0 ? '+' : '−'}${_fmt(c.absoluteReturn.abs())}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cc),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
