import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portfolio.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/design_system.dart';
import '../widgets/brand_header.dart';
import '../widgets/disclaimer_dialog.dart';
import '../widgets/notification_settings_dialog.dart';
import 'fractional_settings_screen.dart';

/// 더보기 탭 (v23a).
///
/// **값이 있는 설정은 현재 값을 오른쪽에 적는다.** 눌러야 확인되는 설정은
/// 목록으로 둘 이유가 없기 때문이다. 설명 문구는 값으로 대신할 수 있으면 넣지 않는다.
class MoreScreen extends StatefulWidget {
  /// 다른 탭으로 보내기 위한 콜백 (MainShell이 넘긴다)
  final void Function(int index)? onNavigateToTab;

  const MoreScreen({super.key, this.onNavigateToTab});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _notifEnabled = false;
  String _notifFreq = 'weekly';
  List<String> _settlementNotifs = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifState();
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  /// 알림 상태는 SharedPreferences에 있어 목록에 값을 적으려면 미리 읽어야 한다
  Future<void> _loadNotifState() async {
    final enabled = await NotificationService.isEnabled();
    final freq = await NotificationService.getFrequency();
    final types = <String>[];
    for (final t in ['weekly', 'monthly', 'quarterly', 'yearly']) {
      if (await NotificationService.isSettlementEnabled(t)) types.add(t);
    }
    if (!mounted) return;
    setState(() {
      _notifEnabled = enabled;
      _notifFreq = freq;
      _settlementNotifs = types;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final portfolios = provider.portfolios;

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          body: Column(
            children: [
              // 이 탭만 총자산 없이 제목 한 줄로 시작한다
              BrandHeader(title: l10n.tabMore),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _group(context, _isKo ? '포트폴리오' : 'Portfolios', [
                      _row(
                        context,
                        label: _isKo ? '포트폴리오 · 종목 관리' : 'Portfolios & holdings',
                        value: _isKo
                            ? '${portfolios.length}개'
                            : '${portfolios.length}',
                        onTap: () => widget.onNavigateToTab?.call(0),
                      ),
                      _row(
                        context,
                        label: _isKo ? '목표 비중 · 허용 편차' : 'Targets & tolerance',
                        value: _toleranceSummary(portfolios),
                        onTap: () => widget.onNavigateToTab?.call(1),
                      ),
                      // 계좌별 설정이라는 게 목록에서 드러나야 한다 (시안 v23a)
                      _row(
                        context,
                        label: context.l10n.fractionalTrading,
                        value: _fractionalSummary(portfolios),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FractionalSettingsScreen(),
                          ),
                        ),
                      ),
                    ]),

                    _group(context, _isKo ? '표시' : 'Display', [
                      _row(
                        context,
                        label: l10n.language,
                        value: _isKo ? '한국어' : 'English',
                        onTap: _pickLanguage,
                      ),
                      _row(
                        context,
                        label: _isKo ? '손익 색상' : 'P&L color',
                        value: context.watch<PnlColorNotifier>().scheme ==
                                PnlColorScheme.greenRed
                            ? (_isKo ? '+초록 / −빨강' : '+green / −red')
                            : (_isKo ? '+빨강 / −파랑' : '+red / −blue'),
                        onTap: _pickPnlScheme,
                      ),
                      _row(
                        context,
                        label: l10n.baseCurrency,
                        value: context.watch<MainCurrencyNotifier>().currency ==
                                'KRW'
                            ? l10n.currencyKRW
                            : l10n.currencyUSD,
                        onTap: _pickCurrency,
                      ),
                    ]),

                    _group(context, _isKo ? '결산 · 알림' : 'Returns & alerts', [
                      _row(
                        context,
                        label: l10n.notifReminder,
                        value: _notifEnabled
                            ? (_notifFreq == 'weekly'
                                ? l10n.notifWeekly
                                : l10n.notifMonthly)
                            : (_isKo ? '꺼짐' : 'Off'),
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => const NotificationSettingsDialog(),
                          );
                          _loadNotifState();
                        },
                      ),
                      _row(
                        context,
                        label: l10n.settlementNotifHeader,
                        value: _settlementNotifSummary(l10n),
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => const NotificationSettingsDialog(),
                          );
                          _loadNotifState();
                        },
                      ),
                    ]),

                    _group(context, _isKo ? '데이터 · 앱' : 'Data & app', [
                      _row(
                        context,
                        label: l10n.backupData,
                        value: 'JSON',
                        onTap: _backup,
                      ),
                      _row(
                        context,
                        label: l10n.restoreData,
                        value: _isKo ? '파일에서' : 'From file',
                        onTap: _restore,
                      ),
                      _row(
                        context,
                        label: l10n.notice,
                        value: '',
                        onTap: () => DisclaimerDialog.showAlways(context),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 값 요약 ──

  /// `2개 계좌` — 켜진 계좌 수. 꺼져 있으면 `사용 안 함`.
  String _fractionalSummary(List<Portfolio> portfolios) {
    final on = portfolios.where((p) => p.fractionalEnabled).length;
    if (on == 0) return _isKo ? '사용 안 함' : 'Off';
    return _isKo ? '$on개 계좌' : '$on accounts';
  }

  /// 허용 편차는 포트별 설정이라 값이 다르면 대표값을 쓰지 않는다
  String _toleranceSummary(List<Portfolio> portfolios) {
    if (portfolios.isEmpty) return '—';
    final values = portfolios.map((p) => p.rebalancingThreshold).toSet();
    if (values.length == 1) {
      final v = values.first;
      final s = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(1);
      return _isKo ? '±$s%p' : '±${s}pp';
    }
    return _isKo ? '포트별 다름' : 'Varies';
  }

  String _settlementNotifSummary(dynamic l10n) {
    if (_settlementNotifs.isEmpty) return _isKo ? '꺼짐' : 'Off';
    // 넷을 다 나열하면 잘린다 — 전부 켜져 있으면 한 단어로 줄인다
    if (_settlementNotifs.length == 4) return _isKo ? '전체' : 'All';
    final names = {
      'weekly': l10n.settlementWeekly,
      'monthly': l10n.settlementMonthly,
      'quarterly': l10n.settlementQuarterly,
      'yearly': l10n.settlementYearly,
    };
    return _settlementNotifs.map((t) => names[t]).join(' · ');
  }

  // ── 목록 조각 ──

  Widget _group(BuildContext context, String label, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
            child: Text(
              label,
              style: TextStyle(
                  fontSize: DS.groupLabel,
                  fontWeight: FontWeight.w800,
                  color: context.sectionLabel),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(DS.listCardRadius),
              border: Border.all(color: context.cardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DS.cardPaddingH),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  DecoratedBox(
                    decoration: i == rows.length - 1
                        ? const BoxDecoration()
                        : BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: context.dividerColor))),
                    child: rows[i],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String value,
    String? sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: sub == null ? DS.minTouch : 56,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(
                          fontSize: DS.body,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (value.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: DS.returnPct,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 18, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  // ── 선택 시트 ──

  Future<void> _pickSheet({
    required String title,
    required List<({String label, bool selected, VoidCallback onTap})> options,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, MediaQuery.of(sheetCtx).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6CFBC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(DS.listCardRadius),
                border: Border.all(color: context.cardBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: DS.cardPaddingH),
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++)
                    DecoratedBox(
                      decoration: i == options.length - 1
                          ? const BoxDecoration()
                          : BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: context.dividerColor))),
                      child: InkWell(
                        onTap: () {
                          options[i].onTap();
                          Navigator.pop(sheetCtx);
                        },
                        child: SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(options[i].label,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimary)),
                              ),
                              if (options[i].selected)
                                Icon(Icons.check,
                                    size: 18, color: context.brand),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickLanguage() {
    final provider = context.read<LocaleProvider>();
    final code = provider.locale.languageCode;
    _pickSheet(
      title: context.l10n.language,
      options: [
        (
          label: '한국어',
          selected: code == 'ko',
          onTap: () => provider.setLocale(const Locale('ko')),
        ),
        (
          label: 'English',
          selected: code == 'en',
          onTap: () => provider.setLocale(const Locale('en')),
        ),
      ],
    );
  }

  void _pickPnlScheme() {
    final notifier = context.read<PnlColorNotifier>();
    _pickSheet(
      title: _isKo ? '손익 색상' : 'P&L color',
      options: [
        (
          label: _isKo ? '+초록 / −빨강' : '+green / −red',
          selected: notifier.scheme == PnlColorScheme.greenRed,
          onTap: () => notifier.setScheme(PnlColorScheme.greenRed),
        ),
        (
          label: _isKo ? '+빨강 / −파랑' : '+red / −blue',
          selected: notifier.scheme == PnlColorScheme.redBlue,
          onTap: () => notifier.setScheme(PnlColorScheme.redBlue),
        ),
      ],
    );
  }

  void _pickCurrency() {
    final l10n = context.l10n;
    final notifier = context.read<MainCurrencyNotifier>();
    _pickSheet(
      title: l10n.baseCurrency,
      options: [
        (
          label: l10n.currencyKRW,
          selected: notifier.currency == 'KRW',
          onTap: () => notifier.setCurrency('KRW'),
        ),
        (
          label: l10n.currencyUSD,
          selected: notifier.currency == 'USD',
          onTap: () => notifier.setCurrency('USD'),
        ),
      ],
    );
  }

  // ── 백업 · 복원 ──

  Future<void> _backup() async {
    final l10n = context.l10n;
    final portfolios = context.read<PortfolioProvider>().portfolios;
    try {
      await StorageService.exportPortfolios(portfolios);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    }
  }

  Future<void> _restore() async {
    final l10n = context.l10n;
    try {
      final portfolios = await StorageService.importPortfolios();
      if (portfolios == null || !mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(l10n.restoreConfirmTitle),
          content: Text(l10n.restoreConfirmContent(portfolios.length)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel)),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.confirm)),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      await context.read<PortfolioProvider>().replaceAll(portfolios);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.restoreSuccess(portfolios.length))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.restoreFailed)));
    }
  }
}
