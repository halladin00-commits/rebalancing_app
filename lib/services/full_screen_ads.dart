import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';

/// 화면을 통째로 덮는 광고 — 앱 오프닝과 전면.
///
/// 배너와 달리 **하던 일을 막는다.** 그래서 두 가지를 지킨다.
///
/// 1. **자리를 가린다.** 돈을 계산하는 흐름(조정 제안, 거래 저장) 중간에는
///    절대 띄우지 않는다. 일이 **끝난** 지점에서만 부른다.
/// 2. **횟수를 막는다.** 앱 오프닝은 하루 한 번, 전면은 하루 두 번에
///    최소 3분 간격. 상한이 없으면 재방문이 줄고, 그러면 결국 수익도 준다.
class FullScreenAds {
  FullScreenAds._();

  static const _keyOpenDay = 'appopen_last_day';
  static const _keyInterLast = 'interstitial_last_ms';
  static const _keyInterDay = 'interstitial_day';
  static const _keyInterCount = 'interstitial_count';


  /// 전면은 하루 두 번, 최소 3분 간격.
  static const _interPerDay = 2;
  static const _interGap = Duration(minutes: 3);

  static bool _showing = false;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  // ── 앱 오프닝 ──

  /// 앱을 켤 때 한 번. **콜드 스타트에서만** 부른다.
  ///
  /// 이 앱은 「빨리 확인」하는 앱이라 켤 때마다 막으면 안 쓰게 된다.
  /// 온보딩·면책 고지를 지난 뒤에만 부르는 것도 같은 이유다 — 첫인상이
  /// 광고면 그 자리에서 지운다.
  static Future<void> maybeShowAppOpen() async {
    if (_showing) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyOpenDay) == _today()) return;

    AppOpenAd.load(
      adUnitId: AdService.appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) async {
          // 뜨는 데 성공한 날만 적는다 — 못 받은 날까지 세면 하루를 날린다
          await prefs.setString(_keyOpenDay, _today());
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

  // ── 전면 ──

  /// 일이 끝난 지점에서 부른다 — 일괄 기록 완료, 결산 이미지 저장·공유 뒤.
  ///
  /// 계산 중이나 저장 중에는 **절대 부르지 않는다.** 돈 계산 흐름을 끊으면
  /// 사용자는 앱을 못 믿게 된다.
  static Future<void> maybeShowInterstitial() async {
    if (_showing) return;
    final prefs = await SharedPreferences.getInstance();

    final today = _today();
    final count = prefs.getString(_keyInterDay) == today
        ? (prefs.getInt(_keyInterCount) ?? 0)
        : 0;
    if (count >= _interPerDay) return;

    final last = prefs.getInt(_keyInterLast) ?? 0;
    final since = DateTime.now().millisecondsSinceEpoch - last;
    if (since < _interGap.inMilliseconds) return;

    InterstitialAd.load(
      adUnitId: AdService.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) async {
          await prefs.setString(_keyInterDay, today);
          await prefs.setInt(_keyInterCount, count + 1);
          await prefs.setInt(
              _keyInterLast, DateTime.now().millisecondsSinceEpoch);
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
