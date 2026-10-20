import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const _keyCount = 'rebalance_apply_count';

  /// 마지막으로 별점 창을 **요청한** 시각 (ms).
  static const _keyLastAsked = 'review_last_asked_at';

  /// 예전 판이 쓰던 「한 번 요청했으면 끝」 표시. 읽기만 한다.
  static const _keyDoneLegacy = 'review_requested';

  static const _threshold = 3;

  /// 다시 요청하기까지의 최소 간격.
  ///
  /// **한 번으로 끝내지 않는다.** 별점 창은 Google이 띄울지 말지 정하고, 앱은
  /// 떴는지 알 수 없다 — 최근에 다른 앱이 띄웠으면 조용히 안 뜬다. 예전에는
  /// 요청하기 **전에** 「끝」으로 표시해서, 그 한 번이 그렇게 날아가면 다시는
  /// 묻지 않았다. 너무 자주 뜨는 건 Google이 알아서 막으므로, 간격을 두고
  /// 다시 요청해도 사용자를 괴롭히지 않는다.
  static const reaskAfter = Duration(days: 90);

  /// 리밸런싱 적용 완료 시 호출. 3회 이상이고 마지막 요청에서 90일이
  /// 지났으면 별점 창을 요청한다.
  static Future<void> onRebalancingApplied({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final at = now ?? DateTime.now();

    final count = (prefs.getInt(_keyCount) ?? 0) + 1;
    await prefs.setInt(_keyCount, count);
    if (count < _threshold) return;

    // 예전 판에서 이미 한 번 요청한 사람 — 언제였는지 모르니 **지금부터**
    // 90일을 센다. 업데이트하자마자 다시 뜨지 않게 한다.
    var lastMs = prefs.getInt(_keyLastAsked);
    if (lastMs == null && prefs.getBool(_keyDoneLegacy) == true) {
      lastMs = at.millisecondsSinceEpoch;
      await prefs.setInt(_keyLastAsked, lastMs);
      return;
    }

    if (!shouldAsk(lastMs, at)) return;

    await prefs.setInt(_keyLastAsked, at.millisecondsSinceEpoch);
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  }

  /// 마지막 요청([lastMs])에서 [reaskAfter]가 지났는가. 한 번도 안 했으면 참.
  static bool shouldAsk(int? lastMs, DateTime now) {
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return now.difference(last) >= reaskAfter;
  }

  /// 스토어의 앱 페이지를 연다 — 더보기의 「앱 평가하기」.
  ///
  /// 별점 창과 달리 **제한이 없다.** 만족한 사람이 언제든 직접 남길 수 있다.
  /// 열지 못하면 false.
  static Future<bool> openStorePage() async {
    try {
      await InAppReview.instance.openStoreListing();
      return true;
    } catch (_) {
      return false;
    }
  }
}
