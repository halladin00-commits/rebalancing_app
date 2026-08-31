/// 「얼마나 지났나」를 말로 옮기는 한 곳.
///
/// 마지막 백업과 마지막 리밸런싱이 같은 질문을 한다 — *언제 마지막으로
/// 했더라*. 두 곳이 각자 세면 경계에서 어긋난다(29일이 `0개월 전`이 되는
/// 식이다). 규칙은 여기에만 둔다.
library;

enum ElapsedUnit { never, today, yesterday, days, months, years }

/// [at]으로부터 지금까지. `at`이 null이면 [ElapsedUnit.never].
///
/// [staleAfterDays]를 넘으면 `stale`이 참이 되고, 화면은 색을 바꾼다.
/// 한 번도 안 했으면 늘 stale이다 — **아예 안 해본 사람이 가장 위험하다.**
({ElapsedUnit unit, int count, bool stale}) elapsedSince(
  DateTime? at, {
  DateTime? now,
  int staleAfterDays = 30,
}) {
  if (at == null) {
    return (unit: ElapsedUnit.never, count: 0, stale: true);
  }
  final days = (now ?? DateTime.now()).difference(at).inDays;
  final stale = days >= staleAfterDays;
  if (days <= 0) return (unit: ElapsedUnit.today, count: 0, stale: stale);
  if (days == 1) return (unit: ElapsedUnit.yesterday, count: 1, stale: stale);
  if (days < 30) return (unit: ElapsedUnit.days, count: days, stale: stale);
  if (days < 365) {
    return (unit: ElapsedUnit.months, count: days ~/ 30, stale: stale);
  }
  return (unit: ElapsedUnit.years, count: days ~/ 365, stale: stale);
}
