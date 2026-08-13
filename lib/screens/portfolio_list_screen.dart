import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/settlement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/portfolio_form_dialog.dart';
import '../widgets/disclaimer_dialog.dart';
import '../widgets/app_settings_dialog.dart';
import '../widgets/speed_dial_fab.dart';
import '../widgets/app_logo.dart';
import '../widgets/bottom_banner_ad.dart';
import '../services/ad_service.dart';
import 'portfolio_detail_screen.dart';

class PortfolioListScreen extends StatefulWidget {
  const PortfolioListScreen({super.key});
  @override
  State<PortfolioListScreen> createState() => _PortfolioListScreenState();
}

class _PortfolioListScreenState extends State<PortfolioListScreen>
    with SingleTickerProviderStateMixin {
  bool _editMode = false;
  bool _refreshing = false;
  bool _savingMain = false;
  bool _sharingMain = false;
  final _screenshotCtrl = ScreenshotController();
  late final TabController _tabController;

  // ── 종료 팝업 광고만 유지 (메인 배너는 BottomBannerAd 위젯이 담당) ──
  BannerAd? _exitBanner;
  bool _exitBannerLoaded = false;

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExitAd();
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
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final provider = context.read<PortfolioProvider>();
    final portfolios = List<Portfolio>.from(provider.portfolios);
    double? cachedRate;
    for (final pf in portfolios) {
      if (pf.exchangeAuto) {
        cachedRate ??=
            await ApiService.fetchExchangeRate().then((r) => r.ok ? r.data : null);
        if (cachedRate != null) {
          await provider.updateSettings(pf.id, exchangeRate: cachedRate);
        }
      }
      if (pf.priceAuto) {
        for (final item in pf.items) {
          if (item.isCash || item.ticker.isEmpty) continue;
          final r = await ApiService.fetchStockPrice(item.ticker, item.market);
          if (r.ok && r.data != null) {
            await provider.updateItem(
              pf.id,
              item.copyWith(
                currentPrice: r.data!.currentPrice,
                previousClose: r.data!.previousClose,
              ),
            );
          }
        }
      }
      await provider.updateLastRefreshed(pf.id);
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.updateSuccess)),
    );
  }

  void _loadExitAd() {
    _exitBanner = AdService.createBanner(
      adUnitId: AdService.exitBannerId,
      size: AdSize.mediumRectangle,
      onLoaded: () { if (mounted) setState(() => _exitBannerLoaded = true); },
      onFailed: () { _exitBanner = null; },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _exitBanner?.dispose();
    super.dispose();
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
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PortfolioDetailScreen(portfolioId: id)));
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => PortfolioFormDialog(
        onSave: (name, emoji) {
          context.read<PortfolioProvider>().addPortfolio(
              Portfolio(id: _uid(), name: name, emoji: emoji));
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
          context.read<PortfolioProvider>().updatePortfolio(
              pf.id, pf.copyWith(name: name, emoji: emoji));
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.exit)),
        ],
      ),
    );
    if (result == true) setState(() => _editMode = false);
  }

  Future<void> _showExitConfirm() async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 제목 (질문)
              Text(
                l10n.appExitContent,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
              ),
              // 광고 (로드된 경우만)
              if (_exitBannerLoaded && _exitBanner != null) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: _exitBanner!.size.width.toDouble(),
                    height: _exitBanner!.size.height.toDouble(),
                    child: AdWidget(ad: _exitBanner!),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // 버튼 행
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(l10n.cancel,
                        style: TextStyle(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(l10n.exit,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (result == true) SystemNavigator.pop();
  }

  void _handleBackPress() {
    if (_editMode) _showEditExitConfirm();
    else _showExitConfirm();
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: ctx.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(l10n.capture,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _saveMainImage(portfolios); },
                  icon: const Icon(Icons.save_alt_rounded, size: 16),
                  label: Text(l10n.saveImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ctx.textPrimary,
                    side: BorderSide(color: ctx.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _shareMainImage(portfolios); },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(l10n.shareImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
      final file = File('${dir.path}/portfolio_main_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
      if (pf.hasPriceData && pf.hasAvgData) { pnlKrw += _toKrw(pf.unrealizedPnL, pf); hasAvg = true; }
      if (pf.hasPriceData && pf.hasDayData) { dayKrw += _toKrw(pf.dayPnL, pf); hasDay = true; }
    }

    final rates = portfolios.where((p) => p.exchangeRate > 0).map((p) => p.exchangeRate).toList();
    final avgRate = rates.isNotEmpty ? rates.reduce((a, b) => a + b) / rates.length : 1370.0;
    final total = displayCur == 'USD' ? totalKrw / avgRate : totalKrw;
    final pnl   = displayCur == 'USD' ? pnlKrw   / avgRate : pnlKrw;
    final day   = displayCur == 'USD' ? dayKrw    / avgRate : dayKrw;

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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textHint)),
            AppLogo(iconSize: 22, textColor: context.textPrimary),
          ]),
          const SizedBox(height: 4),
          Text(_fmt(total, displayCur),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
          if (hasAvg || hasDay) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (hasAvg)
                Expanded(child: _summaryChip(context, l10n.profitLoss, pnl, pnlPct, pnlColors, currency: displayCur)),
              if (hasAvg && hasDay) const SizedBox(width: 8),
              if (hasDay)
                Expanded(child: _summaryChip(context, l10n.dayChange, day, dayPct, pnlColors, currency: displayCur)),
            ]),
          ],
          const SizedBox(height: 16),
          ...portfolios.map((pf) {
            final pfVal = pf.totalValue;
            final pfCur = pf.currency;
            final pfPnl = (pf.hasPriceData && pf.hasAvgData) ? pf.unrealizedPnL : null;
            final pfDay = (pf.hasPriceData && pf.hasDayData) ? pf.dayPnL : null;
            final pfPnlIsPos = (pfPnl ?? 0) >= 0;
            final pfDayIsPos = (pfDay ?? 0) >= 0;
            final pfPnlColor = pfPnlIsPos ? pnlColors.positiveColor : pnlColors.negativeColor;
            final pfDayColor = pfDayIsPos ? pnlColors.positiveColor : pnlColors.negativeColor;
            final pfPnlBase = pfVal - (pfPnl ?? 0);
            final pfPnlPct = pfPnlBase != 0 ? (pfPnl ?? 0) / pfPnlBase * 100 : 0.0;
            final pfDayBase = pfVal - (pfDay ?? 0);
            final pfDayPct = pfDayBase != 0 ? (pfDay ?? 0) / pfDayBase * 100 : 0.0;
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(pf.name,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Text(l10n.itemCountLabel(pf.items.length),
                          style: TextStyle(fontSize: 11, color: context.textSecondary)),
                      const SizedBox(width: 8),
                      Text(_fmt(pfVal, pfCur),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
                    ]),
                    if (pfPnl != null) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Text(l10n.profitLoss, style: TextStyle(fontSize: 11, color: context.textHint)),
                        Expanded(
                          child: Text(
                            '${pfPnlIsPos ? '+' : ''}${_fmt(pfPnl, pfCur)} (${pfPnlIsPos ? '+' : ''}${pfPnlPct.toStringAsFixed(1)}%)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pfPnlColor),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                    if (pfDay != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(l10n.dayChange, style: TextStyle(fontSize: 11, color: context.textHint)),
                        Expanded(
                          child: Text(
                            '${pfDayIsPos ? '+' : ''}${_fmt(pfDay, pfCur)} (${pfDayIsPos ? '+' : ''}${pfDayPct.toStringAsFixed(1)}%)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pfDayColor),
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

  Future<void> _backupData(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final portfolios = context.read<PortfolioProvider>().portfolios;
      await StorageService.exportPortfolios(portfolios);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.backupFailed}: $e')),
      );
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final portfolios = await StorageService.importPortfolios();
      if (portfolios == null) return;
      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(l10n.restoreConfirmTitle,
              style: TextStyle(color: context.textPrimary)),
          content: Text(l10n.restoreConfirmContent(portfolios.length),
              style: TextStyle(color: context.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel)),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.confirm,
                    style: const TextStyle(color: Color(0xFF3B82F6)))),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;
      await context.read<PortfolioProvider>().replaceAll(portfolios);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.restoreSuccess(portfolios.length))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.restoreFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        if (!provider.loaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBackPress();
          },
          child: Scaffold(
            backgroundColor: context.scaffoldBg,
            appBar: AppBar(
              backgroundColor: context.appBarBg,
              title: const AppLogo(iconSize: 26),
              actions: [
                if (!_editMode)
                  IconButton(
                    icon: _refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refreshing ? null : _doRefreshAll,
                  ),
                if (_editMode)
                  TextButton.icon(
                    onPressed: () => setState(() => _editMode = false),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: Text(l10n.done,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(text: l10n.portfolio),
                  Tab(text: l10n.settlementTab),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ── Tab 1: 포트폴리오 목록 ──
                      Stack(
                        children: [
                          Positioned.fill(
                            child: _editMode
                                ? ReorderableListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                                    itemCount: provider.portfolios.length,
                                    onReorder: (o, n) {
                                      if (n > o) n--;
                                      final list = List<Portfolio>.from(provider.portfolios);
                                      final item = list.removeAt(o);
                                      list.insert(n, item);
                                      provider.reorderPortfolios(list);
                                    },
                                    itemBuilder: (ctx, idx) {
                                      final pf = provider.portfolios[idx];
                                      return _buildCard(context, pf, key: ValueKey(pf.id));
                                    },
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                                    itemCount: provider.portfolios.length + 2,
                                    itemBuilder: (ctx, idx) {
                                      if (idx == 0) {
                                        return _buildSummaryHeader(context, provider.portfolios);
                                      }
                                      if (idx == provider.portfolios.length + 1) {
                                        return _buildSlimAddCard(context);
                                      }
                                      return _buildCard(context, provider.portfolios[idx - 1]);
                                    },
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
                                  SpeedDialItem(
                                    icon: Icons.settings_outlined,
                                    label: l10n.settings,
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => AppSettingsDialog(
                                        onBackup: () => _backupData(context),
                                        onRestore: () => _restoreData(context),
                                      ),
                                    ),
                                  ),
                                  if (provider.portfolios.isNotEmpty)
                                    SpeedDialItem(
                                      icon: Icons.camera_alt_outlined,
                                      label: l10n.capture,
                                      onTap: () => _showMainCaptureSheet(provider.portfolios),
                                    ),
                                  SpeedDialItem(
                                    icon: Icons.info_outline,
                                    label: l10n.notice,
                                    onTap: () => DisclaimerDialog.showAlways(context),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      // ── Tab 2: 전체 결산 ──
                      _AllSettlementTab(portfolios: provider.portfolios),
                    ],
                  ),
                ),
                // ── 하단 배너 광고 ──
                const BottomBannerAd(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryHeader(BuildContext context, List<Portfolio> portfolios) {
    if (portfolios.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final pnlColors = context.watch<PnlColorNotifier>();
    final displayCur = context.watch<MainCurrencyNotifier>().currency;

    final hasAnyPrice = portfolios.any((p) => p.hasPriceData);

    double totalKrw = 0;
    double pnlKrw = 0;
    double dayKrw = 0;
    bool hasAvg = false;
    bool hasDay = false;

    // 평균 환율 계산 (USD 표시 시 사용)
    final rates = portfolios.where((p) => p.exchangeRate > 0).map((p) => p.exchangeRate).toList();
    final avgRate = rates.isNotEmpty ? rates.reduce((a, b) => a + b) / rates.length : 1370.0;

    for (final pf in portfolios) {
      totalKrw += _toKrw(pf.totalValue, pf);
      if (pf.hasAvgData) { pnlKrw += _toKrw(pf.unrealizedPnL, pf); hasAvg = true; }
      if (pf.hasDayData) { dayKrw += _toKrw(pf.dayPnL, pf); hasDay = true; }
    }

    // 표시 통화로 환산
    final total = displayCur == 'USD' ? totalKrw / avgRate : totalKrw;
    final pnl   = displayCur == 'USD' ? pnlKrw   / avgRate : pnlKrw;
    final day   = displayCur == 'USD' ? dayKrw    / avgRate : dayKrw;

    final pnlPct = (total - pnl) > 0 ? pnl / (total - pnl) * 100 : 0.0;
    final dayPct = (total - day) > 0 ? day / (total - day) * 100 : 0.0;

    // 가장 오래된 lastUpdated
    final oldestUpdated = portfolios
        .where((p) => p.lastUpdated != null)
        .map((p) => p.lastUpdated!)
        .fold<int?>(null, (m, t) => m == null || t < m ? t : m);
    final timeStr = oldestUpdated == null
        ? l10n.neverUpdated
        : () {
            final d = DateTime.fromMillisecondsSinceEpoch(oldestUpdated);
            return '${d.month}/${d.day} '
                '${d.hour.toString().padLeft(2, '0')}:'
                '${d.minute.toString().padLeft(2, '0')}';
          }();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.evaluationAmount,
              style: TextStyle(fontSize: 11, color: context.textHint, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hasAnyPrice ? _fmt(total, displayCur) : '—',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
          ),
          if (hasAnyPrice && (hasAvg || hasDay)) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (hasAvg)
                Expanded(child: _summaryChip(context, l10n.profitLoss, pnl, pnlPct, pnlColors, currency: displayCur)),
              if (hasAvg && hasDay) const SizedBox(width: 8),
              if (hasDay)
                Expanded(child: _summaryChip(context, l10n.dayChange, day, dayPct, pnlColors, currency: displayCur)),
            ]),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(timeStr, style: TextStyle(fontSize: 10, color: context.textHint)),
            Text(l10n.priceDelayNote, style: TextStyle(fontSize: 10, color: context.textHint)),
          ]),
        ],
      ),
    );
  }

  Widget _summaryChip(BuildContext context, String label, double amount, double pct, PnlColorNotifier pnlColors, {String currency = 'KRW'}) {
    final isPos = amount >= 0;
    final color = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: context.infoBoxBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.textHint)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$sign${pct.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$sign${_fmt(amount, currency)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlimAddCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showCreateDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(12),
            color: context.cardBg.withValues(alpha: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text(context.l10n.portfolioAddBtn,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3B82F6))),
          ]),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Portfolio pf, {Key? key}) {
    final tv = pf.totalValue;
    final l10n = context.l10n;
    final subtitle = '${l10n.itemCountLabel(pf.items.length)} · ${_fmt(tv, pf.currency)}';

    if (_editMode) {
      return Card(
        key: key,
        color: context.cardBg,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(children: [
            Text(pf.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pf.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 13, color: context.textSecondary)),
            ])),
            IconButton(
              onPressed: () => _showEditDialog(context, pf),
              icon: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4))),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 16),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            IconButton(
              onPressed: () => _duplicatePortfolio(pf),
              icon: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4))),
                child: const Icon(Icons.content_copy, color: Color(0xFF22C55E), size: 16),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            IconButton(
              onPressed: () => _showDeleteConfirm(context, pf),
              icon: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4))),
                child: const Icon(Icons.remove, color: Colors.red, size: 20),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ]),
        ),
      );
    }

    final hasPnl = pf.hasPriceData && pf.hasAvgData;
    final hasDay = pf.hasPriceData && pf.hasDayData;
    final pnl = pf.unrealizedPnL;
    final day = pf.dayPnL;
    final pnlColors = context.watch<PnlColorNotifier>();
    final pnlColor = pnl >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;
    final dayColor = day >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;
    final costBasis = tv - pnl;
    final pnlPct = costBasis != 0 ? pnl / costBasis * 100 : 0.0;
    final dayBase = tv - day;
    final dayPct = dayBase != 0 ? day / dayBase * 100 : 0.0;

    return Card(
      key: key,
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(context, pf.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(pf.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: 포폴명 + N개 종목 + 총금액
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            pf.name,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.itemCountLabel(pf.items.length),
                          style: TextStyle(fontSize: 11, color: context.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fmt(tv, pf.currency),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ],
                    ),
                    // Row 2: 평가손익
                    if (hasPnl) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Text(l10n.profitLoss,
                            style: TextStyle(fontSize: 11, color: context.textHint)),
                        Expanded(
                          child: Text(
                            '${pnl >= 0 ? '+' : ''}${_fmt(pnl, pf.currency)} (${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pnlColor),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                    // Row 3: 전일대비
                    if (hasDay) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(l10n.dayChange,
                            style: TextStyle(fontSize: 11, color: context.textHint)),
                        Expanded(
                          child: Text(
                            '${day >= 0 ? '+' : ''}${_fmt(day, pf.currency)} (${dayPct >= 0 ? '+' : ''}${dayPct.toStringAsFixed(1)}%)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dayColor),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: context.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 전체 포트폴리오 합산 결산 탭 ──

class _AllSettlementTab extends StatefulWidget {
  final List<Portfolio> portfolios;
  const _AllSettlementTab({required this.portfolios});
  @override
  State<_AllSettlementTab> createState() => _AllSettlementTabState();
}

class _AllSettlementTabState extends State<_AllSettlementTab> {
  SettlementPeriod _period = SettlementPeriod.monthly;
  late int _year;
  late int _sub;
  bool _loading = false;

  double? _startValue;
  double? _endValue;
  double? _absoluteReturn;
  double? _returnRate;
  double _netCashFlow = 0.0;
  bool _isCurrentPeriod = false;
  List<Map<String, dynamic>> _portfolioResults = [];

  bool _saving = false;
  bool _sharing = false;
  final _screenshotCtrl = ScreenshotController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _sub = SettlementService.currentSub(_period);
    _load();
  }

  @override
  void didUpdateWidget(_AllSettlementTab old) {
    super.didUpdateWidget(old);
    if (old.portfolios != widget.portfolios) _load();
  }

  Future<void> _load() async {
    if (widget.portfolios.isEmpty) return;
    setState(() { _loading = true; _startValue = null; _portfolioResults = []; });

    double start = 0, end = 0, absReturn = 0, netCashFlow = 0;
    bool isCurrentPeriod = false;
    final key = PeriodKey(_year, _sub);
    final results = <Map<String, dynamic>>[];

    final rates = widget.portfolios.where((p) => p.exchangeRate > 0).map((p) => p.exchangeRate).toList();
    final avgRate = rates.isNotEmpty ? rates.reduce((a, b) => a + b) / rates.length : 1370.0;

    await Future.wait(widget.portfolios.map((pf) async {
      final r = await SettlementService.calculate(pf, _period, key);
      if (r == null) return;
      final fx = pf.currency == 'USD' ? avgRate : 1.0;
      final pfStart = r.startValue * fx;
      final pfEnd = r.endValue * fx;
      final pfAbs = r.absoluteReturn * fx;
      start += pfStart;
      end += pfEnd;
      absReturn += pfAbs;
      netCashFlow += r.netCashFlow * fx;
      if (r.isCurrentPeriod) isCurrentPeriod = true;
      results.add({
        'emoji': pf.emoji,
        'name': pf.name,
        'startValue': pfStart,
        'endValue': pfEnd,
        'absoluteReturn': pfAbs,
        'returnRate': pfStart > 0 ? pfAbs / pfStart * 100 : 0.0,
      });
    }));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _startValue = start;
      _endValue = end;
      _absoluteReturn = absReturn;
      _returnRate = start > 0 ? absReturn / start * 100 : 0;
      _netCashFlow = netCashFlow;
      _isCurrentPeriod = isCurrentPeriod;
      _portfolioResults = results;
    });
  }

  void _onPeriodChanged(SettlementPeriod p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      _year = DateTime.now().year;
      _sub = SettlementService.currentSub(p);
    });
    _load();
  }

  void _onYearChanged(int y) {
    final maxSub = SettlementService.maxSub(_period, y);
    setState(() {
      _year = y;
      if (_sub > maxSub) _sub = maxSub;
    });
    _load();
  }

  void _onSubChanged(int s) {
    setState(() => _sub = s);
    _load();
  }

  String _fmt(double n) {
    final prefix = n < 0 ? '-' : '';
    final abs = n.abs();
    return '$prefix₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

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
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: ctx.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(l10n.capture,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _saveImage(); },
                  icon: const Icon(Icons.save_alt_rounded, size: 16),
                  label: Text(l10n.saveImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ctx.textPrimary,
                    side: BorderSide(color: ctx.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _shareImage(); },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(l10n.shareImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.saveFailedError(e.toString())),
        duration: const Duration(seconds: 2),
      ));
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
      final file = File('${dir.path}/settlement_all_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.saveFailedError(e.toString())),
        duration: const Duration(seconds: 2),
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _buildCapture() {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final pnlColors = context.read<PnlColorNotifier>();
    final retColor = (_returnRate ?? 0) >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;
    final absColor = (_absoluteReturn ?? 0) >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;

    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isKo ? '전체 결산' : 'All Settlement',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
            AppLogo(iconSize: 22, textColor: context.textPrimary),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _captureValueBox(isKo ? '기준 평가금액' : 'Base Value', _fmt(_startValue ?? 0))),
                const SizedBox(width: 10),
                Expanded(child: _captureValueBox(isKo ? '현재 평가금액' : 'Current Value', _fmt(_endValue ?? 0))),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isKo ? '기간 손익' : 'Period P&L',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${(_returnRate ?? 0) >= 0 ? '+' : ''}${(_returnRate ?? 0).toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: retColor),
                  ),
                  Text(
                    '${(_absoluteReturn ?? 0) >= 0 ? '+' : ''}${_fmt(_absoluteReturn ?? 0)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: absColor),
                  ),
                ]),
              ]),
            ]),
          ),
          if (_portfolioResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._portfolioResults.map((r) {
              final ret = (r['returnRate'] as double);
              final abs = (r['absoluteReturn'] as double);
              final color = ret >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${r['emoji']} ${r['name']}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
                    const Spacer(),
                    Text('${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(isKo ? '기준 ${_fmt(r['startValue'] as double)}' : 'Base ${_fmt(r['startValue'] as double)}',
                        style: TextStyle(fontSize: 10, color: context.textHint)),
                    const Spacer(),
                    Text(isKo ? '현재 ${_fmt(r['endValue'] as double)}' : 'Now ${_fmt(r['endValue'] as double)}',
                        style: TextStyle(fontSize: 10, color: context.textHint)),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${isKo ? '손익' : 'P&L'}  ${abs >= 0 ? '+' : ''}${_fmt(abs)}',
                        style: TextStyle(fontSize: 10, color: color)),
                  ]),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _captureValueBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: context.infoBoxBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.textHint)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final pnlColors = context.watch<PnlColorNotifier>();
    final maxSub = SettlementService.maxSub(_period, _year);
    final now = DateTime.now();
    final earliestYear = widget.portfolios.isEmpty ? now.year
        : widget.portfolios.map((p) => SettlementService.earliestYear(p)).reduce((a, b) => a < b ? a : b);
    final years = List.generate(now.year - earliestYear + 1, (i) => earliestYear + i).reversed.toList();

    final content = Column(children: [
      // 기간 선택
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SegmentedButton<SettlementPeriod>(
          segments: [
            ButtonSegment(value: SettlementPeriod.weekly,    label: Text(l10n.settlementWeekly,    style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: SettlementPeriod.monthly,   label: Text(l10n.settlementMonthly,   style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: SettlementPeriod.quarterly, label: Text(l10n.settlementQuarterly, style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: SettlementPeriod.yearly,    label: Text(l10n.settlementYearly,    style: const TextStyle(fontSize: 12))),
          ],
          selected: {_period},
          onSelectionChanged: (s) => _onPeriodChanged(s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ),
      // 연도/세부 선택
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          DropdownButton<int>(
            value: years.contains(_year) ? _year : years.first,
            isDense: true,
            underline: Container(height: 1, color: context.borderColor),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
            dropdownColor: context.cardBg,
            items: years.map((y) => DropdownMenuItem(value: y, child: Text(l10n.settlementYearLabel(y)))).toList(),
            onChanged: (v) { if (v != null) _onYearChanged(v); },
          ),
          if (_period != SettlementPeriod.yearly) ...[
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _sub.clamp(1, maxSub),
              isDense: true,
              underline: Container(height: 1, color: context.borderColor),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
              dropdownColor: context.cardBg,
              items: List.generate(maxSub, (i) => i + 1).map((s) {
                final label = switch (_period) {
                  SettlementPeriod.weekly    => l10n.settlementWeekNum(s),
                  SettlementPeriod.monthly   => l10n.settlementMonthNum(s),
                  SettlementPeriod.quarterly => l10n.settlementQuarterNum(s),
                  SettlementPeriod.yearly    => '',
                };
                return DropdownMenuItem(value: s, child: Text(label));
              }).toList(),
              onChanged: (v) { if (v != null) _onSubChanged(v); },
            ),
          ],
          if (_isCurrentPeriod) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.settlementCurrentPeriod,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
            ),
          ],
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : widget.portfolios.isEmpty
                ? Center(child: Text(l10n.settlementNoHoldings,
                    style: TextStyle(color: context.textSecondary)))
                : _startValue == null
                    ? Center(child: Text(l10n.settlementNoHoldings,
                        style: TextStyle(color: context.textSecondary)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        children: [
                          // ── 합산 결과 카드 ──
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              IntrinsicHeight(
                                child: Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(l10n.settlementReturn,
                                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_returnRate! >= 0 ? '+' : ''}${_returnRate!.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w700,
                                        color: _returnRate! >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor,
                                      ),
                                    ),
                                  ])),
                                  VerticalDivider(color: context.borderColor, width: 24, thickness: 1),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text(isKo ? '기간 손익' : 'Period P&L',
                                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_absoluteReturn! >= 0 ? '+' : ''}${_fmt(_absoluteReturn!)}',
                                      style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w700,
                                        color: _absoluteReturn! >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor,
                                      ),
                                    ),
                                  ])),
                                ]),
                              ),
                              if (_netCashFlow.abs() > 0) ...[
                                const SizedBox(height: 6),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(
                                    _netCashFlow >= 0
                                        ? (isKo ? '추가 투자금' : 'Capital Added')
                                        : (isKo ? '자본 회수' : 'Capital Withdrawn'),
                                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                                  ),
                                  Text(
                                    '${_netCashFlow >= 0 ? '+' : ''}${_fmt(_netCashFlow)}',
                                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                                  ),
                                ]),
                              ],
                              Divider(height: 20, color: context.borderColor),
                              Row(children: [
                                Expanded(child: _valueBox(context, l10n.settlementStartValue, _fmt(_startValue!))),
                                const SizedBox(width: 10),
                                Expanded(child: _valueBox(context, l10n.settlementEndValue, _fmt(_endValue!))),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Text(isKo ? '* 모든 포트폴리오 합산, KRW 기준' : '* All portfolios combined, KRW basis',
                              style: TextStyle(fontSize: 11, color: context.textHint)),
                          // ── 기여도 ──
                          if (_portfolioResults.isNotEmpty && (_startValue ?? 0) > 0) ...[
                            const SizedBox(height: 16),
                            Text(l10n.settlementContribution,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
                            const SizedBox(height: 8),
                            ...() {
                              final totalStart = _startValue!;
                              final contributions = _portfolioResults.map((r) => {
                                ...r,
                                'contribution': (r['absoluteReturn'] as double) / totalStart * 100,
                              }).toList();
                              final sumAbs = contributions.fold(
                                  0.0, (s, r) => s + (r['contribution'] as double).abs());
                              return contributions.map((r) =>
                                  _buildPortfolioContributionRow(r, pnlColors, sumAbs)).toList();
                            }(),
                          ],
                        ],
                      ),
      ),
    ]);

    return Stack(children: [
      content,
      if (_startValue != null)
        Positioned.fill(
          child: SpeedDialFab(
            key: const ValueKey('settlement_fab'),
            items: [
              SpeedDialItem(
                icon: Icons.camera_alt_outlined,
                label: context.l10n.capture,
                onTap: _showCaptureSheet,
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildPortfolioContributionRow(Map<String, dynamic> r, PnlColorNotifier pnlColors, double sumAbsContrib) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final contribution = r['contribution'] as double;
    final isPos = contribution >= 0;
    final color = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '';
    final relWeight = sumAbsContrib > 0 ? contribution.abs() / sumAbsContrib * 100 : 0.0;
    final barRatio = sumAbsContrib > 0 ? (contribution.abs() / sumAbsContrib).clamp(0.0, 1.0) : 0.0;
    final itemReturnPct = r['returnRate'] as double;
    final itemAbsReturn = r['absoluteReturn'] as double;
    final itemReturnIsPos = itemReturnPct >= 0;

    final returnColor = itemReturnIsPos ? pnlColors.positiveColor : pnlColors.negativeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text('${r['emoji']} ${r['name']}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            RichText(text: TextSpan(children: [
              TextSpan(text: '${isKo ? '수익률' : 'Return'} ',
                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
              TextSpan(text: '${itemReturnIsPos ? '+' : ''}${itemReturnPct.toStringAsFixed(2)}%  ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: returnColor)),
              TextSpan(text: '${isKo ? '손익' : 'P&L'} ',
                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
              TextSpan(text: '${itemReturnIsPos ? '+' : ''}${_fmt(itemAbsReturn)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: returnColor)),
            ])),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
            return Stack(children: [
              Container(height: 4, width: constraints.maxWidth,
                  decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              Container(height: 4, width: constraints.maxWidth * barRatio,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            ]);
          })),
          const SizedBox(width: 8),
          Text(
            '${isKo ? '기여' : 'Contrib'} ${relWeight.toStringAsFixed(1)}% ($sign${contribution.toStringAsFixed(2)}%p)',
            style: TextStyle(fontSize: 11, color: context.textSecondary),
          ),
        ]),
      ]),
    );
  }

  Widget _valueBox(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: context.infoBoxBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.textHint)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
        ),
      ]),
    );
  }
}
