import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../utils/rebalancer.dart';
import '../services/api_service.dart';
import '../widgets/item_form_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/item_bottom_sheet.dart';

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

  // ── Helpers ──

  String _fmt(double n, String cur) {
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtPrice(double n, String market) {
    if (market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _pct(double n) => '${n.toStringAsFixed(2)}%';

  String _fmtTime(int? ts) {
    if (ts == null) return '업데이트 전';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.year}.${d.month.toString().padLeft(2, "0")}.${d.day.toString().padLeft(2, "0")} '
        '${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
  }

  @override
  void dispose() {
    _investController.dispose();
    super.dispose();
  }

  // ── Refresh ──

  Future<void> _doRefresh(Portfolio pf) async {
    if (_refreshing) return;
    if (!pf.exchangeAuto && !pf.priceAuto) {
      _showToast('설정에서 환율 또는 주가를 자동으로 변경해 주세요', Colors.orange);
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
      final stockItems = pf.items.where((i) => !i.isCash && i.ticker.isNotEmpty).toList();
      for (final item in stockItems) {
        final r = await ApiService.fetchStockPrice(item.ticker, item.market);
        if (r.ok) { item.currentPrice = r.data!; successCount++; }
        else { errors.add(r.error!); }
      }
    }

    pf.lastUpdated = DateTime.now().millisecondsSinceEpoch;
    await provider.updatePortfolio(pf.id, pf);
    setState(() => _refreshing = false);

    if (errors.isEmpty) _showToast('$successCount건 업데이트 완료', Colors.green);
    else if (successCount > 0) _showToast('$successCount건 성공, ${errors.length}건 실패', Colors.orange);
    else _showToast('업데이트 실패: ${errors.first}', Colors.red);
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

  // ── Dialogs ──

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
            exchangeRate: s['exchangeRate'], priceAuto: s['priceAuto']);
        },
      ),
    );
  }

  void _showDeleteConfirm(Portfolio pf, PortfolioItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text("'${item.name}'을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () { context.read<PortfolioProvider>().deleteItem(pf.id, item.id); Navigator.pop(context); },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showApplyConfirm(Portfolio pf, RebalanceResult rb) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('리밸런싱 적용'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _applyBullet('리밸런싱 결과를 보유 수량에 반영'),
            const SizedBox(height: 4),
            _applyBullet('잔여 현금은 추가 투자금으로 변환'),
            const SizedBox(height: 10),
            Text('이 작업은 되돌릴 수 없습니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
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
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  Widget _applyBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 14)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  void _showItemSheet(Portfolio pf, PortfolioItem item, RebalanceResult? rb) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ItemBottomSheet(item: item, portfolio: pf, rb: rb),
    );
  }

  void _handleBackPress() async {
    if (_editMode) {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('편집 종료'),
          content: const Text('편집 모드를 종료하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('종료')),
          ],
        ),
      );
      if (result == true) setState(() => _editMode = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final pf = provider.getPortfolio(widget.portfolioId);
        if (pf == null) {
          return const Scaffold(body: Center(child: Text('포트폴리오를 찾을 수 없습니다')));
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
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBackPress();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (_editMode) {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('편집 종료'),
                        content: const Text('편집 모드를 종료하시겠습니까?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('종료')),
                        ],
                      ),
                    );
                    if (result == true) setState(() => _editMode = false);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Text('${pf.emoji} ${pf.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              actions: _editMode
                  ? [
                      TextButton.icon(
                        onPressed: () => setState(() => _editMode = false),
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: const Text('완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ]
                  : [
                      IconButton(
                        icon: _refreshing
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(Icons.refresh,
                                color: (pf.exchangeAuto || pf.priceAuto) ? Colors.white : Colors.grey[600]),
                        onPressed: () => _doRefresh(pf),
                      ),
                      IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => _showSettings(pf)),
                      IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => setState(() => _editMode = true)),
                      if (rb != null && hasChanges)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white12,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _showApplyConfirm(pf, rb),
                            icon: const Icon(Icons.check, color: Color(0xFF34D399), size: 16),
                            label: const Text('적용', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                    ],
            ),
            body: Column(
              children: [
                // ── Top Panel ──
                if (!_editMode)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('추가 투자금', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _investController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '$curSym ',
                            hintText: '0',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (v) { provider.setAdditionalInvestment(pf.id, double.tryParse(v) ?? 0); },
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          _infoBox('현재 자산', rb != null ? _fmt(rb.total - pf.additionalInvestment, pf.currency) : '—'),
                          const SizedBox(width: 8),
                          _infoBox('리밸런싱 기준', rb != null ? _fmt(rb.total, pf.currency) : '—'),
                          const SizedBox(width: 8),
                          _infoBox('잔여 현금', rb != null ? _fmt(rb.cash, pf.currency) : '—', highlight: true),
                        ]),
                        if (rb != null && commOn && rb.commission > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('예상 수수료: ${_fmt(rb.commission, pf.currency)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('환율: 1 USD = ₩${pf.exchangeRate.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                              Text(_fmtTime(pf.lastUpdated),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
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
                    color: const Color(0xFFFEF3C7),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      const Text('⚠️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('목표 비중 합계: ${_pct(weightSum)} (100%가 아닙니다)',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF92400E))),
                    ]),
                  ),

                // ── Items ──
                Expanded(
                  child: pf.items.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('종목을 추가해 주세요', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
                          const SizedBox(height: 6),
                          Text('아래 + 버튼을 눌러 시작하세요', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                        ]))
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
                                  _buildItemCard(pf, pf.items[idx], rb, key: ValueKey(pf.items[idx].id)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                              itemCount: pf.items.length,
                              itemBuilder: (ctx, idx) => _buildItemCard(pf, pf.items[idx], rb),
                            ),
                ),
              ],
            ),
            floatingActionButton: _editMode
                ? null
                : FloatingActionButton(
                    onPressed: () => _showItemForm(pf),
                    backgroundColor: const Color(0xFF3B82F6),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
          ),
        );
      },
    );
  }

  // ── Widgets ──

  Widget _infoBox(String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xFF16A34A) : const Color(0xFF1E293B))),
        ]),
      ),
    );
  }

  Widget _buildItemCard(Portfolio pf, PortfolioItem item, RebalanceResult? rb, {Key? key}) {
    final r = rb?.results.where((x) => x.id == item.id).firstOrNull;
    final delta = r?.isCash == true ? r!.cashDelta.round() : (r?.delta ?? 0);
    final isBuy = delta > 0;

    // ── 편집 모드 ──
    if (_editMode) {
      return Card(
        key: key,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(children: [
            IconButton(
              onPressed: () => _showDeleteConfirm(pf, item),
              icon: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle, border: Border.all(color: Colors.red[200]!)),
                child: const Icon(Icons.remove, color: Colors.red, size: 18),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _marketBadge(item), const SizedBox(width: 6),
                Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 2),
              Text(item.isCash ? _fmt(item.shares, pf.currency) : '${_fmtPrice(item.currentPrice, item.market)} × ${item.shares.toInt()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ])),
            IconButton(
              onPressed: () => _showItemForm(pf, item),
              icon: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle, border: Border.all(color: Colors.blue[200]!)),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 16),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ]),
        ),
      );
    }

    // ── 일반 모드 ──
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemSheet(pf, item, rb),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(children: [
            Row(children: [
              _marketBadge(item), const SizedBox(width: 6),
              Expanded(child: RichText(overflow: TextOverflow.ellipsis, text: TextSpan(
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                children: [
                  TextSpan(text: item.name),
                  if (item.ticker.isNotEmpty) TextSpan(text: ' ${item.ticker}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey[400])),
                ],
              ))),
              Text(item.isCash ? _fmt(item.shares, pf.currency) : '${_fmtPrice(item.currentPrice, item.market)} × ${item.shares.toInt()}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: _pct(item.targetWeight), style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 12)),
                TextSpan(text: ' → ', style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                TextSpan(text: r != null ? _pct(r.currentWeight) : '—', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                TextSpan(text: ' → ', style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                TextSpan(text: r != null ? _pct(r.finalWeight) : '—',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: r != null ? const Color(0xFF1E293B) : Colors.grey[400])),
              ])),
              const Spacer(),
              if (r != null && delta != 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: isBuy ? const Color(0xFF22C55E) : const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                  child: Text(isBuy ? '매수' : '매도', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 4),
                Text(item.isCash ? _fmt(delta.abs().toDouble(), pf.currency) : '${delta.abs()}주',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
              ],
              if (r != null && delta == 0) Text('유지', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _marketBadge(PortfolioItem item) {
    if (item.isCash) return _badge('현금', const Color(0xFF65A30D), const Color(0xFFF7FEE7));
    if (item.market == 'US') return _badge('US', const Color(0xFF7C3AED), const Color(0xFFF5F3FF));
    return _badge('KR', const Color(0xFF0369A1), const Color(0xFFF0F9FF));
  }

  Widget _badge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
