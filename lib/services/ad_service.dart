import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // ── 실제 광고 단위 ID ──
  static const String _mainBannerIdReal =
      'ca-app-pub-7508564356740806/5707542304';
  static const String _exitBannerIdReal =
      'ca-app-pub-7508564356740806/2908516398';

  // ── 테스트 광고 단위 ID (개발 중에만 사용) ──
  static const String _testBannerId =
      'ca-app-pub-3940256099942544/9214589741';

  // ── 출시 시 false로 변경 ──
  static const bool _useTestAds = false;

  static String get mainBannerId =>
      _useTestAds ? _testBannerId : _mainBannerIdReal;
  static String get exitBannerId =>
      _useTestAds ? _testBannerId : _exitBannerIdReal;

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
