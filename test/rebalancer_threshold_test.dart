import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// 허용 편차(`Portfolio.rebalancingThreshold`)가 실제 매매 제안에 반영되는지 본다.
/// 이 값은 모델과 설정 화면에는 있었지만 계산에는 연결돼 있지 않았다.
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

  Portfolio pf(
    List<PortfolioItem> items, {
    double threshold = 0,
    double additional = 0,
  }) =>
      Portfolio(
        id: 'p',
        name: 'p',
        items: items,
        rebalancingThreshold: threshold,
        additionalInvestment: additional,
      );

  /// id → delta 로 정리
  Map<String, double> deltas(RebalanceResult r) =>
      {for (final x in r.results) x.id: x.delta};

  Map<String, double> shares(RebalanceResult r) =>
      {for (final x in r.results) x.id: x.newShares};

  // a 52%, b 48% / 목표 50:50 → 편차 ±2%p
  List<PortfolioItem> twoOffBy2() => [
        stock(id: 'a', target: 50, shares: 52, price: 10000),
        stock(id: 'b', target: 50, shares: 48, price: 10000),
      ];

  test('허용 편차 안이면 아무것도 거래하지 않는다', () {
    final r = Rebalancer.calculate(pf(twoOffBy2(), threshold: 3))!;

    expect(r.hasChanges, isFalse);
    expect(deltas(r), {'a': 0, 'b': 0});
    expect(shares(r), {'a': 52, 'b': 48});
  });

  test('허용 편차를 넘으면 목표 비중으로 되돌린다', () {
    final r = Rebalancer.calculate(pf(twoOffBy2(), threshold: 1))!;

    expect(r.hasChanges, isTrue);
    expect(deltas(r), {'a': -2, 'b': 2});
    expect(shares(r), {'a': 50, 'b': 50});
  });

  test('임계값 0은 예전처럼 전 종목을 재배분한다', () {
    final r = Rebalancer.calculate(pf(twoOffBy2()))!;

    expect(shares(r), {'a': 50, 'b': 50});
  });

  test('편차를 넘은 종목만 거래하고 나머지는 수량을 유지한다', () {
    // a 60%(+10%p) · b 29%(−1%p) · c 11%(−9%p) / 목표 50:30:20, 허용 ±3%p
    final r = Rebalancer.calculate(pf([
      stock(id: 'a', target: 50, shares: 60, price: 10000),
      stock(id: 'b', target: 30, shares: 29, price: 10000),
      stock(id: 'c', target: 20, shares: 11, price: 10000),
    ], threshold: 3))!;

    // b는 잠겨 그대로, a와 c만 목표로
    expect(deltas(r)['b'], 0);
    expect(shares(r), {'a': 50, 'b': 29, 'c': 20});

    // b가 목표보다 1%p 모자란 만큼(10,000원)은 현금으로 남는다.
    // 이 돈을 억지로 a나 c에 넣으면 그 종목이 목표를 넘어간다.
    expect(r.cash, closeTo(10000, 1));
  });

  test('추가 투자금이 있으면 잠그지 않는다 — 새 돈을 배분해야 한다', () {
    // 편차는 ±2%p로 허용(3%p) 안이지만, 추가 투자금 1,000,000이 들어온다
    final r = Rebalancer.calculate(
        pf(twoOffBy2(), threshold: 3, additional: 1000000))!;

    // 총액 2,000,000 → 각 1,000,000 = 100주씩
    expect(shares(r), {'a': 100, 'b': 100});
    expect(r.hasChanges, isTrue);
  });

  test('현금 항목도 허용 편차 안이면 유지된다', () {
    final r = Rebalancer.calculate(pf([
      stock(id: 'a', target: 70, shares: 71, price: 10000), // 71%
      PortfolioItem(
        id: 'cash',
        name: 'cash',
        isCash: true,
        market: 'CASH',
        targetWeight: 30,
        shares: 290000, // 29%
      ),
    ], threshold: 3))!;

    expect(r.hasChanges, isFalse);
    final cashRow = r.results.firstWhere((x) => x.id == 'cash');
    expect(cashRow.newCashAmount, 290000);
    expect(cashRow.cashDelta, 0);
  });

  test('목표 비중 합이 100이 아니면 계산하지 않는다', () {
    final r = Rebalancer.calculate(pf([
      stock(id: 'a', target: 50, shares: 10, price: 10000),
      stock(id: 'b', target: 30, shares: 10, price: 10000),
    ], threshold: 3));

    expect(r, isNull);
  });

  test('소수점이 남지 않는 종목에는 여윳돈을 더 얹지 않는다', () {
    // 목표가 딱 떨어지는 경우: 총 1,000,000, 목표 50:50, 가격 10,000
    // 각 50주가 정확한 답이므로 51주가 되면 안 된다
    final r = Rebalancer.calculate(pf([
      stock(id: 'a', target: 50, shares: 40, price: 10000),
      stock(id: 'b', target: 50, shares: 60, price: 10000),
    ]))!;

    expect(shares(r), {'a': 50, 'b': 50});
    expect(r.cash, 0);
  });
}
