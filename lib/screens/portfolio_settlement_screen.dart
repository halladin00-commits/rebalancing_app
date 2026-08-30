import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_header.dart';
import '../widgets/period_jump_sheet.dart';
import '../widgets/settlement_chart.dart';
import '../widgets/excluded_banner.dart';

/// 포트폴리오 하나의 결산 (v22b).
///
/// 전체 결산과 **기간을 각자 기억한다** — 전체가 월간이어도 이 포트는 분기를
/// 볼 수 있다. 그래서 기간 상태를 전역이 아니라 이 화면이 들고 있다.
class PortfolioSettlementScreen extends StatefulWidget {
  final String portfolioId;

  const PortfolioSettlementScreen({super.key, required this.portfolioId});

  @override
  State<PortfolioSettlementScreen> createState() =>
      _PortfolioSettlementScreenState();
}

class _PortfolioSettlementScreenState extends State<PortfolioSettlementScreen> {
  /// 차트 칸 수. 월간만 12칸 — 1년을 한눈에 보려면 열두 달이 있어야 한다.
  int get _barCount => _period == SettlementPeriod.monthly ? 12 : 6;

  SettlementPeriod _period = SettlementPeriod.monthly;
  late PeriodKey _endKey;
  late PeriodKey _selected;

  List<SettlementResult?> _series = const [];
  bool _loading = false;
  bool _sharing = false;
  final _screenshotCtrl = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _endKey = SettlementService.currentKey(_period);
    _selected = _endKey;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  Portfolio? get _pf {
    final list = context.read<PortfolioProvider>().portfolios;
    for (final p in list) {
      if (p.id == widget.portfolioId) return p;
    }
    return null;
  }

  SettlementResult? get _current {
    for (final r in _series) {
      if (r != null && r.key == _selected) return r;
    }
    return null;
  }

  // ── 데이터 ──

  /// 결산을 불러온다.
  ///
  /// [endKey]·[select]는 **받아온 다음에** 반영한다. 먼저 옮겨 놓으면
  /// 그 기간의 결과가 아직 `_series`에 없어 화면이 통째로 비고, 사용자는
  /// 방금까지 보던 숫자를 잃는다. 실패하면 아예 못 돌아온다.
  Future<void> _load({PeriodKey? endKey, PeriodKey? select}) async {
    final pf = _pf;
    if (pf == null) return;
    final targetEnd = endKey ?? _endKey;
    setState(() => _loading = true);

    final series = await SettlementService.calculateSeries(
      pf,
      _period,
      targetEnd,
      count: _barCount,
    );

    if (!mounted) return;
    setState(() {
      _series = series;
      _endKey = targetEnd;
      if (select != null) {
        _selected = select;
      } else if (!_windowKeys(targetEnd).contains(_selected)) {
        _selected = _windowKeys(targetEnd).last;
      }
      _loading = false;
    });
  }

  void _changePeriod(SettlementPeriod p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      // `PeriodKey`는 기간 단위를 식별에 넣지 않는다 — 월간 3월과 분기 3분기가
      // 둘 다 (2026, 3)이다. 옛 결과를 남겨 두면 단위를 바꾼 직후 **3월 숫자가
      // 3분기 라벨 밑에 뜬다.** 지어낸 숫자보다 빈 화면이 낫다.
      _series = const [];
      _endKey = SettlementService.currentKey(p);
      _selected = _endKey;
    });
    _load();
  }

  void _shiftWindow(int offset) {
    final next = SettlementService.shiftKey(_period, _endKey, offset);
    if (offset > 0 && SettlementService.isFuture(_period, next)) return;
    _load(endKey: next);
  }

  List<PeriodKey> _windowKeys(PeriodKey endKey) => [
        for (var i = _barCount - 1; i >= 0; i--)
          SettlementService.shiftKey(_period, endKey, -i),
      ];

  Future<void> _openJumpSheet() async {
    final pf = _pf;
    if (pf == null) return;

    final picked = await PeriodJumpSheet.show(
      context,
      period: _period,
      selected: _selected,
      earliestYear: SettlementService.earliestYear(pf),
      // 이 시트가 어느 범위를 다루는지 밝힌다
      scopeName: pf.name,
      amountOf: (k) {
        for (final r in _series) {
          if (r != null && r.key == k) return r.absoluteReturn;
        }
        return null;
      },
    );
    if (picked == null || !mounted) return;

    // 이미 차트에 있는 기간이면 다시 받을 게 없다 — 누르자마자 바뀐다
    if (_windowKeys(_endKey).contains(picked)) {
      setState(() => _selected = picked);
      return;
    }
    _load(endKey: picked, select: picked);
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        Portfolio? pf;
        for (final p in provider.portfolios) {
          if (p.id == widget.portfolioId) pf = p;
        }
        if (pf == null) {
          return Scaffold(
              body: Center(child: Text(context.l10n.portfolioNotFound)));
        }

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              BrandHeader(
                title: pf.name,
                titleSize: 17,
                titleWeight: FontWeight.w700,
                childPadding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (_current != null)
                    IconButton(
                      icon: const Icon(Icons.ios_share, color: Colors.white),
                      tooltip: context.l10n.shareImage,
                      onPressed: _sharing ? null : _shareImage,
                    ),
                ],
                child: _buildHeaderBody(context, pf),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _buildExcluded(context, pf),
                    _buildChartCard(context, pf),
                    const SizedBox(height: 14),
                    _buildItemContributions(context, pf),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBody(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    final pnlColors = context.watch<PnlColorNotifier>();
    final r = _current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      : '${r.absoluteReturn >= 0 ? '+' : '−'}${fmtMoney(r.absoluteReturn.abs(), pf.currency)}',
                  style: TextStyle(
                    fontSize: DS.displayAmount,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1.08,
                    // 덜 받은 값은 확정된 것처럼 보이면 안 된다
                    color: r == null
                        ? context.onBrandSecondary
                        : (r.absoluteReturn >= 0
                                ? pnlColors.onBrandPositive
                                : pnlColors.onBrandNegative)
                            .withValues(alpha: r.isPartial ? 0.45 : 1.0),
                  ),
                ),
              ),
              if (r != null && r.isPartial) ...[
                const SizedBox(height: 5),
                Row(children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.6, color: context.onBrandSecondary),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                        context.l10n.partialSettlement(r.missingPriceCount),
                        style: TextStyle(
                            fontSize: DS.body,
                            fontWeight: FontWeight.w600,
                            color: context.onBrandSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (r != null)
                    Text(
                      r.rateAvailable
                          ? '${r.returnRate >= 0 ? '+' : '−'}${r.returnRate.abs().toStringAsFixed(2)}%'
                          : '—',
                      style: TextStyle(
                        fontSize: DS.sectionTitle,
                        fontWeight: FontWeight.w700,
                        color: r.absoluteReturn >= 0
                            ? pnlColors.onBrandPositive
                            : pnlColors.onBrandNegative,
                      ),
                    ),
                  if (r != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        // 계산 근거를 한 줄로 — 입출금이 없으면 그대로 밝힌다
                        r.netCashFlow.abs() < 1
                            ? (_isKo
                                ? '이 포트는 입출금 없음'
                                : 'No deposits or withdrawals')
                            : (_isKo
                                ? '순입금 ${fmtMoney(r.netCashFlow.abs(), pf.currency)}은 제외'
                                : 'Excludes ${fmtMoney(r.netCashFlow.abs(), pf.currency)} net deposits'),
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

  // ── 차트 ──

  /// 이 포트에서 결산에 안 잡히는 종목.
  Widget _buildExcluded(BuildContext context, Portfolio pf) {
    final excluded = SettlementService.excludedItems(pf, _period, _selected);
    if (excluded.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ExcludedBanner(
        items: excluded,
        amountText: fmtMoney(SettlementService.excludedValue(pf, excluded), pf.currency),
        onFix: () => showExcludedSheet(context, items: excluded),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, Portfolio pf) {
    final r = _current;
    final range = SettlementService.periodRange(_period, _selected);
    final inProgress = r?.isCurrentPeriod ?? !range.end.isBefore(DateTime.now());
    final elapsed = DateTime.now().difference(range.start).inDays + 1;

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
                      _fullRangeLabel(range.start,
                          inProgress ? DateTime.now() : range.end),
                      style: TextStyle(
                          fontSize: DS.returnPct,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // 창을 옮기는 동안에도 보던 기간을 그대로 두므로,
                      // 말해주지 않으면 눌러도 아무 일이 없는 것처럼 보인다
                      _loading
                          ? (_isKo
                              ? '다른 기간을 불러오는 중…'
                              : 'Loading another period…')
                      // 진행 중이면 경과 일수까지 — 아직 안 끝난 값임을 못박는다
                      : inProgress
                          // 어느 기간이 진행 중인지 이름까지 밝힌다 (시안 v22b)
                          ? (_isKo
                              ? '${_subLabel(_selected)} 진행 중 · $elapsed일 경과'
                              : '${_subLabel(_selected)} in progress · day $elapsed')
                          : (_isKo ? '마감 · 막대를 눌러 기간 선택' : 'Closed · tap a bar to pick'),
                      style: TextStyle(
                        fontSize: DS.caption,
                        fontWeight: FontWeight.w600,
                        color: inProgress
                            ? context.warningText
                            : context.textSecondary,
                      ),
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
                height: 100, child: Center(child: CircularProgressIndicator()))
          else
            GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 200) {
                  _shiftWindow(-1);
                } else if (v < -200) {
                  _shiftWindow(1);
                }
              },
              child: SettlementChart(
                bars: _buildBars(),
                selected: _selected,
                onSelect: (k) => setState(() => _selected = k),
                // 월간도 열두 칸이라 해가 바뀌는 자리를 표시해야
                // 작년 3월과 올해 3월이 안 섞인다
                showYearBoundary: _period != SettlementPeriod.yearly,
              ),
            ),
        ],
      ),
    );
  }

  List<SettlementBar> _buildBars() {
    final today = DateTime.now();
    return [
      for (final k in _windowKeys(_endKey))
        () {
          SettlementResult? found;
          for (final r in _series) {
            if (r != null && r.key == k) found = r;
          }
          final range = SettlementService.periodRange(_period, k);
          final isFuture = range.start.isAfter(today);
          return SettlementBar(
            key: k,
            label: _barLabel(k),
            amount: isFuture ? null : found?.absoluteReturn,
            inProgress: !isFuture && !range.end.isBefore(today),
          );
        }(),
    ];
  }

  // ── 종목별 기여 ──

  Widget _buildItemContributions(BuildContext context, Portfolio pf) {
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

    final sumAbs =
        r.contributions.fold(0.0, (s, c) => s + c.itemAbsoluteReturn.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Row(
            children: [
              Text(
                _isKo ? '종목별 기여' : 'Contribution by holding',
                style: TextStyle(
                    fontSize: DS.sectionTitle,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
              ),
              const Spacer(),
              Text(
                _isKo ? '수수료 전 값' : 'before fees',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary),
              ),
            ],
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
                _itemRow(context, pf, r.contributions[i], sumAbs,
                    isLast: i == r.contributions.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemRow(BuildContext context, Portfolio pf,
      SettlementItemContribution c, double sumAbs,
      {required bool isLast}) {
    final pnlColors = context.watch<PnlColorNotifier>();
    final isPos = c.itemAbsoluteReturn >= 0;
    final color = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '−';
    final share = sumAbs > 0 ? c.itemAbsoluteReturn.abs() / sumAbs : 0.0;

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
                '$sign${fmtMoney(c.itemAbsoluteReturn.abs(), pf.currency)}',
                style: TextStyle(
                    fontSize: DS.rowAmount,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: color),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                // 칸 너비는 행끼리 맞추려고 고정이다. 네 자리 수익률
                // (+4178.77%)은 이 폭을 넘겨 **두 줄로 쪼개졌다.**
                // 줄을 늘리는 대신 글자를 줄인다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${c.itemReturnPct >= 0 ? '+' : '−'}${c.itemReturnPct.abs().toStringAsFixed(2)}%',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                        fontSize: DS.returnPct,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
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

  /// 차트 막대 밑에 적을 라벨.
  ///
  /// 문장('3분기 진행 중')에 쓰는 [_subLabel]과 달리 **칸 폭이 정해져 있다.**
  /// 월간은 열두 칸이라 한 칸이 29px 남짓이고 '12월'이 잘린다. 해가 바뀌는
  /// 자리에 연도가 찍히므로 숫자만으로 읽힌다.
  String _barLabel(PeriodKey key) =>
      (_period == SettlementPeriod.monthly && _isKo)
          ? '${key.sub}'
          : _subLabel(key);

  String _subLabel(PeriodKey key) {
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


  // ── 공유 ──

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
          '${dir.path}/settlement_${DateTime.now().millisecondsSinceEpoch}.png');
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
    final pf = _pf;
    final r = _current;
    final pnlColors = context.read<PnlColorNotifier>();
    final range = SettlementService.periodRange(_period, _selected);
    final color = (r?.absoluteReturn ?? 0) >= 0
        ? pnlColors.positiveColor
        : pnlColors.negativeColor;
    final cur = pf?.currency ?? 'KRW';

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
              Flexible(
                child: Text('${pf?.emoji ?? ''} ${pf?.name ?? ''}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
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
                    style:
                        TextStyle(fontSize: 12, color: context.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  r == null
                      ? '—'
                      : '${r.absoluteReturn >= 0 ? '+' : '−'}${fmtMoney(r.absoluteReturn.abs(), cur)}',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: color),
                ),
                if (r != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    r.rateAvailable
                          ? '${r.returnRate >= 0 ? '+' : '−'}${r.returnRate.abs().toStringAsFixed(2)}%'
                          : '—',
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
            ...r.contributions.take(6).map((c) {
              final cc = c.itemAbsoluteReturn >= 0
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
                      child: Text(c.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${c.itemAbsoluteReturn >= 0 ? '+' : '−'}${fmtMoney(c.itemAbsoluteReturn.abs(), cur)}',
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
