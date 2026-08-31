import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/elapsed.dart';

/// 마지막 리밸런싱 시각은 **저장 형식이 바뀐 값**이다.
///
/// 옛 저장본에는 이 키가 없다. 되살릴 때 깨지거나 엉뚱한 날짜가 들어가면
/// 사용자는 "3개월 전에 조정했다"는 거짓말을 믿고 판단한다.
void main() {
  Portfolio pf({int? at}) => Portfolio(
        id: 'p',
        name: 'p',
        lastRebalancedAt: at,
        items: [
          PortfolioItem(
              id: 'a',
              name: 'a',
              ticker: 'a',
              market: 'KR',
              shares: 10,
              avgPrice: 100,
              currentPrice: 110),
        ],
      );

  Portfolio roundTrip(Portfolio p) => Portfolio.fromJson(p.toJson());

  group('저장 · 복원', () {
    test('시각이 한 자리도 안 틀리고 돌아온다', () {
      final at = DateTime(2026, 3, 14, 9, 26, 53).millisecondsSinceEpoch;
      expect(roundTrip(pf(at: at)).lastRebalancedAt, at);
    });

    test('한 적 없으면 null 그대로다 — 0으로 바뀌면 1970년이 된다', () {
      expect(roundTrip(pf()).lastRebalancedAt, isNull);
    });

    test('이 키가 없는 옛 저장본도 읽힌다', () {
      final j = pf(at: 123).toJson()..remove('lastRebalancedAt');
      final restored = Portfolio.fromJson(j);
      expect(restored.lastRebalancedAt, isNull);
      // 나머지 값은 멀쩡해야 한다 — 키 하나 때문에 포트가 날아가면 안 된다
      expect(restored.id, 'p');
      expect(restored.items.length, 1);
    });

    test('copyWith가 값을 흘리지 않는다', () {
      final p = pf(at: 999);
      expect(p.copyWith().lastRebalancedAt, 999);
      expect(p.copyWith(name: '다른 이름').lastRebalancedAt, 999);
    });
  });

  group('얼마나 지났나', () {
    final now = DateTime(2026, 8, 31, 12);
    DateTime ago(int d) => now.subtract(Duration(days: d));

    test('한 적 없으면 never', () {
      expect(elapsedSince(null, now: now).unit, ElapsedUnit.never);
    });

    test('오늘·어제', () {
      expect(elapsedSince(ago(0), now: now).unit, ElapsedUnit.today);
      expect(elapsedSince(ago(1), now: now).unit, ElapsedUnit.yesterday);
    });

    test('30일에서 개월로 넘어간다 — 여기서 0개월이 나오면 안 된다', () {
      final a = elapsedSince(ago(30), now: now);
      expect(a.unit, ElapsedUnit.months);
      expect(a.count, 1);
    });

    test('364일까지 개월, 365일부터 연 단위', () {
      expect(elapsedSince(ago(364), now: now).unit, ElapsedUnit.months);
      final y = elapsedSince(ago(365), now: now);
      expect(y.unit, ElapsedUnit.years);
      expect(y.count, 1);
    });

    test('기준 일수를 바꿔 부를 수 있다 — 백업 30일, 조정은 더 길 수 있다', () {
      expect(elapsedSince(ago(100), now: now, staleAfterDays: 30).stale, isTrue);
      expect(
          elapsedSince(ago(100), now: now, staleAfterDays: 365).stale, isFalse);
    });

    test('시계가 뒤로 가도 오늘로 본다', () {
      final a = elapsedSince(now.add(const Duration(days: 5)), now: now);
      expect(a.unit, ElapsedUnit.today);
    });
  });
}
