import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'models/portfolio.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/asset_history_service.dart';
import 'services/settlement_service.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/stock_search_service.dart';
import 'services/notification_service.dart';
import 'widgets/disclaimer_dialog.dart';
import 'widgets/app_logo.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  StockSearchService.initialize();
  NotificationService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => PnlColorNotifier()),
        ChangeNotifierProvider(create: (_) => MainCurrencyNotifier()),
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
    final saved = prefs.getString('locale');
    if (saved != null) {
      // 저장된 값 있으면 그대로 사용
      _locale = Locale(saved);
    } else {
      // 첫 실행: 기기 언어가 한국어면 한국어, 아니면 영어
      final deviceLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _locale = Locale(deviceLang == 'ko' ? 'ko' : 'en');
    }
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

// ── 손익 색상 관리 ──

enum PnlColorScheme { greenRed, redBlue }

class PnlColorNotifier extends ChangeNotifier {
  PnlColorScheme _scheme = PnlColorScheme.greenRed;
  PnlColorScheme get scheme => _scheme;

  PnlColorNotifier() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('pnlColorScheme') == 'redBlue') {
      _scheme = PnlColorScheme.redBlue;
      notifyListeners();
    }
  }

  Future<void> setScheme(PnlColorScheme scheme) async {
    _scheme = scheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pnlColorScheme', scheme == PnlColorScheme.redBlue ? 'redBlue' : 'greenRed');
    notifyListeners();
  }

  /// 스킴별 색 — 설정 화면 미리보기도 이 값을 쓴다(정의는 여기 한 곳).
  static Color positiveOf(PnlColorScheme s) => s == PnlColorScheme.redBlue
      ? const Color(0xFFB85127)
      : const Color(0xFF0E7A52);

  static Color negativeOf(PnlColorScheme s) => s == PnlColorScheme.redBlue
      ? const Color(0xFF2A5C8A)
      : const Color(0xFFB85127);

  Color get positiveColor => positiveOf(_scheme);
  Color get negativeColor => negativeOf(_scheme);

  // ── 딥그린 헤더 위에서 쓰는 손익색 ──
  // 위 값들은 밝은 배경 기준이라 딥그린(#0E4F49) 위에서는 대비가 나온다.
  // 같은 색상 계열을 명도만 올려 대응시킨다.

  Color get onBrandPositive => _scheme == PnlColorScheme.redBlue
      ? const Color(0xFFE88C6A)
      : const Color(0xFF8FE7B0);

  Color get onBrandNegative => _scheme == PnlColorScheme.redBlue
      ? const Color(0xFF7FB5E0)
      : const Color(0xFFE88C6A);
}

// ── 메인페이지 기준 통화 관리 ──

class MainCurrencyNotifier extends ChangeNotifier {
  static const _key = 'main_currency';
  String _currency = 'KRW';
  String get currency => _currency;

  MainCurrencyNotifier() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_key) ?? 'KRW';
    notifyListeners();
  }

  Future<void> setCurrency(String c) async {
    _currency = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, c);
  }
}

// ── 앱 색상 확장 ──
// 라이트 전용. 다크 모드는 제공하지 않는다.

extension AppColors on BuildContext {
  // ── 배경 · 표면 ──
  Color get scaffoldBg => const Color(0xFFFBF8F1);   // 크림 배경
  Color get cardBg => Colors.white;
  Color get rowBg => const Color(0xFFF7F3EA);
  Color get fieldFill => const Color(0xFFF7F3EA);
  Color get infoBoxBg => const Color(0xFFF7F3EA);
  Color get subtleFill => const Color(0xFFF7F3EA);
  Color get trackBg => const Color(0xFFF2EDE1);      // 진행 막대 트랙 · 세그먼트
  Color get disabledFill => const Color(0xFFEFEADC);

  // ── 텍스트 ──
  Color get textPrimary => const Color(0xFF16130F);
  Color get textStrong => const Color(0xFF4A443B);   // 표 라벨 등 강한 보조
  Color get textSecondary => const Color(0xFF726B5F);
  Color get textTertiary => const Color(0xFF8A8478); // 기여도 · 부가 수치
  Color get textHint => const Color(0xFFA39B8C);
  Color get textDisabled => const Color(0xFFC3BCAC); // 비활성 · 미래 기간
  Color get sectionLabel => const Color(0xFF8A8478);

  // ── 선 ──
  Color get dividerColor => const Color(0xFFEFEADC); // 카드 안 행 구분선
  Color get borderColor => const Color(0xFFE4DECF);  // 카드 밖 경계
  Color get cardBorder => const Color(0xFFE4DECF);   // 카드 테두리 (크림 배경 대비 보강)

  // ── 브랜드 (딥 그린) ──
  Color get brand => const Color(0xFF0E4F49);        // AppBar · CTA · 선택
  Color get appBarBg => const Color(0xFF0E4F49);
  Color get brandOnLight => const Color(0xFF3D5C58); // 밝은 배경 위 브랜드 텍스트
  Color get brandTint => const Color(0xFFE6EEEC);    // 브랜드 옅은 배경
  Color get onBrandAccent => const Color(0xFF8FE7B0); // 딥그린 위 강조 숫자
  Color get onBrandSecondary => Colors.white.withValues(alpha: 0.72);
  Color get onBrandWarning => const Color(0xFFF2C36B);
  Color get highlightBg => const Color(0xFFE6EEEC);
  Color get highlightText => const Color(0xFF3D5C58);

  // ── 손익 배지 배경 (색 자체는 PnlColorNotifier를 통과시킬 것) ──
  Color get pnlUpTint => const Color(0xFFE6EEEC);
  Color get pnlDownTint => const Color(0xFFF7E4DA);

  // ── 주의 · 진행중 ──
  Color get warningBg => const Color(0xFFF5EEDF);
  Color get warningText => const Color(0xFF9C4A16);

  // 액션 카드 안쪽 글자 — 배경(warningBg · brandTint) 위에서 읽히도록
  // 시안이 따로 잡아 둔 값이다. textPrimary/textSecondary보다 배경에 가깝다.
  Color get onWarningTitle => const Color(0xFF4A3512);
  Color get onWarningBody => const Color(0xFF7A5F22);
  Color get onTintTitle => const Color(0xFF123D39);
  Color get onTintBody => const Color(0xFF3D5C58);
  Color get progressAccent => const Color(0xFFC08A3E); // 진행 중 기간 점 · 테두리
  /// 파괴적 액션 (앱 종료 · 삭제) 버튼 채움
  Color get danger => const Color(0xFFB85127);

  // ── 시장 칩 ──
  Color get chipKrText => const Color(0xFF1E4E6B);
  Color get chipKrBg => const Color(0xFFDCE9F0);
  Color get chipUsText => const Color(0xFF4C2A72);
  Color get chipUsBg => const Color(0xFFEBE4F3);
  Color get chipCashText => const Color(0xFF3F5218);
  Color get chipCashBg => const Color(0xFFE9EFDC);

  // ── 결산 차트 ──
  Color get barSettled => const Color(0xFFBFE3CF);    // 확정 기간
  Color get barSelected => const Color(0xFF0E4F49);   // 선택된 기간
  Color get barNegative => const Color(0xFFEED4C6);   // 손실 기간
  Color get barInProgress => const Color(0xFFA9CBBB); // 진행 중 (점선 테두리)
  Color get chartBaseline => const Color(0xFFE4DECF);
}

// ── 앱 ──

class RebalancingApp extends StatelessWidget {
  const RebalancingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return MaterialApp(
          title: 'Rebalancing',
          debugShowCheckedModeBanner: false,
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
              seedColor: const Color(0xFF0E4F49),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFFBF8F1),
            fontFamily: 'Pretendard',
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0E4F49),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Colors.white,
              elevation: 0,
              shadowColor: Color(0x0D16130F),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
            dividerTheme: const DividerThemeData(color: Color(0xFFEFEADC)),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.white
                      : const Color(0xFFFBF8F1)),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? const Color(0xFF0E4F49)
                      : const Color(0xFFEFEADC)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0E4F49)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF7F3EA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4DECF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4DECF)),
              ),
              hintStyle: const TextStyle(color: Color(0xFFA39B8C)),
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
  bool? _onboardingDone; // null = 아직 로딩 중

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _timerDone = true);
    });
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (mounted) setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    final loaded = context.watch<PortfolioProvider>().loaded;

    if (!_timerDone || !loaded || _onboardingDone == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E4F49),
        body: Center(child: AppLogo(iconSize: 38)),
      );
    }

    if (!_onboardingDone!) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }

    // 첫 전환 시 공지사항 팝업
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DisclaimerDialog.showIfNeeded(context);
    });

    return const MainShell();
  }
}

// ── 포트폴리오 Provider ──

class PortfolioProvider extends ChangeNotifier {
  List<Portfolio> _portfolios = [];
  bool _loaded = false;

  bool _refreshing = false;

  List<Portfolio> get portfolios => _portfolios;
  bool get loaded => _loaded;

  /// 시세 갱신 중 여부. 자산 탭과 리밸런싱 탭이 같은 상태를 본다.
  bool get refreshing => _refreshing;

  int _lastFailed = 0;
  int _lastTried = 0;

  /// 마지막 갱신에서 시세를 못 받은 종목 수.
  ///
  /// 실패해도 마지막 값을 유지하므로 화면의 숫자는 그대로 보인다.
  /// 그래서 **실패했다는 사실을 따로 알리지 않으면** 사용자는 낡은 시세를
  /// 최신인 줄 알고 판단한다. 돈이 걸린 화면에서 그건 그냥 거짓말이다.
  int get lastRefreshFailed => _lastFailed;

  /// 마지막 갱신에서 시도한 종목 수. 0이면 아직 갱신한 적이 없다.
  int get lastRefreshTried => _lastTried;

  /// 자동 설정된 환율·주가를 모두 갱신하고, 끝나면 총자산을 하루 한 점 기록한다.
  ///
  /// 두 탭이 같은 동작을 하므로 화면이 아니라 여기에 둔다.
  /// 실패한 종목은 건너뛰고 마지막 값을 유지한다 — 화면의 숫자를 비우지 않는다.
  Future<void> refreshAll() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();

    var failed = 0;
    var tried = 0;

    double? cachedRate;
    for (final pf in List<Portfolio>.from(_portfolios)) {
      if (pf.exchangeAuto) {
        cachedRate ??= await ApiService.fetchExchangeRate()
            .then((r) => r.ok ? r.data : null);
        if (cachedRate != null) {
          await updateSettings(pf.id, exchangeRate: cachedRate);
        }
      }
      if (pf.priceAuto) {
        for (final item in pf.items) {
          if (item.isCash || item.ticker.isEmpty) continue;
          tried++;
          final r = await ApiService.fetchStockPrice(item.ticker, item.market);
          if (r.ok && r.data != null) {
            await updateItem(
              pf.id,
              item.copyWith(
                currentPrice: r.data!.currentPrice,
                previousClose: r.data!.previousClose,
              ),
            );
          } else {
            failed++;
          }
        }
      }
      await updateLastRefreshed(pf.id);
    }

    _lastFailed = failed;
    _lastTried = tried;

    await _recordTotalAssets();

    _refreshing = false;
    notifyListeners();
  }

  /// 갱신 직후의 총자산(원화 환산)을 자산 추이 그래프의 재료로 남긴다.
  Future<void> _recordTotalAssets() async {
    if (!_portfolios.any((p) => p.hasPriceData)) return;
    final totalKrw = _portfolios.fold(0.0, (sum, pf) {
      final v = pf.totalValue;
      return sum + (pf.currency == 'USD' ? v * pf.exchangeRate : v);
    });
    await AssetHistoryService.record(totalKrw);

    // 포트별로도 남긴다 — 포트 상세 헤더의 추이가 이 기록을 쓴다
    final byId = <String, double>{};
    for (final pf in _portfolios) {
      if (!pf.hasPriceData) continue;
      final v = pf.totalValue;
      byId[pf.id] = pf.currency == 'USD' ? v * pf.exchangeRate : v;
    }
    await AssetHistoryService.recordPortfolios(byId);
  }

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
    // 거래·시세가 바뀌면 결산 계산 결과가 달라진다
    SettlementService.clearCache();
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

  Future<void> replaceAll(List<Portfolio> portfolios) async {
    _portfolios = portfolios;
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

  // ── 거래 내역 관리 ──

  static double _recalcAvgPrice(List<StockTransaction> txs) {
    double totalCost = 0;
    double totalQty = 0;
    for (final t in txs) {
      if (t.quantity > 0) {
        totalCost += t.quantity * t.price;
        totalQty += t.quantity;
      }
    }
    return totalQty > 0 ? totalCost / totalQty : 0;
  }

  Future<void> upsertTransaction(
      String pfId, String itemId, StockTransaction tx) async {
    final pf = getPortfolio(pfId);
    if (pf == null) return;
    final idx = pf.items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final item = pf.items[idx];
    final txs = List<StockTransaction>.from(item.transactions);
    final existing = txs.indexWhere((t) => t.id == tx.id);
    if (existing != -1) {
      txs[existing] = tx;
    } else {
      txs.add(tx);
    }
    txs.sort((a, b) => a.date.compareTo(b.date));
    final newShares = txs.fold(0.0, (s, t) => s + t.quantity);
    final newAvg = _recalcAvgPrice(txs);
    pf.items[idx] = item.copyWith(
        transactions: txs, shares: newShares, avgPrice: newAvg);
    await _save();
  }

  Future<void> deleteTransaction(
      String pfId, String itemId, String txId) async {
    final pf = getPortfolio(pfId);
    if (pf == null) return;
    final idx = pf.items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final item = pf.items[idx];
    final txs = item.transactions.where((t) => t.id != txId).toList();
    final newShares = txs.fold(0.0, (s, t) => s + t.quantity);
    final newAvg = _recalcAvgPrice(txs);
    pf.items[idx] = item.copyWith(
        transactions: txs, shares: newShares, avgPrice: newAvg);
    await _save();
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
    double? rebalancingThreshold,
    bool? fractionalEnabled,
    FractionalRounding? fractionalRounding,
  }) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      if (currency != null) pf.currency = currency;
      if (commissionRate != null) pf.commissionRate = commissionRate;
      if (commissionEnabled != null) pf.commissionEnabled = commissionEnabled;
      if (exchangeRate != null) pf.exchangeRate = exchangeRate;
      if (exchangeAuto != null) pf.exchangeAuto = exchangeAuto;
      if (priceAuto != null) pf.priceAuto = priceAuto;
      if (rebalancingThreshold != null) pf.rebalancingThreshold = rebalancingThreshold;
      if (fractionalEnabled != null) pf.fractionalEnabled = fractionalEnabled;
      if (fractionalRounding != null) pf.fractionalRounding = fractionalRounding;
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
        if (r['newAvgPrice'] != null) {
          item.avgPrice = (r['newAvgPrice'] as num).toDouble();
        }
      }
      pf.additionalInvestment = residualCash;
      await _save();
    }
  }

  Future<void> updateCashAndResidual(
    String pfId,
    List<Map<String, dynamic>> cashItems,
    double residualCash,
  ) async {
    final pf = getPortfolio(pfId);
    if (pf == null) return;
    for (final r in cashItems) {
      final idx = pf.items.indexWhere((i) => i.id == r['id']);
      if (idx == -1) continue;
      pf.items[idx].shares = (r['newShares'] as num).toDouble();
    }
    pf.additionalInvestment = residualCash;
    await _save();
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
