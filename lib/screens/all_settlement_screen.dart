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
  /// 차트 칸 수.
  ///
  /// 월간만 12칸이다 — 1년을 한눈에 보려면 열두 달이 있어야 한다.
  /// 나머지는 6칸이면 주간 6주·분기 1년반·연간 6년으로 충분하다.
  /// 차트에 깔아 둘 칸 수.
  ///
  /// 예전에는 열두 칸을 화면 폭에 나눠 넣고 **한 칸씩** 창을 옮겼다. 한 번
  /// 밀면 한 달만 움직이니 답답했다. 이제 넉넉히 깔아 두고 그 안을 그냥
  /// 스크롤한다 — 멈춘 뒤 계산을 기다릴 일도 없다.
  ///
  /// 보유 전 기간은 계산이 거의 공짜다(시세를 받을 종목이 없다). 한 번 계산한
  /// 기간은 디스크에 남아 다음부터 바로 나온다.
  int get _barCount => switch (_period) {
        SettlementPeriod.weekly => 26,
        SettlementPeriod.monthly => 36,
        SettlementPeriod.quarterly => 16,
        SettlementPeriod.yearly => 8,
      };

  SettlementPeriod _period = SettlementPeriod.monthly;

  /// 차트 오른쪽 끝 기간
  late PeriodKey _endKey;

  /// 선택된 기간
  late PeriodKey _selected;

  List<CombinedSettlement?> _series = const [];
  bool _loading = false;

  /// 계산이 끝난 칸 수. 진행 표시에 쓴다.
  ///
  /// 45초를 `계산 중…` 한 줄로 기다리게 하면 **앱이 멈춘 것으로 읽힌다.**
  /// 몇 칸 중 몇 칸인지만 알려줘도 기다림의 성질이 달라진다.
  int _done = 0;

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
    _endKey = SettlementService.currentKey(_period);
    _selected = _endKey;
    _loadedStamp = _priceStamp;
    if (j != null) {
      _appliedJump = j.nonce;
      _jumpTo(j);
    } else {
      _load();
    }
  }

  /// 요청한 기간을 고른 채로 연다.
  ///
  /// 창은 되도록 **현재 기간을 오른쪽 끝**으로 둔다 — 지난달만 덩그러니
  /// 놓이면 앞뒤 기간과 견줄 수 없다. 창 밖이면 그때만 창을 옮긴다.
  void _jumpTo(SettlementJump j) {
    _period = j.period;
    // 이미 화면에 있는 기간이면 **고르기만 한다.** 다시 부르면 열두 칸이
    // 통째로 비었다 차올라, 계산할 게 없는데도 계산하는 것처럼 보인다.
    if (_windowKeys(_endKey).contains(j.key) &&
        _series.any((e) => e?.key == j.key)) {
      setState(() => _selected = j.key);
      return;
    }
    final end = SettlementService.currentKey(j.period);
    final target = _windowKeys(end).contains(j.key) ? end : j.key;
    _load(endKey: target, select: j.key);
  }

  @override
  void didUpdateWidget(AllSettlementScreen old) {
    super.didUpdateWidget(old);
    final j = widget.jump;
    if (j != null && j.nonce != _appliedJump) {
      _appliedJump = j.nonce;
      _loadedStamp = _priceStamp;
      setState(() => _period = j.period);
      _jumpTo(j);
      return;
    }
    if (old.portfolios != widget.portfolios) {
      _loadedStamp = _priceStamp;
      _load();
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
    if (_loading || _series.isEmpty) {
      // 아직 첫 계산 중이면 그 결과가 옛 가격으로 나온다 — 통째로 다시 부른다
      _load();
      return;
    }
    final keys = _windowKeys(_endKey);
    for (var i = 0; i < keys.length && i < _series.length; i++) {
      if (_series[i]?.isCurrentPeriod != true) continue;
      final r = await SettlementService.calculateCombined(
          widget.portfolios, _period, keys[i],
          useCache: false);
      if (!mounted) return;
      setState(() {
        final next = List<CombinedSettlement?>.of(_series);
        if (i < next.length) next[i] = r;
        _series = next;
      });
    }
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
    // 창을 옮겨도 열두 칸 중 열한 칸은 이미 계산돼 있다. 그런데 매번
    // `불러오는 중 · 12칸 중 N칸`을 띄우니 전부 다시 계산하는 것처럼 보였다.
    // 다 있으면 로딩 표시 없이 그냥 그린다.
    final keys = _windowKeys(targetEnd);
    final cached = [
      for (final k in keys)
        SettlementService.isFuture(_period, k)
            ? null
            : SettlementService.peekCombined(_period, k)
    ];
    final allReady = () {
      for (var i = 0; i < keys.length; i++) {
        if (SettlementService.isFuture(_period, keys[i])) continue;
        if (cached[i] == null) return false;
      }
      return true;
    }();
    if (allReady) {
      setState(() {
        _series = cached;
        _endKey = targetEnd;
        if (select != null) {
          _selected = select;
        } else if (!_windowKeys(targetEnd).contains(_selected)) {
          _selected = _windowKeys(targetEnd).last;
        }
        _loading = false;
        _done = keys.length;
      });
      return;
    }

    // 캐시가 다 없어도 디스크에서 읽어 오는 정도면 몇 밀리초다. 그 사이에
    // `불러오는 중`을 띄웠다 지우면 깜빡이기만 하고, 사용자는 매번 다시
    // 계산하는 줄 안다. **오래 걸릴 때만** 띄운다.
    var finished = false;
    _done = 0;
    final loaderTimer = Timer(const Duration(milliseconds: 350), () {
      if (!finished && mounted) setState(() => _loading = true);
    });

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
      onProgress: (partial) {
        if (!mounted) return;
        setState(() {
          _done = partial.where((e) => e != null).length;
          // 창을 옮기는 중이면 결과는 안 그린다 — 아직 옛 기간을 보여주는데
          // 새 창의 값을 섞으면 라벨과 숫자가 어긋난다. 진행률만 올린다.
          if (targetEnd == _endKey) _series = partial;
        });
      },
    );

    finished = true;
    loaderTimer.cancel();
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
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
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
                              ? '불러오는 중 · $_barCount칸 중 $_done칸'
                              : 'Loading · $_done of $_barCount')
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
          if (_loading && _series.isEmpty)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SettlementChart(
                bars: _buildBars(l10n),
                selected: _selected,
                onSelect: _selectKey,
                // 월간도 열두 칸이라 해가 바뀌는 자리를 표시해야
                // 작년 3월과 올해 3월이 안 섞인다
              showYearBoundary: _period != SettlementPeriod.yearly,
            ),
        ],
      ),
    );
  }

  List<SettlementBar> _buildBars(dynamic l10n) {
    // 과거 → 최신 순으로 둔다. 차트가 `reverse: true`라 **콘텐츠의 오른쪽
    // 끝**에 붙어 시작하므로, 맨 뒤(최신)가 처음 보이는 자리다.
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
                ? (_isKo
                    ? '계산 중 · $_barCount칸 중 $_done칸'
                    : 'Calculating · $_done of $_barCount')
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
