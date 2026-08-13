import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const _keyCount = 'rebalance_apply_count';
  static const _keyDone = 'review_requested';
  static const _threshold = 3;

  /// 리밸런싱 적용 완료 시 호출. 3회 도달하면 리뷰 팝업 요청.
  static Future<void> onRebalancingApplied() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyDone) == true) return;

    final count = (prefs.getInt(_keyCount) ?? 0) + 1;
    await prefs.setInt(_keyCount, count);

    if (count >= _threshold) {
      await prefs.setBool(_keyDone, true);
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    }
  }
}
