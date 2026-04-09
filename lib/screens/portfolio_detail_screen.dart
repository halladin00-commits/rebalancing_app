import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../utils/rebalancer.dart';
import '../services/api_service.dart';
import '../widgets/item_form_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/item_bottom_sheet.dart';
import '../widgets/speed_dial_fab.dart';
import '../widgets/bottom_banner_ad.dart';
import 'portfolio_graph_screen.dart';

class PortfolioDetailScreen extends StatefulWidget {
  final String portfolioId;
  const PortfolioDetailScreen({super.key, required this.portfolioId});
  @override
  State<PortfolioDetailScreen> createState() => _PortfolioDetailScreenState();
}

class _PortfolioDetailScreenState extends State<PortfolioDetailScreen> {
  bool _editMode = false;
  bool _refreshing = false;
  final _investController = TextEditingController();

  String _fmt(double n, String cur) {
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'  ;
  }

  String _fmtCompact(double n, String cur) {
    if (cur == 'USD') {
      if (n >= 1000000) return '\$${(n / 1000000).toStringAsFixed(2)}M';
      if (n >= 1000) return '\$${(n / 1000).toStringAsFixed(1)}K';
      return '\$${n.toStringAsFixed(2)}';
    }
    if (n >= 100000000) return '₩${(n / 100000000).toStringAsFixed(2)}억';
    if (n >= 10000) return '₩${(n / 10000).toStringAsFixed(0)}만';
    return '₩${n.round()}';
  }

  String _fmtAmount(double n, String cur, bool compact) =>
      compact ? _fmtCompact(n, cur) : _fmt(n, cur);

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

  @override
  void dispose() {
    _investController.dispose();
    super.dispose();
  }

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
        if (r.ok) { item.currentPrice = r.data!; successCount++; }
        else { errors.add(r.error!); }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    ));
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
            compactAmount: s['compactAmount']);
        },
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

  void _showApplyConfirm(Portfolio pf, RebalanceResult rb) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.rebalanceApplyTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _applyBullet(l10n.rebalanceBullet1),
            const SizedBox(height: 4),
            _applyBullet(l10n.rebalanceBullet2),
            const SizedBox(height: 10),
            Text(l10n.irrevocable,
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              final results = rb.results.map((r) => {
                'id': r.id,
                'newShares': r.isCash ? r.newCashAmount : r.newShares,
              }).toList();
              context.read<PortfolioProvider>().applyRebalancing(pf.id, results, rb.cash);
              _investController.text = rb.cash > 0 ? rb.cash.toStringAsFixed(0) : '';
              Navigator.pop(context);
            },
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
  }

  Widget _applyBullet(String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('• ', style: TextStyle(fontSize: 14)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
    ],
  );

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null) {
          return Scaffold(body: Center(child: Text(l10n.portfolioNotFound)));
        }

        if (_investController.text.isEmpty && pf.additionalInvestment > 0) {
          _investController.text = pf.additionalInvestment.toStringAsFixed(0);
        }

        final rb = Rebalancer.calculate(pf);
        final weightSum = pf.weightSum;
        final hasChanges = rb?.hasChanges ?? false;
        final commOn = pf.commissionEnabled;
        final curSym = pf.currency == 'USD' ? '\$' : '₩';

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
                  child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      // ── Top Panel ──
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
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: context.textPrimary),
                                decoration: InputDecoration(
                                  prefixText: '$curSym ',
                                  prefixStyle: TextStyle(color: context.textPrimary),
                                  hintText: '0',
                                  filled: true,
                                  fillColor: context.fieldFill,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.borderColor)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (v) => provider.setAdditionalInvestment(pf.id, double.tryParse(v) ?? 0),
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                _infoBox(context, l10n.currentAssets,
                                    rb != null ? _fmtAmount(rb.total - pf.additionalInvestment, pf.currency, pf.compactAmount) : '—'),
                                const SizedBox(width: 8),
                                _infoBox(context, l10n.rebalancingBase,
                                    rb != null ? _fmtAmount(rb.total, pf.currency, pf.compactAmount) : '—'),
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

                      // ── Weight Warning ──
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

                      // ── Items ──
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
                                      provider.reorderItems(pf.id, list);
                                    },
                                    itemBuilder: (ctx, idx) =>
                                        _buildItemCard(context, pf, pf.items[idx], rb,
                                            key: ValueKey(pf.items[idx].id)),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                                    itemCount: pf.items.length + 1,
                                    itemBuilder: (ctx, idx) {
                                      if (idx == pf.items.length) {
                                        return _buildSlimAddCard(context, pf);
                                      }
                                      return _buildItemCard(context, pf, pf.items[idx], rb);
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
                if (!_editMode)
                  Positioned.fill(
                    child: SpeedDialFab(
                      key: const ValueKey('detail_fab'),
                      items: [
                        SpeedDialItem(
                          icon: Icons.settings_outlined,
                          label: l10n.labelSettings,
                          onTap: () => _showSettings(pf),
                        ),
                        SpeedDialItem(
                          icon: Icons.edit_outlined,
                          label: l10n.labelEdit,
                          onTap: () => setState(() => _editMode = true),
                        ),
                        SpeedDialItem(
                          icon: Icons.pie_chart_outline,
                          label: l10n.labelGraph,
                          iconColor: const Color(0xFF93C5FD),
                          bgColor: const Color(0xFF1D4ED8),
                          onTap: () => _openGraph(pf),
                        ),
                        if (rb != null && hasChanges)
                          SpeedDialItem(
                            icon: Icons.check_circle_outline,
                            label: l10n.labelRebalanceApply,
                            iconColor: const Color(0xFF4ADE80),
                            bgColor: const Color(0xFF052E16),
                            onTap: () => _showApplyConfirm(pf, rb),
                          ),
                      ],
                    ),
                  ),
              ],       // Stack children
            ),         // Stack
                ),     // Expanded
                const BottomBannerAd(),
              ],       // Column children
            ),         // Column
          ),
        );
      },
    );
  }

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
              decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(5)),
              child: const Icon(Icons.add, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text(context.l10n.addStock,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6))),
          ]),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Portfolio pf, PortfolioItem item,
      RebalanceResult? rb, {Key? key}) {
    final l10n = context.l10n;
    final r = rb?.results.where((x) => x.id == item.id).firstOrNull;
    final delta = r?.isCash == true ? r!.cashDelta.round() : (r?.delta ?? 0);
    final isBuy = delta > 0;

    if (_editMode) {
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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4))),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 16),
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

    return Card(
      key: key,
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
                      style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 12)),
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
              if (r != null && delta != 0) ...[
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
              if (r != null && delta == 0)
                Text(l10n.hold, style: TextStyle(fontSize: 12, color: context.textHint)),
            ]),
          ]),
        ),
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
          color: color.withValues(alpha: context.isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
