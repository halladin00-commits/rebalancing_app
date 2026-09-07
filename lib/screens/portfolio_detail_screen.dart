import 'dart:io';
import 'package:flutter/material.dart';

import '../utils/josa.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../main.dart';
import '../services/undo_service.dart';
import '../utils/money_format.dart';
import '../models/portfolio.dart';
import '../utils/rebalancer.dart';
import '../utils/share_format.dart';
import '../services/api_service.dart';
import '../services/excel_import_service.dart';
import '../widgets/portfolio_actions.dart';
import 'transaction_import_screen.dart';
import 'item_form_screen.dart';
import 'portfolio_settings_screen.dart';
import 'item_detail_screen.dart';
import 'item_search_screen.dart';
import 'transaction_history_screen.dart';
import 'target_weights_screen.dart';
import '../widgets/app_logo.dart';
import '../services/ad_service.dart';
import '../widgets/bottom_banner_ad.dart';
import '../widgets/brand_header.dart';
import '../widgets/cash_edit_sheet.dart';
import '../widgets/collapsing_header.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/list_card.dart';
import '../widgets/sparkline_panel.dart';
import '../services/asset_history_service.dart';
import '../theme/design_system.dart';
import 'portfolio_graph_screen.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final String portfolioId;
  const PortfolioDetailScreen({super.key, required this.portfolioId});
  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen> {
  bool _editMode = false;

  /// 되돌릴 수 있는 마지막 묶음. 없으면 메뉴에 항목이 안 나온다.
  UndoBatch? _undo;
  bool _refreshing = false;
  bool _savingAsset = false;
  bool _sharingAsset = false;
  final _investController = TextEditingController();
  final _screenshotCtrl = ScreenshotController();

  SparkPeriod _sparkPeriod = SparkPeriod.month;
  List<AssetPoint> _history = [];

  Future<void> _loadHistory() async {
    final h = await AssetHistoryService.loadPortfolio(widget.portfolioId,
        days: _sparkPeriod.days);
    if (!mounted) return;
    setState(() => _history = h);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRefreshIfStale());
    _loadHistory();
  }

  @override
  void dispose() {
    _investController.dispose();
    super.dispose();
  }

  // ── Formatters ──

  String _pct(double n) => '${n.toStringAsFixed(2)}%';

  String _fmtTime(int? ts) {
    if (ts == null) return context.l10n.neverUpdated;
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// 헤더 한 줄에 들어갈 짧은 형태 (`08.21 12:40`).
  String _fmtTimeShort(int? ts) {
    if (ts == null) return context.l10n.neverUpdated;
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Auto refresh ──

  void _autoRefreshIfStale() {
    final pf =
        context.read<PortfolioProvider>().getPortfolio(widget.portfolioId);
    if (pf == null || (!pf.exchangeAuto && !pf.priceAuto)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final stale =
        pf.lastUpdated == null || (now - pf.lastUpdated!) > 5 * 60 * 1000;
    if (stale) _doRefresh(pf);
  }

  // ── Actions ──

  Future<void> _doRefresh(Portfolio pf) async {
    if (_refreshing) return;
    final l10n = context.l10n;
    if (!pf.exchangeAuto && !pf.priceAuto) {
      _showToast(l10n.toastAutoSettingRequired, danger: true);
      return;
    }
    setState(() => _refreshing = true);
    final provider = context.read<PortfolioProvider>();
    final errors = <String>[];
    int successCount = 0;

    if (pf.exchangeAuto) {
      final r = await ApiService.fetchExchangeRate();
      if (r.ok) {
        pf.exchangeRate = r.data!;
        successCount++;
      } else {
        errors.add(r.error!);
      }
    }
    if (pf.priceAuto) {
      for (final item
          in pf.items.where((i) => !i.isCash && i.ticker.isNotEmpty)) {
        final r = await ApiService.fetchStockPrice(item.ticker, item.market);
        if (r.ok) {
          item.currentPrice = r.data!.currentPrice;
          item.previousClose = r.data!.previousClose;
          successCount++;
        } else {
          errors.add(r.error!);
        }
      }
    }
    pf.lastUpdated = DateTime.now().millisecondsSinceEpoch;
    await provider.updatePortfolio(pf.id, pf);
    setState(() => _refreshing = false);

    if (errors.isEmpty) {
      _showToast(l10n.updateSuccessCount(successCount));
    }
    // 일부라도 실패하면 마지막 값이 유지된다는 걸 알려야 한다
    else if (successCount > 0) {
      _showToast(l10n.refreshPartialFail(errors.length), danger: true);
    } else {
      _showToast(l10n.updateFailed(errors.first), danger: true);
    }
  }

  /// [danger]면 배경을 주의색으로 — 실패를 성공과 같은 모양으로 띄우면
  /// 사용자가 못 알아챈다.
  void _showToast(String msg, {bool danger = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: danger ? context.warningText : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showItemForm(Portfolio pf, [PortfolioItem? item]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(
          item: item,
          otherWeights: pf.weighedItems
              .where((i) => i.id != item?.id)
              .fold<double>(0, (s, i) => s + i.targetWeight),
          priceAuto: pf.priceAuto,
          currency: pf.currency,
          onSave: (newItem) {
            final p = context.read<PortfolioProvider>();
            if (item != null) {
              p.updateItem(pf.id, newItem);
            } else {
              p.addItem(pf.id, newItem);
            }
          },
        ),
      ),
    );
  }

  void _showSettings(Portfolio pf) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortfolioSettingsScreen(
          portfolio: pf,
          onSave: (s) {
            context.read<PortfolioProvider>().updateSettings(pf.id,
                currency: s['currency'],
                commissionEnabled: s['commissionEnabled'],
                commissionRate: s['commissionRate'],
                exchangeAuto: s['exchangeAuto'],
                exchangeRate: s['exchangeRate'],
                priceAuto: s['priceAuto']);
          },
        ),
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
      _showToast(ok ? l10n.savedToGallery : l10n.saveFailed, danger: !ok);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), danger: true);
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
      final file = File(
          '${dir.path}/asset_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), danger: true);
    } finally {
      if (mounted) setState(() => _sharingAsset = false);
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
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
            AppLogo(iconSize: 22, textColor: context.textPrimary),
          ]),
          const SizedBox(height: 12),
          Text(l10n.evaluationAmount,
              style: TextStyle(fontSize: 11, color: context.textHint)),
          const SizedBox(height: 2),
          Text(
            rb != null
                ? fmtMoney(rb.total - pf.additionalInvestment, pf.currency)
                : '—',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.textPrimary),
          ),
          const SizedBox(height: 12),
          ...pf.items.map((item) {
            final curWeight = rb?.results
                .where((r) => r.id == item.id)
                .firstOrNull
                ?.currentWeight;
            double evalVal = 0;
            if (!item.isCash && item.currentPrice > 0) {
              evalVal = item.currentPrice * item.shares;
              if (item.market == 'US' && pf.currency == 'KRW')
                evalVal *= pf.exchangeRate;
              else if (item.market == 'KR' && pf.currency == 'USD')
                evalVal /= pf.exchangeRate;
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _marketBadge(context, item),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(item.displayName(context),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary),
                              overflow: TextOverflow.ellipsis)),
                      if (curWeight != null)
                        Text(_pct(curWeight),
                            style: TextStyle(
                                fontSize: 12, color: context.textSecondary)),
                    ]),
                    if (!item.isCash) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(
                            '${fmtPrice(item.currentPrice, item.market)} × ${formatShares(item.shares)}',
                            style: TextStyle(
                                fontSize: 11, color: context.textSecondary)),
                        const Spacer(),
                        if (evalVal > 0)
                          Text(fmtMoney(evalVal, pf.currency),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary)),
                      ]),
                    ] else ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Spacer(),
                        Text(fmtMoney(evalVal, pf.currency),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary)),
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
                    onSave();
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
                    onShare();
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

  void _showDeleteConfirm(Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteItemContent(
          withJosa(item.displayName(context), Josa.eulReul,
              korean: Localizations.localeOf(context).languageCode == 'ko'),
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              context.read<PortfolioProvider>().deleteItem(pf.id, item.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: context.danger),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// 포트 메뉴 (시안 v13d). 시안에 FAB는 없다 — 액션은 이 시트에 모은다.
  Future<void> _showPortfolioMenu(Portfolio pf, RebalanceResult? rb) async {
    final l10n = context.l10n;
    // 메뉴를 열 때 읽는다. 화면에 들어올 때만 읽으면, 업로드나 일괄 기록을
    // 하고 돌아온 직후에 항목이 안 보인다.
    _undo = await UndoService.load(pf.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.scaffoldBg,
      // 항목이 늘면 기본 높이(화면의 절반)를 넘어 잘린다.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
      ),
      builder: (sheetCtx) {
        Widget row(IconData icon, String label, VoidCallback onTap,
            {String? hint, String? subtitle, bool danger = false}) {
          final fg = danger ? context.danger : context.textPrimary;
          return ListTile(
            leading: Icon(icon,
                color: danger ? context.danger : context.textStrong, size: 21),
            title: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
            // 무엇을 되돌리는지 눌러보기 전에 알아야 한다
            subtitle: subtitle == null
                ? null
                : Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary)),
            trailing: hint == null
                ? null
                : Text(hint,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary)),
            onTap: () {
              Navigator.pop(sheetCtx);
              onTap();
            },
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6CFBC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // 시안 v13d의 `거래 내역 전체보기`
                    row(
                        Icons.history,
                        l10n.transactionHistory,
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionHistoryScreen(
                                    portfolioId: pf.id),
                              ),
                            )),
                    row(
                        Icons.balance,
                        l10n.targetWeightsTitle,
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TargetWeightsScreen(portfolioId: pf.id),
                              ),
                            )),
                    row(Icons.swap_vert, l10n.reorderItems,
                        () => setState(() => _editMode = true)),
                    row(Icons.tune, l10n.labelSettings,
                        () => _showSettings(pf)),
                    row(Icons.pie_chart_outline, l10n.labelGraph,
                        () => _openGraph(pf)),
                    row(
                        Icons.ios_share,
                        l10n.capture,
                        () => _showCaptureSheet(
                              () => _saveAssetImage(pf, rb),
                              () => _shareAssetImage(pf, rb),
                            )),
                    row(Icons.upload_file, l10n.excelImportTitle,
                        () => _openImport(context, pf)),
                    // 한 번에 수십 건이 들어가는 두 경로(조정 제안 일괄 기록 ·
                    // 거래내역 업로드) 뒤에만 나온다. 되돌릴 게 없으면 안 낸다 —
                    // 늘 있는 항목이면 무엇을 되돌리는지 알 수 없다.
                    if (_undo != null)
                      row(Icons.undo, l10n.undoLastTitle,
                          () => _confirmUndo(pf, _undo!),
                          subtitle: _undoSubtitle(l10n, _undo!)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Divider(height: 1, color: context.dividerColor),
                    ),
                    // 포트 자체를 다루는 것들 (시안 v13d). 예전에는 자산 탭 편집
                    // 모드에만 있었는데, 순서 변경이 별도 화면이 되며 갈 곳을 잃었다.
                    row(Icons.edit_outlined, l10n.rename,
                        () => editPortfolio(context, pf)),
                    row(Icons.copy_outlined, l10n.duplicate,
                        () => duplicatePortfolio(context, pf, l10n.copySuffix)),
                    row(Icons.delete_outline, l10n.delete, () async {
                      final gone = await confirmDeletePortfolio(context, pf);
                      // 지운 포트의 상세에 남아 있을 수 없다
                      if (gone && context.mounted) Navigator.pop(context);
                    }, danger: true),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  /// 종목 상세는 시안 v12c에서 바텀시트가 아니라 전용 화면이다.
  void _showItemSheet(Portfolio pf, PortfolioItem item, RebalanceResult? rb) {
    // 예수금은 볼 게 금액 하나뿐이다. 종목 상세로 보내면 시세·손익처럼
    // 예수금에 없는 칸만 잔뜩 나온다 — 바로 고치는 시트를 연다.
    if (item.isCash) {
      CashEditSheet.show(context, pf, item);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(portfolioId: pf.id, itemId: item.id),
      ),
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.exit)),
        ],
      ),
    );
    return result == true;
  }

  void _openGraph(Portfolio pf) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PortfolioGraphScreen(portfolioId: pf.id)));
  }

  /// 거래내역 업로드 (시안 v17b·v17c).
  ///
  /// 예전에는 여기서 바텀시트를 띄우고 그 안에서 파일을 골라 **바로 저장**했다.
  /// 지금은 두 단계 화면이 그 일을 하고, 저장 전에 무엇이 들어가는지 보여준다.
  /// 시트는 같은 내용을 한 번 더 묻는 단계일 뿐이라 없앴다.
  String _undoSubtitle(dynamic l10n, UndoBatch b) {
    final d = DateTime.fromMillisecondsSinceEpoch(b.at);
    String two(int v) => v.toString().padLeft(2, '0');
    final when = '${two(d.month)}.${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    return b.kind == UndoBatch.kindImport
        ? l10n.undoFromImport(b.count, when)
        : l10n.undoFromProposal(b.count, when);
  }

  /// **무엇이 사라지는지 먼저 말하고 묻는다.** 되돌리기도 되돌릴 수 없다.
  Future<void> _confirmUndo(Portfolio pf, UndoBatch b) async {
    final l10n = context.l10n;
    final lines = <String>[
      l10n.undoConfirmTrades(b.count),
      if (b.createdItemIds.isNotEmpty)
        l10n.undoConfirmItems(b.createdItemIds.length),
      if (b.cashItemId != null) l10n.undoConfirmCash,
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(l10n.undoConfirmTitle,
            style: TextStyle(fontSize: 16, color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(t,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.textSecondary)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.undoAction,
                  style: TextStyle(color: context.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final provider = context.read<PortfolioProvider>();
    final kept = await provider.undoBatch(b);
    await UndoService.clear(b.portfolioId);
    if (!mounted) return;
    setState(() => _undo = null);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(kept.isEmpty
          ? l10n.undoDone(b.count)
          : '${l10n.undoDone(b.count)}\n'
              '${l10n.undoKeptItems(kept.join(", "))}'),
    ));
  }

  Future<void> _openImport(BuildContext context, Portfolio pf) async {
    final l10n = context.l10n;
    final result = await Navigator.push<ImportResult?>(
      context,
      MaterialPageRoute(
          builder: (_) => TransactionImportScreen(portfolioId: pf.id)),
    );
    if (!context.mounted || result == null) return;
    _showImportResult(context, l10n, result);
  }

  void _showImportResult(
      BuildContext context, dynamic l10n, ImportResult result) {
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
              _resultLine('✓', l10n.excelImportAdded(result.addedCount),
                  const Color(0xFF16A34A)),
            if (result.createdItems.isNotEmpty)
              _resultLine(
                  '+',
                  l10n.excelImportCreated(result.createdItems.length),
                  context.brand),
            if (result.skippedRows.isNotEmpty)
              _resultLine(
                  '⚠',
                  l10n.excelImportSkipped(result.skippedRows.length),
                  const Color(0xFFF59E0B)),
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
          Text('$icon  ',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          Expanded(
              child: Text(text, style: TextStyle(fontSize: 13, color: color))),
        ]),
      );

  // ── Build ──

  /// 헤더 본문의 실제 높이. 글자 크기·내용에 따라 달라져 재서 쓴다.
  /// **스크롤 중에 바뀌면 미룬다** — 접히는 도중 최대 높이가 바뀌면
  /// 접힘 비율과 실제 높이가 어긋난다.
  final HeaderBody _body = HeaderBody();

  /// 화면 세로 스크롤.
  final ScrollController _pageScroll = ScrollController();

  /// 마지막으로 반영한 기록 갱신 번호.
  ///
  /// 빈 날을 메우고 나면 다시 읽는다 — 안 그러면 다음에 앱을 켤 때까지
  /// 방금 채운 날들이 화면에 안 나온다.
  int _seenHistorySeq = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        if (provider.historySeq != _seenHistorySeq) {
          _seenHistorySeq = provider.historySeq;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
        }
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }

        if (_investController.text.isEmpty && pf.additionalInvestment != 0) {
          _investController.text = pf.additionalInvestment.toStringAsFixed(0);
        }

        final rb = Rebalancer.calculate(pf);

        double totalPnl = 0,
            totalCost = 0,
            totalDayChange = 0,
            totalPrevValue = 0;
        for (final item in pf.items) {
          if (item.isCash || item.currentPrice <= 0) continue;
          double fx = 1.0;
          if (item.market == 'US' && pf.currency == 'KRW')
            fx = pf.exchangeRate;
          else if (item.market == 'KR' && pf.currency == 'USD')
            fx = 1.0 / pf.exchangeRate;
          if (item.avgPrice > 0) {
            totalPnl += (item.currentPrice - item.avgPrice) * item.shares * fx;
            totalCost += item.avgPrice * item.shares * fx;
          }
          if (item.previousClose > 0) {
            totalDayChange +=
                (item.currentPrice - item.previousClose) * item.shares * fx;
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
            body: Column(
              children: [
                // 편집 모드는 순서를 끌어 옮기는 목록이라 슬리버로 바꾸기
                // 까다롭고, 오래 머무는 화면도 아니다. 헤더를 그대로 둔다.
                if (_editMode)
                  BrandHeader(
                  title: '${pf.emoji} ${pf.name}',
                  titleSize: 17,
                  titleWeight: FontWeight.w700,
                  childPadding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
                  leading: IconButton(
                    tooltip: context.l10n.a11yBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      if (_editMode) {
                        final ok = await _confirmExitEdit();
                        if (ok) setState(() => _editMode = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  actions: [
                    if (_editMode)
                      TextButton.icon(
                        onPressed: () => setState(() => _editMode = false),
                        icon: const Icon(Icons.check,
                            color: Colors.white, size: 18),
                        label: Text(l10n.done,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      )
                    else
                      IconButton(
                        tooltip: context.l10n.a11yRefresh,
              icon: _refreshing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Icon(Icons.refresh,
                                color: (pf.exchangeAuto || pf.priceAuto)
                                    ? Colors.white
                                    : context.onBrandSecondary),
                        onPressed: () => _doRefresh(pf),
                      ),
                    if (!_editMode)
                      IconButton(
                        tooltip: context.l10n.a11yMenu,
              icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () => _showPortfolioMenu(pf, rb),
                      ),
                  ],
                    child: _buildHeaderBody(context, pf, rb, hasPnl,
                        hasDayChange, totalPnl, totalCost, totalDayChange,
                        totalPrevValue),
                  ),
                Expanded(
                  child: _editMode
                      ? _buildAssetView(context, pf, rb)
                      : _buildScrollBody(context, pf, rb, hasPnl, hasDayChange,
                          totalPnl, totalCost, totalDayChange, totalPrevValue),
                ),
                // 광고도 네비바 위로 올린다. 이 화면은 셸 밖이라 SafeArea가 없어
                // 그대로 두면 배너가 시스템 버튼에 깔린다.
                const SafeArea(
                    top: false,
                    child: BottomBannerAd(slot: AdSlot.detail)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 딥그린 헤더 안쪽 ──

  /// 헤더 = [자산 · 리밸런싱] 탭 + 선택된 탭의 요약.
  ///
  /// 두 탭 모두 `큰 금액 + 타일 2개 + 하단 한 줄`이라는 같은 골격을 써서
  /// 탭을 오갈 때 헤더 높이가 흔들리지 않게 한다. 값이 없는 칸은 감추지 않고
  /// `—`로 남겨 자리를 지킨다.
  Widget _buildHeaderBody(
      BuildContext context,
      Portfolio pf,
      RebalanceResult? rb,
      bool hasPnl,
      bool hasDayChange,
      double totalPnl,
      double totalCost,
      double totalDayChange,
      double totalPrevValue) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final hasForeign =
        pf.currency == 'USD' || pf.items.any((i) => i.market == 'US');
    final pnlColors = context.watch<PnlColorNotifier>();

    final bigLabel = l10n.evaluationAmount;
    final bigValue = rb == null
        ? '—'
        : fmtMoney(rb.total - pf.additionalInvestment, pf.currency);

    final tiles = <Widget>[
      _brandPnlTile(context, pf, l10n.profitLoss, hasPnl ? totalPnl : null,
          hasPnl ? totalPnl / totalCost * 100 : null),
      const SizedBox(width: 9),
      _brandPnlTile(
          context,
          pf,
          l10n.dayChange,
          hasDayChange ? totalDayChange : null,
          hasDayChange ? totalDayChange / totalPrevValue * 100 : null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 편집 중에는 요약을 접어 목록에 집중시킨다
        if (!_editMode) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(bigLabel,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.onBrandSecondary)),
                  const Spacer(),
                  if (hasForeign)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(DS.chipRadius),
                      ),
                      child: Text(
                        '1 USD = ₩${pf.exchangeRate.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: DS.caption,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    bigValue,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.2,
                      height: 1.08,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: tiles),
                const SizedBox(height: 12),
                SparklinePanel(
                  points: _history,
                  period: _sparkPeriod,
                  onPeriodChanged: (p) {
                    setState(() => _sparkPeriod = p);
                    _loadHistory();
                  },
                  building: context.watch<PortfolioProvider>().backfilling,
                  asOf: isKo
                      ? '${_fmtTimeShort(pf.lastUpdated)} 기준'
                      : 'as of ${_fmtTimeShort(pf.lastUpdated)}',
                  color: _history.length >= 2 &&
                          _history.last.totalKrw >= _history.first.totalKrw
                      ? pnlColors.onBrandPositive
                      : pnlColors.onBrandNegative,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 딥그린 위 요약 타일.
  Widget _brandTile(BuildContext context,
      {required String label,
      required String value,
      required String sub,
      required Color color}) {
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
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: color)),
            ),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: color == Colors.white
                        ? context.onBrandSecondary
                        : color),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  /// 손익 타일 — 값이 없으면(`amount == null`) 자리만 지킨다.
  Widget _brandPnlTile(BuildContext context, Portfolio pf, String label,
      double? amount, double? pct) {
    final pnlColors = context.watch<PnlColorNotifier>();
    if (amount == null || pct == null) {
      return _brandTile(context,
          label: label, value: '—', sub: '—', color: Colors.white);
    }
    final isPos = amount >= 0;
    final sign = isPos ? '+' : '−';
    return _brandTile(context,
        label: label,
        value: '$sign${fmtMoney(amount.abs(), pf.currency)}',
        sub: '$sign${pct.abs().toStringAsFixed(2)}%',
        color: isPos ? pnlColors.onBrandPositive : pnlColors.onBrandNegative);
  }

  // ── Tab: 자산현황 ──

  /// 접히는 헤더 + 종목 목록.
  ///
  /// 자산 탭과 같은 문제였다 — 딥그린 헤더가 화면의 3분의 1을 먹어서 종목이
  /// 열 개만 돼도 목록을 보려면 계속 밀어야 한다. 목록을 올리는 동안에는
  /// 평가금액 한 줄만 남긴다.
  Widget _buildScrollBody(
    BuildContext context,
    Portfolio pf,
    RebalanceResult? rb,
    bool hasPnl,
    bool hasDayChange,
    double totalPnl,
    double totalCost,
    double totalDayChange,
    double totalPrevValue,
  ) {
    final l10n = context.l10n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _body.flush(_pageScroll)) setState(() {});
    });
    return CustomScrollView(
      controller: _pageScroll,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          // 멈추면 끝까지 접거나 끝까지 편다
          delegate: CollapsingHeaderDelegate(
            background: context.appBarBg,
            topInset: MediaQuery.paddingOf(context).top,
            titleHeight:
                48 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
            bodyHeight: _body.value,
            leading: IconButton(
              tooltip: l10n.a11yBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            expandedTitle: Text(
              '${pf.emoji} ${pf.name}',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3),
              overflow: TextOverflow.ellipsis,
            ),
            collapsedTitle: _buildCompactValue(context, pf, hasDayChange,
                totalDayChange, totalPrevValue),
            actions: [
              IconButton(
                tooltip: l10n.a11yRefresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.refresh,
                        color: (pf.exchangeAuto || pf.priceAuto)
                            ? Colors.white
                            : context.onBrandSecondary),
                onPressed: () => _doRefresh(pf),
              ),
              IconButton(
                tooltip: l10n.a11yMenu,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showPortfolioMenu(pf, rb),
              ),
            ],
            body: MeasureSize(
              onHeight: (h) {
                if (mounted && _body.update(h, _pageScroll)) {
                  setState(() {});
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
                child: _buildHeaderBody(context, pf, rb, hasPnl, hasDayChange,
                    totalPnl, totalCost, totalDayChange, totalPrevValue),
              ),
            ),
          ),
        ),
        if (pf.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context, pf),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 14, 16, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SectionTitle(
                  title: l10n.holdingsSection,
                  trailing: _holdingsSummary(context, pf),
                ),
                const SizedBox(height: DS.cardGap),
                ListCard(
                  rows: [
                    for (final item in pf.items)
                      _buildHoldingRow(context, pf, item, rb),
                  ],
                ),
                const SizedBox(height: 10),
                _buildSlimAddCard(context, pf),
              ]),
            ),
          ),
        CollapseTailSliver(collapseRange: _body.value),
      ],
    );
  }

  /// 접힌 헤더의 한 줄 — 평가금액과 전일대비.
  Widget _buildCompactValue(BuildContext context, Portfolio pf,
      bool hasDayChange, double totalDayChange, double totalPrevValue) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final pnlColors = context.watch<PnlColorNotifier>();
    final cur = pf.currency;
    final pct = totalPrevValue > 0 ? totalDayChange / totalPrevValue * 100 : 0.0;
    final up = totalDayChange >= 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmtMoney(pf.totalValue, cur),
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        if (hasDayChange) ...[
          const SizedBox(width: 8),
          Text(
            '${up ? '+' : '−'}${pct.abs().toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: DS.caption,
              fontWeight: FontWeight.w700,
              color: up ? pnlColors.onBrandPositive : pnlColors.onBrandNegative,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            isKo ? '전일대비' : 'today',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: context.onBrandSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildAssetView(
      BuildContext context, Portfolio pf, RebalanceResult? rb) {
    final l10n = context.l10n;
    return pf.items.isEmpty
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
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  SectionTitle(
                    title: l10n.holdingsSection,
                    trailing: _holdingsSummary(context, pf),
                  ),
                  const SizedBox(height: DS.cardGap),
                  ListCard(
                    rows: [
                      for (final item in pf.items)
                        _buildHoldingRow(context, pf, item, rb),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSlimAddCard(context, pf),
                ],
              );
  }

  /// `3종목 · 예수금 포함` — 섹션 제목 우측 부가.
  ///
  /// 비중에서 뺀 예수금을 「포함」이라고 하면 안 된다. 예수금 항목이 목록에
  /// 있다는 뜻으로 쓰던 말인데, 비중 포함이 설정이 된 뒤로는 정반대로 읽힌다.
  String _holdingsSummary(BuildContext context, Portfolio pf) {
    final l10n = context.l10n;
    final stocks = pf.items.where((i) => !i.isCash).length;
    final count = l10n.itemCountLabel(stocks);
    final cash = pf.items.where((i) => i.isCash).firstOrNull;
    if (cash == null) return count;
    return '$count · ${cash.inWeight ? l10n.cashIncluded : l10n.cashExcluded}';
  }

  /// 구성 종목 한 행 (시안 v12b).
  ///
  /// 좌: [시장 칩] 이름 14.5/700 / 보조 줄 `₩21,450 · 220주`
  /// 우: 평가금액 15/700 / 전일대비 11/600 무채색 + 누적 12.5/700 손익색
  Widget _buildHoldingRow(BuildContext context, Portfolio pf,
      PortfolioItem item, RebalanceResult? rb) {
    final pnlColors = context.watch<PnlColorNotifier>();

    // 기준통화 환산 (US 종목을 원화 포트에 담는 경우 등)
    double fx = 1.0;
    if (item.market == 'US' && pf.currency == 'KRW') {
      fx = pf.exchangeRate;
    } else if (item.market == 'KR' && pf.currency == 'USD') {
      fx = 1.0 / pf.exchangeRate;
    }
    final value =
        item.isCash ? item.shares : item.shares * item.currentPrice * fx;

    String? dayText;
    if (!item.isCash && item.previousClose > 0 && item.currentPrice > 0) {
      final pct =
          (item.currentPrice - item.previousClose) / item.previousClose * 100;
      dayText = '${pct >= 0 ? '▲' : '▼'}${pct.abs().toStringAsFixed(2)}%';
    }

    String? returnText;
    Color? returnColor;
    if (!item.isCash && item.avgPrice > 0 && item.currentPrice > 0) {
      final pct = (item.currentPrice - item.avgPrice) / item.avgPrice * 100;
      returnText = '${pct >= 0 ? '+' : '−'}${pct.abs().toStringAsFixed(2)}%';
      returnColor =
          pct >= 0 ? pnlColors.positiveColor : pnlColors.negativeColor;
    }

    return ListRow(
      leading: MarketChip(
        market: item.isCash ? 'CASH' : item.market,
        label: item.isCash
            ? context.l10n.cash
            : (item.market == 'US' ? 'US' : 'KR'),
      ),
      title: item.displayName(context),
      titleSize: 14.5,
      // 시안은 `가격 · 수량` 순서 — 곱셈 기호가 아니라 점 구분자다
      subtitle: item.isCash
          ? null
          : Text(
              '${fmtPrice(item.currentPrice, item.market)} · ${formatShares(item.shares)}${context.l10n.unitShares}',
              style: TextStyle(
                  fontSize: DS.body,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary),
            ),
      amount: fmtMoney(value, pf.currency),
      dayText: dayText,
      returnText: returnText,
      returnColor: returnColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: () => _showItemSheet(pf, item, rb),
    );
  }

  Widget _buildEditCard(BuildContext context, Portfolio pf, PortfolioItem item,
      {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        border: Border.all(color: context.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  _marketBadge(context, item),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(item.displayName(context),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary),
                          overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 2),
                Text(
                    item.isCash
                        ? fmtMoney(item.shares, pf.currency)
                        : '${fmtPrice(item.currentPrice, item.market)} × ${formatShares(item.shares)}',
                    style:
                        TextStyle(fontSize: 12, color: context.textSecondary)),
              ])),
          IconButton(
            onPressed: () => _showItemForm(pf, item),
            tooltip: context.l10n.edit,
              icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: context.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: context.brand.withValues(alpha: 0.4))),
              child: Icon(Icons.edit_outlined, color: context.brand, size: 16),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () => _showDeleteConfirm(pf, item),
            tooltip: context.l10n.a11yRemove,
              icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: context.pnlDownTint,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: context.danger.withValues(alpha: 0.4))),
              child: Icon(Icons.remove, color: context.danger, size: 18),
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

  Widget _buildSlimAddCard(BuildContext context, Portfolio pf) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemSearchScreen(portfolio: pf),
          ),
        ),
        borderRadius: BorderRadius.circular(DS.tileRadius),
        child: DashedBorderBox(
          color: const Color(0xFFD6CFBC),
          radius: DS.tileRadius,
          child: SizedBox(
            height: 46,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, size: 19, color: context.brand),
              const SizedBox(width: 8),
              Text(context.l10n.addStock,
                  style: TextStyle(
                      fontSize: DS.sectionTitle,
                      fontWeight: FontWeight.w700,
                      color: context.brand)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _marketBadge(BuildContext context, PortfolioItem item) {
    if (item.isCash)
      return _badge(context, context.l10n.cash, const Color(0xFF65A30D));
    if (item.market == 'US')
      return _badge(context, 'US', const Color(0xFF7C3AED));
    return _badge(context, 'KR', const Color(0xFF0369A1));
  }

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
