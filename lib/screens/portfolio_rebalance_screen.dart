import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:flutter/material.dart';
import '../utils/widget_capture.dart';

import '../utils/josa.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import 'target_weights_screen.dart';
import '../services/ad_service.dart';
import '../widgets/bottom_banner_ad.dart';
import '../widgets/app_menu.dart';
import '../widgets/capture_frame.dart';
import '../widgets/brand_header.dart';
import '../widgets/weight_bar.dart';
import 'rebalance_proposal_screen.dart';

/// 포트폴리오 하나의 편차 진단 (v18b).
///
/// "무엇이 얼마나 어긋났는가"만 보여준다.
/// 실제 매매 수량 제안은 조정 제안 화면이 맡는다.
class PortfolioRebalanceScreen extends StatefulWidget {
  final String portfolioId;

  const PortfolioRebalanceScreen({super.key, required this.portfolioId});

  @override
  State<PortfolioRebalanceScreen> createState() =>
      _PortfolioRebalanceScreenState();
}

class _PortfolioRebalanceScreenState extends State<PortfolioRebalanceScreen> {
  bool _capturing = false;

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.portfolios
            .where((p) => p.id == widget.portfolioId)
            .cast<Portfolio?>()
            .firstWhere((p) => true, orElse: () => null);

        if (pf == null) {
          return Scaffold(
              body: Center(child: Text(context.l10n.portfolioNotFound)));
        }

        final drifts = Rebalancer.allDrifts(pf);
        final over = Rebalancer.needsAdjusting(pf);

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          // **`bottomNavigationBar`에 둔다.** 본문 안에 붙이면 Scaffold가
          // 배너의 존재를 몰라서, 새로고침 알림(스낵바)이 광고를 그대로
          // 덮는다. 광고를 가리는 건 구글 정책 위반이고, 가려진 노출은
          // 무효 트래픽으로 잡힐 수 있다.
          // **버튼을 화면 맨 아래에 못 박고, 광고는 그 위에 둔다.**
          //
          // 예전에는 버튼이 본문 끝, 광고가 그 아래였다. 광고가 안 붙는
          // 날에는 자리가 사라지면서 버튼이 아래로 툭 내려간다 — 쓰는
          // 사람에게는 광고 사정이 안 보이므로 **버튼이 혼자 움직이는**
          // 것으로만 읽힌다.
          //
          // `bottomNavigationBar`의 마지막 자식은 늘 화면 맨 아래다.
          // 광고가 붙든 말든 버튼 자리는 그대로고, 대신 본문이 밀린다.
          bottomNavigationBar: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BottomBannerAd(slot: AdSlot.work),
                if (drifts.isNotEmpty) _buildCta(context, pf, isKo),
              ],
            ),
          ),
          body: Column(
            children: [
              BrandHeader(
                title: pf.name,
                titleSize: 17,
                titleWeight: FontWeight.w700,
                childPadding: const EdgeInsets.fromLTRB(22, 2, 22, 18),
                leading: IconButton(
                  tooltip: context.l10n.a11yBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
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
                  CaptureMenu(
                    busy: _capturing,
                    onSave: () => _emit(share: false),
                    onShare: () => _emit(share: true),
                  ),
                  // 목표 비중은 처음 정할 때 쓰고 그 뒤로는 거의 안 건드린다.
                  // 늘 보이는 자리를 내줄 만큼 자주 쓰는 동작이 아니다.
                  AppMenu(entries: [
                    MenuAction(Icons.balance, context.l10n.targetWeightsTitle,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TargetWeightsScreen(portfolioId: pf.id),
                        ),
                      );
                    }),
                  ]),
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


  // ── 이미지 저장 · 공유 ──
  //
  // **화면을 그대로 찍는다.** 캡처용 카드를 따로 그리면 화면이 바뀔 때마다
  // 두 곳을 맞춰야 하고, 어긋나면 공유한 그림이 앱과 달라 보인다.
  Future<void> _emit({required bool share}) async {
    if (_capturing) return;
    final l10n = context.l10n;
    setState(() => _capturing = true);
    try {
      final pf = context.read<PortfolioProvider>()
          .getPortfolio(widget.portfolioId);
      if (pf == null) return;
      final bytes = await captureWidget(context, _buildCapture(context, pf));
      if (bytes == null) {
        // 그림을 못 만들었다. **말없이 끝내지 않는다** — 시트는 닫혔는데
        // 아무 일도 안 일어나면 저장된 줄 알고 앨범을 찾게 된다.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.saveFailed),
            duration: const Duration(seconds: 2),
          ));
        }
        return;
      }
      if (!mounted) return;
      if (share) {
        final dir = await getTemporaryDirectory();
        final f = File(
            '${dir.path}/rebalance_pf_${DateTime.now().millisecondsSinceEpoch}.png');
        await f.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(f.path)]);
      } else {
        final r = await ImageGallerySaverPlus.saveImage(bytes,
            name: 'rebalance_pf_${DateTime.now().millisecondsSinceEpoch}');
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
      if (mounted) setState(() => _capturing = false);
    }
  }


  /// 저장·공유할 편차 그림.
  ///
  /// **화면을 그대로 찍지 않는다.** 종목 목록이 화면 밖으로 이어지면 그
  /// 아래가 그림에 안 들어가고, 경계 안에 배경이 없어 검게 찍힌다.
  /// 여기서 스크롤 없이 전부 다시 그린다.
  Widget _buildCapture(BuildContext context, Portfolio pf) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final drifts = Rebalancer.allDrifts(pf);
    final over = Rebalancer.needsAdjusting(pf);
    return CaptureFrame(
      title: pf.name,
      // 화면이 쓰는 머리글 그대로 — 따로 그리면 또 어긋난다.
      // 실제로 편차 숫자가 35 대 26으로 갈라졌고, 상태줄이 빠져 있었다.
      headerBody:
          _buildMaxDrift(context, pf, drifts, over, isKo, forCapture: true),
      children: [
        if (drifts.isNotEmpty) ...[
          CaptureCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
            children: [
              WeightBar(
                threshold: pf.rebalancingThreshold,
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
              // 막대 읽는 법 — 그림에만 붙인다. 화면에는 바로 아래 목록이
              // 있어 굳이 설명할 필요가 없다.
              CaptureNote(text: isKo
                  ? '세로선이 목표 비중'
                  : 'Vertical lines are targets'),
            ],
          ),
          const SizedBox(height: 14),
          CaptureCard(
            title: isKo ? '종목별 비중' : 'Weight by holding',
            // 화면이 쓰는 행을 그대로 쓴다 — 여기서 따로 그리면 또 어긋난다.
            // 실제로 평가금액이 빠진 채 나갔다.
            children: [
              for (var i = 0; i < drifts.length; i++)
                _buildDriftRow(context, pf, drifts[i],
                    exceeds: over.any((o) => o.item.id == drifts[i].item.id),
                    isLast: i == drifts.length - 1),
            ],
          ),
        ],
      ],
    );
  }


  // ── 헤더: 최대 편차 ──

  /// 최대 편차 머리글 — **화면과 캡처가 같이 쓴다.**
  ///
  /// `forCapture: true`면 허용 편차 칩이 안 눌리고 화살표도 빠진다.
  /// 예전에는 캡처가 이 블록을 손으로 옮겨 적어 **편차 숫자가 35 대 26으로**
  /// 갈라졌고, 「조정 필요/유지」 상태줄도 그림에서 빠져 있었다.
  Widget _buildMaxDrift(BuildContext context, Portfolio pf,
      List<ItemDrift> drifts, List<ItemDrift> over, bool isKo,
      {bool forCapture = false}) {
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
          children: [
            // **결론을 먼저 낸다.** 편차 숫자만 두면 허용치와 견줘 봐야
            // 알 수 있어서 「한눈에」가 아니다.
            if (pf.items.length >= 2)
              _statusPill(context, needsAdjusting, isKo),
            const Spacer(),
            // **허용 편차가 앱에서 보이는 유일한 자리다.** 여기가 안 눌리면
            // 고치러 갈 길이 ⋮ 메뉴뿐이라 사실상 못 찾는다.
            // 화살표를 붙여 눌리는 것임을 밝힌다 — 칩은 보통 안 눌린다.
            GestureDetector(
              onTap: forCapture ? null : () => _openTargets(pf),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DS.chipRadius),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    isKo
                        ? '허용 ±${_trimZero(pf.rebalancingThreshold)}%p'
                        : '±${_trimZero(pf.rebalancingThreshold)}pp',
                    style: TextStyle(
                        fontSize: DS.caption,
                        fontWeight: FontWeight.w700,
                        color: context.onBrandSecondary),
                  ),
                  // 그림에서는 못 누르니 화살표를 빼야 거짓말이 안 된다
                  if (!forCapture)
                    Icon(Icons.chevron_right,
                        size: 15, color: context.onBrandSecondary),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              fmtPp(worst.drift, isKo),
              style: TextStyle(
                fontSize: DS.displayAmount,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                height: 1.08,
                color: valueColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isKo ? '최대 편차' : 'largest drift',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.onBrandSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          needsAdjusting
              ? (isKo
                  ? '${withJosa(worst.item.displayName(context), Josa.iGa)} 목표보다 ${worst.drift >= 0 ? '많습니다' : '적습니다'}'
                  : '${worst.item.displayName(context)} is ${worst.drift >= 0 ? 'over' : 'under'} target')
              // 종목이 하나뿐이면 "편차 안에 있다"는 말이 거짓이다 —
              // 옮길 데가 없어서 조정을 못 하는 것뿐이다.
              : pf.items.length < 2
                  ? context.l10n.needMoreItems
                  : (isKo
                      ? '모든 종목이 허용 편차 안에 있습니다'
                      : 'All holdings within tolerance'),
          style: TextStyle(
              fontSize: DS.body,
              fontWeight: FontWeight.w500,
              color: context.onBrandSecondary),
        ),
      ],
    );
  }

  /// 조정이 필요한지 아닌지 — 자산 탭과 **같은 말**을 쓴다.
  /// 종목 목록 맨 끝에 다는 「바꾸러 가기」 줄.
  ///
  /// 이 카드는 종목마다 「현재 → 목표」를 늘어놓는다. 다 읽고 나면 그
  /// 목표를 바꾸고 싶어지는데, 지금까지는 그 길이 ⋮ 메뉴뿐이었다.
  Widget _targetsRow(BuildContext context, Portfolio pf, bool isKo) {
    return InkWell(
      onTap: () => _openTargets(pf),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.dividerColor)),
        ),
        child: Row(children: [
          Icon(Icons.balance, size: 17, color: context.brand),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isKo ? '목표 비중 · 허용 편차 바꾸기' : 'Change targets & tolerance',
              style: TextStyle(
                  fontSize: DS.rowName,
                  fontWeight: FontWeight.w600,
                  color: context.brand),
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: context.textTertiary),
        ]),
      ),
    );
  }

  /// 목표 비중·허용 편차를 고치는 화면으로.
  ///
  /// **둘은 같은 화면에서 고친다.** 그런데 이 화면은 처음부터 끝까지 목표
  /// 비중 이야기(「허용 ±3%p」, 「현재 → 목표」)면서 정작 아무것도 안 눌렸다.
  /// 읽을 수만 있고 손댈 수는 없는 화면이었다.
  void _openTargets(Portfolio pf) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TargetWeightsScreen(portfolioId: pf.id)),
    );
  }

  Widget _statusPill(BuildContext context, bool needsAdjusting, bool isKo) {
    final color =
        needsAdjusting ? context.onBrandWarning : context.onBrandAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(DS.chipRadius),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            needsAdjusting
                ? Icons.error_outline
                : Icons.check_circle_outline,
            size: 15,
            color: color),
        const SizedBox(width: 5),
        Text(
          needsAdjusting
              ? (isKo ? '조정 필요' : 'Needs adjusting')
              : (isKo ? '비중 유지' : 'On target'),
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
        ),
      ]),
    );
  }

  // ── 종목별 비중 ──

  Widget _buildList(BuildContext context, Portfolio pf, List<ItemDrift> drifts,
      bool isKo) {
    final over = Rebalancer.needsAdjusting(pf);
    final overIds = over.map((d) => d.item.id).toSet();
    // 목표 비중 합이 100%여야 조정 제안을 계산할 수 있다
    final weightsReady = (pf.weightSum - 100).abs() <= 0.01;

    return ListView(
      // 아래는 배너가 자리를 잡는다 (배너가 SafeArea를 쓴다).
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
                threshold: pf.rebalancingThreshold,
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
                    isLast: false),
              // **목표들을 다 훑고 난 자리다.** 「이 목표는 누가 정했나,
              // 바꾸려면 어디로 가나」가 생기는 지점이 바로 여기다.
              _targetsRow(context, pf, isKo),
            ],
          ),
        ),

        // 목표 비중 합이 100%가 아니면 조정 제안을 계산할 수 없다.
        // 예전에는 그걸 알면서도 버튼을 눌리게 뒀고, 누르면 빈 화면에
        // "100%가 아닙니다" 한 줄만 나왔다 — 고치러 갈 길도 없었다.
        // 여기서 미리 말하고, 버튼도 고치러 가는 것으로 바꾼다.
        if (!weightsReady) ...[
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            decoration: BoxDecoration(
              color: context.warningBg,
              borderRadius: BorderRadius.circular(DS.listCardRadius),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 17, color: context.warningText),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                    context.l10n.weightSumNotice(
                        '${pf.weightSum.toStringAsFixed(2)}%'),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                        color: context.warningText)),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ── 화면 아래 고정 버튼 ──

  Widget _buildCta(BuildContext context, Portfolio pf, bool isKo) {
    // 목표 비중 합이 100%여야 조정 제안을 계산할 수 있다
    final weightsReady = (pf.weightSum - 100).abs() <= 0.01;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        border: Border(top: BorderSide(color: context.dividerColor)),
      ),
      child: SizedBox(
        // **폭을 반드시 지정한다.** 예전에는 이 버튼이 ListView 안에 있어
        // 저절로 가로를 꽉 채웠는데, 스크롤 밖 Column으로 옮기면서 그게
        // 사라졌다 — Column은 자식을 가운데에 내용 너비만큼만 놓는다.
        width: double.infinity,
        height: DS.buttonHeight,
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => weightsReady
                  ? RebalanceProposalScreen(portfolioId: pf.id)
                  : TargetWeightsScreen(portfolioId: pf.id),
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
            weightsReady
                ? (isKo ? '조정 제안 보기' : 'See adjustment plan')
                : context.l10n.fixTargetWeights,
            style:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
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
    // 색은 **「손봐야 하나」만** 말한다. 어느 쪽으로 벗어났는지는 부호(+/−)와
    // 아래 `현재 → 목표` 줄이 이미 말해준다.
    //
    // 방향에 따라 초록·빨강을 나누면 안 된다. 비중은 합이 100%로 묶여 있어서
    // 한 종목이 초과면 다른 종목은 **반드시** 미달이다 — 열 종목이 전부 오른
    // 날에도 절반은 미달로 나온다. 미달은 「떨어졌다」가 아니라 「남들보다 덜
    // 올랐다」인데, 손익 색을 쓰면 같은 줄에서 손익과 편차가 서로 다른 색을
    // 말하게 된다. 게다가 초과는 **팔 것**이라 초록으로 칠하면 신호가 거꾸로다.
    final driftColor = exceeds ? context.warningText : context.textTertiary;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

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
                  d.item.displayName(context),
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
                fmtPp(d.drift, isKo),
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
                fmtMoney(value, pf.currency),
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


  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
