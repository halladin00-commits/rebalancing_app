import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// 앱을 켤 때 한 번 뜨는 전면 광고.
///
/// 전면 광고(Interstitial)는 넣었다 뺐다. 띄울 만한 자리가 한 달에 몇 번 안
/// 열려서, 얻는 것에 비해 자리가 비쌌다. 앱 오프닝만 남긴다 — 켤 때마다
/// 한 번이라 노출이 훨씬 많고, 닫기 버튼이 바로 있어 기다리게 하지 않는다.
///
/// **미리 받아 둔다.** 켠 다음에 받기 시작하면 몇 초 뒤에야 뜨는데, 그때는
/// 사용자가 이미 화면을 쓰고 있다. 하던 일을 끊는 광고가 되어 가장 나쁘다.
/// 스플래시가 떠 있는 동안 받아 두고, 준비되면 그 자리에서 띄운다.
class FullScreenAds {
  FullScreenAds._();

  /// 받아 놓은 광고. 띄우면 비운다.
  static AppOpenAd? _cached;
  static bool _loading = false;
  static bool _showing = false;

  /// 이번에 켠 뒤로 이미 띄웠는가. 한 번만 띄운다.
  static bool _shownThisLaunch = false;

  static bool get isReady => _cached != null;

  /// 받아 두기만 한다. 앱을 켜자마자 부른다.
  static void preload() {
    if (_cached != null || _loading || _shownThisLaunch) return;
    _loading = true;
    AppOpenAd.load(
      adUnitId: AdService.appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _cached = ad;
        },
        onAdFailedToLoad: (_) {
          _loading = false;
        },
      ),
    );
  }

  /// 받아 둔 게 있으면 띄운다. 없으면 아무것도 안 한다 — **기다리지 않는다.**
  ///
  /// 광고를 기다리느라 앱이 안 열리는 게 광고가 안 뜨는 것보다 나쁘다.
  static void showIfReady() {
    final ad = _cached;
    if (ad == null || _showing || _shownThisLaunch) return;
    _cached = null;
    _showing = true;
    _shownThisLaunch = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showing = false;
        ad.dispose();
      },
    );
    ad.show();
  }
}
