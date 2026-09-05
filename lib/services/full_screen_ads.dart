import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// 앱을 켤 때 한 번 뜨는 전면 광고.
///
/// 전면 광고(Interstitial)는 넣었다 뺐다. 띄울 만한 자리가 **일괄 기록 완료**
/// 와 **결산 이미지 저장·공유** 둘뿐인데, 둘 다 한 달에 몇 번 안 열린다.
/// 얻는 건 얼마 안 되면서 하나는 돈을 막 기록한 직후라 가장 비싼 자리였다.
///
/// 앱 오프닝만 남긴다. 켤 때마다 한 번이라 노출이 훨씬 많고, **닫기 버튼이
/// 바로 있는 형식**이라 몇 초를 기다리게 하지 않는다.
class FullScreenAds {
  FullScreenAds._();

  static bool _showing = false;

  /// 앱을 켤 때. **콜드 스타트에서만** 부른다.
  ///
  /// 온보딩·면책 고지·알림 권한을 다 지난 뒤에만 부른다 — 처음 켠 사람에게
  /// 첫 화면이 광고면 그 자리에서 지운다.
  static Future<void> maybeShowAppOpen() async {
    if (_showing) return;
    AppOpenAd.load(
      adUnitId: AdService.appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _showing = true;
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
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }
}
