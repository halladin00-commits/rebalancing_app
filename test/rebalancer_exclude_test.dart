import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// 조정 제안에서 체크를 끈 종목은 건드리지 않고 나머지만 맞춰야 한다.
/// "저건 팔기 싫은데 나머지는 어떻게 하지"에 답하는 기능이다.
void main() {
  PortfolioItem stock({
    required String id,
    required double target,
    required double shares,
    required double price,
  }) =>
      PortfolioItem(
        id: id,
        name: id,
        ticker: id,
        market: 'KR',
        targetWeight: target,
        shares: shares,
        currentPrice: price,
      );

  Portfolio pf(List<PortfolioItem> items) =>
      Portfolio(id: 'p', name: 'p', items: items);

  /// a가 과다, b·c가 부족한 구성 (목표 각 33.34/33.33/33.33)
  List<PortfolioItem> skewed() => [
        stock(id: 'a', target: 33.34, shares: 60, price: 10000),
        stock(id: 'b', target: 33.33, shares: 20, price: 10000),
        stock(id: 'c', target: 33.33, shares: 20, price: 10000),
      ];

  Map<String, double> deltas(RebalanceResult r) =>
      {for (final x in r.results) x.id: x.delta};

  test('빼지 않으면 세 종목 모두 조정된다', () {
    final r = Rebalancer.calculate(pf(skewed()))!;
    final d = deltas(r);
    expect(d['a'], lessThan(0)); // 과다 → 매도
    expect(d['b'], greaterThan(0));
    expect(d['c'], greaterThan(0));
  });

  test('뺀 종목은 수량이 그대로다', () {
    final r = Rebalancer.calculate(pf(skewed()), excludeIds: {'a'})!;
    final d = deltas(r);
    expect(d['a'], 0, reason: 'a를 뺐는데 거래가 잡혔다');
  });

  test('뺀 종목이 있어도 나머지는 계속 조정된다', () {
    final r = Rebalancer.calculate(pf(skewed()), excludeIds: {'a'})!;
    final d = deltas(r);
    // a가 60주를 그대로 들고 있으므로 b·c는 목표(각 33.33%)를 향해 늘어난다
    expect(d['b'], greaterThan(0));
    expect(d['c'], greaterThan(0));
  });

  test('전부 빼면 아무 거래도 없다', () {
    final r =
        Rebalancer.calculate(pf(skewed()), excludeIds: {'a', 'b', 'c'})!;
    for (final x in r.results) {
      expect(x.delta, 0);
    }
  });

  test('빈 집합은 안 뺀 것과 같다', () {
    final a = deltas(Rebalancer.calculate(pf(skewed()))!);
    final b = deltas(Rebalancer.calculate(pf(skewed()), excludeIds: {})!);
    expect(b, a);
  });

  test('허용 편차 잠금과 함께 걸려도 둘 다 지켜진다', () {
    // 임계값 3%p면 편차가 그보다 작은 종목은 원래도 잠긴다.
    // 거기에 a를 명시적으로 빼도 a는 여전히 그대로여야 한다.
    final p = Portfolio(
      id: 'p',
      name: 'p',
      items: skewed(),
      rebalancingThreshold: 3,
    );
    final r = Rebalancer.calculate(p, excludeIds: {'a'})!;
    expect(deltas(r)['a'], 0);
  });
}
