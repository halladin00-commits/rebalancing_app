import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'models/portfolio.dart';
import 'services/storage_service.dart';
import 'screens/portfolio_list_screen.dart';
import 'services/stock_search_service.dart';
import 'widgets/disclaimer_dialog.dart';
import 'widgets/app_logo.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  StockSearchService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const RebalancingApp(),
    ),
  );
}

// ── 언어 관리 ──

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ko');
  Locale get locale => _locale;

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale') ?? 'ko';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    notifyListeners();
  }
}

// ── l10n 편의 Extension ──

extension L10nExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// ── 테마 관리 ──

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('themeMode') ?? 'system';
    _mode = v == 'dark'
        ? ThemeMode.dark
        : v == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system',
    );
    notifyListeners();
  }

  void toggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

// ── 앱 색상 확장 ──

extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get scaffoldBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get panelBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get rowBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get fieldFill =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
  Color get disabledFill =>
      isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
  Color get infoBoxBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  Color get textPrimary =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
  Color get textHint =>
      isDark ? const Color(0xFF475569) : Colors.grey.shade400;

  Color get borderColor =>
      isDark ? const Color(0xFF334155) : Colors.grey.shade300;
  Color get dividerColor =>
      isDark ? const Color(0xFF334155) : Colors.grey.shade200;
  Color get sectionLabel =>
      isDark ? const Color(0xFF64748B) : Colors.grey.shade400;

  Color get appBarBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);

  Color get warningBg =>
      isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
  Color get warningText =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);

  Color get highlightBg =>
      isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);
  Color get highlightText =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
}

// ── 앱 ──

class RebalancingApp extends StatelessWidget {
  const RebalancingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeNotifier, LocaleProvider>(
      builder: (context, themeNotifier, localeProvider, _) {
        return MaterialApp(
          title: 'Rebalancing',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.mode,
          locale: localeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ko'),
            Locale('en'),
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            fontFamily: 'Pretendard',
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Colors.white,
              elevation: 1,
              shadowColor: Color(0x18000000),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            fontFamily: 'Pretendard',
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF1E293B),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            dialogTheme:
                const DialogThemeData(backgroundColor: Color(0xFF1E293B)),
            dividerTheme:
                const DividerThemeData(color: Color(0xFF334155)),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF3B82F6);
                }
                return const Color(0xFF64748B);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF1D4ED8);
                }
                return const Color(0xFF334155);
              }),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF60A5FA)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              hintStyle: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          home: const _AppEntryPoint(),
        );
      },
    );
  }
}

// ── 첫 실행 처리 ──

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();
  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool _timerDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _timerDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loaded = context.watch<PortfolioProvider>().loaded;

    // 타이머 완료 AND 데이터 로드 완료 둘 다 충족돼야 메인 화면으로 전환
    if (!_timerDone || !loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: AppLogo(iconSize: 38)),
      );
    }

    // 첫 전환 시 공지사항 팝업
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DisclaimerDialog.showIfNeeded(context);
    });

    return const PortfolioListScreen();
  }
}

// ── 포트폴리오 Provider ──

class PortfolioProvider extends ChangeNotifier {
  List<Portfolio> _portfolios = [];
  bool _loaded = false;

  List<Portfolio> get portfolios => _portfolios;
  bool get loaded => _loaded;

  PortfolioProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    _portfolios = await StorageService.loadPortfolios();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await StorageService.savePortfolios(_portfolios);
    notifyListeners();
  }

  Future<void> addPortfolio(Portfolio pf) async {
    _portfolios.add(pf);
    await _save();
  }

  Future<void> updatePortfolio(String id, Portfolio updated) async {
    final idx = _portfolios.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _portfolios[idx] = updated;
      await _save();
    }
  }

  Future<void> deletePortfolio(String id) async {
    _portfolios.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<void> reorderPortfolios(List<Portfolio> newOrder) async {
    _portfolios = newOrder;
    await _save();
  }

  Portfolio? getPortfolio(String id) {
    try {
      return _portfolios.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addItem(String pfId, PortfolioItem item) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.items.add(item);
      await _save();
    }
  }

  Future<void> updateItem(String pfId, PortfolioItem item) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      final idx = pf.items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        pf.items[idx] = item;
        await _save();
      }
    }
  }

  Future<void> deleteItem(String pfId, String itemId) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.items.removeWhere((i) => i.id == itemId);
      await _save();
    }
  }

  Future<void> reorderItems(String pfId, List<PortfolioItem> newOrder) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.items = newOrder;
      await _save();
    }
  }

  Future<void> updateSettings(
    String pfId, {
    String? currency,
    double? commissionRate,
    bool? commissionEnabled,
    double? exchangeRate,
    bool? exchangeAuto,
    bool? priceAuto,
    bool? compactAmount,
  }) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      if (currency != null) pf.currency = currency;
      if (commissionRate != null) pf.commissionRate = commissionRate;
      if (commissionEnabled != null) pf.commissionEnabled = commissionEnabled;
      if (exchangeRate != null) pf.exchangeRate = exchangeRate;
      if (exchangeAuto != null) pf.exchangeAuto = exchangeAuto;
      if (priceAuto != null) pf.priceAuto = priceAuto;
      if (compactAmount != null) pf.compactAmount = compactAmount;
      await _save();
    }
  }

  Future<void> setAdditionalInvestment(String pfId, double amount) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.additionalInvestment = amount;
      await _save();
    }
  }

  Future<void> applyRebalancing(
    String pfId,
    List<Map<String, dynamic>> results,
    double residualCash,
  ) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      for (final r in results) {
        final item = pf.items.firstWhere((i) => i.id == r['id']);
        item.shares = (r['newShares'] as num).toDouble();
      }
      pf.additionalInvestment = residualCash;
      await _save();
    }
  }

  Future<void> updateLastRefreshed(String pfId) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.lastUpdated = DateTime.now().millisecondsSinceEpoch;
      await _save();
    }
  }

  void refresh() => notifyListeners();
}
