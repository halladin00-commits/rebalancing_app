import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebalancing_app/services/review_service.dart';

/// 별점 창은 **한 번으로 끝내지 않고, 90일 간격으로 다시** 요청한다.
///
/// 예전에는 요청하기 전에 「끝」으로 표시했다. 별점 창은 Google이 띄울지
/// 정하고 앱은 떴는지 모르므로, 그 한 번이 조용히 날아가면 다시는 안 물었다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 1, 1);

  group('간격', () {
    test('한 번도 안 물었으면 묻는다', () {
      expect(ReviewService.shouldAsk(null, t0), isTrue);
    });

    test('89일 뒤에는 안 묻는다', () {
      final last = t0.millisecondsSinceEpoch;
      expect(
          ReviewService.shouldAsk(last, t0.add(const Duration(days: 89))),
          isFalse);
    });

    test('90일 뒤에는 다시 묻는다', () {
      final last = t0.millisecondsSinceEpoch;
      expect(
          ReviewService.shouldAsk(last, t0.add(const Duration(days: 90))),
          isTrue);
    });
  });

  group('기록 횟수와 저장 값', () {
    Future<SharedPreferences> run(Map<String, Object> start,
        List<DateTime> times) async {
      SharedPreferences.setMockInitialValues(start);
      for (final t in times) {
        await ReviewService.onRebalancingApplied(now: t);
      }
      return SharedPreferences.getInstance();
    }

    test('두 번째까지는 안 묻는다', () async {
      final p = await run({}, [t0, t0]);
      expect(p.getInt('review_last_asked_at'), isNull);
    });

    test('세 번째에 묻고 그 시각을 남긴다', () async {
      final p = await run({}, [t0, t0, t0]);
      expect(p.getInt('review_last_asked_at'), t0.millisecondsSinceEpoch);
    });

    test('물은 뒤 90일 안의 기록은 시각을 바꾸지 않는다', () async {
      final later = t0.add(const Duration(days: 30));
      final p = await run({}, [t0, t0, t0, later]);
      expect(p.getInt('review_last_asked_at'), t0.millisecondsSinceEpoch);
    });

    test('90일이 지나 기록하면 다시 묻는다', () async {
      final later = t0.add(const Duration(days: 91));
      final p = await run({}, [t0, t0, t0, later]);
      expect(p.getInt('review_last_asked_at'), later.millisecondsSinceEpoch);
    });

    test('예전 판에서 이미 물은 사람은 업데이트 직후 다시 안 묻는다', () async {
      // 언제 물었는지 모르므로 지금부터 90일을 센다
      final p = await run(
          {'review_requested': true, 'rebalance_apply_count': 5}, [t0]);
      expect(p.getInt('review_last_asked_at'), t0.millisecondsSinceEpoch);

      final p2 = await run({
        'review_requested': true,
        'rebalance_apply_count': 6,
        'review_last_asked_at': t0.millisecondsSinceEpoch,
      }, [t0.add(const Duration(days: 10))]);
      expect(p2.getInt('review_last_asked_at'), t0.millisecondsSinceEpoch,
          reason: '90일 안이라 다시 묻지 않아야 한다');
    });
  });
}
