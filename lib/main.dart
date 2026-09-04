import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'models/portfolio.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/asset_backfill_service.dart';
import 'services/asset_history_service.dart';
import 'services/settlement_service.dart';
import 'services/undo_service.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/stock_search_service.dart';
import 'services/notification_service.dart';
import 'widgets/disclaimer_dialog.dart';
import 'widgets/app_logo.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // **세로로 고정한다.** 가로로 돌리면 자산 탭 헤더가 화면을 다 먹고
  // `BOTTOM OVERFLOWED BY 69 PIXELS`와 함께 포트폴리오 목록이 사라진다.
  // 이 앱은 세로로 긴 목록을 훑는 도구라 가로 레이아웃을 따로 만들 이유가
  // 없다. 태블릿 대응을 하게 되면 그때 푼다.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
        ChangeNotifierProvider(create: (_) => PortfolioSortNotifier()),
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

/// 자산 탭에서 포트폴리오를 어떤 순서로 보일지 (시안 v16c).
///
/// `manual`은 사용자가 직접 끌어다 놓은 순서다. 금액이 바뀌어도 그대로 둔다 —
/// 정렬 규칙을 골라 두면 자리가 계속 움직여서 어느 포트가 어디 있는지
/// 외울 수가 없다. 그걸 원하지 않는 사람을 위해 직접 배치를 한 축으로 뒀다.
enum PortfolioSort { manual, value, returnRate }

class PortfolioSortNotifier extends ChangeNotifier {
  static const _key = 'portfolio_sort';
  PortfolioSort _sort = PortfolioSort.manual;
  PortfolioSort get sort => _sort;

  PortfolioSortNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _sort = PortfolioSort.values.firstWhere((e) => e.name == saved,
        orElse: () => PortfolioSort.manual);
    notifyListeners();
  }

  Future<void> setSort(PortfolioSort s) async {
    _sort = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, s.name);
  }
}

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

  /// 편차 막대에서 **허용 편차 안**인 구간.
  ///
  /// 트랙 배경(trackBg)과 같은 색을 쓰면 모두 정상일 때 막대가 통째로 비어
  /// 보인다 — 종목이 몇 개인지도, 무엇을 보라는 건지도 알 수 없다.
  /// 경고색·브랜드색을 이기지 않으면서 「점검했고 괜찮다」로 읽히는 톤.
  Color get weightOkFill => const Color(0xFFA9C7BF);
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
          // **넓은 화면에서는 폭을 묶는다.**
          //
          // 태블릿(800dp)에서 그대로 늘리면 목록 한 줄이 화면을 가로질러,
          // 왼쪽 끝 종목명과 오른쪽 끝 금액 사이가 텅 빈다. 눈이 한 줄을
          // 따라가느라 읽기가 더 어려워진다 — 넓어서 좋을 게 없는 화면이다.
          //
          // 이 앱은 세로로 긴 목록을 훑는 도구다. 폰에서 잘 읽히는 폭
          // (560dp)을 넘지 않게 가운데로 모으고, 남는 자리는 배경으로 둔다.
          // 폰에서는 화면이 이보다 좁아 아무것도 달라지지 않는다.
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return ColoredBox(
              color: const Color(0xFFFBF8F1),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: child,
                ),
              ),
            );
          },
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

  bool _promptsDone = false;

  /// 첫 실행에 물어볼 것들. 순서가 있다 — 면책 고지를 먼저 받고 알림을 묻는다.
  ///
  /// 알림 권한은 **여기서 한 번** 묻는다. 예전에는 안 묻고 기본값만 켜 뒀는데,
  /// 그러면 설정 화면은 켜져 있다고 하면서 알림은 한 번도 오지 않는다.
  /// 껐다 다시 켜야 시스템이 물어보는 게 유일한 방법이었다.
  Future<void> _firstRunPrompts() async {
    if (_promptsDone) return;
    _promptsDone = true;
    if (!mounted) return;
    await DisclaimerDialog.showIfNeeded(context);
    await NotificationService.setUpOnFirstRun();
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

    // 첫 전환 시 공지사항 팝업 → 그다음 알림 권한
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRunPrompts());

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

  bool _backfilling = false;

  /// 자산 추이의 빈 날을 메우는 중인가. 화면은 이걸 보고 `업데이트 중`을 띄운다.
  bool get backfilling => _backfilling;

  /// 메우기가 끝날 때마다 오르는 번호. 화면이 기록을 다시 읽는 신호다.
  int _historySeq = 0;
  int get historySeq => _historySeq;

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
        final targets = pf.items
            .where((i) => !i.isCash && i.ticker.isNotEmpty)
            .toList();
        tried += targets.length;

        // 종목마다 순서대로 기다리면 **종목 수만큼 왕복이 쌓인다** —
        // 10종목이면 앱을 켤 때마다 그 시간을 전부 기다린다.
        //
        // 그렇다고 전부 한꺼번에 던지지는 않는다. 이 코드는 앱을 열 때마다
        // 도는데, 한도에 걸려 몇 종목이 실패하면 사용자가 매번
        // `2종목 시세를 못 받았습니다`를 보게 된다. 4개씩 나눠 받는다 —
        // 직렬보다 4배 빠르면서 한 번에 던지는 요청은 4개를 넘지 않는다.
        const lanes = 4;
        final fetched = <({PortfolioItem item, ApiResult<StockPriceData> r})>[];
        for (var i = 0; i < targets.length; i += lanes) {
          final chunk = targets.skip(i).take(lanes);
          fetched.addAll(await Future.wait(chunk.map((item) async =>
              (item: item, r: await ApiService.fetchStockPrice(
                  item.ticker, item.market)))));
        }

        // 받아온 값은 **메모리에만** 반영한다. 종목마다 저장하면 열두 종목이면
        // 파일을 열두 번 쓰고 화면을 열두 번 다시 그린다. 저장은 마지막에 한 번.
        for (final f in fetched) {
          if (f.r.ok && f.r.data != null) {
            final idx = pf.items.indexWhere((i) => i.id == f.item.id);
            if (idx != -1) {
              pf.items[idx] = pf.items[idx].copyWith(
                currentPrice: f.r.data!.currentPrice,
                previousClose: f.r.data!.previousClose,
              );
            }
          } else {
            failed++;
          }
        }
      }
      pf.lastUpdated = DateTime.now().millisecondsSinceEpoch;
    }
    // 시세만 바뀌었다 — 결산 캐시는 그대로 둔다
    await _save(settlementAffected: false);

    _lastFailed = failed;
    _lastTried = tried;

    await _recordTotalAssets();

    _refreshing = false;
    notifyListeners();

    // 안 켠 날의 자산도 채운다. 기다리지 않는다 — 시세는 이미 화면에 있고,
    // 추이는 채워지는 대로 다시 그리면 된다.
    unawaited(_backfillHistory());
  }

  /// 앱을 켜지 않은 날의 자산을 거래 내역 + 과거 종가로 계산해 채운다.
  ///
  /// 기록만 쌓는 방식은 선을 **접속 기록**으로 만든다. 며칠 쉬면 그 사이가
  /// 통째로 비고, 앱 구조를 모르는 사람에게는 데이터가 사라진 것으로 보인다.
  Future<void> _backfillHistory() async {
    if (_backfilling) return;
    final pending = await AssetBackfillService.pendingRange(_portfolios);
    if (pending == null) return;

    _backfilling = true;
    notifyListeners();
    try {
      final filled = await AssetBackfillService.run(_portfolios);
      if (filled > 0) _historySeq++;
    } catch (_) {
      // 못 채워도 기록은 그대로다 — 다음 새로고침에 다시 시도한다
    }
    _backfilling = false;
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

  /// 저장하고 알린다.
  ///
  /// [settlementAffected]가 참이면 결산 캐시를 비운다. **시세가 바뀐 것만으로는
  /// 비우지 않는다** — 지난 기간의 결산은 그때의 과거 종가로 계산하므로 지금
  /// 시세와 무관하고, 진행 중인 기간은 애초에 캐시하지 않는다.
  ///
  /// 예전에는 무조건 비웠다. 새로고침 한 번이 종목 수만큼 `_save()`를 부르니
  /// 앱을 열 때마다 캐시가 열두 번 날아갔고, 결산 탭은 매번 12개월치를 처음부터
  /// 다시 받아 계산했다.
  Future<void> _save({bool settlementAffected = true}) async {
    await StorageService.savePortfolios(_portfolios);
    if (settlementAffected) SettlementService.clearCache();
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

  /// 백업 파일로 데이터를 통째로 갈아끼운다 (복원).
  ///
  /// 백업에는 **백업을 뜬 시점의 현재가**가 같이 들어 있다. 그대로 두면
  /// 자산 화면이 며칠 전 가격으로 총자산을 보여주고, 결산은 그 가격을
  /// 진행 중인 기간의 끝값으로 써서 손익 부호까지 뒤집힌다.
  /// 시세 자동 갱신은 자산 탭이 처음 뜰 때 한 번만 도는 터라, 복원으로는
  /// 다시 돌지 않는다 — 여기서 직접 받는다.
  ///
  /// 결산 캐시도 비운다. 캐시 키가 포트 id라 같은 id로 다른 데이터가
  /// 들어오면 옛 계산 결과가 그대로 붙는다.
  Future<void> replaceAll(List<Portfolio> portfolios) async {
    _portfolios = portfolios;
    SettlementService.clearCache();
    // 자산 추이 기록은 옛 포트의 것이다. 메운 표시도 같이 지워 다시 채우게 한다.
    await AssetHistoryService.clear();
    await AssetBackfillService.reset();
    await _save();
    // 기다리지 않는다 — 복원한 목록은 바로 보여주고, 시세는 들어오는 대로
    // 갈아끼운다. 여기서 기다리면 확인을 누른 뒤 십수 초 동안 아무 일도
    // 일어나지 않는 것처럼 보인다.
    unawaited(refreshAll());
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

  /// 묶음 하나를 통째로 되돌린다.
  ///
  /// 되돌릴 수 없는 것을 조용히 넘기지 않는다 — 이미 사용자가 손댄
  /// 종목은 남기고, **무엇이 남았는지 돌려준다.** 화면이 그걸 말해준다.
  ///
  /// 반환: 남겨둔 종목 이름들 (그 뒤에 다른 거래가 붙어 못 지운 것).
  Future<List<String>> undoBatch(UndoBatch batch) async {
    final pf = getPortfolio(batch.portfolioId);
    if (pf == null) return const [];

    // 1. 거래를 뺀다
    for (final t in batch.transactions) {
      final item = pf.items.where((i) => i.id == t.itemId).firstOrNull;
      if (item == null) continue;
      item.transactions.removeWhere((x) => x.id == t.txId);
      _recalcFromTransactions(item);
    }

    // 2. 예수금을 되돌린다
    if (batch.cashItemId != null && batch.cashBefore != null) {
      final cash = pf.items.where((i) => i.id == batch.cashItemId).firstOrNull;
      if (cash != null) cash.shares = batch.cashBefore!;
    }

    // 3. 조정 시각을 되돌린다
    pf.lastRebalancedAt = batch.lastRebalancedBefore;

    // 4. 업로드가 만든 종목을 지운다.
    //    **그 뒤에 다른 거래가 붙었으면 남긴다** — 사용자가 손댄 것을
    //    되돌리기가 말없이 지우면 안 된다.
    final kept = <String>[];
    for (final id in batch.createdItemIds) {
      final item = pf.items.where((i) => i.id == id).firstOrNull;
      if (item == null) continue;
      if (item.transactions.isEmpty) {
        pf.items.removeWhere((i) => i.id == id);
      } else {
        kept.add(item.name);
      }
    }

    await _save();
    return kept;
  }

  /// 거래 내역만으로 보유 수량과 평균 단가를 다시 만든다.
  void _recalcFromTransactions(PortfolioItem item) {
    if (item.transactions.isEmpty) {
      item.shares = 0;
      item.avgPrice = 0;
      return;
    }
    double shares = 0, cost = 0;
    for (final t in item.transactions) {
      shares += t.quantity;
      if (t.quantity > 0) cost += t.quantity * t.price;
    }
    item.shares = shares;
    final bought = item.transactions
        .where((t) => t.quantity > 0)
        .fold(0.0, (s, t) => s + t.quantity);
    item.avgPrice = bought > 0 ? cost / bought : 0;
  }

  /// 리밸런싱을 실행한 날을 남긴다.
  ///
  /// 조정 제안에서 거래를 **일괄 기록할 때만** 부른다. 사용자가 고른
  /// 거래 일자를 그대로 쓴다 — 실제로 체결한 날이 그날이기 때문이다.
  Future<void> markRebalanced(String pfId, DateTime when) async {
    final pf = getPortfolio(pfId);
    if (pf == null) return;
    pf.lastRebalancedAt = when.millisecondsSinceEpoch;
    await _save();
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
      await _save(settlementAffected: false);
    }
  }

  void refresh() => notifyListeners();
}
