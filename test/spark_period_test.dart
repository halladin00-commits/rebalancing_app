import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/widgets/sparkline_panel.dart';

/// 기간 칩 다섯 대신 버튼 하나를 눌러 넘긴다.
///
/// 한 바퀴 돌아 제자리로 오지 않으면 마지막 기간에서 막힌다 — 1년까지 갔다가
/// 1주로 돌아올 방법이 없어진다.
void main() {
  test('짧은 기간에서 긴 기간 순으로 넘어간다', () {
    expect(SparkPeriod.week.next, SparkPeriod.month);
    expect(SparkPeriod.month.next, SparkPeriod.quarter);
    expect(SparkPeriod.quarter.next, SparkPeriod.half);
    expect(SparkPeriod.half.next, SparkPeriod.year);
  });

  test('마지막에서 처음으로 돌아온다', () {
    expect(SparkPeriod.year.next, SparkPeriod.week);
  });

  test('다섯 번 누르면 제자리 — 빠지는 기간이 없다', () {
    var p = SparkPeriod.week;
    final seen = <SparkPeriod>{};
    for (var i = 0; i < SparkPeriod.values.length; i++) {
      seen.add(p);
      p = p.next;
    }
    expect(p, SparkPeriod.week);
    expect(seen, SparkPeriod.values.toSet());
  });

  test('기간이 길어지는 순서로 정의돼 있다', () {
    for (var i = 1; i < SparkPeriod.values.length; i++) {
      expect(SparkPeriod.values[i].days,
          greaterThan(SparkPeriod.values[i - 1].days));
    }
  });
}
