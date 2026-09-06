import 'dart:async';
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
import '../services/asset_backfill_service.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';
import '../widgets/portfolio_actions.dart';
import '../widgets/brand_header.dart';
import '../widgets/collapsing_header.dart';
import '../widgets/period_jump_sheet.dart';
import '../widgets/settlement_chart.dart';
import '../widgets/settlement_capture_card.dart';
import '../widgets/settlement_header.dart';
import '../widgets/excluded_banner.dart';
import 'portfolio_settlement_screen.dart';

/// 결산 탭 — 전체 포트폴리오 합산 (v22a).
///
/// 기간 칩과 주차 드롭다운 대신 **차트가 기간 선택 컨트롤**이다.
/// 어떤 기간을 왜 골랐는지가 이웃 기간과 함께 화면에 남는다.
/// 다른 탭에서 "이 기간을 열어달라"고 넘기는 요청.
///
/// 자산 탭의 `결산 준비` 카드는 **지난달** 수익률을 적어 둔다. 눌렀는데
/// 이번 달이 열리면 카드가 말한 숫자가 화면 어디에도 없다.
class SettlementJump {
  final SettlementPeriod period;
  final PeriodKey key;

  /// 같은 카드를 다시 눌러도 반영되도록 누를 때마다 새 값을 넣는다.
  final int nonce;

  const SettlementJump({
    required this.period,
    required this.key,
    required this.nonce,
  });
}

class AllSettlementScreen extends StatefulWidget {
  final List<Portfolio> portfolios;

  /// 다른 탭이 지정한 기간. 없으면 현재 기간으로 연다.
  final SettlementJump? jump;

  const AllSettlementScreen({
    super.key,
    required this.portfolios,
    this.jump,
  });

  @override
  State<AllSettlementScreen> createState() => _AllSettlementScreenState();
}

class _AllSettlementScreenState extends State<AllSettlementScreen> {
  SettlementPeriod _period = SettlementPeriod.monthly;

  /// 선택된 기간
  late PeriodKey _selected;

  /// 계산해 둔 결과. 차트에 깔린 기간 전부가 아니라 **본 것만** 들어 있다.
  final Map<PeriodKey, CombinedSettlement> _results = {};

  /// 지금 계산 중인 기간. 같은 칸을 두 번 부르지 않는다.
  final Set<PeriodKey> _busy = {};

  bool _loading = false;

  /// 차트 가로 스크롤. 멈춘 자리를 읽어 그 구간만 계산한다.
  final ScrollController _chartScroll = ScrollController();

  /// 화면 세로 스크롤. 헤더가 끝까지 접히는지 재는 데 쓴다.
  final ScrollController _pageScroll = ScrollController();

  /// 헤더가 끝까지 접히도록 모자란 스크롤 거리를 채운다.
  final CollapseTail _tail = CollapseTail();

  /// 헤더 본문의 실제 높이. 글자 크기 설정에 따라 달라져 한 번 재서 쓴다.
  double _bodyH = 250;

  bool _saving = false;
  bool _sharing = false;
  final _screenshotCtrl = ScreenshotController();

  /// 마지막으로 계산에 쓴 시세 기준 시각.
  ///
  /// 진행 중인 기간의 끝값은 **현재가**다. 앱을 켠 직후나 복원 직후엔
  /// 아직 갱신 전 가격이 들어 있고, 그 값으로 계산한 손익이 화면에 남는다.
  /// 시세가 들어와도 포트폴리오 목록 자체는 같은 객체라 `didUpdateWidget`의
  /// 리스트 비교로는 안 걸린다 — 기준 시각을 따로 본다.
  int _loadedStamp = 0;

  int get _priceStamp {
    var m = 0;
    for (final p in widget.portfolios) {
      final t = p.lastUpdated;
      if (t != null && t > m) m = t;
    }
    return m;
  }

  /// 이미 반영한 이동 요청. 같은 요청을 두 번 처리하지 않는다.
  int? _appliedJump;

  @override
  void initState() {
    super.initState();
    final j = widget.jump;
    if (j != null) _period = j.period;
    _selected = j?.key ?? SettlementService.currentKey(_period);
    _loadedStamp = _priceStamp;
    if (j != null) _appliedJump = j.nonce;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVisible();
      if (j != null) _scrollToSelected();
    });
  }

  @override
  void dispose() {
    _chartScroll.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  // ── 차트에 깔 기간 ──

  /// 첫 거래가 든 기간부터 지금까지. **데이터가 있는 만큼** 연다.
  ///
  /// 예전에는 칸 수를 박아 두고(월간 36칸) 그만큼만 그렸다. 계산량이 걱정돼
  /// 막아 둔 것인데, 보이지도 않는 칸까지 미리 계산하던 게 원인이었다.
  /// 화면에 들어온 칸만 계산하면 범위를 제한할 이유가 없다.
  List<PeriodKey> get _allKeys {
    final now = SettlementService.currentKey(_period);
    final first = AssetBackfillService.firstTransactionDay(widget.portfolios);
    // 기록이 짧아도 차트가 허전하지 않게 최소 칸은 둔다
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
    return out.reversed.toList(); // 과거 → 최신
  }

  /// 요청한 기간을 고른 채로 연다.
  void _jumpTo(SettlementJump j) {
    setState(() {
      _period = j.period;
      _selected = j.key;
    });
    _loadVisible(around: j.key);
    _scrollToSelected();
  }

  @override
  void didUpdateWidget(AllSettlementScreen old) {
    super.didUpdateWidget(old);
    final j = widget.jump;
    if (j != null && j.nonce != _appliedJump) {
      _appliedJump = j.nonce;
      _loadedStamp = _priceStamp;
      _jumpTo(j);
      return;
    }
    if (old.portfolios != widget.portfolios) {
      _loadedStamp = _priceStamp;
      _results.clear();
      _loadVisible();
    } else if (_priceStamp != _loadedStamp) {
      _loadedStamp = _priceStamp;
      _refreshLive();
    }
  }

  /// 시세가 갱신됐을 때 **진행 중인 칸만** 다시 계산한다.
  ///
  /// 전체를 다시 부르면 지난 기간까지 지웠다 그리느라 차트가 깜빡인다.
  /// 현재가에 영향받는 칸은 진행 중인 하나뿐이다.
  Future<void> _refreshLive() async {
    final now = SettlementService.currentKey(_period);
    final r = await SettlementService.calculateCombined(
        widget.portfolios, _period, now,
        useCache: false);
    if (!mounted) return;
    setState(() {
      if (r != null) _results[now] = r;
    });
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  CombinedSettlement? get _current => _results[_selected];

  // ── 데이터 ──

  /// 지금 화면에 보이는 칸들. 차트가 아직 안 그려졌으면 최신 쪽 몇 칸.
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
    // `reverse: true`라 offset 0이 **최신**이다. 끝에서부터 센다.
    final fromEnd = (offset / pitch).floor();
    final count = (viewport / pitch).ceil() + 2;
    final last = (keys.length - fromEnd).clamp(0, keys.length);
    final first = (last - count).clamp(0, keys.length);
    return keys.sublist(first, last);
  }

  /// 보이는 칸 중 아직 계산 안 한 것만 계산한다.
  ///
  /// 차트에 깔린 기간을 전부 미리 계산하면, 스크롤을 열어 준 만큼 계산량이
  /// 늘어난다. **화면에 들어온 것만** 한다 — 최신 칸부터.
  Future<void> _loadVisible({PeriodKey? around}) async {
    if (widget.portfolios.isEmpty) return;
    final keys = <PeriodKey>[..._visibleKeys()];
    if (around != null && !keys.contains(around)) {
      // 고른 기간이 아직 화면 밖이면 그 언저리를 먼저 채운다
      final all = _allKeys;
      final i = all.indexOf(around);
      if (i != -1) {
        keys.addAll(all.sublist(
            (i - 6).clamp(0, all.length), (i + 7).clamp(0, all.length)));
      }
    }

    final todo = [
      for (final k in keys.reversed) // 최신부터
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
      final r =
          await SettlementService.calculateCombined(widget.portfolios, _period, k);
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
      // `PeriodKey`는 기간 단위를 식별에 넣지 않는다 — 월간 3월과 분기 3분기가
      // 둘 다 (2026, 3)이다. 옛 결과를 남겨 두면 단위를 바꾼 직후 **3월 숫자가
      // 3분기 라벨 밑에 뜬다.** 지어낸 숫자보다 빈 화면이 낫다.
      _results.clear();
      _busy.clear();
      _selected = SettlementService.currentKey(p);
    });
    if (_chartScroll.hasClients) _chartScroll.jumpTo(0);
    _loadVisible();
  }

  void _selectKey(PeriodKey key) {
    setState(() => _selected = key);
    _loadVisible(around: key);
  }

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
      // 차트가 첫 거래부터 시작하니 시트도 거기까지만 연다
      earliestDay: AssetBackfillService.firstTransactionDay(widget.portfolios),
      amountOf: (k) => _results[k]?.absoluteReturn,
    );
    if (picked == null || !mounted) return;
    // 고른 기간이 화면 밖이면 **차트도 그리로 옮긴다** — 골라 놓고 어디 있는지
    // 못 찾으면 고른 게 아니다.
    setState(() => _selected = picked);
    _loadVisible(around: picked);
    _scrollToSelected();
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tail.fit(_pageScroll, _bodyH)) setState(() {});
    });

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: widget.portfolios.isEmpty
          ? Column(children: [
              BrandHeader(
                title: l10n.tabSettlement,
                childPadding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
                child: _buildHeaderBody(context, l10n),
              ),
              Expanded(child: _buildEmpty(context)),
            ])
          : CustomScrollView(
              controller: _pageScroll,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  // 스크롤을 멈추면 끝까지 접거나 끝까지 편다 — 반쯤 접힌 채
                  // 굳으면 탭 글자가 잘려 고장 난 것처럼 보인다.
                  floating: true,
                  delegate: CollapsingHeaderDelegate(
                    background: context.appBarBg,
                    topInset: MediaQuery.paddingOf(context).top,
                    titleHeight: 48 *
                        MediaQuery.textScalerOf(context)
                            .scale(1)
                            .clamp(1.0, 1.6),
                    bodyHeight: _bodyH,
                    expandedTitle: Text(
                      l10n.tabSettlement,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3),
                    ),
                    collapsedTitle: _buildCompactHeader(context),
                    actions: [
                      if (_current != null)
                        IconButton(
                          icon:
                              const Icon(Icons.ios_share, color: Colors.white),
                          tooltip: l10n.capture,
                          onPressed: _showCaptureSheet,
                        ),
                    ],
                    body: MeasureSize(
                      onHeight: (h) {
                        if ((_bodyH - h).abs() < 0.5) return;
                        if (mounted) setState(() => _bodyH = h);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
                        child: _buildHeaderBody(context, l10n),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildExcluded(context),
                      _buildChartCard(context, l10n),
                      const SizedBox(height: 14),
                      _buildContributions(context),
                      SizedBox(height: _tail.value),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  /// 헤더가 접혔을 때 제목 자리에 남는 한 줄.
  ///
  /// 종목이 많으면 기여 목록을 보려고 계속 밀게 되는데, 그때도 **지금 어느
  /// 기간의 얼마를 보는 중인지**는 남아 있어야 한다.
  Widget _buildCompactHeader(BuildContext context) {
    final r = _current;
    final pnl = context.watch<PnlColorNotifier>();
    if (r == null) {
      return Text(
        context.l10n.tabSettlement,
        style: const TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
      );
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
              '${up ? '+' : '−'}${fmtMoney(r.absoluteReturn.abs(), 'KRW')}',
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

  Widget _buildHeaderBody(BuildContext context, dynamic l10n) {
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
                currency: 'KRW',
                fallback: (r == null && !_loading)
                    ? _buildCannotCompute(context, l10n)
                    : null,
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
                    child: Text(l10n.partialSettlement(r.missingPriceCount),
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
          onTap: _loading ? null : () => _loadVisible(),
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
                          ? (_isKo ? '불러오는 중…' : 'Loading…')
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
              const SizedBox(width: 4),
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
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SettlementChart(
              bars: _buildBars(l10n),
              selected: _selected,
              onSelect: _selectKey,
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

  List<SettlementBar> _buildBars(dynamic l10n) {
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
            label: _subLabel(k, l10n),
            amount: isFuture ? null : found?.absoluteReturn,
            inProgress: found?.isCurrentPeriod ?? false,
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

  /// `₩339,380,230 → ₩338,407,160` — 기여 행의 근거.
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
            // 얼마에서 얼마가 됐는지. 손익만 보여주면 그 크기를 가늠할
            // 기준이 없다 — 100만 원이 큰지 작은지는 원금이 정한다.
            const SizedBox(height: 3),
            _basisLine(context, c.startValue, c.endValue, 'KRW'),
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
    final range = SettlementService.periodRange(_period, _selected);
    final inProgress = r?.isCurrentPeriod ?? !range.end.isBefore(DateTime.now());

    return SettlementCaptureCard(
      title: _isKo ? '전체 결산' : 'All portfolios',
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
      currency: 'KRW',
      rowsTitle: _isKo ? '포트별 기여' : 'Contribution by portfolio',
      isKo: _isKo,
      positiveColor: context.read<PnlColorNotifier>().positiveColor,
      negativeColor: context.read<PnlColorNotifier>().negativeColor,
      rows: [
        for (final c in (r?.contributions ?? const []).take(8))
          CaptureRow(
            name: c.name,
            absoluteReturn: c.absoluteReturn,
            returnRate: c.returnRate,
            rateAvailable: c.rateAvailable,
            startValue: c.startValue,
            endValue: c.endValue,
          ),
      ],
    );
  }
}
