import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../services/asset_backfill_service.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';
import '../widgets/bottom_banner_ad.dart';
import '../widgets/collapsing_header.dart';
import '../widgets/period_jump_sheet.dart';
import '../widgets/settlement_chart.dart';
import '../widgets/settlement_capture_card.dart';
import '../widgets/settlement_header.dart';
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
  SettlementPeriod _period = SettlementPeriod.monthly;
  /// 계산해 둔 결과. 차트에 깔린 기간 전부가 아니라 **본 것만** 들어 있다.
  final Map<PeriodKey, SettlementResult> _results = {};
  final Set<PeriodKey> _busy = {};

  /// 차트 가로 스크롤. 멈춘 자리를 읽어 그 구간만 계산한다.
  final ScrollController _chartScroll = ScrollController();

  /// 화면 세로 스크롤. 헤더가 끝까지 접히는지 재는 데 쓴다.
  final ScrollController _pageScroll = ScrollController();

  /// 헤더가 끝까지 접히도록 모자란 스크롤 거리를 채운다.
  final CollapseTail _tail = CollapseTail();
  late PeriodKey _selected;

  bool _loading = false;
  bool _sharing = false;
  bool _saving = false;

  /// 헤더 본문의 실제 높이. 글자 크기 설정에 따라 달라져 한 번 재서 쓴다.
  double _bodyH = 250;
  final _screenshotCtrl = ScreenshotController();

  /// 계산에 쓴 시세 기준 시각.
  ///
  /// 진행 중인 기간의 끝값은 현재가다. 앱을 켠 직후엔 아직 갱신 전 가격이라
  /// 그 값으로 낸 손익이 화면에 굳는다 — 시세가 들어오면 다시 계산한다.
  int _loadedStamp = 0;
  PortfolioProvider? _provider;

  @override
  void initState() {
    super.initState();
    _selected = SettlementService.currentKey(_period);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadedStamp = _pf?.lastUpdated ?? 0;
      _provider = context.read<PortfolioProvider>()..addListener(_onPrices);
      _loadVisible();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onPrices);
    _chartScroll.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  // ── 차트에 깔 기간 ──

  /// 첫 거래가 든 기간부터 지금까지. **데이터가 있는 만큼** 연다.
  List<PeriodKey> get _allKeys {
    final pf = _pf;
    final now = SettlementService.currentKey(_period);
    final first =
        pf == null ? null : AssetBackfillService.firstTransactionDay([pf]);
    final minBars = _period == SettlementPeriod.yearly ? 5 : 12;
    final cap = switch (_period) {
      SettlementPeriod.weekly => 520,
      SettlementPeriod.monthly => 240,
      SettlementPeriod.quarterly => 80,
      SettlementPeriod.yearly => 30,
    };
    final out = <PeriodKey>[];
    var k = now;
    for (var i = 0; i < cap; i++) {
      out.add(k);
      final r = SettlementService.periodRange(_period, k);
      if (first != null && !r.start.isAfter(first) && out.length >= minBars) {
        break;
      }
      if (first == null && out.length >= minBars) break;
      k = SettlementService.shiftKey(_period, k, -1);
    }
    return out.reversed.toList();
  }

  void _onPrices() {
    if (!mounted) return;
    final s = _pf?.lastUpdated ?? 0;
    if (s == _loadedStamp) return;
    _loadedStamp = s;
    final now = SettlementService.currentKey(_period);
    _results.remove(now);
    _loadVisible();
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  Portfolio? get _pf {
    final list = context.read<PortfolioProvider>().portfolios;
    for (final p in list) {
      if (p.id == widget.portfolioId) return p;
    }
    return null;
  }

  SettlementResult? get _current => _results[_selected];

  // ── 데이터 ──

  /// 지금 화면에 보이는 칸들.
  List<PeriodKey> _visibleKeys() {
    final keys = _allKeys;
    if (keys.isEmpty) return const [];
    const pitch = SettlementChart.barPitch;
    double offset = 0;
    double viewport = 360;
    if (_chartScroll.hasClients) {
      offset = _chartScroll.offset.clamp(0.0, double.infinity);
      viewport = _chartScroll.position.viewportDimension;
    }
    final fromEnd = (offset / pitch).floor();
    final count = (viewport / pitch).ceil() + 2;
    final last = (keys.length - fromEnd).clamp(0, keys.length);
    final first = (last - count).clamp(0, keys.length);
    return keys.sublist(first, last);
  }

  /// 보이는 칸 중 아직 계산 안 한 것만 계산한다 — 최신 칸부터.
  Future<void> _loadVisible({PeriodKey? around}) async {
    final pf = _pf;
    if (pf == null) return;
    final keys = <PeriodKey>[..._visibleKeys()];
    if (around != null && !keys.contains(around)) {
      final all = _allKeys;
      final i = all.indexOf(around);
      if (i != -1) {
        keys.addAll(all.sublist(
            (i - 6).clamp(0, all.length), (i + 7).clamp(0, all.length)));
      }
    }
    final todo = [
      for (final k in keys.reversed)
        if (!_results.containsKey(k) &&
            !_busy.contains(k) &&
            !SettlementService.isFuture(_period, k))
          k
    ];
    if (todo.isEmpty) return;

    _busy.addAll(todo);
    var finished = false;
    final loaderTimer = Timer(const Duration(milliseconds: 350), () {
      if (!finished && mounted) setState(() => _loading = true);
    });

    for (final k in todo) {
      final r = await SettlementService.calculateCached(pf, _period, k);
      if (!mounted) return;
      setState(() {
        if (r != null) _results[k] = r;
        _busy.remove(k);
      });
    }
    finished = true;
    loaderTimer.cancel();
    if (mounted) setState(() => _loading = false);
  }

  /// 고른 기간이 화면 가운데에 오도록 차트를 옮긴다.
  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chartScroll.hasClients) return;
      final keys = _allKeys;
      final i = keys.indexOf(_selected);
      if (i == -1) return;
      const pitch = SettlementChart.barPitch;
      final fromEnd = keys.length - 1 - i;
      final viewport = _chartScroll.position.viewportDimension;
      final target = (fromEnd * pitch - viewport / 2 + pitch / 2)
          .clamp(0.0, _chartScroll.position.maxScrollExtent);
      _chartScroll.animateTo(target,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    });
  }

  void _changePeriod(SettlementPeriod p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      _results.clear();
      _busy.clear();
      _selected = SettlementService.currentKey(p);
    });
    if (_chartScroll.hasClients) _chartScroll.jumpTo(0);
    _loadVisible();
  }

  Future<void> _openJumpSheet() async {
    final pf = _pf;
    if (pf == null) return;

    final picked = await PeriodJumpSheet.show(
      context,
      period: _period,
      selected: _selected,
      earliestYear: SettlementService.earliestYear(pf),
      // 차트가 첫 거래부터 시작하니 시트도 거기까지만 연다
      earliestDay: AssetBackfillService.firstTransactionDay([pf]),
      // 이 시트가 어느 범위를 다루는지 밝힌다
      scopeName: pf.name,
      amountOf: (k) => _results[k]?.absoluteReturn,
    );
    if (picked == null || !mounted) return;

    // 이미 차트에 있는 기간이면 다시 받을 게 없다 — 누르자마자 바뀐다
    // 고른 기간이 화면 밖이면 **차트도 그리로 옮긴다**
    setState(() => _selected = picked);
    _loadVisible(around: picked);
    _scrollToSelected();
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tail.fit(_pageScroll, _bodyH)) setState(() {});
    });
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
              Expanded(
                child: CustomScrollView(
                  controller: _pageScroll,
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      // 멈추면 끝까지 접거나 끝까지 편다
                      floating: true,
                      delegate: CollapsingHeaderDelegate(
                        background: context.appBarBg,
                        topInset: MediaQuery.paddingOf(context).top,
                        titleHeight: 48 *
                            MediaQuery.textScalerOf(context)
                                .scale(1)
                                .clamp(1.0, 1.6),
                        bodyHeight: _bodyH,
                        leading: IconButton(
                          tooltip: context.l10n.a11yBack,
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        expandedTitle: Text(
                          pf.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                        collapsedTitle: _buildCompactHeader(context, pf),
                        actions: [
                          if (_current != null)
                            IconButton(
                              icon: const Icon(Icons.ios_share,
                                  color: Colors.white),
                              tooltip: context.l10n.shareImage,
                              onPressed: (_sharing || _saving)
                                  ? null
                                  : _showCaptureSheet,
                            ),
                        ],
                        body: MeasureSize(
                          onHeight: (h) {
                            if ((_bodyH - h).abs() < 0.5) return;
                            if (mounted) setState(() => _bodyH = h);
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
                            child: _buildHeaderBody(context, pf),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      // 아래는 배너가 자리를 잡는다 (배너가 SafeArea를 쓴다).
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildExcluded(context, pf),
                          _buildChartCard(context, pf),
                          const SizedBox(height: 14),
                          _buildItemContributions(context, pf),
                          SizedBox(height: _tail.value),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              // 공유 이미지는 `captureFromWidget`으로 따로 그린다 — 화면에
              // 배너를 붙여도 저장·공유한 그림에는 안 들어간다.
              const SafeArea(top: false, child: BottomBannerAd()),
            ],
          ),
        );
      },
    );
  }

  /// 헤더가 접혔을 때 제목 자리에 남는 한 줄.
  Widget _buildCompactHeader(BuildContext context, Portfolio pf) {
    final r = _current;
    final pnl = context.watch<PnlColorNotifier>();
    if (r == null) {
      return Text(pf.name,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white),
          overflow: TextOverflow.ellipsis);
    }
    final up = r.absoluteReturn >= 0;
    final color = up ? pnl.onBrandPositive : pnl.onBrandNegative;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(settlementPeriodLabel(context, _period, _selected),
            style: TextStyle(
                fontSize: DS.body,
                fontWeight: FontWeight.w700,
                color: context.onBrandSecondary)),
        const SizedBox(width: 7),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${up ? '+' : '−'}${fmtMoney(r.absoluteReturn.abs(), pf.currency)}',
              maxLines: 1,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: color),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          r.rateAvailable
              ? '${r.returnRate >= 0 ? '+' : '−'}${r.returnRate.abs().toStringAsFixed(2)}%'
              : '—',
          style: TextStyle(
              fontSize: DS.caption, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildHeaderBody(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
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
              SettlementHeaderBody(
                periodLabel:
                    settlementPeriodLabel(context, _period, _selected),
                rangeLabel: settlementRangeLabel(
                    SettlementService.periodRange(_period, _selected).start,
                    SettlementService.periodRange(_period, _selected).end),
                absoluteReturn: r?.absoluteReturn,
                returnRate: r?.returnRate ?? 0,
                rateAvailable: r?.rateAvailable ?? false,
                startValue: r?.startValue ?? 0,
                endValue: r?.endValue ?? 0,
                netCashFlow: r?.netCashFlow ?? 0,
                partial: r?.isPartial ?? false,
                inProgress: r?.isCurrentPeriod ?? false,
                currency: pf.currency,
              ),
              if (r != null && r.isPartial) ...[
                const SizedBox(height: 7),
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
          if (_loading && _results.isEmpty)
            const SizedBox(
                height: 100, child: Center(child: CircularProgressIndicator()))
          else
            SettlementChart(
              bars: _buildBars(),
              selected: _selected,
              onSelect: (k) {
                setState(() => _selected = k);
                _loadVisible(around: k);
              },
              controller: _chartScroll,
              // 손을 떼고 멈추면 그때 보이는 칸만 계산한다
              onSettled: _loadVisible,
              // 해가 바뀌는 자리를 표시해야 작년 3월과 올해 3월이 안 섞인다
              showYearBoundary: _period != SettlementPeriod.yearly,
            ),
        ],
      ),
    );
  }

  List<SettlementBar> _buildBars() {
    final today = DateTime.now();
    // 과거 → 최신 순. 차트가 `reverse: true`라 맨 뒤(최신)가 먼저 보인다.
    return [
      for (final k in _allKeys)
        () {
          final found = _results[k];
          final range = SettlementService.periodRange(_period, k);
          final isFuture = range.start.isAfter(today);
          return SettlementBar(
            key: k,
            label: _subLabel(k),
            amount: isFuture ? null : found?.absoluteReturn,
            inProgress: found?.isCurrentPeriod ?? false,
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

  /// `₩5,206,640 → ₩5,180,120` — 기여 행의 근거.
  Widget _basisLine(
      BuildContext context, double start, double end, String currency) {
    final style = TextStyle(
        fontSize: DS.caption,
        fontWeight: FontWeight.w600,
        color: context.textTertiary);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(children: [
        Text(fmtMoney(start, currency), style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Icon(Icons.arrow_forward,
              size: 11, color: context.textTertiary),
        ),
        Text(fmtMoney(end, currency), style: style),
      ]),
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
          // 얼마에서 얼마가 됐는지. 손익만 보여주면 그 크기를 가늠할
          // 기준이 없다 — 10만 원이 큰지 작은지는 원금이 정한다.
          const SizedBox(height: 3),
          _basisLine(context, c.startValue, c.endValue, pf.currency),
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


  /// 막대 밑에 적는 짧은 라벨 — `36주`, `9`, `3분기`, `2026`.
  String _subLabel(PeriodKey key) {
    switch (_period) {
      case SettlementPeriod.weekly:
        return _isKo ? '${key.sub}주' : 'W${key.sub}';
      case SettlementPeriod.monthly:
        // 칸이 좁아 `12월`은 잘린다. 해가 바뀌는 자리에 연도가 찍히므로
        // 숫자만으로도 읽힌다.
        return _isKo ? '${key.sub}' : _monthAbbr(key.sub);
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

  /// 저장할지 공유할지 고르는 시트.
  ///
  /// 전체 결산 탭은 이걸 띄우는데 여기서는 바로 공유 창이 떴다. 같은 아이콘이
  /// 화면마다 다르게 동작하면 어느 쪽이 맞는지 매번 눌러 봐야 한다.
  void _showCaptureSheet() {
    final l10n = context.l10n;
    final ctx = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // 시트 안에서 `MediaQuery.padding.bottom`은 이미 소비돼 0으로 온다 —
      // 그걸 더해 봐야 네비바를 못 비킨다. SafeArea에 맡긴다.
      useSafeArea: true,
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    foregroundColor: ctx.brand,
                    side: BorderSide(color: ctx.brand),
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
      final r = await ImageGallerySaverPlus.saveImage(bytes,
          quality: 100,
          name: 'settlement_${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      final ok = r is Map && (r['isSuccess'] == true);
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
    final range = SettlementService.periodRange(_period, _selected);
    final inProgress = r?.isCurrentPeriod ?? !range.end.isBefore(DateTime.now());
    final cur = pf?.currency ?? 'KRW';

    return SettlementCaptureCard(
      title: '${pf?.emoji ?? ''} ${pf?.name ?? ''}'.trim(),
      subtitle: _isKo
          ? '${settlementPeriodLabel(context, _period, _selected)} 손익 · '
              '${settlementRangeLabel(range.start, range.end)}'
          : '${settlementPeriodLabel(context, _period, _selected)} · '
              '${settlementRangeLabel(range.start, range.end)}',
      statusLabel: inProgress
          ? (_isKo ? '진행 중' : 'in progress')
          : (_isKo ? '마감' : 'closed'),
      absoluteReturn: r?.absoluteReturn,
      returnRate: r?.returnRate ?? 0,
      rateAvailable: r?.rateAvailable ?? false,
      startValue: r?.startValue ?? 0,
      endValue: r?.endValue ?? 0,
      netCashFlow: r?.netCashFlow ?? 0,
      inProgress: inProgress,
      currency: cur,
      rowsTitle: _isKo ? '종목별 기여' : 'Contribution by holding',
      isKo: _isKo,
      positiveColor: context.read<PnlColorNotifier>().positiveColor,
      negativeColor: context.read<PnlColorNotifier>().negativeColor,
      rows: [
        for (final c in (r?.contributions ?? const []).take(8))
          CaptureRow(
            name: c.name,
            absoluteReturn: c.itemAbsoluteReturn,
            returnRate: c.itemReturnPct,
            rateAvailable: true,
            startValue: c.startValue,
            endValue: c.endValue,
          ),
      ],
    );
  }
}
