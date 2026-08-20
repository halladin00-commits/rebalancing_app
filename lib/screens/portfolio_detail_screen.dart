import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../utils/rebalancer.dart';
import '../services/api_service.dart';
import '../services/excel_import_service.dart';
import '../services/review_service.dart';
import '../services/settlement_service.dart';
import '../widgets/item_form_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/item_bottom_sheet.dart';
import '../widgets/app_logo.dart';
import '../widgets/speed_dial_fab.dart';
import '../widgets/bottom_banner_ad.dart';
import 'portfolio_graph_screen.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final String portfolioId;
  /// 진입 시 열어둘 탭 (0 자산 · 1 리밸런싱 · 2 결산).
  /// 리밸런싱 탭에서 조정 제안으로 바로 들어올 때 쓴다.
  final int initialTab;

  const PortfolioDetailScreen(
      {super.key, required this.portfolioId, this.initialTab = 0});
  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _editMode = false;
  bool _refreshing = false;
  bool _savingAsset = false;
  bool _sharingAsset = false;
  bool _savingRebalancing = false;
  bool _sharingRebalancing = false;
  final _investController = TextEditingController();
  late final TabController _tabController;
  final _screenshotCtrl = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRefreshIfStale());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _investController.dispose();
    super.dispose();
  }

  // ── Formatters ──

  String _fmt(double n, String cur) {
    final prefix = n < 0 ? '-' : '';
    final abs = n.abs();
    if (cur == 'USD') return '$prefix\$${abs.toStringAsFixed(2)}';
    return '$prefix₩${abs.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtPrice(double n, String market) {
    if (market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'  ;
  }

  String _pct(double n) => '${n.toStringAsFixed(2)}%';

  String _fmtTime(int? ts) {
    if (ts == null) return context.l10n.neverUpdated;
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Auto refresh ──

  void _autoRefreshIfStale() {
    final pf = context.read<PortfolioProvider>().getPortfolio(widget.portfolioId);
    if (pf == null || (!pf.exchangeAuto && !pf.priceAuto)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final stale = pf.lastUpdated == null || (now - pf.lastUpdated!) > 5 * 60 * 1000;
    if (stale) _doRefresh(pf);
  }

  // ── Actions ──

  Future<void> _doRefresh(Portfolio pf) async {
    if (_refreshing) return;
    final l10n = context.l10n;
    if (!pf.exchangeAuto && !pf.priceAuto) {
      _showToast(l10n.toastAutoSettingRequired, Colors.orange);
      return;
    }
    setState(() => _refreshing = true);
    final provider = context.read<PortfolioProvider>();
    final errors = <String>[];
    int successCount = 0;

    if (pf.exchangeAuto) {
      final r = await ApiService.fetchExchangeRate();
      if (r.ok) { pf.exchangeRate = r.data!; successCount++; }
      else { errors.add(r.error!); }
    }
    if (pf.priceAuto) {
      for (final item in pf.items.where((i) => !i.isCash && i.ticker.isNotEmpty)) {
        final r = await ApiService.fetchStockPrice(item.ticker, item.market);
        if (r.ok) {
          item.currentPrice = r.data!.currentPrice;
          item.previousClose = r.data!.previousClose;
          successCount++;
        } else { errors.add(r.error!); }
      }
    }
    pf.lastUpdated = DateTime.now().millisecondsSinceEpoch;
    await provider.updatePortfolio(pf.id, pf);
    setState(() => _refreshing = false);

    if (errors.isEmpty) _showToast('$successCount${l10n.updateSuccess}', Colors.green);
    else if (successCount > 0) _showToast('$successCount건 성공, ${errors.length}건 실패', Colors.orange);
    else _showToast(l10n.updateFailed(errors.first), Colors.red);
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showItemForm(Portfolio pf, [PortfolioItem? item]) {
    showDialog(
      context: context,
      builder: (_) => ItemFormDialog(
        item: item, priceAuto: pf.priceAuto, currency: pf.currency,
        onSave: (newItem) {
          final p = context.read<PortfolioProvider>();
          if (item != null) p.updateItem(pf.id, newItem);
          else p.addItem(pf.id, newItem);
        },
      ),
    );
  }

  void _showSettings(Portfolio pf) {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        portfolio: pf,
        onSave: (s) {
          context.read<PortfolioProvider>().updateSettings(pf.id,
            currency: s['currency'], commissionEnabled: s['commissionEnabled'],
            commissionRate: s['commissionRate'], exchangeAuto: s['exchangeAuto'],
            exchangeRate: s['exchangeRate'], priceAuto: s['priceAuto'],
            rebalancingThreshold: s['rebalancingThreshold']);
        },
      ),
    );
  }

  // ── Asset image save/share ──

  Future<void> _saveAssetImage(Portfolio pf, RebalanceResult? rb) async {
    if (_savingAsset) return;
    final l10n = context.l10n;
    setState(() => _savingAsset = true);
    try {
      final captureHeight = 120.0 + pf.items.length * 90.0;
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildAssetCapture(pf, rb),
        pixelRatio: 3.0,
        context: context,
        targetSize: Size(380, captureHeight),
      );
      final r = await ImageGallerySaverPlus.saveImage(
        bytes,
        name: 'asset_${pf.name}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final ok = r['isSuccess'] == true || r['filePath'] != null;
      _showToast(ok ? l10n.savedToGallery : l10n.saveFailed, ok ? Colors.green : Colors.red);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _savingAsset = false);
    }
  }

  Future<void> _shareAssetImage(Portfolio pf, RebalanceResult? rb) async {
    if (_sharingAsset) return;
    final l10n = context.l10n;
    setState(() => _sharingAsset = true);
    try {
      final captureHeight = 120.0 + pf.items.length * 90.0;
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildAssetCapture(pf, rb),
        pixelRatio: 3.0,
        context: context,
        targetSize: Size(380, captureHeight),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/asset_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _sharingAsset = false);
    }
  }

  // ── Rebalancing image save/share ──

  Future<void> _saveRebalancingImage(Portfolio pf, RebalanceResult? rb) async {
    if (_savingRebalancing) return;
    final l10n = context.l10n;
    setState(() => _savingRebalancing = true);
    try {
      final captureHeight = 160.0 + pf.items.length * 80.0;
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildRebalancingCapture(pf, rb),
        pixelRatio: 3.0,
        context: context,
        targetSize: Size(380, captureHeight),
      );
      final r = await ImageGallerySaverPlus.saveImage(
        bytes,
        name: 'rebalancing_${pf.name}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final ok = r['isSuccess'] == true || r['filePath'] != null;
      _showToast(ok ? l10n.savedToGallery : l10n.saveFailed, ok ? Colors.green : Colors.red);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _savingRebalancing = false);
    }
  }

  Future<void> _shareRebalancingImage(Portfolio pf, RebalanceResult? rb) async {
    if (_sharingRebalancing) return;
    final l10n = context.l10n;
    setState(() => _sharingRebalancing = true);
    try {
      final captureHeight = 160.0 + pf.items.length * 80.0;
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildRebalancingCapture(pf, rb),
        pixelRatio: 3.0,
        context: context,
        targetSize: Size(380, captureHeight),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rebalancing_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _sharingRebalancing = false);
    }
  }

  // ── Capture widgets ──

  Widget _buildAssetCapture(Portfolio pf, RebalanceResult? rb) {
    final l10n = context.l10n;
    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${pf.emoji}  ${pf.name}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
            AppLogo(iconSize: 22, textColor: context.textPrimary),
          ]),
          const SizedBox(height: 12),
          Text(l10n.evaluationAmount,
              style: TextStyle(fontSize: 11, color: context.textHint)),
          const SizedBox(height: 2),
          Text(
            rb != null ? _fmt(rb.total - pf.additionalInvestment, pf.currency) : '—',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
          const SizedBox(height: 12),
          ...pf.items.map((item) {
            final curWeight = rb?.results.where((r) => r.id == item.id).firstOrNull?.currentWeight;
            double evalVal = 0;
            if (!item.isCash && item.currentPrice > 0) {
              evalVal = item.currentPrice * item.shares;
              if (item.market == 'US' && pf.currency == 'KRW') evalVal *= pf.exchangeRate;
              else if (item.market == 'KR' && pf.currency == 'USD') evalVal /= pf.exchangeRate;
            } else if (item.isCash) {
              evalVal = item.shares;
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _marketBadge(context, item), const SizedBox(width: 6),
                  Expanded(child: Text(item.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                      overflow: TextOverflow.ellipsis)),
                  if (curWeight != null)
                    Text(_pct(curWeight),
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ]),
                if (!item.isCash) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${_fmtPrice(item.currentPrice, item.market)} × ${item.shares.toInt()}',
                        style: TextStyle(fontSize: 11, color: context.textSecondary)),
                    const Spacer(),
                    if (evalVal > 0)
                      Text(_fmt(evalVal, pf.currency),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  ]),
                ] else ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Spacer(),
                    Text(_fmt(evalVal, pf.currency),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  ]),
                ],
              ]),
            );
          }),
          const SizedBox(height: 8),
          Text(_fmtTime(pf.lastUpdated),
              style: TextStyle(fontSize: 10, color: context.textHint)),
        ],
      ),
    );
  }

  Widget _buildRebalancingCapture(Portfolio pf, RebalanceResult? rb) {
    final l10n = context.l10n;
    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${pf.emoji}  ${pf.name}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
            AppLogo(iconSize: 22, textColor: context.textPrimary),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _infoBox(context, l10n.currentAssets,
                rb != null ? _fmt(rb.total - pf.additionalInvestment, pf.currency) : '—')),
            const SizedBox(width: 8),
            Expanded(child: _infoBox(context, l10n.rebalancingBase,
                rb != null ? _fmt(rb.total, pf.currency) : '—')),
          ]),
          const SizedBox(height: 12),
          ...pf.items.map((item) {
            final r = rb?.results.where((x) => x.id == item.id).firstOrNull;
            final delta = r?.isCash == true ? r!.cashDelta.round() : (r?.delta ?? 0);
            final isBuy = delta > 0;
            final showAction = r != null && delta != 0 && (pf.rebalancingThreshold <= 0 ||
                (r.currentWeight - item.targetWeight).abs() >= pf.rebalancingThreshold);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _marketBadge(context, item), const SizedBox(width: 6),
                  Expanded(child: Text(item.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                      overflow: TextOverflow.ellipsis)),
                  if (showAction) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBuy ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(isBuy ? l10n.buy : l10n.sell,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                    Text(item.isCash ? _fmt(delta.abs().toDouble(), pf.currency) : '${delta.abs()}${l10n.unitShares}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                  ] else if (r != null)
                    Text(l10n.hold, style: TextStyle(fontSize: 12, color: context.textHint)),
                ]),
                if (r != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(_pct(item.targetWeight),
                        style: TextStyle(color: context.brand, fontWeight: FontWeight.w600, fontSize: 11)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.arrow_forward, size: 10, color: context.textHint),
                    ),
                    Text(_pct(r.currentWeight),
                        style: TextStyle(color: context.textSecondary, fontSize: 11)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.arrow_forward, size: 10, color: context.textHint),
                    ),
                    Text(_pct(r.finalWeight),
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: context.textPrimary)),
                  ]),
                ],
              ]),
            );
          }),
          const SizedBox(height: 8),
          Text(_fmtTime(pf.lastUpdated),
              style: TextStyle(fontSize: 10, color: context.textHint)),
        ],
      ),
    );
  }

  void _showCaptureSheet(VoidCallback onSave, VoidCallback onShare) {
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
                  onPressed: () { Navigator.pop(ctx); onSave(); },
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
                  onPressed: () { Navigator.pop(ctx); onShare(); },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(l10n.shareImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brand,
                    side: BorderSide(color: context.brand),
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

  void _showDeleteConfirm(Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteItemContent(item.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              context.read<PortfolioProvider>().deleteItem(pf.id, item.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showRebalanceTransactionDialog(Portfolio pf, RebalanceResult rb) async {
    final applied = await showDialog<bool>(
      context: context,
      builder: (_) => _RebalanceTransactionDialog(pf: pf, rb: rb),
    );
    if (applied == true) {
      _investController.text = rb.cash > 0 ? rb.cash.toStringAsFixed(0) : '';
    }
  }

  void _showItemSheet(Portfolio pf, PortfolioItem item, RebalanceResult? rb) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ItemBottomSheet(item: item, portfolio: pf, rb: rb),
    );
  }

  Future<bool> _confirmExitEdit() async {
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
    return result == true;
  }

  void _openGraph(Portfolio pf) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PortfolioGraphScreen(portfolioId: pf.id)));
  }

  void _showExcelSheet(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    bool importing = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
              Text(l10n.excelImportTitle,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ExcelImportService.downloadTemplate(isKo),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text(l10n.excelDownloadTemplate),
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
                    onPressed: importing
                        ? null
                        : () async {
                            setS(() => importing = true);
                            final result = await ExcelImportService.importTransactions(
                              pf, context.read<PortfolioProvider>(), isKo,
                            );
                            setS(() => importing = false);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (result != null) _showImportResult(context, l10n, result);
                          },
                    icon: importing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_outlined, size: 16),
                    label: Text(l10n.excelImportFile),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.brand,
                      side: BorderSide(color: context.brand),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Text(l10n.excelTemplateHint,
                  style: TextStyle(fontSize: 11, color: ctx.textHint, height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportResult(BuildContext context, dynamic l10n, ImportResult result) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(l10n.excelImportDone,
            style: TextStyle(color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.addedCount > 0)
              _resultLine('✓', l10n.excelImportAdded(result.addedCount), const Color(0xFF16A34A)),
            if (result.createdItems.isNotEmpty)
              _resultLine('+', l10n.excelImportCreated(result.createdItems.length), context.brand),
            if (result.skippedRows.isNotEmpty)
              _resultLine('⚠', l10n.excelImportSkipped(result.skippedRows.length), const Color(0xFFF59E0B)),
            if (result.addedCount == 0 && result.createdItems.isEmpty)
              Text(l10n.excelImportNothingAdded,
                  style: TextStyle(color: context.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Widget _resultLine(String icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$icon  ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
        ]),
      );

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }

        if (_investController.text.isEmpty && pf.additionalInvestment != 0) {
          _investController.text = pf.additionalInvestment.toStringAsFixed(0);
        }

        final rb = Rebalancer.calculate(pf);
        final weightSum = pf.weightSum;
        final hasChanges = rb?.hasChanges ?? false;

        double totalPnl = 0, totalCost = 0, totalDayChange = 0, totalPrevValue = 0;
        for (final item in pf.items) {
          if (item.isCash || item.currentPrice <= 0) continue;
          double fx = 1.0;
          if (item.market == 'US' && pf.currency == 'KRW') fx = pf.exchangeRate;
          else if (item.market == 'KR' && pf.currency == 'USD') fx = 1.0 / pf.exchangeRate;
          if (item.avgPrice > 0) {
            totalPnl += (item.currentPrice - item.avgPrice) * item.shares * fx;
            totalCost += item.avgPrice * item.shares * fx;
          }
          if (item.previousClose > 0) {
            totalDayChange += (item.currentPrice - item.previousClose) * item.shares * fx;
            totalPrevValue += item.previousClose * item.shares * fx;
          }
        }
        final hasPnl = totalCost > 0;
        final hasDayChange = totalPrevValue > 0;

        return PopScope(
          canPop: !_editMode,
          onPopInvokedWithResult: (didPop, _) async {
            if (!didPop) {
              final ok = await _confirmExitEdit();
              if (ok) setState(() => _editMode = false);
            }
          },
          child: Scaffold(
            backgroundColor: context.scaffoldBg,
            appBar: AppBar(
              backgroundColor: context.appBarBg,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (_editMode) {
                    final ok = await _confirmExitEdit();
                    if (ok) setState(() => _editMode = false);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Text('${pf.emoji} ${pf.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              bottom: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                tabs: [
                  Tab(text: l10n.tabAssets),
                  Tab(text: l10n.tabRebalancing),
                  Tab(text: l10n.tabSettlement),
                ],
              ),
              actions: [
                if (_editMode)
                  TextButton.icon(
                    onPressed: () => setState(() => _editMode = false),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: Text(l10n.done,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  )
                else
                  IconButton(
                    icon: _refreshing
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(Icons.refresh,
                            color: (pf.exchangeAuto || pf.priceAuto) ? Colors.white : Colors.grey[600]),
                    onPressed: () => _doRefresh(pf),
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssetView(context, pf, rb,
                          hasPnl, hasDayChange,
                          totalPnl, totalCost, totalDayChange, totalPrevValue),
                      _buildRebalancingView(context, pf, rb, weightSum, hasChanges),
                      _SettlementTab(pf: pf),
                    ],
                  ),
                ),
                const BottomBannerAd(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab: 자산현황 ──

  Widget _buildAssetView(BuildContext context, Portfolio pf, RebalanceResult? rb,
      bool hasPnl, bool hasDayChange,
      double totalPnl, double totalCost, double totalDayChange, double totalPrevValue) {
    final l10n = context.l10n;
    return Stack(
      children: [
        Column(
          children: [
            if (!_editMode)
              Container(
                color: context.panelBg,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 현재 자산(좌) + 환율·시간(우)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.evaluationAmount,
                                  style: TextStyle(fontSize: 11, color: context.textHint)),
                              const SizedBox(height: 1),
                              Text(
                                rb != null
                                    ? _fmt(rb.total - pf.additionalInvestment, pf.currency)
                                    : '—',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(l10n.exchangeRateLabel(pf.exchangeRate.toStringAsFixed(0)),
                                style: TextStyle(fontSize: 11, color: context.textHint)),
                            const SizedBox(height: 1),
                            Text(_fmtTime(pf.lastUpdated),
                                style: TextStyle(fontSize: 11, color: context.textHint),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ],
                    ),
                    // 종합손익·전일대비 칩 (2열)
                    if (hasPnl || hasDayChange) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        if (hasPnl)
                          Expanded(child: _pnlChip(context, pf, l10n.profitLoss,
                              totalPnl, totalPnl / totalCost * 100)),
                        if (hasPnl && hasDayChange) const SizedBox(width: 8),
                        if (hasDayChange)
                          Expanded(child: _pnlChip(context, pf, l10n.dayChange,
                              totalDayChange, totalDayChange / totalPrevValue * 100)),
                      ]),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: pf.items.isEmpty
                  ? _buildEmptyState(context, pf)
                  : _editMode
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: pf.items.length,
                          onReorder: (o, n) {
                            if (n > o) n--;
                            final list = List<PortfolioItem>.from(pf.items);
                            final item = list.removeAt(o);
                            list.insert(n, item);
                            context.read<PortfolioProvider>().reorderItems(pf.id, list);
                          },
                          itemBuilder: (ctx, idx) => _buildEditCard(
                              context, pf, pf.items[idx],
                              key: ValueKey(pf.items[idx].id)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: pf.items.length + 1,
                          itemBuilder: (ctx, idx) {
                            if (idx == pf.items.length) return _buildSlimAddCard(context, pf);
                            return _buildAssetCard(context, pf, pf.items[idx], rb);
                          },
                        ),
            ),
          ],
        ),
        if (!_editMode)
          Positioned.fill(
            child: SpeedDialFab(
              key: const ValueKey('asset_fab'),
              items: [
                SpeedDialItem(
                  icon: Icons.edit_outlined,
                  label: l10n.labelEdit,
                  onTap: () => setState(() => _editMode = true),
                ),
                SpeedDialItem(
                  icon: Icons.settings_outlined,
                  label: l10n.labelSettings,
                  onTap: () => _showSettings(pf),
                ),
                SpeedDialItem(
                  icon: Icons.camera_alt_outlined,
                  label: l10n.capture,
                  onTap: () => _showCaptureSheet(
                    () => _saveAssetImage(pf, rb),
                    () => _shareAssetImage(pf, rb),
                  ),
                ),
                SpeedDialItem(
                  icon: Icons.pie_chart_outline,
                  label: l10n.labelGraph,
                  iconColor: context.brandOnLight,
                  bgColor: context.brand,
                  onTap: () => _openGraph(pf),
                ),
                SpeedDialItem(
                  icon: Icons.table_chart_outlined,
                  label: l10n.excelImportTitle,
                  onTap: () => _showExcelSheet(context, pf),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Tab: 리밸런싱 ──

  Widget _buildRebalancingView(BuildContext context, Portfolio pf, RebalanceResult? rb,
      double weightSum, bool hasChanges) {
    final l10n = context.l10n;
    final commOn = pf.commissionEnabled;
    final curSym = pf.currency == 'USD' ? '\$' : '₩';
    return Stack(
      children: [
        Column(
          children: [
            if (!_editMode)
              Container(
                color: context.panelBg,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.additionalInvestment,
                        style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _investController,
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        prefixText: '$curSym ',
                        prefixStyle: TextStyle(color: context.textPrimary),
                        hintText: l10n.additionalInvestmentHint,
                        filled: true,
                        fillColor: context.fieldFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v) ?? 0;
                        context.read<PortfolioProvider>()
                            .setAdditionalInvestment(pf.id, parsed);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      _infoBox(context, l10n.currentAssets,
                          rb != null ? _fmt(rb.total - pf.additionalInvestment, pf.currency) : '—'),
                      const SizedBox(width: 8),
                      _infoBox(context, l10n.rebalancingBase,
                          rb != null ? _fmt(rb.total, pf.currency) : '—'),
                      const SizedBox(width: 8),
                      _infoBox(context, l10n.remainingCash,
                          rb != null ? _fmt(rb.cash, pf.currency) : '—', highlight: true),
                    ]),
                    if (rb != null && commOn && rb.commission > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(l10n.estimatedFee(_fmt(rb.commission, pf.currency)),
                            style: TextStyle(fontSize: 12, color: context.textHint)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.exchangeRateLabel(pf.exchangeRate.toStringAsFixed(0)),
                              style: TextStyle(fontSize: 12, color: context.textHint)),
                          Text(_fmtTime(pf.lastUpdated),
                              style: TextStyle(fontSize: 12, color: context.textHint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (pf.items.isNotEmpty && (weightSum - 100).abs() > 0.01)
              Container(
                width: double.infinity,
                color: context.warningBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Text('⚠️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(l10n.weightWarning(_pct(weightSum)),
                      style: TextStyle(fontSize: 13, color: context.warningText)),
                ]),
              ),
            Expanded(
              child: pf.items.isEmpty
                  ? _buildEmptyState(context, pf)
                  : _editMode
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: pf.items.length,
                          onReorder: (o, n) {
                            if (n > o) n--;
                            final list = List<PortfolioItem>.from(pf.items);
                            final item = list.removeAt(o);
                            list.insert(n, item);
                            context.read<PortfolioProvider>().reorderItems(pf.id, list);
                          },
                          itemBuilder: (ctx, idx) => _buildEditCard(
                              context, pf, pf.items[idx],
                              key: ValueKey(pf.items[idx].id)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: pf.items.length + 1,
                          itemBuilder: (ctx, idx) {
                            if (idx == pf.items.length) return _buildSlimAddCard(context, pf);
                            return _buildRebalancingCard(context, pf, pf.items[idx], rb);
                          },
                        ),
            ),
          ],
        ),
        if (!_editMode)
          Positioned.fill(
            child: SpeedDialFab(
              key: const ValueKey('rebalancing_fab'),
              items: [
                SpeedDialItem(
                  icon: Icons.edit_outlined,
                  label: l10n.labelEdit,
                  onTap: () => setState(() => _editMode = true),
                ),
                SpeedDialItem(
                  icon: Icons.settings_outlined,
                  label: l10n.labelSettings,
                  onTap: () => _showSettings(pf),
                ),
                SpeedDialItem(
                  icon: Icons.camera_alt_outlined,
                  label: l10n.capture,
                  onTap: () => _showCaptureSheet(
                    () => _saveRebalancingImage(pf, rb),
                    () => _shareRebalancingImage(pf, rb),
                  ),
                ),
                SpeedDialItem(
                  icon: Icons.pie_chart_outline,
                  label: l10n.labelGraph,
                  iconColor: context.brandOnLight,
                  bgColor: context.brand,
                  onTap: () => _openGraph(pf),
                ),
                if (rb != null && hasChanges)
                  SpeedDialItem(
                    icon: Icons.check_circle_outline,
                    label: l10n.labelRebalanceApply,
                    iconColor: const Color(0xFF4ADE80),
                    bgColor: const Color(0xFF052E16),
                    onTap: () => _showRebalanceTransactionDialog(pf, rb),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Cards ──

  Widget _buildAssetCard(BuildContext context, Portfolio pf, PortfolioItem item,
      RebalanceResult? rb) {
    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemSheet(pf, item, rb),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(children: [
            // Row1: badge + 종목명/ticker
            Row(children: [
              _marketBadge(context, item), const SizedBox(width: 6),
              Expanded(child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  children: [
                    TextSpan(text: item.name),
                    if (item.ticker.isNotEmpty)
                      TextSpan(text: ' ${item.ticker}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: context.textHint)),
                  ],
                ),
              )),
            ]),
            // Row2: 현재가×수량(좌) + 평가금액·현재비중(우)
            if (!item.isCash) ...[
              const SizedBox(height: 6),
              Row(children: [
                Text('${_fmtPrice(item.currentPrice, item.market)} × ${item.shares.toInt()}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
                const Spacer(),
                Builder(builder: (ctx) {
                  double evalVal = item.currentPrice * item.shares;
                  if (item.market == 'US' && pf.currency == 'KRW') {
                    evalVal *= pf.exchangeRate;
                  } else if (item.market == 'KR' && pf.currency == 'USD') {
                    evalVal /= pf.exchangeRate;
                  }
                  final curWeight = rb?.results.where((r) => r.id == item.id).firstOrNull?.currentWeight;
                  return Row(children: [
                    if (evalVal > 0)
                      Text(_fmt(evalVal, pf.currency),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
                    if (evalVal > 0 && curWeight != null) ...[
                      const SizedBox(width: 4),
                      Text('(${_pct(curWeight)})',
                          style: TextStyle(fontSize: 11, color: context.textHint)),
                    ],
                  ]);
                }),
              ]),
            ] else ...[
              const SizedBox(height: 6),
              Row(children: [
                const Spacer(),
                Text(_fmt(item.shares, pf.currency),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
              ]),
            ],
            if (!item.isCash && (item.avgPrice > 0 || item.previousClose > 0)) ...[
              const SizedBox(height: 6),
              _buildPnlRow(context, pf, item),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildRebalancingCard(BuildContext context, Portfolio pf, PortfolioItem item,
      RebalanceResult? rb) {
    final l10n = context.l10n;
    final r = rb?.results.where((x) => x.id == item.id).firstOrNull;
    final delta = r?.isCash == true ? r!.cashDelta.round() : (r?.delta ?? 0);
    final isBuy = delta > 0;

    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemSheet(pf, item, rb),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(children: [
            Row(children: [
              _marketBadge(context, item), const SizedBox(width: 6),
              Expanded(child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  children: [
                    TextSpan(text: item.name),
                    if (item.ticker.isNotEmpty)
                      TextSpan(text: ' ${item.ticker}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: context.textHint)),
                  ],
                ),
              )),
              Text(item.isCash ? _fmt(item.shares, pf.currency)
                      : '${_fmtPrice(item.currentPrice, item.market)} × ${item.shares.toInt()}',
                  style: TextStyle(fontSize: 13, color: context.textSecondary)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_pct(item.targetWeight),
                      style: TextStyle(color: context.brand, fontWeight: FontWeight.w600, fontSize: 12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Icons.arrow_forward, size: 10, color: context.textHint),
                  ),
                  Text(r != null ? _pct(r.currentWeight) : '—',
                      style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Icons.arrow_forward, size: 10, color: context.textHint),
                  ),
                  Text(r != null ? _pct(r.finalWeight) : '—',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
                          color: r != null ? context.textPrimary : context.textHint)),
                ],
              ),
              const Spacer(),
              if (r != null && delta != 0 && (pf.rebalancingThreshold <= 0 ||
                  (r.currentWeight - item.targetWeight).abs() >= pf.rebalancingThreshold)) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: isBuy ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(isBuy ? l10n.buy : l10n.sell,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 4),
                Text(item.isCash ? _fmt(delta.abs().toDouble(), pf.currency) : '${delta.abs()}${l10n.unitShares}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
              ],
              if (r != null && (delta == 0 || (pf.rebalancingThreshold > 0 &&
                  (r.currentWeight - item.targetWeight).abs() < pf.rebalancingThreshold)))
                Text(l10n.hold, style: TextStyle(fontSize: 12, color: context.textHint)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildEditCard(BuildContext context, Portfolio pf, PortfolioItem item, {Key? key}) {
    return Card(
      key: key,
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _marketBadge(context, item), const SizedBox(width: 6),
              Expanded(child: Text(item.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Text(item.isCash ? _fmt(item.shares, pf.currency)
                    : '${_fmtPrice(item.currentPrice, item.market)} × ${item.shares.toInt()}',
                style: TextStyle(fontSize: 12, color: context.textSecondary)),
          ])),
          IconButton(
            onPressed: () => _showItemForm(pf, item),
            icon: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: context.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: context.brand.withValues(alpha: 0.4))),
              child: Icon(Icons.edit_outlined, color: context.brand, size: 16),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () => _showDeleteConfirm(pf, item),
            icon: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4))),
              child: const Icon(Icons.remove, color: Colors.red, size: 18),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ]),
      ),
    );
  }

  // ── Shared UI helpers ──

  Widget _buildEmptyState(BuildContext context, Portfolio pf) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [_buildSlimAddCard(context, pf)],
    );
  }

  Widget _infoBox(BuildContext context, String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlight ? context.highlightBg : context.infoBoxBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.textHint)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: highlight ? context.highlightText : context.textPrimary)),
          ),
        ]),
      ),
    );
  }

  Widget _buildSlimAddCard(BuildContext context, Portfolio pf) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showItemForm(pf),
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
              width: 20, height: 20,
              decoration: BoxDecoration(color: context.brand, borderRadius: BorderRadius.circular(5)),
              child: const Icon(Icons.add, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text(context.l10n.addStock,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.brand)),
          ]),
        ),
      ),
    );
  }

  Widget _buildPnlRow(BuildContext context, Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    final rows = <Widget>[];

    if (item.avgPrice > 0 && item.currentPrice > 0) {
      double pnl = (item.currentPrice - item.avgPrice) * item.shares;
      if (item.market == 'US' && pf.currency == 'KRW') pnl *= pf.exchangeRate;
      if (item.market == 'KR' && pf.currency == 'USD') pnl /= pf.exchangeRate;
      final rate = (item.currentPrice - item.avgPrice) / item.avgPrice * 100;
      final isProfit = pnl >= 0;
      final pnlColors = context.read<PnlColorNotifier>();
      final color = isProfit ? pnlColors.positiveColor : pnlColors.negativeColor;
      final sign = isProfit ? '+' : '';
      rows.add(Row(children: [
        Text(l10n.profitLoss, style: TextStyle(fontSize: 11, color: context.textHint)),
        const Spacer(),
        Text('$sign${_fmt(pnl, pf.currency)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 4),
        Text('($sign${rate.toStringAsFixed(2)}%)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]));
    }

    if (item.previousClose > 0 && item.currentPrice > 0) {
      double dc = (item.currentPrice - item.previousClose) * item.shares;
      if (item.market == 'US' && pf.currency == 'KRW') dc *= pf.exchangeRate;
      if (item.market == 'KR' && pf.currency == 'USD') dc /= pf.exchangeRate;
      final rate = (item.currentPrice - item.previousClose) / item.previousClose * 100;
      final isUp = dc >= 0;
      final pnlColors2 = context.read<PnlColorNotifier>();
      final color = isUp ? pnlColors2.positiveColor : pnlColors2.negativeColor;
      final sign = isUp ? '+' : '';
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 3));
      rows.add(Row(children: [
        Text(l10n.dayChange, style: TextStyle(fontSize: 11, color: context.textHint)),
        const Spacer(),
        Text('$sign${_fmt(dc, pf.currency)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 4),
        Text('($sign${rate.toStringAsFixed(2)}%)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _pnlChip(BuildContext context, Portfolio pf, String label, double amount, double rate) {
    final isPos = amount >= 0;
    final pnlColors = context.read<PnlColorNotifier>();
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
              child: Text('$sign${rate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$sign${_fmt(amount, pf.currency)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _marketBadge(BuildContext context, PortfolioItem item) {
    if (item.isCash) return _badge(context, context.l10n.cash, const Color(0xFF65A30D));
    if (item.market == 'US') return _badge(context, 'US', const Color(0xFF7C3AED));
    return _badge(context, 'KR', const Color(0xFF0369A1));
  }

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── 결산 탭 ──

class _SettlementTab extends StatefulWidget {
  final Portfolio pf;
  const _SettlementTab({required this.pf});
  @override
  State<_SettlementTab> createState() => _SettlementTabState();
}

class _SettlementTabState extends State<_SettlementTab> {
  SettlementPeriod _period = SettlementPeriod.monthly;
  late int _year;
  late int _sub;
  bool _loading = false;
  bool _noHoldings = false;
  bool _saving = false;
  bool _sharing = false;
  SettlementResult? _result;
  final ScreenshotController _screenshotCtrl = ScreenshotController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _sub = SettlementService.currentSub(_period);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _noHoldings = false; _result = null; });
    final result = await SettlementService.calculate(
        widget.pf, _period, PeriodKey(_year, _sub));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      _noHoldings = result == null;
    });
  }

  void _onPeriodChanged(SettlementPeriod p) {
    if (_period == p) return;
    final now = DateTime.now();
    setState(() {
      _period = p;
      _year = now.year;
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
    if (widget.pf.currency == 'USD') return '$prefix\$${abs.toStringAsFixed(2)}';
    return '$prefix₩${abs.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  Future<void> _saveSettlementImage(BuildContext context, dynamic l10n, SettlementResult result) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final pnlColors = context.read<PnlColorNotifier>();
      final captureHeight = 450.0 + result.contributions.length * 70.0;
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildSettlementCapture(context, l10n, result, pnlColors),
        pixelRatio: 3.0,
        context: context,
        targetSize: Size(380, captureHeight),
      );
      final r = await ImageGallerySaverPlus.saveImage(
        bytes,
        name: 'settlement_${widget.pf.name}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final ok = r['isSuccess'] == true || r['filePath'] != null;
      _showToast(ok ? l10n.savedToGallery : l10n.saveFailed, ok ? Colors.green : Colors.red);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareSettlementImage(BuildContext context, dynamic l10n, SettlementResult result) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final pnlColors = context.read<PnlColorNotifier>();
      final captureHeight = 450.0 + result.contributions.length * 70.0;
      final bytes = await _screenshotCtrl.captureFromWidget(
        _buildSettlementCapture(context, l10n, result, pnlColors),
        pixelRatio: 3.0,
        context: context,
        targetSize: Size(380, captureHeight),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/settlement_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildSettlementCapture(BuildContext context, dynamic l10n, SettlementResult result, PnlColorNotifier pnlColors) {
    final isPos = result.absoluteReturn >= 0;
    final returnColor = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '';
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final sumAbsContrib = result.contributions.fold(0.0, (s, c) => s + c.contribution.abs());

    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${widget.pf.emoji}  ${widget.pf.name}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
            AppLogo(iconSize: 14, textColor: context.textHint),
          ]),
          const SizedBox(height: 8),
          Text(l10n.settlementPeriodRange(_fmtDate(result.periodStart), _fmtDate(result.periodEnd)),
              style: TextStyle(fontSize: 11, color: context.textHint)),
          const SizedBox(height: 12),
          // 요약 카드
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _captureValueBox(context, l10n.settlementStartValue, _fmt(result.startValue))),
                const SizedBox(width: 10),
                Expanded(child: _captureValueBox(context, l10n.settlementEndValue, _fmt(result.endValue))),
              ]),
              if (result.netCashFlow.abs() > 0) ...[
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    result.netCashFlow >= 0
                        ? (isKo ? '추가 투자금' : 'Capital Added')
                        : (isKo ? '자본 회수' : 'Capital Withdrawn'),
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                  Text('${result.netCashFlow >= 0 ? '+' : ''}${_fmt(result.netCashFlow)}',
                      style: TextStyle(fontSize: 13, color: context.textSecondary)),
                ]),
              ],
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(l10n.settlementReturn, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$sign${result.returnRate.toStringAsFixed(2)}%',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: returnColor)),
                  Text('$sign${_fmt(result.absoluteReturn)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: returnColor)),
                ]),
              ]),
            ]),
          ),
          // 기여도
          if (result.contributions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(l10n.settlementContribution,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary)),
            const SizedBox(height: 8),
            ...result.contributions.map((c) => _buildContributionRow(context, c, pnlColors, sumAbsContrib)),
          ],
        ],
      ),
    );
  }

  Widget _captureValueBox(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.infoBoxBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
      ]),
    );
  }

  void _showCaptureSheet(VoidCallback onSave, VoidCallback onShare) {
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
                  onPressed: () { Navigator.pop(ctx); onSave(); },
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
                  onPressed: () { Navigator.pop(ctx); onShare(); },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(l10n.shareImage),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brand,
                    side: BorderSide(color: context.brand),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        Column(
          children: [
            _buildPeriodSelector(context, l10n),
            _buildKeyPicker(context, l10n),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _noHoldings
                      ? _buildNoHoldings(context, l10n)
                      : _result != null
                          ? _buildResult(context, l10n, _result!)
                          : const SizedBox.shrink(),
            ),
          ],
        ),
        if (_result != null)
          Positioned.fill(
            child: SpeedDialFab(
              key: const ValueKey('settlement_fab'),
              items: [
                SpeedDialItem(
                  icon: Icons.camera_alt_outlined,
                  label: l10n.capture,
                  onTap: () => _showCaptureSheet(
                    () => _saveSettlementImage(context, l10n, _result!),
                    () => _shareSettlementImage(context, l10n, _result!),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPeriodSelector(BuildContext context, dynamic l10n) {
    return Padding(
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
    );
  }

  Widget _buildKeyPicker(BuildContext context, dynamic l10n) {
    final now = DateTime.now();
    final earliestYear = SettlementService.earliestYear(widget.pf);
    final years = List.generate(now.year - earliestYear + 1,
        (i) => earliestYear + i).reversed.toList();
    final maxSub = SettlementService.maxSub(_period, _year);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(children: [
        // 연도 드롭다운
        _dropdown<int>(
          context,
          value: _year,
          items: years,
          label: (y) => l10n.settlementYearLabel(y),
          onChanged: _onYearChanged,
        ),
        if (_period != SettlementPeriod.yearly) ...[
          const SizedBox(width: 8),
          // 주차/월/분기 드롭다운
          _dropdown<int>(
            context,
            value: _sub.clamp(1, maxSub),
            items: List.generate(maxSub, (i) => i + 1),
            label: (s) {
              switch (_period) {
                case SettlementPeriod.weekly:    return l10n.settlementWeekNum(s);
                case SettlementPeriod.monthly:   return l10n.settlementMonthNum(s);
                case SettlementPeriod.quarterly: return l10n.settlementQuarterNum(s);
                case SettlementPeriod.yearly:    return '';
              }
            },
            onChanged: _onSubChanged,
          ),
        ],
        if (_result != null && _result!.isCurrentPeriod) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(l10n.settlementCurrentPeriod,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: context.brand)),
          ),
        ],
      ]),
    );
  }

  Widget _dropdown<T>(BuildContext context,
      {required T value, required List<T> items, required String Function(T) label,
      required void Function(T) onChanged}) {
    return DropdownButton<T>(
      value: items.contains(value) ? value : items.first,
      isDense: true,
      underline: Container(height: 1, color: context.borderColor),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
      dropdownColor: context.cardBg,
      items: items.map((v) => DropdownMenuItem(
        value: v,
        child: Text(label(v)),
      )).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }

  Widget _buildNoHoldings(BuildContext context, dynamic l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: context.textHint),
          const SizedBox(height: 12),
          Text(l10n.settlementNoHoldings,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildResult(BuildContext context, dynamic l10n, SettlementResult result) {
    final isPos = result.absoluteReturn >= 0;
    final pnlColors = context.watch<PnlColorNotifier>();
    final returnColor = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '';
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        // 기간 날짜 표시
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.settlementPeriodRange(
                _fmtDate(result.periodStart), _fmtDate(result.periodEnd)),
            style: TextStyle(fontSize: 11, color: context.textHint),
          ),
        ),

        // 요약 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.settlementReturn,
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    const SizedBox(height: 4),
                    Text('$sign${result.returnRate.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: returnColor)),
                  ])),
                  VerticalDivider(color: context.borderColor, width: 24, thickness: 1),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(isKo ? '기간 손익' : 'Period P&L',
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    const SizedBox(height: 4),
                    Text('$sign${_fmt(result.absoluteReturn)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: returnColor)),
                  ])),
                ]),
              ),
              if (result.netCashFlow.abs() > 0) ...[
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    result.netCashFlow >= 0
                        ? (isKo ? '추가 투자금' : 'Capital Added')
                        : (isKo ? '자본 회수' : 'Capital Withdrawn'),
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                  Text(
                    '${result.netCashFlow >= 0 ? '+' : ''}${_fmt(result.netCashFlow)}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                ]),
              ],
              Divider(height: 20, color: context.borderColor),
              Row(children: [
                Expanded(child: _valueBox(context, l10n.settlementStartValue, _fmt(result.startValue))),
                const SizedBox(width: 10),
                Expanded(child: _valueBox(context, l10n.settlementEndValue, _fmt(result.endValue))),
              ]),
            ],
          ),
        ),

        if (result.contributions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.settlementContribution,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary)),
          const SizedBox(height: 8),
          ...() {
            final sumAbsContrib = result.contributions.fold(
                0.0, (s, c) => s + c.contribution.abs());
            return result.contributions
                .map((c) => _buildContributionRow(context, c, pnlColors, sumAbsContrib))
                .toList();
          }(),
        ],
      ],
    );
  }

  Widget _valueBox(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: context.infoBoxBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.textHint)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionRow(BuildContext context,
      SettlementItemContribution c, PnlColorNotifier pnlColors,
      double sumAbsContrib) {
    final isPos = c.contribution >= 0;
    final color = isPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final sign = isPos ? '+' : '';
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final relWeight = sumAbsContrib > 0
        ? c.contribution.abs() / sumAbsContrib * 100
        : 0.0;
    final barRatio = sumAbsContrib > 0
        ? (c.contribution.abs() / sumAbsContrib).clamp(0.0, 1.0)
        : 0.0;

    final itemIsPos = c.itemReturnPct >= 0;
    final returnColor = itemIsPos ? pnlColors.positiveColor : pnlColors.negativeColor;
    final returnSign = itemIsPos ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(c.name,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${isKo ? '수익률' : 'Return'} ',
                    style: TextStyle(fontSize: 11, color: context.textSecondary)),
                TextSpan(text: '$returnSign${c.itemReturnPct.toStringAsFixed(2)}%  ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: returnColor)),
                TextSpan(text: '${isKo ? '손익' : 'P&L'} ',
                    style: TextStyle(fontSize: 11, color: context.textSecondary)),
                TextSpan(text: '$returnSign${_fmt(c.itemAbsoluteReturn)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: returnColor)),
              ])),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
              return Stack(children: [
                Container(
                  height: 4, width: constraints.maxWidth,
                  decoration: BoxDecoration(
                      color: context.borderColor, borderRadius: BorderRadius.circular(2)),
                ),
                Container(
                  height: 4, width: constraints.maxWidth * barRatio,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ]);
            })),
            const SizedBox(width: 8),
            Text(
              '${isKo ? '기여' : 'Contrib'} ${relWeight.toStringAsFixed(1)}% ($sign${c.contribution.toStringAsFixed(2)}%p)',
              style: TextStyle(fontSize: 11, color: context.textSecondary),
            ),
          ]),
        ],
      ),
    );
  }
}

class _RebalanceTransactionDialog extends StatefulWidget {
  final Portfolio pf;
  final RebalanceResult rb;

  const _RebalanceTransactionDialog({required this.pf, required this.rb});

  @override
  State<_RebalanceTransactionDialog> createState() => _RebalanceTransactionDialogState();
}

class _RebalanceTransactionDialogState extends State<_RebalanceTransactionDialog> {
  late final List<RebalanceItemResult> _tradeable;
  late final Map<String, TextEditingController> _qtyCtrl;
  late final Map<String, TextEditingController> _priceCtrl;
  late final Map<String, bool> _isBuyMap;

  @override
  void initState() {
    super.initState();
    _tradeable = widget.rb.results.where((r) => !r.isCash && r.delta != 0).toList();
    _qtyCtrl = {
      for (final r in _tradeable)
        r.id: TextEditingController(text: r.delta.abs().toString())
    };
    _priceCtrl = {
      for (final r in _tradeable)
        r.id: TextEditingController(text: _priceStr(
          widget.pf.items.firstWhere((i) => i.id == r.id).currentPrice,
        ))
    };
    _isBuyMap = {
      for (final r in _tradeable) r.id: r.delta > 0
    };
  }

  @override
  void dispose() {
    for (final c in _qtyCtrl.values) c.dispose();
    for (final c in _priceCtrl.values) c.dispose();
    super.dispose();
  }

  String _priceStr(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(l10n.rebalanceTransactionTitle,
          style: TextStyle(color: context.textPrimary)),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(l10n.rebalanceTransactionDesc,
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _tradeable.map((r) {
                    final item = widget.pf.items.firstWhere((i) => i.id == r.id);
                    final isBuy = _isBuyMap[r.id]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.infoBoxBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor),
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _segmentChip(r.id, isBuy),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(item.name,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimary),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: _field(l10n.transactionQty, _qtyCtrl[r.id]!, isInt: true)),
                              const SizedBox(width: 8),
                              Expanded(child: _field(l10n.transactionPrice, _priceCtrl[r.id]!)),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel)),
        TextButton(
            onPressed: _submit,
            child: Text(l10n.done)),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctl, {bool isInt = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
      const SizedBox(height: 3),
      TextField(
        controller: ctl,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 13, color: context.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: context.fieldFill,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: context.borderColor)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _segmentChip(String id, bool isBuy) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentBtn(id, true, isBuy, l10n.transactionBuy, context.brand),
          Container(width: 1, color: context.borderColor),
          _segmentBtn(id, false, isBuy, l10n.transactionSell, Colors.red),
        ],
      ),
    );
  }

  Widget _segmentBtn(String id, bool targetBuy, bool currentBuy, String label, Color color) {
    final selected = targetBuy == currentBuy;
    return GestureDetector(
      onTap: () => setState(() => _isBuyMap[id] = targetBuy),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: targetBuy
              ? const BorderRadius.horizontal(left: Radius.circular(3))
              : const BorderRadius.horizontal(right: Radius.circular(3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? color : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final provider = context.read<PortfolioProvider>();
    final now = DateTime.now();

    for (var i = 0; i < _tradeable.length; i++) {
      final r = _tradeable[i];
      final qty = double.tryParse(_qtyCtrl[r.id]!.text) ?? 0;
      final price = double.tryParse(_priceCtrl[r.id]!.text) ?? 0;
      if (qty <= 0 || price <= 0) continue;
      final tx = StockTransaction(
        id: '${now.millisecondsSinceEpoch}_$i',
        date: now,
        quantity: qty * (_isBuyMap[r.id]! ? 1.0 : -1.0),
        price: price,
      );
      await provider.upsertTransaction(widget.pf.id, r.id, tx);
    }

    final cashItems = widget.rb.results
        .where((r) => r.isCash)
        .map((r) => {'id': r.id, 'newShares': r.newCashAmount})
        .toList();
    await provider.updateCashAndResidual(widget.pf.id, cashItems, widget.rb.cash);

    if (!mounted) return;
    ReviewService.onRebalancingApplied();
    Navigator.pop(context, true);
  }
}
