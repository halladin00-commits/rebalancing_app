import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../services/notification_service.dart';
import '../services/asset_history_service.dart';
import '../theme/design_system.dart';
import '../utils/rebalancer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/portfolio_form_dialog.dart';
import '../widgets/speed_dial_fab.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_header.dart';
import '../widgets/asset_sparkline.dart';
import '../widgets/dashed_border_box.dart';
import 'portfolio_detail_screen.dart';

class PortfolioListScreen extends StatefulWidget {
  /// 액션 카드에서 다른 탭으로 보내기 위한 콜백 (MainShell이 넘긴다).
  final void Function(int index)? onNavigateToTab;

  const PortfolioListScreen({super.key, this.onNavigateToTab});
  @override
  State<PortfolioListScreen> createState() => PortfolioListScreenState();
}

class PortfolioListScreenState extends State<PortfolioListScreen> {
  /// MainShell의 뒤로가기 처리용 — 편집 모드면 종료 확인을 먼저 띄운다.
  bool get isEditMode => _editMode;
  Future<void> confirmExitEdit() => _showEditExitConfirm();

  bool _editMode = false;
  bool _savingMain = false;
  bool _sharingMain = false;
  final _screenshotCtrl = ScreenshotController();

  /// 총자산 추이 (헤더 스파크라인용)
  List<AssetPoint> _history = const [];

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoRefreshIfStale();
      await _ensureNotificationPermission();
    });
  }

  Future<void> _ensureNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('permission_asked') == true) return;
    await prefs.setBool('permission_asked', true);
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      await NotificationService.disable();
      await NotificationService.disableAllSettlements();
    }
  }

  void _autoRefreshIfStale() {
    final portfolios = context.read<PortfolioProvider>().portfolios;
    final hasAuto = portfolios.any((p) => p.exchangeAuto || p.priceAuto);
    if (!hasAuto) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStale = portfolios.any(
        (p) => p.lastUpdated == null || (now - p.lastUpdated!) > 5 * 60 * 1000);
    if (isStale) _doRefreshAll();
  }

  Future<void> _doRefreshAll() async {
    final provider = context.read<PortfolioProvider>();
    await provider.refreshAll();
    await _loadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.updateSuccess)),
    );
  }

  Future<void> _loadHistory() async {
    final h = await AssetHistoryService.loadRecent();
    if (!mounted) return;
    setState(() => _history = h);
  }

  String _fmt(double n, String cur) {
    final prefix = n < 0 ? '-' : '';
    final abs = n.abs();
    if (cur == 'USD') return '$prefix\$${abs.toStringAsFixed(2)}';
    return '$prefix₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  // 포트폴리오 손익을 KRW로 환산 (USD 포트폴리오는 exchangeRate 사용)
  double _toKrw(double value, Portfolio pf) {
    if (pf.currency == 'USD') return value * pf.exchangeRate;
    return value;
  }

  void _openDetail(BuildContext context, String id) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PortfolioDetailScreen(portfolioId: id)));
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => PortfolioFormDialog(
        onSave: (name, emoji) {
          context
              .read<PortfolioProvider>()
              .addPortfolio(Portfolio(id: _uid(), name: name, emoji: emoji));
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Portfolio pf) {
    showDialog(
      context: context,
      builder: (_) => PortfolioFormDialog(
        initialName: pf.name,
        initialEmoji: pf.emoji,
        isEdit: true,
        onSave: (name, emoji) {
          context
              .read<PortfolioProvider>()
              .updatePortfolio(pf.id, pf.copyWith(name: name, emoji: emoji));
        },
      ),
    );
  }

  void _duplicatePortfolio(Portfolio pf) {
    final newPf = pf.copyWith(
      id: _uid(),
      name: '${pf.name} (복사)',
      items: pf.items.map((item) => item.copyWith(id: _uid())).toList(),
    );
    context.read<PortfolioProvider>().addPortfolio(newPf);
  }

  void _showDeleteConfirm(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deletePortfolioContent(pf.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              context.read<PortfolioProvider>().deletePortfolio(pf.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditExitConfirm() async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.editExitTitle),
        content: Text(l10n.editExitContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.exit)),
        ],
      ),
    );
    if (result == true) setState(() => _editMode = false);
  }

  // ── Main image save/share ──

  void _showMainCaptureSheet(List<Portfolio> portfolios) {
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
                    _saveMainImage(portfolios);
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
                    _shareMainImage(portfolios);
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

  Future<void> _saveMainImage(List<Portfolio> portfolios) async {
    if (_savingMain) return;
    final l10n = context.l10n;
    setState(() => _savingMain = true);
    try {
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildMainCapture(portfolios),
        pixelRatio: 3.0,
        context: context,
      );
      final r = await ImageGallerySaverPlus.saveImage(
        bytes,
        name: 'portfolio_main_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final ok = r['isSuccess'] == true || r['filePath'] != null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l10n.savedToGallery : l10n.saveFailed),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.saveFailedError(e.toString())),
          duration: const Duration(seconds: 2),
        ));
    } finally {
      if (mounted) setState(() => _savingMain = false);
    }
  }

  Future<void> _shareMainImage(List<Portfolio> portfolios) async {
    if (_sharingMain) return;
    final l10n = context.l10n;
    setState(() => _sharingMain = true);
    try {
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildMainCapture(portfolios),
        pixelRatio: 3.0,
        context: context,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/portfolio_main_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.saveFailedError(e.toString())),
          duration: const Duration(seconds: 2),
        ));
    } finally {
      if (mounted) setState(() => _sharingMain = false);
    }
  }

  Widget _buildMainCapture(List<Portfolio> portfolios) {
    final l10n = context.l10n;
    final pnlColors = context.read<PnlColorNotifier>();
    final displayCur = context.read<MainCurrencyNotifier>().currency;

    double totalKrw = 0;
    double pnlKrw = 0;
    double dayKrw = 0;
    bool hasAvg = false;
    bool hasDay = false;

    for (final pf in portfolios) {
      totalKrw += _toKrw(pf.totalValue, pf);
      if (pf.hasPriceData && pf.hasAvgData) {
        pnlKrw += _toKrw(pf.unrealizedPnL, pf);
        hasAvg = true;
      }
      if (pf.hasPriceData && pf.hasDayData) {
        dayKrw += _toKrw(pf.dayPnL, pf);
        hasDay = true;
      }
    }

    final rates = portfolios
        .where((p) => p.exchangeRate > 0)
        .map((p) => p.exchangeRate)
        .toList();
    final avgRate = rates.isNotEmpty
        ? rates.reduce((a, b) => a + b) / rates.length
        : 1370.0;
    final total = displayCur == 'USD' ? totalKrw / avgRate : totalKrw;
    final pnl = displayCur == 'USD' ? pnlKrw / avgRate : pnlKrw;
    final day = displayCur == 'USD' ? dayKrw / avgRate : dayKrw;

    final pnlPct = (total - pnl) > 0 ? pnl / (total - pnl) * 100 : 0.0;
    final dayPct = (total - day) > 0 ? day / (total - day) * 100 : 0.0;

    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(l10n.evaluationAmount,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textHint)),
            AppLogo(iconSize: 22, textColor: context.textPrimary),
          ]),
          const SizedBox(height: 4),
          Text(_fmt(total, displayCur),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          if (hasAvg || hasDay) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (hasAvg)
                Expanded(
                    child: _summaryChip(
                        context, l10n.profitLoss, pnl, pnlPct, pnlColors,
                        currency: displayCur)),
              if (hasAvg && hasDay) const SizedBox(width: 8),
              if (hasDay)
                Expanded(
                    child: _summaryChip(
                        context, l10n.dayChange, day, dayPct, pnlColors,
                        currency: displayCur)),
            ]),
          ],
          const SizedBox(height: 16),
          ...portfolios.map((pf) {
            final pfVal = pf.totalValue;
            final pfCur = pf.currency;
            final pfPnl =
                (pf.hasPriceData && pf.hasAvgData) ? pf.unrealizedPnL : null;
            final pfDay = (pf.hasPriceData && pf.hasDayData) ? pf.dayPnL : null;
            final pfPnlIsPos = (pfPnl ?? 0) >= 0;
            final pfDayIsPos = (pfDay ?? 0) >= 0;
            final pfPnlColor =
                pfPnlIsPos ? pnlColors.positiveColor : pnlColors.negativeColor;
            final pfDayColor =
                pfDayIsPos ? pnlColors.positiveColor : pnlColors.negativeColor;
            final pfPnlBase = pfVal - (pfPnl ?? 0);
            final pfPnlPct =
                pfPnlBase != 0 ? (pfPnl ?? 0) / pfPnlBase * 100 : 0.0;
            final pfDayBase = pfVal - (pfDay ?? 0);
            final pfDayPct =
                pfDayBase != 0 ? (pfDay ?? 0) / pfDayBase * 100 : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(children: [
                Text(pf.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(pf.name,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Text(l10n.itemCountLabel(pf.items.length),
                              style: TextStyle(
                                  fontSize: 11, color: context.textSecondary)),
                          const SizedBox(width: 8),
                          Text(_fmt(pfVal, pfCur),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary)),
                        ]),
                        if (pfPnl != null) ...[
                          const SizedBox(height: 5),
                          Row(children: [
                            Text(l10n.profitLoss,
                                style: TextStyle(
                                    fontSize: 11, color: context.textHint)),
                            Expanded(
                              child: Text(
                                '${pfPnlIsPos ? '+' : ''}${_fmt(pfPnl, pfCur)} (${pfPnlIsPos ? '+' : ''}${pfPnlPct.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: pfPnlColor),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ],
                        if (pfDay != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            Text(l10n.dayChange,
                                style: TextStyle(
                                    fontSize: 11, color: context.textHint)),
                            Expanded(
                              child: Text(
                                '${pfDayIsPos ? '+' : ''}${_fmt(pfDay, pfCur)} (${pfDayIsPos ? '+' : ''}${pfDayPct.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: pfDayColor),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ],
                      ]),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        if (!provider.loaded) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final portfolios = provider.portfolios;
        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              BrandHeader(
                titleWidget: const AppLogo(iconSize: 26),
                childPadding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                actions: [
                  if (!_editMode)
                    IconButton(
                      icon: provider.refreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.refresh, color: Colors.white),
                      onPressed: provider.refreshing ? null : _doRefreshAll,
                    ),
                  if (_editMode)
                    TextButton.icon(
                      onPressed: () => setState(() => _editMode = false),
                      icon: const Icon(Icons.check,
                          color: Colors.white, size: 18),
                      label: Text(l10n.done,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
                // 편집 중에는 총자산을 접어 목록에 집중시킨다
                child: (portfolios.isEmpty || _editMode)
                    ? null
                    : _buildTotalAssets(context, portfolios),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _editMode
                          ? ReorderableListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 80),
                              itemCount: portfolios.length,
                              onReorder: (o, n) {
                                if (n > o) n--;
                                final list = List<Portfolio>.from(portfolios);
                                final item = list.removeAt(o);
                                list.insert(n, item);
                                provider.reorderPortfolios(list);
                              },
                              itemBuilder: (ctx, idx) => _buildEditCard(
                                  context, portfolios[idx],
                                  key: ValueKey(portfolios[idx].id)),
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 100),
                              children: [
                                if (portfolios.isNotEmpty) ...[
                                  _buildActionCards(context, portfolios),
                                  const SizedBox(height: 10),
                                  _buildPortfolioCard(context, portfolios),
                                  const SizedBox(height: 10),
                                ],
                                _buildAddCard(context),
                              ],
                            ),
                    ),
                    if (!_editMode)
                      Positioned.fill(
                        child: SpeedDialFab(
                          key: const ValueKey('list_fab'),
                          items: [
                            SpeedDialItem(
                              icon: Icons.edit_outlined,
                              label: l10n.edit,
                              onTap: () => setState(() => _editMode = true),
                            ),
                            if (portfolios.isNotEmpty)
                              SpeedDialItem(
                                icon: Icons.camera_alt_outlined,
                                label: l10n.capture,
                                onTap: () => _showMainCaptureSheet(portfolios),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 딥그린 헤더: 총자산 ──

  Widget _buildTotalAssets(BuildContext context, List<Portfolio> portfolios) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final pnlColors = context.watch<PnlColorNotifier>();
    final displayCur = context.watch<MainCurrencyNotifier>().currency;

    final hasAnyPrice = portfolios.any((p) => p.hasPriceData);

    double totalKrw = 0, pnlKrw = 0, dayKrw = 0;
    bool hasAvg = false, hasDay = false;

    final rates = portfolios
        .where((p) => p.exchangeRate > 0)
        .map((p) => p.exchangeRate)
        .toList();
    final avgRate = rates.isNotEmpty
        ? rates.reduce((a, b) => a + b) / rates.length
        : 1370.0;

    for (final pf in portfolios) {
      totalKrw += _toKrw(pf.totalValue, pf);
      if (pf.hasAvgData) {
        pnlKrw += _toKrw(pf.unrealizedPnL, pf);
        hasAvg = true;
      }
      if (pf.hasDayData) {
        dayKrw += _toKrw(pf.dayPnL, pf);
        hasDay = true;
      }
    }

    final total = displayCur == 'USD' ? totalKrw / avgRate : totalKrw;
    final pnl = displayCur == 'USD' ? pnlKrw / avgRate : pnlKrw;
    final day = displayCur == 'USD' ? dayKrw / avgRate : dayKrw;

    final pnlPct = (total - pnl) > 0 ? pnl / (total - pnl) * 100 : 0.0;
    final dayPct = (total - day) > 0 ? day / (total - day) * 100 : 0.0;

    // 환율 칩은 해외 종목이 있을 때만 의미가 있다
    final hasForeign = portfolios.any(
        (p) => p.currency == 'USD' || p.items.any((i) => i.market == 'US'));

    final oldestUpdated = portfolios
        .where((p) => p.lastUpdated != null)
        .map((p) => p.lastUpdated!)
        .fold<int?>(null, (m, t) => m == null || t < m ? t : m);
    final timeStr = oldestUpdated == null
        ? l10n.neverUpdated
        : () {
            final d = DateTime.fromMillisecondsSinceEpoch(oldestUpdated);
            return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
                '${d.hour.toString().padLeft(2, '0')}:'
                '${d.minute.toString().padLeft(2, '0')}';
          }();

    final showChart = _history.length >= AssetHistoryService.minPointsForChart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isKo ? '총 자산' : 'Total assets',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.onBrandSecondary),
            ),
            const Spacer(),
            if (hasForeign)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(DS.chipRadius),
                ),
                child: Text(
                  '1 USD = ₩${avgRate.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: DS.caption,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            hasAnyPrice ? _fmt(total, displayCur) : '—',
            style: const TextStyle(
              fontSize: DS.displayAmount,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1.08,
            ),
          ),
        ),
        if (hasAnyPrice && (hasAvg || hasDay)) ...[
          const SizedBox(height: 13),
          Row(
            children: [
              if (hasAvg)
                _brandTile(context, l10n.profitLoss, pnl, pnlPct, pnlColors,
                    displayCur),
              if (hasAvg && hasDay) const SizedBox(width: 9),
              if (hasDay)
                _brandTile(context, l10n.dayChange, day, dayPct, pnlColors,
                    displayCur),
            ],
          ),
        ],
        if (showChart) ...[
          const SizedBox(height: 14),
          AssetSparkline(
            points: _history,
            color: _history.last.totalKrw >= _history.first.totalKrw
                ? pnlColors.onBrandPositive
                : pnlColors.onBrandNegative,
          ),
          const SizedBox(height: 4),
        ] else
          const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              showChart
                  ? (isKo
                      ? '최근 ${_history.length}일'
                      : 'Last ${_history.length} days')
                  : l10n.priceDelayNote,
              style: TextStyle(
                  fontSize: DS.caption,
                  fontWeight: FontWeight.w500,
                  color: context.onBrandSecondary),
            ),
            Text(
              isKo ? '$timeStr 기준' : 'as of $timeStr',
              style: TextStyle(
                  fontSize: DS.caption,
                  fontWeight: FontWeight.w500,
                  color: context.onBrandSecondary),
            ),
          ],
        ),
      ],
    );
  }

  /// 딥그린 위 손익 타일 (평가손익 · 전일대비)
  Widget _brandTile(BuildContext context, String label, double amount,
      double pct, PnlColorNotifier pnlColors, String currency) {
    final isPos = amount >= 0;
    final color = isPos ? pnlColors.onBrandPositive : pnlColors.onBrandNegative;
    final sign = isPos ? '+' : '−';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: context.onBrandSecondary)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$sign${_fmt(amount.abs(), currency)}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$sign${pct.abs().toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: DS.body, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// 캡처 이미지용 손익 칩 (밝은 배경 위 — 헤더의 _brandTile과 별개)
  Widget _summaryChip(BuildContext context, String label, double amount,
      double pct, PnlColorNotifier pnlColors,
      {String currency = 'KRW'}) {
    final isPos = amount >= 0;
    final color = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '−';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: context.textSecondary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isPos ? context.pnlUpTint : context.pnlDownTint,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$sign${pct.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: DS.caption,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ]),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$sign${_fmt(amount.abs(), currency)}',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  // ── 액션 카드 2장 ──

  Widget _buildActionCards(BuildContext context, List<Portfolio> portfolios) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    // 허용 편차를 넘어선 포트 중 편차가 가장 큰 것
    Portfolio? worst;
    int worstCount = 0;
    double worstDrift = 0;
    for (final pf in portfolios) {
      final over = Rebalancer.driftExceeding(pf);
      if (over.isEmpty) continue;
      final d = over.first.drift;
      if (worst == null || d.abs() > worstDrift.abs()) {
        worst = pf;
        worstCount = over.length;
        worstDrift = d;
      }
    }

    final now = DateTime.now();
    final lastMonth = now.month == 1 ? 12 : now.month - 1;
    final driftSign = worstDrift >= 0 ? '+' : '−';
    final driftAbs = worstDrift.abs().toStringAsFixed(2);

    // ListView 안에서는 세로 제약이 무한이라 Row에 stretch를 쓸 수 없다.
    // IntrinsicHeight로 두 카드 높이를 먼저 맞춘 뒤 stretch한다.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: worst != null
                ? _actionCard(
                    context,
                    bg: context.warningBg,
                    fg: context.warningText,
                    icon: Icons.error_outline,
                    label: isKo ? '조정 필요' : 'Needs adjusting',
                    title: worst.name,
                    sub: isKo
                        ? '$worstCount종목 · 최대 $driftSign$driftAbs%p'
                        : '$worstCount holdings · max $driftSign$driftAbs' 'pp',
                    onTap: () => widget.onNavigateToTab?.call(1),
                  )
                : _actionCard(
                    context,
                    bg: context.brandTint,
                    fg: context.brand,
                    icon: Icons.check_circle_outline,
                    label: isKo ? '비중 유지' : 'On target',
                    title: isKo ? '조정할 종목 없음' : 'Nothing to adjust',
                    sub: isKo ? '모두 허용 편차 안' : 'All within tolerance',
                    onTap: () => widget.onNavigateToTab?.call(1),
                  ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _actionCard(
              context,
              bg: context.brandTint,
              fg: context.brand,
              icon: Icons.insights_outlined,
              label: isKo ? '결산 준비' : 'Returns ready',
              title: isKo ? '$lastMonth월 월간' : 'Monthly · $lastMonth',
              sub: isKo ? '결산 탭에서 보기' : 'Open Returns tab',
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required Color bg,
    required Color fg,
    required IconData icon,
    required String label,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DS.tileRadius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DS.tileRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: fg),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.chevron_right, size: 16, color: fg),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: DS.sectionTitle,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(sub,
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── 포트폴리오 목록 ──

  /// 포트폴리오 전체가 하나의 카드다. 각 포트는 구분선으로 나뉜 행.
  Widget _buildPortfolioCard(BuildContext context, List<Portfolio> portfolios) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: context.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DS.cardPaddingH),
      child: Column(
        children: [
          for (var i = 0; i < portfolios.length; i++)
            _buildPortfolioRow(context, portfolios[i],
                isLast: i == portfolios.length - 1),
        ],
      ),
    );
  }

  Widget _buildPortfolioRow(BuildContext context, Portfolio pf,
      {required bool isLast}) {
    final pnlColors = context.watch<PnlColorNotifier>();
    final tv = pf.totalValue;

    final hasPnl = pf.hasPriceData && pf.hasAvgData;
    final hasDay = pf.hasPriceData && pf.hasDayData;
    final pnl = pf.unrealizedPnL;
    final day = pf.dayPnL;
    final pnlPct = (tv - pnl) != 0 ? pnl / (tv - pnl) * 100 : 0.0;
    final dayPct = (tv - day) != 0 ? day / (tv - day) * 100 : 0.0;
    final pnlColor =
        pnl >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;

    return InkWell(
      onTap: () => _openDetail(context, pf.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: isLast
            ? null
            : BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: context.dividerColor))),
        child: Row(
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt(tv, pf.currency),
                  style: TextStyle(
                      fontSize: DS.rowAmount,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: context.textPrimary),
                ),
                if (hasPnl || hasDay) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // 전일대비는 방향만 — 무채색으로 두어 누적 수익률과 섞이지 않게
                      if (hasDay)
                        Text(
                          '${day >= 0 ? '▲' : '▼'}${dayPct.abs().toStringAsFixed(2)}%',
                          style: TextStyle(
                              fontSize: DS.body,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary),
                        ),
                      if (hasDay && hasPnl) const SizedBox(width: 8),
                      if (hasPnl)
                        Text(
                          '${pnl >= 0 ? '+' : '−'}${pnlPct.abs().toStringAsFixed(2)}%',
                          style: TextStyle(
                              fontSize: DS.returnPct,
                              fontWeight: FontWeight.w700,
                              color: pnlColor),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard(BuildContext context) {
    return InkWell(
      onTap: () => _showCreateDialog(context),
      borderRadius: BorderRadius.circular(DS.tileRadius),
      child: DashedBorderBox(
        color: const Color(0xFFD6CFBC),
        radius: DS.tileRadius,
        child: SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 19, color: context.brand),
              const SizedBox(width: 8),
              Text(
                context.l10n.portfolioAddBtn,
                style: TextStyle(
                    fontSize: DS.sectionTitle,
                    fontWeight: FontWeight.w700,
                    color: context.brand),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 편집 모드 카드 ──

  Widget _buildEditCard(BuildContext context, Portfolio pf, {Key? key}) {
    final l10n = context.l10n;
    final subtitle =
        '${l10n.itemCountLabel(pf.items.length)} · ${_fmt(pf.totalValue, pf.currency)}';

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        border: Border.all(color: context.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Text(pf.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pf.name,
                    style: TextStyle(
                        fontSize: DS.rowName,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
          _editIconBtn(context, Icons.edit_outlined, context.brand,
              () => _showEditDialog(context, pf)),
          _editIconBtn(context, Icons.content_copy, context.brandOnLight,
              () => _duplicatePortfolio(pf)),
          _editIconBtn(context, Icons.remove, context.danger,
              () => _showDeleteConfirm(context, pf)),
        ],
      ),
    );
  }

  Widget _editIconBtn(
      BuildContext context, IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
