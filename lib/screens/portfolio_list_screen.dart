import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../widgets/portfolio_form_dialog.dart';
import '../widgets/disclaimer_dialog.dart';
import '../widgets/speed_dial_fab.dart';
import 'portfolio_detail_screen.dart';

class PortfolioListScreen extends StatefulWidget {
  const PortfolioListScreen({super.key});
  @override
  State<PortfolioListScreen> createState() => _PortfolioListScreenState();
}

class _PortfolioListScreenState extends State<PortfolioListScreen> {
  bool _editMode = false;

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);

  String _fmt(double n, String cur) {
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
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

  void _showDeleteConfirm(BuildContext context, Portfolio pf) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text("'${pf.name}' 포트폴리오를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              context.read<PortfolioProvider>().deletePortfolio(pf.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditExitConfirm() async {
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

  Future<void> _showExitConfirm() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('종료'),
        content: const Text('앱을 종료하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('종료')),
        ],
      ),
    );
    if (result == true) SystemNavigator.pop();
  }

  void _handleBackPress() {
    if (_editMode) _showEditExitConfirm();
    else _showExitConfirm();
  }

  @override
  Widget build(BuildContext context) {
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
              title: const Text('Rebalancing',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              actions: [
                if (_editMode)
                  TextButton.icon(
                    onPressed: () => setState(() => _editMode = false),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text('완료',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            body: Stack(
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
                          itemCount: provider.portfolios.length + 1,
                          itemBuilder: (ctx, idx) {
                            if (idx == provider.portfolios.length) {
                              return _buildSlimAddCard(context);
                            }
                            return _buildCard(context, provider.portfolios[idx]);
                          },
                        ),
                ),
                // SpeedDial FAB (일반 모드에서만)
                if (!_editMode)
                  Positioned.fill(
                    child: SpeedDialFab(
                      key: const ValueKey('list_fab'),
                      items: [
                        SpeedDialItem(
                          icon: Icons.edit_outlined,
                          label: '편집',
                          onTap: () => setState(() => _editMode = true),
                        ),
                        SpeedDialItem(
                          icon: context.isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          label: context.isDark ? '라이트 모드' : '다크 모드',
                          onTap: () =>
                              context.read<ThemeNotifier>().toggle(context),
                        ),
                        SpeedDialItem(
                          icon: Icons.info_outline,
                          label: '공지사항',
                          onTap: () => DisclaimerDialog.showAlways(context),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
            Text('포트폴리오 추가',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF3B82F6))),
          ]),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Portfolio pf, {Key? key}) {
    final tv = pf.totalValue;

    if (_editMode) {
      return Card(
        key: key,
        color: context.cardBg,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(children: [
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
            const SizedBox(width: 4),
            Text(pf.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pf.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${pf.items.length}개 종목 · ${_fmt(tv, pf.currency)}',
                  style: TextStyle(fontSize: 13, color: context.textSecondary)),
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
        onTap: () => _openDetail(context, pf.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Text(pf.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pf.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${pf.items.length}개 종목 · ${_fmt(tv, pf.currency)}',
                  style: TextStyle(fontSize: 13, color: context.textSecondary)),
            ])),
            Icon(Icons.chevron_right, color: context.textHint),
          ]),
        ),
      ),
    );
  }
}
