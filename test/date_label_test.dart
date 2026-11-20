import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/utils/date_label.dart';

/// 영어 화면에서 `11.01 – 11.30`이 날짜로 안 읽혔다. 영어는 달 이름으로,
/// 한국어는 전과 똑같이 점으로 적는지 본다.
void main() {
  final nov1 = DateTime(2026, 11, 1, 9, 5);
  final nov30 = DateTime(2026, 11, 30);

  test('한국어는 전과 같다', () {
    expect(fmtDate(nov1, 'ko'), '2026.11.01');
    expect(fmtMonthDay(nov1, 'ko'), '11.01');
    expect(fmtMonthDayTime(nov1, 'ko'), '11.01 09:05');
    expect(fmtRange(nov1, nov30, 'ko'), '11.01 – 11.30');
    expect(fmtRange(nov1, nov30, 'ko', withYear: true), '2026.11.01 – 11.30');
  });

  test('영어는 달 이름으로 적는다', () {
    expect(fmtDate(nov1, 'en'), 'Nov 1, 2026');
    expect(fmtMonthDay(nov1, 'en'), 'Nov 1');
    expect(fmtMonthDayTime(nov1, 'en'), 'Nov 1 09:05');
  });

  test('영어 기간: 같은 달이면 달 이름을 한 번만', () {
    expect(fmtRange(nov1, nov30, 'en'), 'Nov 1 – 30');
    expect(fmtRange(nov1, nov30, 'en', withYear: true), 'Nov 1 – 30, 2026');
  });

  test('영어 기간: 달을 넘으면 양쪽에 달 이름', () {
    final a = DateTime(2026, 11, 28), b = DateTime(2026, 12, 4);
    expect(fmtRange(a, b, 'en'), 'Nov 28 – Dec 4');
    expect(fmtRange(a, b, 'en', withYear: true), 'Nov 28 – Dec 4, 2026');
    final y = DateTime(2026, 1, 1), z = DateTime(2026, 12, 31);
    expect(fmtRange(y, z, 'en', withYear: true), 'Jan 1 – Dec 31, 2026');
  });

  test('영어 기간: 해를 넘으면 시작 연도만 (한국어와 같은 길이 규칙)', () {
    final a = DateTime(2025, 12, 29), b = DateTime(2026, 1, 4);
    expect(fmtRange(a, b, 'en', withYear: true), 'Dec 29, 2025 – Jan 4');
    expect(fmtRange(a, b, 'ko', withYear: true), '2025.12.29 – 01.04');
  });
}
