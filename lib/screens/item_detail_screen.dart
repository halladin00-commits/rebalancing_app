import 'package:flutter/material.dart';
import 'dart:io';

import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/widget_capture.dart';

import '../main.dart';
import '../widgets/brand_stat_tile.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import '../utils/share_format.dart';
import '../services/ad_service.dart';
import '../widgets/bottom_banner_ad.dart';
import '../widgets/app_menu.dart';
import '../widgets/capture_frame.dart';
import '../widgets/brand_header.dart';
import '../widgets/list_card.dart';
import 'item_form_screen.dart';
import 'transaction_form_screen.dart';

/// 종목 상세 (시안 v12c).
///
/// 개편 전에는 바텀시트에 `라벨 — 값` 여섯 줄을 쌓고 아래가 잘렸다.
/// 시안은 포트 상세와 같은 골격의 **전용 화면**이다 —
/// 딥그린 헤더(평가금액 + 손익 타일) + 요약 카드 + 거래 내역.
class ItemDetailScreen extends StatefulWidget {
  final String portfolioId;
  final String itemId;

  const ItemDetailScreen(
      {super.key, required this.portfolioId, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _capturing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        final item = pf?.items.where((i) => i.id == widget.itemId).firstOrNull;
        if (pf == null || item == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          // **`bottomNavigationBar`에 둔다.** 본문 안에 붙이면 Scaffold가
          // 배너의 존재를 몰라서, 새로고침 알림(스낵바)이 광고를 그대로
          // 덮는다. 광고를 가리는 건 구글 정책 위반이고, 가려진 노출은
          // 무효 트래픽으로 잡힐 수 있다.
          bottomNavigationBar: const SafeArea(
              top: false, child: BottomBannerAd(slot: AdSlot.detail)),
          body: Column(
            children: [
              _buildHeader(context, pf, item),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 24),
                  children: [
                    _buildSummaryCard(context, pf, item),
                    const SizedBox(height: 13),
                    SectionTitle(
                      title: l10n.transactionHistory,
                      trailing: item.transactions.isEmpty
                          ? null
                          : l10n.txCountLabel(item.transactions.length),
                    ),
                    const SizedBox(height: DS.cardGap),
                    _buildTransactions(context, pf, item),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 이미지 저장 · 공유 ──
  //
  // 종목 화면만 캡처가 없었다. 일부러 뺀 게 아니라 안 넣은 것이다 —
  // 「무엇을 얼마에 얼마나 들고 있고 지금 얼마인가」가 한 장에 들어가는
  // 화면이라, 오히려 나누기 좋은 그림이다.

  Future<void> _emit(Portfolio pf, PortfolioItem item,
      {required bool share}) async {
    if (_capturing) return;
    final l10n = context.l10n;
    setState(() => _capturing = true);
    try {
      final bytes = await captureWidget(context, _buildCapture(pf, item));
      if (bytes == null) {
        // 그림을 못 만들었다. **말없이 끝내지 않는다** — 시트는 닫혔는데
        // 아무 일도 안 일어나면 저장된 줄 알고 앨범을 찾게 된다.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.saveFailed)));
        }
        return;
      }
      if (!mounted) return;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      if (share) {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/item_$stamp.png');
        await f.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(f.path)]);
      } else {
        final r =
            await ImageGallerySaverPlus.saveImage(bytes, name: 'item_$stamp');
        if (!mounted) return;
        final ok = r['isSuccess'] == true || r['filePath'] != null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? l10n.savedToGallery : l10n.saveFailed)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.saveFailedError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// 저장·공유할 그림.
  ///
  /// **여기서 읽은 값만 쓴다.** 이 위젯은 `captureWidget`이 만드는 딴
  /// 트리에서 그려져 Provider도 Localizations도 없다 — 안에서 찾으면
  /// 릴리즈 빌드에서 회색 사각형이 저장된다.
  ///
  /// 손익 타일은 **화면과 같은 위젯**을 쓴다. 손으로 옮겨 적으면 갈라진다.
  Widget _buildCapture(Portfolio pf, PortfolioItem item) {
    return CaptureFrame(
      title: item.displayName(context),
      // **포트 이름은 [_headerBody] 안의 이름표가 맡는다.**
      //
      // 여기 `subtitle`로 내면 제목 밑 맨 글자가 되어, 화면의 칩과
      // 모양도 자리도 달라진다 — 실제로 그렇게 나갔다.
      headerBody:
          _headerBody(context, pf, item, context.read<PnlColorNotifier>()),
      // 요약 카드도 화면과 같은 것을 그대로 쓴다. 비슷하게 다시 그렸다가
      // 「거래 기준」 두 줄과 비중의 `+0.13%p`가 빠진 적이 있다.
      children: [_buildSummaryCard(context, pf, item)],
    );
  }

  // ── 헤더 ──

  Widget _buildHeader(BuildContext context, Portfolio pf, PortfolioItem item) {
    // 금액 계산은 [_headerBody] 안에 있다 — 캡처와 나눠 쓰는 자리라
    // 한 곳에만 둔다.
    final pnlColors = context.watch<PnlColorNotifier>();

    return BrandHeader(
      titleSize: 15,
      titleWeight: FontWeight.w700,
      leading: IconButton(
        tooltip: context.l10n.a11yBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleWidget: Row(children: [
        if (!item.isCash) ...[
          MarketChip(market: item.market, label: item.market),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(item.displayName(context),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Colors.white),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
      actions: [
        // **캡처는 메뉴 밖에 둔다.** 이 앱에서 가장 좋은 홍보물인데
        // 메뉴에 넣으면 아무도 못 찾는다 (다른 화면과 같은 규칙).
        CaptureMenu(
          busy: _capturing,
          onSave: () => _emit(pf, item, share: false),
          onShare: () => _emit(pf, item, share: true),
        ),
        AppMenu(entries: _itemMenu(context, pf, item)),
      ],
      childPadding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      child: _headerBody(context, pf, item, pnlColors),
    );
  }

  /// 딥그린 머리 안에 들어가는 것 — **화면과 캡처가 같이 쓴다.**
  ///
  /// 「위탁계좌」 이름표를 캡처에서는 제목 밑 맨 글자로 그렸다가 모양도
  /// 자리도 달라졌다. 비슷하게 다시 그리면 반드시 갈라진다.
  ///
  /// [pnlColors]는 **넘겨받는다** — 캡처는 Provider가 없는 딴 트리에서
  /// 그려지므로 안에서 찾으면 안 된다.
  Widget _headerBody(BuildContext context, Portfolio pf, PortfolioItem item,
      PnlColorNotifier pnlColors) {
    final l10n = context.l10n;

    double fx = 1.0;
    if (item.market == 'US' && pf.currency == 'KRW') {
      fx = pf.exchangeRate;
    } else if (item.market == 'KR' && pf.currency == 'USD') {
      fx = 1.0 / pf.exchangeRate;
    }
    final value =
        item.isCash ? item.shares : item.shares * item.currentPrice * fx;

    double? pnl, pnlPct, day, dayPct;
    if (!item.isCash && item.avgPrice > 0 && item.currentPrice > 0) {
      pnl = (item.currentPrice - item.avgPrice) * item.shares * fx;
      pnlPct = (item.currentPrice - item.avgPrice) / item.avgPrice * 100;
    }
    if (!item.isCash && item.previousClose > 0 && item.currentPrice > 0) {
      day = (item.currentPrice - item.previousClose) * item.shares * fx;
      dayPct =
          (item.currentPrice - item.previousClose) / item.previousClose * 100;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(l10n.evaluationAmount,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.onBrandSecondary)),
        const Spacer(),
        // 어느 포트에서 왔는지 알려주는 이름표
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DS.chipRadius),
          ),
          child: Text(pf.name,
              style: TextStyle(
                  fontSize: DS.caption,
                  fontWeight: FontWeight.w700,
                  color: context.onBrandSecondary)),
        ),
      ]),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(fmtMoney(value, pf.currency),
            style: const TextStyle(
                fontSize: DS.displayAmount,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1.5,
                height: 1.08)),
      ),
      if (!item.isCash) ...[
        const SizedBox(height: 13),
        Row(children: [
          Expanded(
              child: BrandStatTile(
                  label: l10n.profitLoss,
                  amount: pnl,
                  pct: pnlPct,
                  currency: pf.currency,
                  pnlColors: pnlColors)),
          const SizedBox(width: 9),
          Expanded(
              child: BrandStatTile(
                  label: l10n.dayChange,
                  amount: day,
                  pct: dayPct,
                  currency: pf.currency,
                  pnlColors: pnlColors)),
        ]),
      ],
    ]);
  }

  // ── 요약 카드 (보유 수량 · 평균 매입가 · 현재가) ──

  Widget _buildSummaryCard(
      BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    if (item.isCash) {
      return ListCard(rows: [
        _kv(context, l10n.evaluationAmount, fmtMoney(item.shares, pf.currency)),
      ]);
    }
    // 평균 매입가가 거래에서 계산된 값인지 직접 입력인지 밝힌다
    final fromTx = item.transactions.isNotEmpty;

    // 리밸런싱 앱인데 종목 화면에 **목표 대비 어떤지**가 없었다.
    // 「이거 얼마나 사고팔아야 하지」를 알려면 뒤로 나가 리밸런싱 탭으로
    // 다시 들어가야 했다. 그 답을 여기 둔다.
    final drift = Rebalancer.allDrifts(pf)
        .where((d) => d.item.id == item.id)
        .firstOrNull;

    return ListCard(rows: [
      _kv(context, l10n.holdingQty,
          '${formatShares(item.shares)}${l10n.unitShares}',
          note: fromTx ? l10n.basedOnTransactions : l10n.enteredDirectly),
      _kv(context, l10n.avgCost, fmtPrice(item.avgPrice, item.market),
          note: fromTx ? l10n.basedOnTransactions : l10n.enteredDirectly),
      _kv(context, l10n.currentPrice, fmtPrice(item.currentPrice, item.market)),
      if (drift != null && item.targetWeight > 0)
        _weightRow(context, drift, pf.rebalancingThreshold),
    ]);
  }

  /// `현재 58.53% → 목표 10.00%` 와 편차.
  Widget _weightRow(BuildContext context, ItemDrift d, double threshold) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final over = threshold > 0 && d.drift.abs() >= threshold;
    final pp = fmtPp(d.drift, isKo);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(isKo ? '비중' : 'Weight',
                style: TextStyle(
                    fontSize: DS.rowName,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ),
          const SizedBox(width: 8),
          Text('${d.currentWeight.toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: DS.rowName,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          const SizedBox(width: 5),
          Icon(Icons.arrow_forward, size: 12, color: context.textTertiary),
          const SizedBox(width: 5),
          Text('${d.item.targetWeight.toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: DS.rowName,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
          const SizedBox(width: 8),
          Text(pp,
              style: TextStyle(
                  fontSize: DS.body,
                  fontWeight: FontWeight.w800,
                  color: over ? context.warningText : context.textTertiary)),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value, {String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ),
          if (note != null) ...[
            Text(note,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary)),
            const SizedBox(width: 8),
          ],
          Text(value,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
        ],
      ),
    );
  }

  // ── 거래 내역 ──

  Widget _buildTransactions(
      BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    if (item.transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Column(children: [
          Icon(Icons.history_toggle_off, size: 26, color: context.textDisabled),
          const SizedBox(height: 9),
          Text(l10n.noTransactionsNote,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: context.textTertiary)),
        ]),
      );
    }

    final txs = [...item.transactions]..sort((a, b) => b.date.compareTo(a.date));
    return ListCard(
      rows: [
        for (final t in txs) _buildTxRow(context, pf, item, t),
      ],
    );
  }

  Widget _buildTxRow(BuildContext context, Portfolio pf, PortfolioItem item,
      StockTransaction t) {
    final pnlColors = context.watch<PnlColorNotifier>();
    final l10n = context.l10n;
    final isBuy = t.quantity >= 0;
    final qty = t.quantity.abs();
    final amount = qty * t.price;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionFormScreen(
              portfolio: pf, item: item, transaction: t),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(
            width: 32,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isBuy ? context.pnlUpTint : context.pnlDownTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isBuy ? l10n.buy : l10n.sell,
                style: TextStyle(
                    fontSize: DS.caption,
                    fontWeight: FontWeight.w800,
                    color: isBuy ? pnlColors.positiveColor
                                 : pnlColors.negativeColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.textPrimary),
                    children: [
                      TextSpan(text: fmtPrice(t.price, item.market)),
                      TextSpan(
                        text: ' · ${formatShares(qty)}${l10n.unitShares}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${t.date.year}.${t.date.month.toString().padLeft(2, '0')}.${t.date.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(fmtPrice(amount, item.market),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: context.textPrimary)),
        ]),
      ),
    );
  }

  // ── more_vert 메뉴 ──

  List<MenuEntry> _itemMenu(
      BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    return [
      MenuAction(Icons.edit_outlined, l10n.edit, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemFormScreen(
              item: item,
              otherWeights: pf.weighedItems
                  .where((i) => i.id != item.id)
                  .fold<double>(0, (s, i) => s + i.targetWeight),
              priceAuto: pf.priceAuto,
              currency: pf.currency,
              onSave: (updated) =>
                  context.read<PortfolioProvider>().updateItem(pf.id, updated),
            ),
          ),
        );
      }),
      if (!item.isCash)
        MenuAction(Icons.receipt_long_outlined, l10n.addTransaction, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionFormScreen(portfolio: pf, item: item),
            ),
          );
        }),
    ];
  }

}
