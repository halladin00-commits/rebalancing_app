import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:rebalancing_app/services/notification_service.dart';

/// 매월 알림에서 「말일」이 실제로 그 달의 마지막 날에 잡히는지 확인한다.
///
/// 예전에는 1~28일까지만 고를 수 있었다. 2월에 29~31일이 없어서인데,
/// 31일을 고르려는 사람이 원하는 건 사실 **말일**이다. 없는 날짜를 넘기면
/// Dart가 조용히 다음 달로 넘겨 버려(2월 31일 → 3월 3일) 고른 날과 다른
/// 날에 울린다 — 그래서 날짜를 흉내 내지 않고 말일을 그대로 고르게 했다.
void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  tz.TZDateTime at(int y, int m, int d, [int h = 0]) =>
      tz.TZDateTime(tz.local, y, m, d, h);

  const last = NotificationService.lastDayOfMonth;

  test('달마다 마지막 날짜를 제대로 센다', () {
    expect(NotificationService.daysInMonth(2026, 1), 31);
    expect(NotificationService.daysInMonth(2026, 2), 28);
    expect(NotificationService.daysInMonth(2026, 4), 30);
    // 윤년 — 2028년 2월은 29일까지
    expect(NotificationService.daysInMonth(2028, 2), 29);
  });

  test('말일은 그 달의 마지막 날에 잡힌다', () {
    final feb = NotificationService.nextDayOfMonth(at(2026, 2, 1), last, 9, 0);
    expect(feb.month, 2);
    expect(feb.day, 28, reason: '2월은 28일이 말일이다');

    final apr = NotificationService.nextDayOfMonth(at(2026, 4, 5), last, 9, 0);
    expect(apr.month, 4);
    expect(apr.day, 30);

    final jan = NotificationService.nextDayOfMonth(at(2026, 1, 5), last, 9, 0);
    expect(jan.month, 1);
    expect(jan.day, 31);
  });

  test('말일이 이미 지났으면 다음 달 말일로 넘어간다', () {
    // 1월 31일 10시 — 9시 알림은 이미 지났다
    final next = NotificationService.nextDayOfMonth(at(2026, 1, 31, 10), last, 9, 0);
    expect(next.month, 2);
    expect(next.day, 28, reason: '다음 달도 그 달의 말일이어야 한다');
  });

  test('연말 말일 다음은 1월 31일', () {
    final next =
        NotificationService.nextDayOfMonth(at(2026, 12, 31, 10), last, 9, 0);
    expect(next.year, 2027);
    expect(next.month, 1);
    expect(next.day, 31);
  });

  test('윤년 2월 말일은 29일', () {
    final feb = NotificationService.nextDayOfMonth(at(2028, 2, 1), last, 9, 0);
    expect(feb.day, 29);
  });

  test('보통 날짜는 그대로 그 날에 잡힌다', () {
    final d = NotificationService.nextDayOfMonth(at(2026, 2, 1), 15, 9, 0);
    expect(d.month, 2);
    expect(d.day, 15);
  });

  test('말일을 열두 달 이어 붙이면 달마다 날짜가 달라진다', () {
    // 한 번 잡고 그 뒤를 이어 잡는 것이 실제 예약 방식이다.
    var t = NotificationService.nextDayOfMonth(at(2026, 1, 1), last, 9, 0);
    final days = <int>[];
    for (var i = 0; i < 12; i++) {
      days.add(t.day);
      t = NotificationService.nextDayOfMonth(t, last, 9, 0);
    }
    expect(days, [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]);
  });
}
