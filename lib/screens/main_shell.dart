import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../services/ad_service.dart';
import '../theme/design_system.dart';
import '../widgets/bottom_banner_ad.dart';
import '../widgets/brand_header.dart';
import 'portfolio_list_screen.dart';
import 'all_settlement_screen.dart';

/// 앱의 최상위 셸 — 하단 4탭(자산 / 리밸런싱 / 결산 / 더보기).
///
/// - `IndexedStack`으로 각 탭의 상태를 보존한다(결산 탭의 기간 선택 등).
/// - 배너 광고는 하단 탭바 **바로 위**에 고정한다.
/// - 시스템 뒤로가기는 여기 한 곳에서 처리한다.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _listKey = GlobalKey<PortfolioListScreenState>();

  // 종료 확인 팝업에 붙는 광고
  BannerAd? _exitBanner;
  bool _exitBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadExitAd();
  }

  void _loadExitAd() {
    _exitBanner = AdService.createBanner(
      adUnitId: AdService.exitBannerId,
      size: AdSize.mediumRectangle,
      onLoaded: () {
        if (mounted) setState(() => _exitBannerLoaded = true);
      },
      onFailed: () {
        _exitBanner = null;
      },
    );
  }

  @override
  void dispose() {
    _exitBanner?.dispose();
    super.dispose();
  }

  // ── 뒤로가기 ──

  void _handleBackPress() {
    // 1) 자산 탭이 편집 모드면 편집 종료를 먼저 확인
    final listState = _listKey.currentState;
    if (_index == 0 && listState != null && listState.isEditMode) {
      listState.confirmExitEdit();
      return;
    }
    // 2) 다른 탭이면 자산 탭으로
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    // 3) 자산 탭이면 앱 종료 확인
    _showExitConfirm();
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
              Text(
                l10n.appExitContent,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
              ),
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
                      backgroundColor: context.danger,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final portfolios = context.watch<PortfolioProvider>().portfolios;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: IndexedStack(
          index: _index,
          children: [
            PortfolioListScreen(key: _listKey),
            // 3단계에서 채운다 — 허용 편차 연동이 선행되어야 한다.
            _PlaceholderTab(title: l10n.tabRebalancing),
            AllSettlementScreen(portfolios: portfolios),
            // 5단계에서 채운다.
            _PlaceholderTab(title: l10n.tabMore),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomBannerAd(),
            _buildNavBar(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, AppLocalizations l10n) {
    const icons = [
      Icons.account_balance_wallet_outlined,
      Icons.balance_outlined,
      Icons.bar_chart_outlined,
      Icons.more_horiz,
    ];
    final labels = [
      l10n.tabAssets,
      l10n.tabRebalancing,
      l10n.tabSettlement,
      l10n.tabMore,
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: DS.bottomNavHeight,
          child: Row(
            children: List.generate(icons.length, (i) {
              final selected = _index == i;
              final color = selected ? context.brand : context.textSecondary;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _index = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icons[i], size: DS.navIcon, color: color),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: DS.navLabel,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// 아직 구현하지 않은 탭 자리. 3·5단계에서 실제 화면으로 교체한다.
class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(
        children: [
          BrandHeader(title: title),
          Expanded(
            child: Center(
              child: Text(
                Localizations.localeOf(context).languageCode == 'ko'
                    ? '준비 중'
                    : 'Coming soon',
                style: TextStyle(
                    fontSize: DS.rowName,
                    fontWeight: FontWeight.w600,
                    color: context.textHint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
