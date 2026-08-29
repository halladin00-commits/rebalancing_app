import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// 뺀 종목의 몫을 어디로 보낼 것인가 (시안 v20b).
///
/// 두 가지 답이 있고 결과가 다르다.
///   - `예수금에 남김` — 각 종목이 제 목표 비중을 향한다. 지금까지의 동작이다.
///   - `나머지 종목에`  — 뺀 종목이 붙잡고 있는 돈을 빼고, 남은 예산을
///                       나머지 종목의 목표 비중대로 나눈다.
void main() {
  PortfolioItem stock({
    required String id,
    required double target,
    required double shares,
    double price = 10000,
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

  /// a가 크게 과다(60%), b·c가 부족. 현금 항목은 없다.
  Portfolio skewed() => Portfolio(id: 'p', name: 'p', items: [
        stock(id: 'a', target: 33.34, shares: 60),
        stock(id: 'b', target: 33.33, shares: 20),
        stock(id: 'c', target: 33.33, shares: 20),
      ]);

  Map<String, double> deltas(RebalanceResult r) =>
      {for (final x in r.results) x.id: x.delta};

  /// 이 계획을 실행하는 데 실제로 드는 돈. 매수가 매도보다 많으면 양수 —
  /// 현금이 없는 포트에서 양수면 낼 수 없는 계획이다.
  double netSpend(Portfolio pf, RebalanceResult r) {
    var net = 0.0;
    for (final x in r.results) {
      if (x.isCash) continue;
      final item = pf.items.firstWhere((i) => i.id == x.id);
      net += x.delta * item.currentPrice;
    }
    return net;
  }

  test('아무도 빼지 않으면 매도 대금과 매수 대금이 맞는다', () {
    final pf = skewed();
    final r = Rebalancer.calculate(pf)!;
    expect(netSpend(pf, r), lessThanOrEqualTo(0),
        reason: '없는 돈으로 사는 계획이 나왔다');
  });

  group('예수금에 남김 (골라야 나오는 동작)', () {
    test('뺀 종목은 그대로다', () {
      final pf = skewed();
      final r = Rebalancer.calculate(pf,
          excludeIds: {'a'}, redistributeExcluded: false)!;
      expect(deltas(r)['a'], 0);
    });

    test('나머지는 제 목표 비중을 향해 계속 산다', () {
      final pf = skewed();
      final r = Rebalancer.calculate(pf,
          excludeIds: {'a'}, redistributeExcluded: false)!;
      expect(deltas(r)['b'], greaterThan(0));
      expect(deltas(r)['c'], greaterThan(0));
    });

    test('그 대신 낼 수 없는 계획이 나온다 — 이래서 기본값에서 뺐다', () {
      final pf = skewed();
      final r = Rebalancer.calculate(pf,
          excludeIds: {'a'}, redistributeExcluded: false)!;
      expect(netSpend(pf, r), greaterThan(0),
          reason: '없는 돈으로 사는 계획인데 통과했다');
    });
  });

  group('나머지 종목에 (시안 v20b)', () {
    test('뺀 종목은 여전히 그대로다', () {
      final pf = skewed();
      final r = Rebalancer.calculate(pf,
          excludeIds: {'a'}, redistributeExcluded: true)!;
      expect(deltas(r)['a'], 0);
    });

    test('낼 수 없는 계획을 만들지 않는다', () {
      final pf = skewed();
      final r = Rebalancer.calculate(pf,
          excludeIds: {'a'}, redistributeExcluded: true)!;
      expect(netSpend(pf, r), lessThanOrEqualTo(0),
          reason: 'a를 안 팔면 b·c를 살 돈이 없다');
    });

    test('a를 안 팔면 b·c도 살 게 없다', () {
      // 총액 100만, a가 60만을 붙잡고 있다. 남은 40만을 b·c가 반씩 =
      // 각 20만 = 각 20주. 이미 20주씩 갖고 있으므로 거래가 없다.
      final pf = skewed();
      final r = Rebalancer.calculate(pf,
          excludeIds: {'a'}, redistributeExcluded: true)!;
      expect(deltas(r)['b'], 0);
      expect(deltas(r)['c'], 0);
    });

    test('현금이 있으면 그 현금으로 나머지를 산다', () {
      // a 60주(60만) 고정, b·c 각 10주(10만), 현금 20만. 총 100만.
      // a를 빼면 남는 40만을 b·c가 반씩 = 각 20만 = 각 20주.
      // b·c는 10주씩 더 사고, 그 돈은 현금에서 나온다.
      final pf = Portfolio(id: 'p', name: 'p', items: [
        stock(id: 'a', target: 34, shares: 60),
        stock(id: 'b', target: 33, shares: 10),
        stock(id: 'c', target: 33, shares: 10),
        PortfolioItem(
            id: 'cash',
            name: 'cash',
            ticker: '',
            market: 'CASH',
            isCash: true,
            targetWeight: 0,
            shares: 200000,
            currentPrice: 1),
      ]);
      final r = Rebalancer.calculate(pf,
          excludeIds: {'a'}, redistributeExcluded: true)!;
      final d = deltas(r);
      expect(d['a'], 0);
      expect(d['b'], 10, reason: '현금 20만으로 b·c가 10주씩 더 산다');
      expect(d['c'], 10);
      expect(netSpend(pf, r), lessThanOrEqualTo(200000),
          reason: '가진 현금보다 많이 쓴다');
    });

    test('아무도 빼지 않으면 기존 계산과 같다', () {
      final a = deltas(Rebalancer.calculate(skewed())!);
      final b = deltas(
          Rebalancer.calculate(skewed(), redistributeExcluded: true)!);
      expect(b, a, reason: '뺀 것이 없으면 나눠줄 몫도 없다');
    });
  });
}
