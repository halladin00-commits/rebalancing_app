import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/portfolio_form_dialog.dart';
import '../widgets/disclaimer_dialog.dart';
import '../widgets/app_settings_dialog.dart';
import '../widgets/speed_dial_fab.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_header.dart';
import 'portfolio_detail_screen.dart';

class PortfolioListScreen extends StatefulWidget {
  const PortfolioListScreen({super.key});
  @override
  State<PortfolioListScreen> createState() => PortfolioListScreenState();
}

class PortfolioListScreenState extends State<PortfolioListScreen> {
  /// MainShell의 뒤로가기 처리용 — 편집 모드면 종료 확인을 먼저 띄운다.
  bool get isEditMode => _editMode;
  Future<void> confirmExitEdit() => _showEditExitConfirm();

  bool _editMode = false;
  bool _refreshing = false;
  bool _savingMain = false;
  bool _sharingMain = false;
  final _screenshotCtrl = ScreenshotController();


  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);

  @override
  void initState() {
    super.initState();
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
        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              BrandHeader(
                titleWidget: const AppLogo(iconSize: 26),
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
              ),
              Expanded(
                child: Stack(
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
              ),
            ],
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
