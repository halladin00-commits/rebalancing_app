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

  test('a를 안 팔면 b·c를 살 돈도 없다', () {
    // 기본값은 `나머지 종목에`다. a가 60만을 붙잡고 있으므로 남은 예산은 40만,
    // b·c가 반씩 나눠도 각 20만 — 이미 20주(20만)씩 갖고 있어 거래가 없다.
    //
    // 예전 기본값(`예수금에 남김`)은 여기서 b·c를 33주까지 밀어올렸다.
    // 총액이 100만인데 계획 합계가 126만이 되는, 낼 수 없는 계획이었다.
    final r = Rebalancer.calculate(pf(skewed()), excludeIds: {'a'})!;
    final d = deltas(r);
    expect(d['b'], 0);
    expect(d['c'], 0);
  });

  test('`예수금에 남김`을 고르면 예전처럼 계속 산다', () {
    final r = Rebalancer.calculate(pf(skewed()),
        excludeIds: {'a'}, redistributeExcluded: false)!;
    final d = deltas(r);
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
