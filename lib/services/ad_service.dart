import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // ── 실제 광고 단위 ID ──
  static const String _mainBannerIdReal =
      'ca-app-pub-7508564356740806/5707542304';
  static const String _exitBannerIdReal =
      'ca-app-pub-7508564356740806/2908516398';

  // ── 전면 · 앱 오프닝 ──
  //
  // **아직 실제 단위가 없다.** AdMob 콘솔에서 만들어 아래 두 상수에 넣어야
  // 수익이 잡힌다. 지금은 구글 테스트 단위라 광고는 뜨지만 돈은 안 된다.
  static const String? _appOpenIdReal = null;
  static const String? _interstitialIdReal = null;

  // ── 테스트 광고 단위 ID (개발 중에만 사용) ──
  static const String _testBannerId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testAppOpenId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  // ── 출시 시 false로 변경 ──
  static const bool _useTestAds = false;

  static String get mainBannerId =>
      _useTestAds ? _testBannerId : _mainBannerIdReal;
  static String get exitBannerId =>
      _useTestAds ? _testBannerId : _exitBannerIdReal;

  static String get appOpenId =>
      (_useTestAds ? null : _appOpenIdReal) ?? _testAppOpenId;
  static String get interstitialId =>
      (_useTestAds ? null : _interstitialIdReal) ?? _testInterstitialId;

  /// 실제 단위를 아직 안 넣은 전면·앱 오프닝이 있는가. 출시 전 점검용.
  static bool get fullScreenAdsAreTest =>
      _appOpenIdReal == null || _interstitialIdReal == null;

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
