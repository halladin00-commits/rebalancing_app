import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../models/portfolio.dart';

const _kDefaultColors = [
  Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFF59E0B),
  Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFFEC4899),
  Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFF84CC16),
  Color(0xFF64748B),
];

Color _colorForItem(Portfolio pf, String itemId) {
  final hex = pf.graphColors[itemId];
  if (hex != null && hex.isNotEmpty) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {}
  }
  final hash = itemId.codeUnits.fold(0, (a, b) => a * 31 + b).abs();
  return _kDefaultColors[hash % _kDefaultColors.length];
}

String _nameForItem(Portfolio pf, PortfolioItem item) {
  return pf.graphNames[item.id]?.isNotEmpty == true
      ? pf.graphNames[item.id]!
      : item.name;
}

class _DonutPainter extends CustomPainter {
  final List<PortfolioItem> items;
  final Portfolio portfolio;
  _DonutPainter({required this.items, required this.portfolio});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) * 0.88;
    final innerR = r * 0.54;
    final strokeW = r - innerR;
    final total = items.fold(0.0, (s, i) => s + i.targetWeight);
    if (total <= 0) return;
    double startAngle = -pi / 2;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final sweep = (item.targetWeight / total) * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = _colorForItem(portfolio, item.id);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        startAngle, sweep, false, paint,
      );
      if (items.length > 1) {
        final gapPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.6);
        final x1 = cx + innerR * cos(startAngle);
        final y1 = cy + innerR * sin(startAngle);
        final x2 = cx + r * cos(startAngle);
        final y2 = cy + r * sin(startAngle);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), gapPaint);
      }
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

class PortfolioGraphScreen extends StatefulWidget {
  final String portfolioId;
  const PortfolioGraphScreen({super.key, required this.portfolioId});

  @override
  State<PortfolioGraphScreen> createState() => _PortfolioGraphScreenState();
}

class _PortfolioGraphScreenState extends State<PortfolioGraphScreen> {
  bool _editMode = false;
  bool _showCurrent = false;
  bool _noticeNoData = false;
  bool _saving = false;
  final ScreenshotController _screenshotCtrl = ScreenshotController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureColors());
  }

  void _ensureColors() {
    final provider = context.read<PortfolioProvider>();
    final pf = provider.getPortfolio(widget.portfolioId);
    if (pf == null) return;
    final items = pf.items
        .where((i) => !i.isCash)
        .toList()
      ..sort((a, b) => b.targetWeight.compareTo(a.targetWeight));
    final newColors = Map<String, String>.from(pf.graphColors);
    bool changed = false;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (!newColors.containsKey(item.id) || newColors[item.id]!.isEmpty) {
        final color = _kDefaultColors[i % _kDefaultColors.length];
        newColors[item.id] =
            color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
        changed = true;
      }
    }
    if (changed) {
      provider.updatePortfolio(pf.id, pf.copyWith(graphColors: newColors));
    }
  }

  void _enterEdit() => setState(() => _editMode = true);
  void _exitEdit() => setState(() => _editMode = false);

  Future<void> _confirmExitEdit() async {
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
    if (result == true) _exitEdit();
  }

  Future<void> _saveImage(Portfolio pf) async {
    if (_saving) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      var status = await Permission.photos.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted && mounted) {
          _showToast(l10n.savePermissionRequired, Colors.red);
          setState(() => _saving = false);
          return;
        }
      }
      final Uint8List? imageBytes = await _screenshotCtrl.capture(pixelRatio: 3.0);
      if (imageBytes == null) {
        if (mounted) _showToast(l10n.captureFailed, Colors.red);
        setState(() => _saving = false);
        return;
      }
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        name: 'rebalancing_${pf.name}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        final ok = result['isSuccess'] == true || result['filePath'] != null;
        _showToast(ok ? l10n.savedToGallery : l10n.saveFailed,
            ok ? Colors.green : Colors.red);
      }
    } catch (e) {
      if (mounted) _showToast(l10n.saveFailedError(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    ));
  }

  void _showTitleEdit(Portfolio pf) {
    final l10n = context.l10n;
    final ctrl = TextEditingController(
        text: pf.graphTitle.isNotEmpty ? pf.graphTitle : pf.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(l10n.editCenterText,
            style: TextStyle(color: context.textPrimary, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.fieldFill,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.borderColor)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              context.read<PortfolioProvider>()
                  .updatePortfolio(pf.id, pf.copyWith(graphTitle: ctrl.text.trim()));
              Navigator.pop(context);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showItemEdit(Portfolio pf, PortfolioItem item) {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(
        text: pf.graphNames[item.id]?.isNotEmpty == true
            ? pf.graphNames[item.id]!
            : item.name);
    Color selected = _colorForItem(pf, item.id);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(l10n.editItem,
              style: TextStyle(color: context.textPrimary, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.displayName,
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.fieldFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.colorLabel,
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kDefaultColors.map((c) {
                  final isSel = selected.value == c.value;
                  return GestureDetector(
                    onTap: () => setDlg(() => selected = c),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(6),
                        border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                      child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                final provider = context.read<PortfolioProvider>();
                final newColors = Map<String, String>.from(pf.graphColors);
                final newNames = Map<String, String>.from(pf.graphNames);
                newColors[item.id] = selected.value
                    .toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                newNames[item.id] = nameCtrl.text.trim();
                provider.updatePortfolio(pf.id,
                    pf.copyWith(graphColors: newColors, graphNames: newNames));
                Navigator.pop(ctx);
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(builder: (context, provider, _) {
      final pf = provider.getPortfolio(widget.portfolioId);
      if (pf == null) {
        return Scaffold(body: Center(child: Text(l10n.portfolioEmpty)));
      }

      final sortedItems = pf.graphSortedItems;
      final centerText = pf.graphTitle.isNotEmpty ? pf.graphTitle : pf.name;
      final total = sortedItems.fold(0.0, (s, i) => s + i.targetWeight);

      final Map<String, double> currentValues = {};
      for (final item in sortedItems) {
        if (item.isCash) continue;
        final val = item.market == 'US'
            ? item.currentPrice * item.shares * pf.exchangeRate
            : item.currentPrice * item.shares;
        currentValues[item.id] = val;
      }
      final totalCurrentVal = currentValues.values.fold(0.0, (a, b) => a + b);
      final hasCurrent = totalCurrentVal > 0;

      final displayTotal = (_showCurrent && hasCurrent) ? 100.0 : total;
      List<PortfolioItem> displayItems = sortedItems;
      if (_showCurrent && hasCurrent) {
        displayItems = sortedItems.map((item) {
          final pct = (currentValues[item.id] ?? 0) / totalCurrentVal * 100;
          return item.copyWith(targetWeight: pct);
        }).toList();
      }

      return PopScope(
        canPop: !_editMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmExitEdit();
        },
        child: Scaffold(
          backgroundColor: context.scaffoldBg,
          appBar: AppBar(
            backgroundColor: context.appBarBg,
            title: Text(l10n.portfolioGraph,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            actions: [
              if (_editMode)
                IconButton(
                  icon: const Icon(Icons.check, color: Color(0xFF4ADE80)),
                  tooltip: l10n.editCompleteTooltip,
                  onPressed: _exitEdit,
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.editTooltip,
                  onPressed: _enterEdit,
                ),
              IconButton(
                icon: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.download_outlined,
                        color: _editMode ? Colors.grey[600] : Colors.white),
                tooltip: _editMode ? l10n.editCompleteBeforeSave : l10n.saveImage,
                onPressed: _editMode ? null : () => _saveImage(pf),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(children: [
              Screenshot(
                controller: _screenshotCtrl,
                child: Container(
                  color: context.cardBg,
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    if (_editMode) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: context.rowBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Row(children: [
                          _segBtn(context, l10n.targetWeight, !_showCurrent,
                              () => setState(() {
                                _showCurrent = false;
                                _noticeNoData = false;
                              })),
                          _segBtn(context, l10n.currentWeight,
                              _showCurrent && hasCurrent,
                              hasCurrent
                                  ? () => setState(() {
                                      _showCurrent = true;
                                      _noticeNoData = false;
                                    })
                                  : () => setState(() => _noticeNoData = true)),
                        ]),
                      ),
                      if (_noticeNoData && !hasCurrent)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(l10n.noPriceInfo,
                              style: TextStyle(fontSize: 11, color: Colors.orange[400]),
                              textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 12),
                    ],
                    AspectRatio(
                      aspectRatio: 1,
                      child: Stack(alignment: Alignment.center, children: [
                        CustomPaint(
                          painter: _DonutPainter(items: displayItems, portfolio: pf),
                          child: Container(),
                        ),
                        GestureDetector(
                          onTap: () => _showTitleEdit(pf),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                centerText,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_editMode) ...[
                                const SizedBox(height: 4),
                                Text(l10n.tapToEdit,
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF3B82F6))),
                              ],
                            ],
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _editMode
                        ? _buildReorderableLegend(context, pf, displayItems, displayTotal)
                        : _buildStaticLegend(context, pf, displayItems, displayTotal),
                  ]),
                ),
              ),
              if (_editMode)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(l10n.dragToReorder,
                      style: TextStyle(fontSize: 12, color: context.textHint),
                      textAlign: TextAlign.center),
                ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _segBtn(BuildContext context, String label, bool selected, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1D4ED8) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFF93C5FD)
                  : onTap == null ? context.textHint : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticLegend(BuildContext context, Portfolio pf,
      List<PortfolioItem> items, double total) {
    return Column(
      children: items.map((item) {
        final pct = total > 0 ? item.targetWeight / total * 100 : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: _colorForItem(pf, item.id),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_nameForItem(pf, item),
                style: TextStyle(fontSize: 13, color: context.textPrimary),
                overflow: TextOverflow.ellipsis)),
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildReorderableLegend(BuildContext context, Portfolio pf,
      List<PortfolioItem> items, double total) {
    final l10n = context.l10n;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final newOrder = items.map((e) => e.id).toList();
        final removed = newOrder.removeAt(oldIndex);
        newOrder.insert(newIndex, removed);
        context.read<PortfolioProvider>()
            .updatePortfolio(pf.id, pf.copyWith(graphOrder: newOrder));
      },
      itemBuilder: (ctx, i) {
        final item = items[i];
        final pct = total > 0 ? item.targetWeight / total * 100 : 0.0;
        return ListTile(
          key: ValueKey(item.id),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.drag_handle, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: _colorForItem(pf, item.id),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ]),
          title: Text(_nameForItem(pf, item),
              style: TextStyle(fontSize: 13, color: context.textPrimary),
              overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showItemEdit(pf, item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l10n.edit,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF93C5FD))),
              ),
            ),
          ]),
        );
      },
    );
  }
}
