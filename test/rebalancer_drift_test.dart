import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// 허용 편차(`Portfolio.rebalancingThreshold`) 판정은 자산 탭의 "조정 필요" 카드와
/// 3단계 리밸런싱 탭이 함께 쓰는 계산이다.
void main() {
  PortfolioItem stock({
    required String id,
    required double target,
    required double shares,
    required double price,
    String market = 'KR',
  }) =>
      PortfolioItem(
        id: id,
        name: id,
        ticker: id,
        market: market,
        targetWeight: target,
        shares: shares,
        currentPrice: price,
      );

  Portfolio pf(List<PortfolioItem> items, {double threshold = 0}) => Portfolio(
        id: 'p',
        name: 'p',
        items: items,
        rebalancingThreshold: threshold,
      );

  test('목표와 정확히 맞으면 편차가 0이라 아무것도 안 걸린다', () {
    // 50 : 50 → 각 500,000원
    final p = pf([
      stock(id: 'a', target: 50, shares: 100, price: 5000),
      stock(id: 'b', target: 50, shares: 50, price: 10000),
    ]);

    final drifts = Rebalancer.allDrifts(p);
    expect(drifts.every((d) => d.drift.abs() < 0.001), isTrue);
    expect(Rebalancer.driftExceeding(p), isEmpty);
  });

  test('현재 비중과 목표의 차이를 %p로 낸다', () {
    // a = 800,000 (80%), b = 200,000 (20%) / 목표 60 : 40
    final p = pf([
      stock(id: 'a', target: 60, shares: 160, price: 5000),
      stock(id: 'b', target: 40, shares: 20, price: 10000),
    ]);

    final byId = {for (final d in Rebalancer.allDrifts(p)) d.item.id: d};
    expect(byId['a']!.currentWeight, closeTo(80, 0.001));
    expect(byId['a']!.drift, closeTo(20, 0.001));
    expect(byId['b']!.drift, closeTo(-20, 0.001));
  });

  test('편차 절댓값 내림차순으로 정렬한다', () {
    final p = pf([
      stock(id: 'small', target: 33, shares: 34, price: 10000), // 34% → +1%p
      stock(id: 'big', target: 34, shares: 20, price: 10000), //   20% → −14%p
      stock(id: 'mid', target: 33, shares: 46, price: 10000), //   46% → +13%p
    ]);

    expect(Rebalancer.allDrifts(p).map((d) => d.item.id).toList(),
        ['big', 'mid', 'small']);
  });

  test('허용 편차 미만은 걸러진다', () {
    // a = 52%, b = 48% / 목표 50 : 50 → 편차 ±2%p
    final items = [
      stock(id: 'a', target: 50, shares: 52, price: 10000),
      stock(id: 'b', target: 50, shares: 48, price: 10000),
    ];

    expect(Rebalancer.driftExceeding(pf(items, threshold: 3)), isEmpty);
    expect(Rebalancer.driftExceeding(pf(items, threshold: 2)), hasLength(2));
    expect(Rebalancer.driftExceeding(pf(items, threshold: 1)), hasLength(2));
  });

  test('추가 투자금은 분모에서 뺀다 — 없던 편차가 생기면 안 된다', () {
    final items = [
      stock(id: 'a', target: 50, shares: 50, price: 10000),
      stock(id: 'b', target: 50, shares: 50, price: 10000),
    ];

    final withCash = Portfolio(
      id: 'p',
      name: 'p',
      items: items,
      additionalInvestment: 1000000, // 보유액과 맞먹는 금액
    );

    // 분모에 포함했다면 각 종목이 25%가 되어 −25%p 편차가 생긴다
    expect(
      Rebalancer.allDrifts(withCash).every((d) => d.drift.abs() < 0.001),
      isTrue,
    );
  });

  test('현금 항목도 비중 계산에 포함한다', () {
    final p = pf([
      stock(id: 'a', target: 70, shares: 70, price: 10000), // 700,000
      PortfolioItem(
        id: 'cash',
        name: 'cash',
        isCash: true,
        market: 'CASH',
        targetWeight: 30,
        shares: 300000, // 현금은 shares가 금액
      ),
    ]);

    final byId = {for (final d in Rebalancer.allDrifts(p)) d.item.id: d};
    expect(byId['cash']!.currentWeight, closeTo(30, 0.001));
    expect(byId['cash']!.drift, closeTo(0, 0.001));
  });

  test('현재가가 없는 종목이 있으면 계산하지 않는다', () {
    final p = pf([
      stock(id: 'a', target: 50, shares: 100, price: 5000),
      stock(id: 'b', target: 50, shares: 100, price: 0), // 시세 미수신
    ]);

    expect(Rebalancer.allDrifts(p), isEmpty);
    expect(Rebalancer.driftExceeding(p), isEmpty);
  });

  test('해외 종목은 환율로 환산해 비중을 낸다', () {
    // US 종목 100주 × $10 × 1,000원 = 1,000,000원, KR 종목 100주 × 10,000원 = 1,000,000원
    final p = Portfolio(
      id: 'p',
      name: 'p',
      currency: 'KRW',
      exchangeRate: 1000,
      items: [
        stock(id: 'us', target: 50, shares: 100, price: 10, market: 'US'),
        stock(id: 'kr', target: 50, shares: 100, price: 10000),
      ],
    );

    expect(
      Rebalancer.allDrifts(p).every((d) => d.drift.abs() < 0.001),
      isTrue,
    );
  });

  test('종목이 없거나 총액이 0이면 빈 목록', () {
    expect(Rebalancer.allDrifts(pf([])), isEmpty);
    expect(
      Rebalancer.allDrifts(pf([stock(id: 'a', target: 100, shares: 0, price: 5000)])),
      isEmpty,
    );
  });
}
