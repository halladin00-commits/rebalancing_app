import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/services/asset_history_service.dart';
import 'package:rebalancing_app/widgets/asset_sparkline.dart';

/// 스파크라인의 가로 자리는 날짜여야 한다.
///
/// 기록은 앱을 켠 날에만 남는다. 순번으로 그리면 `1일 · 2일 · 3일 · 4월 3일`이
/// 네 칸으로 고르게 놓여, 석 달을 안 켠 것이 하루 간격처럼 보인다.
void main() {
  final base = DateTime(2026, 1, 1);
  List<AssetPoint> days(List<int> offsets) => [
        for (final o in offsets) AssetPoint(base.add(Duration(days: o)), 100 + o.toDouble())
      ];

  test('매일 기록하면 고르게 놓인다', () {
    final p = days([0, 1, 2, 3, 4]);
    for (var i = 0; i < p.length; i++) {
      expect(sparklineX(p, i), closeTo(i / 4, 1e-9));
    }
  });

  test('빈 날은 자리를 그대로 차지한다', () {
    final p = days([0, 1, 2, 92]);
    expect(sparklineX(p, 0), 0);
    expect(sparklineX(p, 3), 1);
    // 앞의 세 점은 92일 중 2일치 — 왼쪽 끝 3% 안에 몰린다
    expect(sparklineX(p, 2), lessThan(0.03));
    // 마지막 구간이 폭의 90% 이상
    expect(sparklineX(p, 3) - sparklineX(p, 2), greaterThan(0.9));
  });

  test('점이 둘 미만이면 0', () {
    expect(sparklineX(days([0]), 0), 0);
    expect(sparklineX(const [], 0), 0);
  });

  test('같은 날짜만 있으면 0으로 나누지 않는다', () {
    final p = [AssetPoint(base, 100), AssetPoint(base, 110)];
    expect(sparklineX(p, 0), 0);
    expect(sparklineX(p, 1), 1);
  });
}
