import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import '../widgets/brand_header.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/weight_bar.dart';
import 'portfolio_detail_screen.dart';

/// 포트폴리오 하나의 편차 진단 (v18b).
///
/// "무엇이 얼마나 어긋났는가"만 보여준다.
/// 실제 매매 수량 제안은 조정 제안 화면이 맡는다.
class PortfolioRebalanceScreen extends StatelessWidget {
  final String portfolioId;

  const PortfolioRebalanceScreen({super.key, required this.portfolioId});

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.portfolios
            .where((p) => p.id == portfolioId)
            .cast<Portfolio?>()
            .firstWhere((p) => true, orElse: () => null);

        if (pf == null) {
          return Scaffold(
              body: Center(child: Text(context.l10n.portfolioNotFound)));
        }

        final drifts = Rebalancer.allDrifts(pf);
        final over = Rebalancer.driftExceeding(pf);

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              BrandHeader(
                title: pf.name,
                titleSize: 17,
                titleWeight: FontWeight.w700,
                childPadding: const EdgeInsets.fromLTRB(22, 2, 22, 18),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white),
                    tooltip: context.l10n.settings,
                    onPressed: () => _openSettings(context, pf),
                  ),
                ],
                child: _buildMaxDrift(context, pf, drifts, over, isKo),
              ),
              Expanded(
                child: drifts.isEmpty
                    ? _buildNoPrices(context, isKo)
                    : _buildList(context, pf, drifts, isKo),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 헤더: 최대 편차 ──

  Widget _buildMaxDrift(BuildContext context, Portfolio pf,
      List<ItemDrift> drifts, List<ItemDrift> over, bool isKo) {
    if (drifts.isEmpty) {
      return Text(
        isKo ? '시세를 받으면 편차를 계산합니다' : 'Drift needs current prices',
        style: TextStyle(
            fontSize: DS.body,
            fontWeight: FontWeight.w500,
            color: context.onBrandSecondary),
      );
    }

    final worst = drifts.first;
    final needsAdjusting = over.isNotEmpty;
    final valueColor =
        needsAdjusting ? context.onBrandWarning : context.onBrandAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              isKo ? '최대 편차' : 'Largest drift',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.onBrandSecondary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DS.chipRadius),
              ),
              child: Text(
                isKo
                    ? '허용 ±${_trimZero(pf.rebalancingThreshold)}%p'
                    : '±${_trimZero(pf.rebalancingThreshold)}pp',
                style: TextStyle(
                    fontSize: DS.caption,
                    fontWeight: FontWeight.w700,
                    color: context.onBrandSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${worst.drift >= 0 ? '+' : '−'}${worst.drift.abs().toStringAsFixed(2)}%p',
          style: TextStyle(
            fontSize: DS.displayAmount,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            height: 1.08,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          needsAdjusting
              ? (isKo
                  ? '${worst.item.name}이(가) 목표보다 ${worst.drift >= 0 ? '많습니다' : '적습니다'}'
                  : '${worst.item.name} is ${worst.drift >= 0 ? 'over' : 'under'} target')
              : (isKo ? '모든 종목이 허용 편차 안에 있습니다' : 'All holdings within tolerance'),
          style: TextStyle(
              fontSize: DS.body,
              fontWeight: FontWeight.w500,
              color: context.onBrandSecondary),
        ),
      ],
    );
  }

  // ── 종목별 비중 ──

  Widget _buildList(BuildContext context, Portfolio pf, List<ItemDrift> drifts,
      bool isKo) {
    final over = Rebalancer.driftExceeding(pf);
    final overIds = over.map((d) => d.item.id).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // 전체 비중 한눈에
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(DS.cardRadius),
            border: Border.all(color: context.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeightBar(
                segments: [
                  for (final i in pf.items)
                    WeightSegment(
                      currentWeight: drifts
                          .firstWhere((d) => d.item.id == i.id,
                              orElse: () => ItemDrift(
                                  item: i, currentWeight: 0, drift: 0))
                          .currentWeight,
                      targetWeight: i.targetWeight,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isKo ? '세로선이 목표 비중' : 'Vertical lines are targets',
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: DS.cardGap),

        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
          child: Row(
            children: [
              Text(
                isKo ? '종목별 비중' : 'Weight by holding',
                style: TextStyle(
                    fontSize: DS.sectionTitle,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
              ),
              const Spacer(),
              Text(
                isKo ? '현재 → 목표' : 'current → target',
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
              for (var i = 0; i < drifts.length; i++)
                _buildDriftRow(context, pf, drifts[i],
                    exceeds: overIds.contains(drifts[i].item.id),
                    isLast: i == drifts.length - 1),
            ],
          ),
        ),

        const SizedBox(height: 16),
        SizedBox(
          height: DS.buttonHeight,
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PortfolioDetailScreen(
                    portfolioId: pf.id, initialTab: 1),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.buttonRadius)),
            ),
            child: Text(
              isKo ? '조정 제안 보기' : 'See adjustment plan',
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriftRow(BuildContext context, Portfolio pf, ItemDrift d,
      {required bool exceeds, required bool isLast}) {
    final value = d.item.isCash
        ? d.item.shares
        : d.item.shares * _priceInBase(pf, d.item);

    // 편차 색은 손익이 아니므로 PnlColorNotifier를 쓰지 않는다.
    // (빨강/파랑 스킴에서 초과 종목이 파랗게 나오면 뜻이 뒤집힌다)
    // 허용 안이면 무채색으로 두어 조정할 종목만 눈에 띄게 한다.
    final driftColor = exceeds
        ? (d.drift >= 0 ? context.danger : context.brandOnLight)
        : context.textTertiary;

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
                  d.item.name,
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
                '${d.drift >= 0 ? '+' : '−'}${d.drift.abs().toStringAsFixed(2)}%p',
                style: TextStyle(
                    fontSize: DS.returnPct,
                    fontWeight: FontWeight.w700,
                    color: driftColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${d.currentWeight.toStringAsFixed(2)}%',
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w700,
                    color: context.textStrong),
              ),
              const SizedBox(width: 5),
              Icon(Icons.arrow_forward, size: 12, color: context.textHint),
              const SizedBox(width: 5),
              Text(
                '${d.item.targetWeight.toStringAsFixed(2)}%',
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary),
              ),
              const Spacer(),
              Text(
                _fmt(value, pf.currency),
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoPrices(BuildContext context, bool isKo) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          isKo
              ? '시세가 없어 편차를 계산할 수 없습니다\n새로고침으로 현재가를 받아오세요'
              : 'Cannot compute drift without prices\nRefresh to fetch current prices',
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

  void _openSettings(BuildContext context, Portfolio pf) {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        portfolio: pf,
        onSave: (s) {
          context.read<PortfolioProvider>().updateSettings(
                pf.id,
                currency: s['currency'],
                commissionEnabled: s['commissionEnabled'],
                commissionRate: s['commissionRate'],
                exchangeAuto: s['exchangeAuto'],
                exchangeRate: s['exchangeRate'],
                priceAuto: s['priceAuto'],
                rebalancingThreshold: s['rebalancingThreshold'],
                fractionalEnabled: s['fractionalEnabled'],
              );
        },
      ),
    );
  }

  static double _priceInBase(Portfolio pf, PortfolioItem item) {
    if (item.isCash) return 1;
    if (item.market == 'US' && pf.currency == 'KRW') {
      return item.currentPrice * pf.exchangeRate;
    }
    if (item.market == 'KR' && pf.currency == 'USD') {
      return item.currentPrice / pf.exchangeRate;
    }
    return item.currentPrice;
  }

  static String _fmt(double n, String cur) {
    final prefix = n < 0 ? '−' : '';
    final abs = n.abs();
    if (cur == 'USD') return '$prefix\$${abs.toStringAsFixed(2)}';
    return '$prefix₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
