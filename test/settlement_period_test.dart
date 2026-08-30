import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/services/settlement_service.dart';

/// 결산 차트는 기간을 좌우로 넘기며 막대 6칸을 채운다.
/// 기간 이동이 연도 경계에서 어긋나면 엉뚱한 기간의 손익이 표시되므로
/// 경계 처리를 특히 꼼꼼히 본다.
void main() {
  PeriodKey shift(SettlementPeriod p, int y, int s, int off) =>
      SettlementService.shiftKey(p, PeriodKey(y, s), off);

  group('월간', () {
    const p = SettlementPeriod.monthly;

    test('같은 해 안에서 옮긴다', () {
      expect(shift(p, 2026, 7, -1), const PeriodKey(2026, 6));
      expect(shift(p, 2026, 7, 2), const PeriodKey(2026, 9));
      expect(shift(p, 2026, 7, 0), const PeriodKey(2026, 7));
    });

    test('연초에서 뒤로 가면 전년 12월', () {
      expect(shift(p, 2026, 1, -1), const PeriodKey(2025, 12));
      expect(shift(p, 2026, 1, -13), const PeriodKey(2024, 12));
    });

    test('연말에서 앞으로 가면 다음해 1월', () {
      expect(shift(p, 2025, 12, 1), const PeriodKey(2026, 1));
    });

    test('6칸을 거슬러 올라가면 연도를 넘는다', () {
      final keys = [for (var i = 5; i >= 0; i--) shift(p, 2026, 2, -i)];
      expect(keys, const [
        PeriodKey(2025, 9),
        PeriodKey(2025, 10),
        PeriodKey(2025, 11),
        PeriodKey(2025, 12),
        PeriodKey(2026, 1),
        PeriodKey(2026, 2),
      ]);
    });
  });

  group('분기', () {
    const p = SettlementPeriod.quarterly;

    test('같은 해 안에서 옮긴다', () {
      expect(shift(p, 2026, 3, -1), const PeriodKey(2026, 2));
      expect(shift(p, 2026, 1, 2), const PeriodKey(2026, 3));
    });

    test('연도 경계를 넘는다', () {
      expect(shift(p, 2026, 1, -1), const PeriodKey(2025, 4));
      expect(shift(p, 2025, 4, 1), const PeriodKey(2026, 1));
      expect(shift(p, 2026, 1, -5), const PeriodKey(2024, 4));
    });
  });

  group('연간', () {
    const p = SettlementPeriod.yearly;

    test('연도만 옮기고 sub는 0을 유지한다', () {
      expect(shift(p, 2026, 0, -3), const PeriodKey(2023, 0));
      expect(shift(p, 2026, 0, 1), const PeriodKey(2027, 0));
    });
  });

  group('주간', () {
    const p = SettlementPeriod.weekly;

    test('같은 해 안에서 옮긴다', () {
      expect(shift(p, 2026, 10, -1), const PeriodKey(2026, 9));
      expect(shift(p, 2026, 10, 3), const PeriodKey(2026, 13));
    });

    test('1주차에서 뒤로 가면 전년 마지막 주', () {
      final prev = shift(p, 2026, 1, -1);
      expect(prev.year, 2025);
      expect(prev.sub, SettlementService.isoWeeksInYear(2025));
    });

    test('옮긴 주의 월요일이 정확히 7일씩 차이 난다', () {
      final base = SettlementService.isoWeekMonday(2026, 5);
      for (final off in [-8, -3, -1, 1, 4]) {
        final k = shift(p, 2026, 5, off);
        final moved = SettlementService.isoWeekMonday(k.year, k.sub);
        expect(moved.difference(base).inDays, off * 7,
            reason: 'offset $off 에서 어긋남');
      }
    });

    test('왕복하면 제자리로 돌아온다', () {
      for (final week in [1, 2, 26, 51, 52]) {
        final there = shift(p, 2026, week, -6);
        final back = SettlementService.shiftKey(p, there, 6);
        expect(back, PeriodKey(2026, week), reason: '$week주차 왕복 실패');
      }
    });
  });

  group('미래 기간 판정', () {
    test('다음 해는 미래다', () {
      final next = DateTime.now().year + 1;
      expect(
        SettlementService.isFuture(
            SettlementPeriod.yearly, PeriodKey(next, 0)),
        isTrue,
      );
    });

    test('올해는 미래가 아니다', () {
      final now = DateTime.now();
      expect(
        SettlementService.isFuture(
            SettlementPeriod.yearly, PeriodKey(now.year, 0)),
        isFalse,
      );
    });

    test('진행 중인 이번 달은 미래가 아니다', () {
      expect(
        SettlementService.isFuture(SettlementPeriod.monthly,
            SettlementService.currentKey(SettlementPeriod.monthly)),
        isFalse,
      );
    });
  });

  group('기간 범위', () {
    test('월간은 1일부터 말일까지', () {
      final r = SettlementService.periodRange(
          SettlementPeriod.monthly, const PeriodKey(2026, 2));
      expect(r.start, DateTime(2026, 2, 1));
      expect(r.end, DateTime(2026, 2, 28));
    });

    test('윤년 2월 말일을 맞춘다', () {
      final r = SettlementService.periodRange(
          SettlementPeriod.monthly, const PeriodKey(2024, 2));
      expect(r.end, DateTime(2024, 2, 29));
    });

    test('분기는 3개월 묶음', () {
      final r = SettlementService.periodRange(
          SettlementPeriod.quarterly, const PeriodKey(2026, 3));
      expect(r.start, DateTime(2026, 7, 1));
      expect(r.end, DateTime(2026, 9, 30));
    });

    test('주간은 월요일부터 일요일까지 7일', () {
      final r = SettlementService.periodRange(
          SettlementPeriod.weekly, const PeriodKey(2026, 10));
      expect(r.start.weekday, DateTime.monday);
      expect(r.end.difference(r.start).inDays, 6);
    });
  });

  group('키만으로는 기간 단위를 구별하지 못한다', () {
    // 화면이 결산 결과를 `r.key == _selected`로만 찾는다. PeriodKey에는
    // 단위가 없으므로 월간 3월과 분기 3분기가 같은 키다. 단위 탭을 바꿀 때
    // 옛 결과를 안 비우면 **3월 손익이 3분기 라벨 밑에 뜬다.**
    // all_settlement_screen / portfolio_settlement_screen의 _changePeriod가
    // `_series`를 비우는 이유가 이것이다.
    test('월간 3월과 분기 3분기가 같은 키다', () {
      expect(const PeriodKey(2026, 3), const PeriodKey(2026, 3));
      expect(const PeriodKey(2026, 3).hashCode,
          const PeriodKey(2026, 3).hashCode);
    });

    test('가리키는 기간은 전혀 다르다 — 그래서 섞이면 틀린 숫자가 된다', () {
      final m = SettlementService.periodRange(
          SettlementPeriod.monthly, const PeriodKey(2026, 3));
      final q = SettlementService.periodRange(
          SettlementPeriod.quarterly, const PeriodKey(2026, 3));
      expect(m.start, DateTime(2026, 3, 1));
      expect(q.start, DateTime(2026, 7, 1));
      expect(m.start == q.start, isFalse);
    });

    test('주간 8주차와 월간 8월도 같은 키다', () {
      expect(const PeriodKey(2026, 8), const PeriodKey(2026, 8));
      final w = SettlementService.periodRange(
          SettlementPeriod.weekly, const PeriodKey(2026, 8));
      final mo = SettlementService.periodRange(
          SettlementPeriod.monthly, const PeriodKey(2026, 8));
      expect(w.start.month, isNot(mo.start.month));
    });
  });
}
