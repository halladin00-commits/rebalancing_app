import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../widgets/portfolio_actions.dart';
import '../utils/elapsed.dart';
import '../utils/rebalancer.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_menu.dart';
import '../widgets/brand_header.dart';
import '../widgets/weight_bar.dart';
import 'portfolio_detail_screen.dart';
import 'portfolio_rebalance_screen.dart';
import 'target_weights_screen.dart';
import 'rebalance_proposal_screen.dart';

/// 리밸런싱 탭 — 포트폴리오별 편차 진단.
///
/// 허용 편차는 포트마다 다르므로 헤더에 대표값을 쓰지 않는다.
/// 대신 카드마다 `허용 ±N%p`를 편차 바로 옆에 두어,
/// 같은 편차가 어떤 포트에서는 "유지"인 이유가 한 줄에서 설명되게 한다.
class RebalanceTabScreen extends StatefulWidget {
  const RebalanceTabScreen({super.key});

  /// 허용 편차를 넘은 포트폴리오 수 — 하단 탭 배지도 이 값을 쓴다.
  static int needsAdjustingCount(List<Portfolio> portfolios) =>
      portfolios.where((p) => Rebalancer.needsAdjusting(p).isNotEmpty).length;

  /// 시세를 못 받아 **편차를 낼 수 없는** 포트 수.
  ///
  /// 이 수를 안 세면 `needsAdjustingCount == 0`이 "괜찮다"와 "모르겠다"를
  /// 한 덩어리로 만든다.
  static int unknownDriftCount(List<Portfolio> portfolios) =>
      portfolios.where((p) => !Rebalancer.canComputeDrift(p)).length;

  @override
  State<RebalanceTabScreen> createState() => _RebalanceTabScreenState();
}

class _RebalanceTabScreenState extends State<RebalanceTabScreen> {
  final ScreenshotController _screenshotCtrl = ScreenshotController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final portfolios = provider.portfolios;
        final overCount =
            RebalanceTabScreen.needsAdjustingCount(portfolios);
        final unknownCount =
            RebalanceTabScreen.unknownDriftCount(portfolios);

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              BrandHeader(
                title: l10n.tabRebalancing,
                childPadding: const EdgeInsets.fromLTRB(22, 2, 22, 18),
                actions: [
                  // 새로고침을 밖에 두고 나머지는 메뉴로 — 다른 화면과 같은
                  // 자리, 같은 순서다. 「읽는 법」은 처음 한 번 보는 것이라
                  // 늘 보이는 자리를 내줄 만큼 자주 쓰지 않는다.
                  IconButton(
                    tooltip: context.l10n.a11yRefresh,
              icon: provider.refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh, color: Colors.white),
                    onPressed: provider.refreshing ? null : provider.refreshAll,
                  ),
                  if (portfolios.isNotEmpty)
                    IconButton(
                      tooltip: context.l10n.capture,
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.ios_share, color: Colors.white),
                      onPressed:
                          _busy ? null : () => _showCaptureSheet(portfolios),
                    ),
                  AppMenu(entries: [
                    MenuAction(
                        Icons.help_outline,
                        isKo ? '이 화면 읽는 법' : 'Reading this screen',
                        () => showLegend(context)),
                  ]),
                ],
                child: portfolios.isEmpty
                    ? null
                    : _buildSummary(
                        context, portfolios, overCount, unknownCount, isKo),
              ),
              Expanded(
                child: portfolios.isEmpty
                    ? _buildEmpty(context, isKo)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: portfolios.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: DS.cardGap),
                        itemBuilder: (_, i) =>
                            _buildCard(context, portfolios[i], isKo),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 이미지 저장 · 공유 ──

  void _showCaptureSheet(List<Portfolio> portfolios) {
    final l10n = context.l10n;
    final ctx = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // 시트 안에서 `MediaQuery.padding.bottom`은 이미 소비돼 0으로 온다.
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
                      _emit(portfolios, share: false);
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
                      _emit(portfolios, share: true);
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

  Future<void> _emit(List<Portfolio> portfolios, {required bool share}) async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildCapture(context, portfolios),
        pixelRatio: 3.0,
        context: context,
      );
      if (!mounted) return;
      if (share) {
        final dir = await getTemporaryDirectory();
        final f = File(
            '${dir.path}/rebalance_${DateTime.now().millisecondsSinceEpoch}.png');
        await f.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(f.path)]);
      } else {
        final r = await ImageGallerySaverPlus.saveImage(bytes,
            name: 'rebalance_${DateTime.now().millisecondsSinceEpoch}');
        if (!mounted) return;
        final ok = r['isSuccess'] == true || r['filePath'] != null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? l10n.savedToGallery : l10n.saveFailed),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.saveFailedError(e.toString())),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 저장·공유할 리밸런싱 이미지.
  ///
  /// **화면과 같은 것을 보여준다.** 요약 한 줄과 포트별 카드까지 그대로다.
  /// 누를 수 있는 것(화살표)만 뺀다 — 그림에서는 못 누르니 있으면 거짓말이다.
  ///
  /// **여기서 읽은 값만 쓴다.** `captureFromWidget`이 만드는 딴 트리에는
  /// Provider도 Localizations도 없다.
  Widget _buildCapture(BuildContext context, List<Portfolio> portfolios) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    var overCount = 0, unknownCount = 0;
    for (final pf in portfolios) {
      if (Rebalancer.driftBlocker(pf) != null) {
        unknownCount++;
      } else if (Rebalancer.needsAdjusting(pf).isNotEmpty) {
        overCount++;
      }
    }

    return Container(
      width: 380,
      color: context.scaffoldBg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appBarBg,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(DS.headerRadius)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(context.l10n.tabRebalancing,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const AppLogo(iconSize: 18, textColor: Colors.white),
            ]),
            const SizedBox(height: 12),
            _buildSummary(context, portfolios, overCount, unknownCount, isKo),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(children: [
            for (var i = 0; i < portfolios.length; i++) ...[
              if (i > 0) const SizedBox(height: DS.cardGap),
              _buildCard(context, portfolios[i], isKo, forCapture: true),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── 헤더 요약 ──

  Widget _buildSummary(BuildContext context, List<Portfolio> portfolios,
      int overCount, int unknownCount, bool isKo) {
    final oldest = portfolios
        .where((p) => p.lastUpdated != null)
        .map((p) => p.lastUpdated!)
        .fold<int?>(null, (m, t) => m == null || t < m ? t : m);
    final timeStr = oldest == null
        ? context.l10n.neverUpdated
        : () {
            final d = DateTime.fromMillisecondsSinceEpoch(oldest);
            return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
          }();

    final baseStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: context.onBrandSecondary,
    );
    final accent = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.5,
      // 못 잰 것도 초록으로 쓰면 문장만 다르고 **느낌은 "괜찮다"**가 된다
      color: (overCount > 0 || unknownCount > 0)
          ? context.onBrandWarning
          : context.onBrandAccent,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: baseStyle,
            children: overCount > 0
                ? [
                    TextSpan(
                        text: isKo
                            ? '포트폴리오 ${portfolios.length}개 중 '
                            : '${overCount} of ${portfolios.length} portfolios\n'),
                    TextSpan(
                        text: isKo ? '$overCount개' : 'need adjusting',
                        style: accent),
                    if (isKo) const TextSpan(text: '가\n허용 편차를 넘었습니다'),
                  ]
                : unknownCount > 0
                    // 시세를 못 받으면 편차를 못 낸다. 그런데도 "다 괜찮다"고
                    // 하면 **모르는 것을 괜찮다고 말하는 것**이다.
                    ? [
                        TextSpan(
                            text: isKo
                                ? '시세를 받지 못해\n'
                                : "Can't check "),
                        TextSpan(
                            text: isKo
                                ? '$unknownCount개'
                                : '$unknownCount of ${portfolios.length}',
                            style: accent),
                        TextSpan(
                            text: isKo
                                ? ' 포트폴리오는 확인할 수 없습니다'
                                : '\nwithout current prices'),
                      ]
                    : [
                        TextSpan(
                            text:
                                isKo ? '모든 포트폴리오가\n' : 'All portfolios are\n'),
                        TextSpan(
                            text: isKo ? '허용 편차 안' : 'within tolerance',
                            style: accent),
                        if (isKo) const TextSpan(text: '에 있습니다'),
                      ],
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            _headerChip(
                context, isKo ? '허용 편차는 포트별 설정' : 'Tolerance is per portfolio'),
            _headerChip(context, '  ·  '),
            _headerChip(context, timeStr),
          ],
        ),
      ],
    );
  }

  /// 「마지막으로 언제 조정했나」.
  ///
  /// 리밸런싱 규율은 **밴드**(허용 편차를 넘으면)와 **기간**(반년·1년마다)
  /// 둘 중 하나이거나 병행이다. 이 앱은 밴드만 있었다 — 편차가 안 넘으면
  /// `유지`라고만 말하고, 그 상태로 2년이 지나도 아무 말이 없었다.
  ///
  /// 규칙을 새로 강요하지는 않는다. **사실만 적는다** — 판단은 사용자 몫이다.
  static String lastRebalancedLabel(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    final at = pf.lastRebalancedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(pf.lastRebalancedAt!);
    final age = elapsedSince(at);
    return switch (age.unit) {
      ElapsedUnit.never => l10n.lastRebalancedNever,
      ElapsedUnit.today => l10n.lastRebalancedToday,
      ElapsedUnit.yesterday => l10n.lastRebalancedYesterday,
      ElapsedUnit.days => l10n.lastRebalancedDaysAgo(age.count),
      ElapsedUnit.months => l10n.lastRebalancedMonthsAgo(age.count),
      ElapsedUnit.years => l10n.lastRebalancedYearsAgo(age.count),
    };
  }

  /// 이 화면을 읽는 법.
  ///
  /// `%p`(퍼센트포인트)는 정확한 용어지만 금융 실무 밖에서는 **`%`의 오타처럼
  /// 보인다.** 첫 화면부터 모르는 기호가 나오면 「내가 이해 못 할 앱」이라는
  /// 판단이 먼저 선다. 용어를 바꾸는 대신 **한 번만 가르쳐 준다.**
  static void showLegend(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    showModalBottomSheet(
      context: context,
      backgroundColor: context.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            22, 20, 22, MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isKo ? '이 화면 읽는 법' : 'Reading this screen',
                style: TextStyle(
                    fontSize: DS.rowName,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            const SizedBox(height: 16),
            _legendRow(context, '%p',
                isKo
                    ? '비중의 차이입니다. 목표가 10%인데 지금 58%면 +48%p입니다.'
                    : 'A difference in weight. Target 10%, now 58% → +48pp.'),
            _legendRow(context, isKo ? '허용 편차' : 'Tolerance',
                isKo
                    ? '이만큼까지는 그냥 두겠다는 선입니다. 포트폴리오마다 따로 정합니다.'
                    : "How far you'll let it drift before acting. Set per portfolio."),
            _legendRow(context, isKo ? '세로선' : 'Tick marks',
                isKo
                    ? '막대 위의 세로선이 목표 비중 자리입니다.'
                    : 'Where each holding’s target weight sits on the bar.'),
            _legendRow(context, isKo ? '막대 색' : 'Bar colors',
                isKo
                    ? '주황은 목표보다 많은 종목, 초록은 모자란 종목, '
                        '회색은 허용 편차 안이라 손댈 일이 없는 종목입니다.'
                    : 'Amber is above target, green is below, '
                        'grey is within tolerance.'),
          ],
        ),
      ),
    );
  }

  static Widget _legendRow(BuildContext context, String term, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.brandOnLight)),
          const SizedBox(height: 3),
          Text(desc,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary)),
        ],
      ),
    );
  }

  /// 헤더의 부가 정보. **알약 모양을 쓰지 않는다.**
  ///
  /// 같은 화면에 눌리는 알약(필터 칩)과 안 눌리는 알약(이 자리)이 섞여 있으면
  /// 사용자는 매번 눌러 확인해야 한다. 알약은 누를 수 있는 것에만 남긴다.
  Widget _headerChip(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
          fontSize: DS.caption,
          fontWeight: FontWeight.w600,
          color: context.onBrandSecondary),
    );
  }

  // ── 포트 카드 ──

  Widget _buildCard(BuildContext context, Portfolio pf, bool isKo,
      {bool forCapture = false}) {
    final drifts = Rebalancer.allDrifts(pf);
    final over = Rebalancer.driftExceeding(pf);
    final needsAdjusting = over.isNotEmpty;

    // 편차가 가장 큰 종목 (allDrifts는 편차 절댓값 내림차순)
    final maxDrift = drifts.isEmpty ? 0.0 : drifts.first.drift;
    final blocker = Rebalancer.driftBlocker(pf);
    final hasPrices = blocker == null;

    return InkWell(
      // **막힌 이유마다 갈 곳이 다르다.** 리밸런싱 화면에 보내봐야 거기서도
      // 같은 이유로 막혀 있으면 사용자는 한 단계 더 들어가서 막힐 뿐이다.
      onTap: forCapture
          ? null
          : () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => switch (blocker) {
            // 담을 게 없다 → 종목을 추가할 수 있는 곳
            DriftBlocker.noItems => PortfolioDetailScreen(portfolioId: pf.id),
            // 목표가 없다 → 목표를 정하는 곳
            DriftBlocker.noTargets => TargetWeightsScreen(portfolioId: pf.id),
            // 시세만 없다 → 편차 화면(새로고침이 거기 있다)
            _ => PortfolioRebalanceScreen(portfolioId: pf.id),
          },
        ),
      ),
      borderRadius: BorderRadius.circular(DS.listCardRadius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          border: Border.all(
            color:
                needsAdjusting ? const Color(0xFFE8C99A) : context.cardBorder,
            width: needsAdjusting ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pf.name,
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // 앱을 여는 이유의 대부분이 「지금 뭘 사고팔지」인데, 그 답이
                // 자산→리밸런싱→포트→조정 제안으로 가장 멀었다. 배지를
                // 눌리게 만들어 새 요소 없이 한 단계를 줄인다.
                needsAdjusting && !forCapture
                    ? InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RebalanceProposalScreen(
                                  portfolioId: pf.id)),
                        ),
                        borderRadius: BorderRadius.circular(DS.chipRadius),
                        child: _statusBadge(
                            context, needsAdjusting, blocker, isKo),
                      )
                    : _statusBadge(context, needsAdjusting, blocker, isKo,
                        forCapture: forCapture),
                const SizedBox(width: 4),
                if (!forCapture)
                  Icon(Icons.chevron_right,
                      size: 20, color: context.textTertiary),
              ],
            ),
            if (hasPrices) ...[
              const SizedBox(height: 13),
              WeightBar(
                threshold: pf.rebalancingThreshold,
                segments: [
                  for (final d in pf.items.map((i) => drifts.firstWhere(
                      (x) => x.item.id == i.id,
                      orElse: () =>
                          ItemDrift(item: i, currentWeight: 0, drift: 0))))
                    WeightSegment(
                      currentWeight: d.currentWeight,
                      targetWeight: d.item.targetWeight,
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      isKo
                          ? '${pf.items.length}종목 · ${lastRebalancedLabel(context, pf)}'
                          : '${pf.items.length} holdings · ${lastRebalancedLabel(context, pf)}',
                      style: TextStyle(
                          fontSize: DS.body,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isKo
                        ? '허용 ±${_trimZero(pf.rebalancingThreshold)}%p'
                        : '±${_trimZero(pf.rebalancingThreshold)}pp',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmtPp(maxDrift, isKo),
                    style: TextStyle(
                      fontSize: DS.sectionTitle,
                      fontWeight: FontWeight.w700,
                      // 편차는 손익이 아니므로 손익 색 설정과 분리한다
                      color: needsAdjusting
                          ? context.danger
                          : context.textSecondary,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              // 이유를 안 가리면 셋 중 둘은 거짓말이 된다
              Text(
                switch (blocker) {
                  DriftBlocker.noItems => isKo
                      ? '종목을 추가하면 편차를 계산합니다'
                      : 'Add holdings to see drift',
                  DriftBlocker.noTargets => isKo
                      ? '목표 비중을 정하면 편차를 계산합니다'
                      : 'Set target weights to see drift',
                  DriftBlocker.noPrices => isKo
                      ? '시세를 받으면 편차를 계산합니다'
                      : 'Drift needs current prices',
                },
                style:
                    TextStyle(fontSize: DS.body, color: context.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, bool needsAdjusting,
      DriftBlocker? blocker, bool isKo,
      {bool forCapture = false}) {
    if (blocker != null) {
      // `계산 불가`는 앱이 고장난 것처럼 들린다. 할 일이 있으면 그걸 말한다.
      final (text, fg, bg) = switch (blocker) {
        DriftBlocker.noItems => (
            isKo ? '종목 없음' : 'Empty',
            context.textSecondary,
            context.trackBg
          ),
        DriftBlocker.noTargets => (
            isKo ? '목표 미설정' : 'No targets',
            context.warningText,
            context.warningBg
          ),
        DriftBlocker.noPrices => (
            isKo ? '시세 없음' : 'No prices',
            context.warningText,
            context.warningBg
          ),
      };
      return _badge(context, text, fg: fg, bg: bg, weight: FontWeight.w700);
    }
    return needsAdjusting
        ? _badge(context, isKo ? '조정 제안 보기' : 'See plan',
            // 그림에서는 누를 수 없다 — 화살표가 있으면 거짓말이 된다.
            arrow: !forCapture,
            fg: context.warningText,
            bg: context.warningBg,
            weight: FontWeight.w800)
        : _badge(context, isKo ? '유지' : 'On target',
            fg: context.brandOnLight,
            bg: context.brandTint,
            weight: FontWeight.w700);
  }

  Widget _badge(BuildContext context, String text,
      {required Color fg,
      required Color bg,
      required FontWeight weight,
      bool arrow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(DS.chipRadius)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text,
            style:
                TextStyle(fontSize: DS.caption, fontWeight: weight, color: fg)),
        // 누를 수 있는 배지에만 화살표를 붙여 라벨과 구분한다
        if (arrow) ...[
          const SizedBox(width: 2),
          Icon(Icons.chevron_right, size: 13, color: fg),
        ],
      ]),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isKo) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            isKo
                ? '포트폴리오를 먼저 만들면\n편차를 진단해 드립니다'
                : 'Create a portfolio first\nto see drift diagnostics',
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

  /// 3.0 → "3",  2.5 → "2.5"
  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
