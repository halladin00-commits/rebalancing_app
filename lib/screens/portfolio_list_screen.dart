import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../widgets/portfolio_form_dialog.dart';
import '../widgets/disclaimer_dialog.dart';
import '../widgets/speed_dial_fab.dart';
import '../widgets/app_logo.dart';
import '../services/ad_service.dart';
import 'portfolio_detail_screen.dart';

class PortfolioListScreen extends StatefulWidget {
  const PortfolioListScreen({super.key});
  @override
  State<PortfolioListScreen> createState() => _PortfolioListScreenState();
}

class _PortfolioListScreenState extends State<PortfolioListScreen> {
  bool _editMode = false;

  // ── 광고 ──
  BannerAd? _mainBanner;
  bool _mainBannerLoaded = false;
  BannerAd? _exitBanner;
  bool _exitBannerLoaded = false;

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  void _loadAds() {
    _mainBanner = AdService.createBanner(
      adUnitId: AdService.mainBannerId,
      size: AdSize.banner,
      onLoaded: () { if (mounted) setState(() => _mainBannerLoaded = true); },
      onFailed: () { _mainBanner = null; },
    );
    _exitBanner = AdService.createBanner(
      adUnitId: AdService.exitBannerId,
      size: AdSize.mediumRectangle,
      onLoaded: () { if (mounted) setState(() => _exitBannerLoaded = true); },
      onFailed: () { _exitBanner = null; },
    );
  }

  @override
  void dispose() {
    _mainBanner?.dispose();
    _exitBanner?.dispose();
    super.dispose();
  }

  String _fmt(double n, String cur) {
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'  ;
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

  void _showLanguageDialog(BuildContext context) {
    final l10n = context.l10n;
    final localeProvider = context.read<LocaleProvider>();
    final current = localeProvider.locale.languageCode;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(l10n.language, style: TextStyle(color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langTile(context, '한국어', 'ko', current, localeProvider),
            _langTile(context, 'English', 'en', current, localeProvider),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Widget _langTile(BuildContext context, String label, String code,
      String current, LocaleProvider provider) {
    final selected = current == code;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: context.textPrimary)),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
      onTap: () {
        provider.setLocale(Locale(code));
        Navigator.pop(context);
      },
    );
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
                if (_editMode)
                  TextButton.icon(
                    onPressed: () => setState(() => _editMode = false),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: Text(l10n.done,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                          itemCount: provider.portfolios.length + 1,
                          itemBuilder: (ctx, idx) {
                            if (idx == provider.portfolios.length) {
                              return _buildSlimAddCard(context);
                            }
                            return _buildCard(context, provider.portfolios[idx]);
                          },
                        ),
                ),
                if (!_editMode)
                  Positioned.fill(
                    child: SpeedDialFab(
                      key: const ValueKey('list_fab'),
                      bottomOffset: _mainBannerLoaded ? 50 : 0,
                      items: [
                        SpeedDialItem(
                          icon: Icons.edit_outlined,
                          label: l10n.edit,
                          onTap: () => setState(() => _editMode = true),
                        ),
                        SpeedDialItem(
                          icon: context.isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          label: context.isDark ? l10n.lightMode : l10n.darkMode,
                          onTap: () =>
                              context.read<ThemeNotifier>().toggle(context),
                        ),
                        SpeedDialItem(
                          icon: Icons.language_outlined,
                          label: l10n.language,
                          onTap: () => _showLanguageDialog(context),
                        ),
                        SpeedDialItem(
                          icon: Icons.info_outline,
                          label: l10n.notice,
                          onTap: () => DisclaimerDialog.showAlways(context),
                        ),
                      ],
                    ),
                  ),
                // ── 하단 배너 광고 ──
                if (_mainBannerLoaded && _mainBanner != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Container(
                        color: context.scaffoldBg,
                        alignment: Alignment.center,
                        width: _mainBanner!.size.width.toDouble(),
                        height: _mainBanner!.size.height.toDouble(),
                        child: AdWidget(ad: _mainBanner!),
                      ),
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
              Text(subtitle, style: TextStyle(fontSize: 13, color: context.textSecondary)),
            ])),
            Icon(Icons.chevron_right, color: context.textHint),
          ]),
        ),
      ),
    );
  }
}
