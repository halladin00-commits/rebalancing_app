import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 알림이 **언제** 울리는지.
///
/// 사용자가 고른 요일·일자·시각이 그대로 잡히지 않으면, 알림이 안 오거나
/// 엉뚱한 날에 온다. 둘 다 「앱이 고장 났다」로 읽힌다.
void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  tz.TZDateTime at(int y, int m, int d, [int h = 0, int min = 0]) =>
      tz.TZDateTime(tz.local, y, m, d, h, min);

  group('매주', () {
    test('아직 안 온 같은 요일이면 오늘', () {
      // 2026-09-07은 월요일
      final now = at(2026, 9, 7, 8, 0);
      final next = NotificationService.nextWeekday(now, DateTime.monday, 9, 0);
      expect(next, at(2026, 9, 7, 9, 0));
    });

    test('같은 요일이라도 시각이 지났으면 다음 주', () {
      final now = at(2026, 9, 7, 9, 1);
      final next = NotificationService.nextWeekday(now, DateTime.monday, 9, 0);
      expect(next, at(2026, 9, 14, 9, 0));
      expect(next.weekday, DateTime.monday);
    });

    test('일요일을 고르면 그 주 일요일', () {
      final now = at(2026, 9, 7, 9, 1); // 월
      final next = NotificationService.nextWeekday(now, DateTime.sunday, 13, 30);
      expect(next, at(2026, 9, 13, 13, 30));
      expect(next.weekday, DateTime.sunday);
    });

    test('모든 요일이 7일 안에 잡힌다', () {
      final now = at(2026, 9, 7, 12, 0);
      for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
        final next = NotificationService.nextWeekday(now, d, 9, 0);
        expect(next.weekday, d);
        expect(next.isAfter(now), isTrue);
        expect(next.difference(now).inDays, lessThan(8));
      }
    });
  });

  group('매월', () {
    test('아직 안 온 날이면 이번 달', () {
      final now = at(2026, 9, 3, 8, 0);
      final next = NotificationService.nextDayOfMonth(now, 15, 9, 0);
      expect(next, at(2026, 9, 15, 9, 0));
    });

    test('이미 지났으면 다음 달', () {
      final now = at(2026, 9, 20, 8, 0);
      final next = NotificationService.nextDayOfMonth(now, 15, 9, 0);
      expect(next, at(2026, 10, 15, 9, 0));
    });

    test('12월이면 해를 넘긴다', () {
      final now = at(2026, 12, 20, 8, 0);
      final next = NotificationService.nextDayOfMonth(now, 1, 9, 0);
      expect(next, at(2027, 1, 1, 9, 0));
    });

    test('1~28일은 그 달을 벗어나지 않는다 — 화면이 28일까지만 주는 이유', () {
      for (var m = 1; m <= 12; m++) {
        for (final d in [1, 15, 28]) {
          final now = at(2026, m, 1, 0, 0);
          final next = NotificationService.nextDayOfMonth(now, d, 9, 0);
          expect(next.day, d, reason: '$m월 $d일이 다른 날로 밀렸다');
        }
      }
    });

    test('없는 날짜(31일)는 조용히 다음 달로 밀린다 — 그래서 못 고르게 한다', () {
      // 2026-02-31은 없다. Dart는 예외 없이 3월로 넘겨 버린다.
      final now = at(2026, 2, 1, 0, 0);
      final next = NotificationService.nextDayOfMonth(now, 31, 9, 0);
      expect(next.day, isNot(31));
      expect(next.month, 3);
    });
  });

  group('결산 알림 기준', () {
    test('주간 결산은 월요일 — 토요일은 아직 그 주가 안 끝났다', () {
      // 결산의 한 주는 월~일(ISO)이다. 다 끝난 다음 날은 월요일이다.
      final sunday = at(2026, 9, 13, 23, 0);
      final next = NotificationService.nextWeekday(sunday, DateTime.monday, 9, 0);
      expect(next, at(2026, 9, 14, 9, 0));
      expect(next.isAfter(sunday), isTrue);
    });

    test('분기 결산은 1·4·7·10월 1일', () {
      for (final m in [1, 4, 7, 10]) {
        final next = NotificationService.nextSpecificDate(m, 1, 9, 0);
        expect(next.month, m);
        expect(next.day, 1);
        expect(next.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
      }
    });
  });
}
