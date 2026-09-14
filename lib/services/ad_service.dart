import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 배너가 붙는 자리.
///
/// AdMob 단위를 자리별로 나눠야 리포트에서 **어느 화면이 돈이 되는지**
/// 보인다. 한 단위로 뭉치면 전부 한 줄로만 찍힌다. 나중에 나누면 그 전
/// 기록은 못 살리므로 처음부터 나눠 둔다.
///
/// 화면마다 하나씩 만들지는 않았다 — 종목 상세와 포트 상세는 둘 다
/// 「종목을 들여다보는 화면」이라 나눠 봐야 같은 결론이 나오고,
/// 쪼갤수록 단위당 수치가 적어져 판단만 어려워진다.
enum AdSlot {
  /// 메인 4개 탭 (자산·리밸런싱·결산·더보기)
  main,

  /// 포트 상세 · 종목 상세 · 그래프
  detail,

  /// 포트별 결산
  settlement,

  /// 리밸런싱 · 거래 내역
  work,
}

class AdService {
  // ── 실제 광고 단위 ID ──
  static const String _bannerMainReal =
      'ca-app-pub-7508564356740806/5707542304';
  static const String _bannerDetailReal =
      'ca-app-pub-7508564356740806/2245736957';
  static const String _bannerSettlementReal =
      'ca-app-pub-7508564356740806/8866985628';
  static const String _bannerWorkReal =
      'ca-app-pub-7508564356740806/3179544678';
  static const String _exitBannerIdReal =
      'ca-app-pub-7508564356740806/2908516398';
  static const String _appOpenIdReal =
      'ca-app-pub-7508564356740806/1730731635';

  // ── 테스트 광고 단위 ID (개발 중에만 사용) ──
  static const String _testBannerId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testAppOpenId =
      'ca-app-pub-3940256099942544/9257395921';

  /// 구글 시험용 광고 단위를 쓸 것인가.
  ///
  /// **손으로 바꾸는 상수였다.** 그 자리는 양쪽으로 다 위험하다 —
  /// 켠 채로 내보내면 수익이 0이 되고, 끈 채로 시험하면 **실광고를 직접
  /// 누르게 되어** 무효 트래픽으로 계정이 정지될 수 있다.
  ///
  /// 이제 컴파일할 때만 켤 수 있다. 안 주면 거짓이라 **스토어 빌드는
  /// 어떤 경우에도 실광고**다.
  ///
  ///   sh tools/build_review.sh android-x64 --dart-define=USE_TEST_ADS=true
  ///
  /// 시험용 단위는 늘 광고를 내주므로, 광고가 뜨는지 확인할 때 쓴다.
  /// 실제 단위는 에뮬레이터에서 자주 `no fill`이 난다.
  static const bool _useTestAds = bool.fromEnvironment('USE_TEST_ADS');

  /// 자리에 맞는 배너 단위.
  static String bannerIdFor(AdSlot slot) {
    if (_useTestAds) return _testBannerId;
    switch (slot) {
      case AdSlot.main:
        return _bannerMainReal;
      case AdSlot.detail:
        return _bannerDetailReal;
      case AdSlot.settlement:
        return _bannerSettlementReal;
      case AdSlot.work:
        return _bannerWorkReal;
    }
  }

  static String get exitBannerId =>
      _useTestAds ? _testBannerId : _exitBannerIdReal;

  static String get appOpenId =>
      _useTestAds ? _testAppOpenId : _appOpenIdReal;

  /// 배너 광고 생성 (로드 포함)
  static BannerAd createBanner({
    required String adUnitId,
    AdSize size = AdSize.banner,
    required void Function() onLoaded,
    void Function()? onFailed,
  }) {
    final ad = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed?.call();
        },
      ),
    )..load();
    return ad;
  }
}
