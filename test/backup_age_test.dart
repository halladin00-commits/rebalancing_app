import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/screens/more_screen.dart';

/// 더보기 탭의 "마지막 백업" 표시.
///
/// 기기를 잃은 뒤에야 백업을 안 해뒀다는 걸 알게 되는 일을 막으려고 넣었다.
/// 단위가 바뀌는 경계에서 틀리면 "29일 전"이 "0개월 전"이 된다.
void main() {
  final now = DateTime(2026, 8, 30, 12);
  DateTime ago(int days) => now.subtract(Duration(days: days));

  test('한 번도 안 했으면 없음 — 그리고 처음부터 눈에 띈다', () {
    final a = backupAge(null, now: now);
    expect(a.unit, BackupAgeUnit.never);
    expect(a.stale, isTrue, reason: '백업이 아예 없는 사람이 가장 위험하다');
  });

  test('오늘·어제는 날짜 수를 안 적는다', () {
    expect(backupAge(ago(0), now: now).unit, BackupAgeUnit.today);
    expect(backupAge(ago(1), now: now).unit, BackupAgeUnit.yesterday);
  });

  test('2일부터 29일까지는 일 단위', () {
    for (final d in [2, 15, 29]) {
      final a = backupAge(ago(d), now: now);
      expect(a.unit, BackupAgeUnit.days, reason: '$d일');
      expect(a.count, d);
    }
  });

  test('30일에서 개월로 넘어간다 — 여기서 1개월이어야 0개월이 안 뜬다', () {
    final a = backupAge(ago(30), now: now);
    expect(a.unit, BackupAgeUnit.months);
    expect(a.count, 1);
  });

  test('364일까지 개월, 365일부터 연 단위', () {
    expect(backupAge(ago(364), now: now).unit, BackupAgeUnit.months);
    final y = backupAge(ago(365), now: now);
    expect(y.unit, BackupAgeUnit.years);
    expect(y.count, 1);
  });

  test('30일이 되는 순간부터 경고색으로 바뀐다', () {
    expect(backupAge(ago(29), now: now).stale, isFalse);
    expect(backupAge(ago(30), now: now).stale, isTrue);
    expect(backupAge(ago(400), now: now).stale, isTrue);
  });

  test('시계가 뒤로 간 경우에도 "오늘"로 본다 — 음수 일수가 새어나가지 않는다', () {
    final a = backupAge(now.add(const Duration(days: 3)), now: now);
    expect(a.unit, BackupAgeUnit.today);
    expect(a.count, 0);
  });
}
