import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';
import '../widgets/portfolio_actions.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_header.dart';
import '../widgets/period_jump_sheet.dart';
import '../widgets/settlement_chart.dart';
import '../widgets/excluded_banner.dart';
import 'portfolio_settlement_screen.dart';

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
  /// 차트 칸 수.
  ///
  /// 월간만 12칸이다 — 1년을 한눈에 보려면 열두 달이 있어야 한다.
  /// 나머지는 6칸이면 주간 6주·분기 1년반·연간 6년으로 충분하다.
  int get _barCount => _period == SettlementPeriod.monthly ? 12 : 6;

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

  /// 결산을 불러온다.
  ///
  /// [endKey]·[select]는 **받아온 다음에** 반영한다. 먼저 옮겨 놓으면
  /// 그 기간의 결과가 아직 `_series`에 없어 화면이 통째로 비고, 사용자는
  /// 방금까지 보던 숫자를 잃는다. 실패하면 아예 못 돌아온다.
  Future<void> _load({PeriodKey? endKey, PeriodKey? select}) async {
    final targetEnd = endKey ?? _endKey;
    if (widget.portfolios.isEmpty) {
      setState(() => _series = const []);
      return;
    }
    setState(() => _loading = true);

    final series = await SettlementService.calculateCombinedSeries(
      widget.portfolios,
      _period,
      targetEnd,
      count: _barCount,
      // 창을 옮기는 중이 아니면 오는 대로 그린다. 열두 칸을 다 기다리면
      // 화면이 오래 비고, 정작 먼저 보는 건 최신 칸이다.
      //
      // 창을 옮기는 중이면 안 그린다 — 아직 옛 기간을 보여주고 있는데
      // 새 창의 결과를 섞으면 라벨과 숫자가 어긋난다.
      onProgress: targetEnd == _endKey
          ? (partial) {
              if (mounted) setState(() => _series = partial);
            }
          : null,
    );

    if (!mounted) return;
    setState(() {
      _series = series;
      _endKey = targetEnd;
      if (select != null) {
        _selected = select;
      } else if (!_windowKeys(targetEnd).contains(_selected)) {
        // 선택이 창 밖으로 나갔으면 가장 가까운 칸으로 끌어온다
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

  void _selectKey(PeriodKey key) {
    // 차트 안의 기간은 이미 계산돼 있으므로 다시 불러오지 않는다
    setState(() => _selected = key);
  }

  /// 차트 창을 [offset]만큼 옮긴다. 음수면 과거.
  void _shiftWindow(int offset) {
    final next = SettlementService.shiftKey(_period, _endKey, offset);
    // 미래로는 현재 기간까지만
    if (offset > 0 && SettlementService.isFuture(_period, next)) return;
    _load(endKey: next);
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

    // 이미 차트에 있는 기간이면 다시 받을 게 없다 — 누르자마자 바뀐다
    if (_windowKeys(_endKey).contains(picked)) {
      _selectKey(picked);
      return;
    }
    _load(endKey: picked, select: picked);
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
                      _buildExcluded(context),
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
                      : '${r.absoluteReturn >= 0 ? '+' : '−'}${fmtMoney(r.absoluteReturn.abs(), 'KRW')}',
                  style: TextStyle(
                    fontSize: DS.displayAmount,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1.08,
                    // 덜 받은 값은 **확정된 것처럼 보이면 안 된다.**
                    // 사용자가 그대로 옮겨 적는데, 다 받으면 조용히 달라진다.
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
                    child: Text(l10n.partialSettlement(r.missingPriceCount),
                        style: TextStyle(
                            fontSize: DS.body,
                            fontWeight: FontWeight.w600,
                            color: context.onBrandSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              const SizedBox(height: 6),
              // 계산이 안 되면 `—` 하나만 남아 왜 비었는지 알 수 없었다.
              // 숫자를 지어내지 않되, 이유와 다음 행동은 준다 (v13e와 같은 원칙)
              if (r == null && !_loading)
                _buildCannotCompute(context, l10n)
              else
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
                          color: (r.absoluteReturn >= 0
                                  ? pnlColors.onBrandPositive
                                  : pnlColors.onBrandNegative)
                              .withValues(alpha: r.isPartial ? 0.45 : 1.0),
                        ),
                      ),
                    if (r != null && r.netCashFlow.abs() > 1) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isKo
                              ? '순입금 ${fmtMoney(r.netCashFlow.abs(), 'KRW')}은 제외'
                              : 'Excludes ${fmtMoney(r.netCashFlow.abs(), 'KRW')} net deposits',
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

  /// 결산을 계산하지 못했을 때. 왜 비었는지 밝히고 다시 시도할 길을 준다.
  ///
  /// 결산은 기간 시작·끝의 과거 주가를 받아야 나온다. 네트워크가 없거나
  /// 시세 조회가 실패하면 아무 값도 못 만든다 — 그 사실을 말해주지 않으면
  /// 사용자는 앱이 고장 났다고 생각한다.
  Widget _buildCannotCompute(BuildContext context, dynamic l10n) {
    // 보유 종목이 아예 없으면 계산할 게 없는 것이지 실패가 아니다
    final hasHoldings = widget.portfolios
        .any((pf) => pf.items.any((i) => !i.isCash && i.shares > 0));

    return Row(children: [
      Flexible(
        child: Text(
          hasHoldings
              ? l10n.settlementCannotCompute
              : l10n.settlementNoHoldings,
          style: TextStyle(
              fontSize: DS.body,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: context.onBrandSecondary),
        ),
      ),
      if (hasHoldings) ...[
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _loading ? null : _load,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(DS.chipRadius),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.refresh, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(l10n.refreshRetry,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]),
          ),
        ),
      ],
    ]);
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

  /// 결산에서 빠진 종목을 밝힌다 — 전 포트를 합쳐서 센다.
  Widget _buildExcluded(BuildContext context) {
    final excluded = <PortfolioItem>[];
    double value = 0;
    for (final pf in widget.portfolios) {
      final e = SettlementService.excludedItems(pf, _period, _selected);
      if (e.isEmpty) continue;
      excluded.addAll(e);
      // 포트 통화가 섞일 수 있으므로 원화로 모은다
      final v = SettlementService.excludedValue(pf, e);
      value += pf.currency == 'USD' ? v * pf.exchangeRate : v;
    }
    if (excluded.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ExcludedBanner(
        items: excluded,
        amountText: fmtMoney(value, 'KRW'),
        onFix: () => showExcludedSheet(context, items: excluded),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, dynamic l10n) {
    final r = _current;
    final range = SettlementService.periodRange(_period, _selected);
    final inProgress =
        r?.isCurrentPeriod ?? !range.end.isBefore(DateTime.now());

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
                      // 창을 옮기는 동안에도 보던 기간을 그대로 두므로,
                      // 말해주지 않으면 눌러도 아무 일이 없는 것처럼 보인다
                      _loading
                          ? (_isKo
                              ? '다른 기간을 불러오는 중…'
                              : 'Loading another period…')
                          : inProgress
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
                // 월간도 열두 칸이라 해가 바뀌는 자리를 표시해야
                // 작년 3월과 올해 3월이 안 섞인다
                showYearBoundary: _period != SettlementPeriod.yearly,
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

    final sumAbs =
        r.contributions.fold(0.0, (s, c) => s + c.absoluteReturn.abs());

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

    return InkWell(
      // 포트별 결산은 전체와 기간을 각자 기억한다
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PortfolioSettlementScreen(portfolioId: c.portfolioId),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: isLast
            ? null
            : BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: context.dividerColor))),
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
                  '$sign${fmtMoney(c.absoluteReturn.abs(), 'KRW')}',
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
                      c.rateAvailable
                          ? '${c.returnRate >= 0 ? '+' : '−'}${c.returnRate.abs().toStringAsFixed(2)}%'
                          : '—',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                          fontSize: DS.returnPct,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: context.textTertiary),
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
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
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
          const SizedBox(height: 18),
          // 회색 글자만 두면 무엇을 눌러야 할지 알 수 없다
          OutlinedButton.icon(
            onPressed: () => createPortfolioThenAddItems(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.createPortfolioCta,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.brandOnLight,
              side: BorderSide(color: context.brand, width: 1.3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.buttonRadius)),
            ),
          ),
        ]),
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
        // 열두 칸이면 한 칸이 29px 남짓이라 '12월'이 잘린다.
        // 해가 바뀌는 자리에 연도가 찍히므로 숫자만으로 읽힌다.
        return _isKo ? '${key.sub}' : _monthAbbr(key.sub);
      case SettlementPeriod.quarterly:
        return _isKo ? '${key.sub}분기' : 'Q${key.sub}';
      case SettlementPeriod.yearly:
        return '${key.year}';
    }
  }

  static String _monthAbbr(int m) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m - 1];

  String _fullRangeLabel(DateTime a, DateTime b) =>
      '${a.year}.${a.month.toString().padLeft(2, '0')}.${a.day.toString().padLeft(2, '0')}'
      ' – '
      '${b.month.toString().padLeft(2, '0')}.${b.day.toString().padLeft(2, '0')}';

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
                    style:
                        TextStyle(fontSize: 12, color: context.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  r == null
                      ? '—'
                      : '${r.absoluteReturn >= 0 ? '+' : '−'}${fmtMoney(r.absoluteReturn.abs(), 'KRW')}',
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
                      '${c.absoluteReturn >= 0 ? '+' : '−'}${fmtMoney(c.absoluteReturn.abs(), 'KRW')}',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: cc),
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
