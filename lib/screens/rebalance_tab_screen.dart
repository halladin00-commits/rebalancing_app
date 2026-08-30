import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../widgets/portfolio_actions.dart';
import '../utils/rebalancer.dart';
import '../widgets/brand_header.dart';
import '../widgets/weight_bar.dart';
import 'portfolio_rebalance_screen.dart';

/// 리밸런싱 탭 — 포트폴리오별 편차 진단.
///
/// 허용 편차는 포트마다 다르므로 헤더에 대표값을 쓰지 않는다.
/// 대신 카드마다 `허용 ±N%p`를 편차 바로 옆에 두어,
/// 같은 편차가 어떤 포트에서는 "유지"인 이유가 한 줄에서 설명되게 한다.
class RebalanceTabScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final portfolios = provider.portfolios;
        final overCount = needsAdjustingCount(portfolios);
        final unknownCount = unknownDriftCount(portfolios);

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              BrandHeader(
                title: l10n.tabRebalancing,
                childPadding: const EdgeInsets.fromLTRB(22, 2, 22, 18),
                actions: [
                  IconButton(
                    icon: provider.refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh, color: Colors.white),
                    onPressed: provider.refreshing ? null : provider.refreshAll,
                  ),
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
            const SizedBox(width: 6),
            _headerChip(context, timeStr),
          ],
        ),
      ],
    );
  }

  Widget _headerChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DS.chipRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: DS.caption,
            fontWeight: FontWeight.w700,
            color: context.onBrandSecondary),
      ),
    );
  }

  // ── 포트 카드 ──

  Widget _buildCard(BuildContext context, Portfolio pf, bool isKo) {
    final drifts = Rebalancer.allDrifts(pf);
    final over = Rebalancer.driftExceeding(pf);
    final needsAdjusting = over.isNotEmpty;

    // 편차가 가장 큰 종목 (allDrifts는 편차 절댓값 내림차순)
    final maxDrift = drifts.isEmpty ? 0.0 : drifts.first.drift;
    final hasPrices = drifts.isNotEmpty;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PortfolioRebalanceScreen(portfolioId: pf.id)),
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
                _statusBadge(context, needsAdjusting, hasPrices, isKo),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 20, color: context.textTertiary),
              ],
            ),
            if (hasPrices) ...[
              const SizedBox(height: 13),
              WeightBar(
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
                          ? '${pf.items.length}종목 · 세로선이 목표 비중'
                          : '${pf.items.length} holdings · lines are targets',
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
                    '${maxDrift >= 0 ? '+' : '−'}${maxDrift.abs().toStringAsFixed(2)}%p',
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
              Text(
                isKo ? '시세를 받으면 편차를 계산합니다' : 'Drift needs current prices',
                style:
                    TextStyle(fontSize: DS.body, color: context.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(
      BuildContext context, bool needsAdjusting, bool hasPrices, bool isKo) {
    if (!hasPrices) {
      return _badge(context, isKo ? '계산 불가' : 'No data',
          fg: context.textSecondary,
          bg: context.trackBg,
          weight: FontWeight.w700);
    }
    return needsAdjusting
        ? _badge(context, isKo ? '조정 필요' : 'Adjust',
            fg: context.warningText,
            bg: context.warningBg,
            weight: FontWeight.w800)
        : _badge(context, isKo ? '유지' : 'On target',
            fg: context.brandOnLight,
            bg: context.brandTint,
            weight: FontWeight.w700);
  }

  Widget _badge(BuildContext context, String text,
      {required Color fg, required Color bg, required FontWeight weight}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(DS.chipRadius)),
      child: Text(text,
          style:
              TextStyle(fontSize: DS.caption, fontWeight: weight, color: fg)),
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
