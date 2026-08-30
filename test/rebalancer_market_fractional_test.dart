import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// 소수점 매매는 **계좌가 아니라 시장**이 정한다.
///
/// 국내 상장 종목은 소수점 주문이 안 된다. 계좌 설정 하나로 켜고 끄던
/// 시절에는, 해외주식 때문에 켠 설정이 국내 ETF까지 소수점으로 만들어
/// `2819.1312주` 같은 **그대로는 주문할 수 없는 수량**을 냈다.
void main() {
  PortfolioItem stock(String id, String market,
          {required double shares, required double price, required double w}) =>
      PortfolioItem(
        id: id,
        name: id,
        ticker: id,
        market: market,
        shares: shares,
        avgPrice: price,
        currentPrice: price,
        targetWeight: w,
      );

  Portfolio pf(List<PortfolioItem> items, {required bool fractional}) =>
      Portfolio(
        id: 'p',
        name: 'p',
        currency: 'KRW',
        exchangeRate: 1000,
        items: items,
        fractionalEnabled: fractional,
      );

  double sharesOf(RebalanceResult r, String id) =>
      r.results.firstWhere((x) => x.id == id).newShares;

  bool isWhole(double v) => v == v.roundToDouble();

  test('소수점을 켜도 국내 종목은 정수로 나온다', () {
    final p = pf([
      stock('kr1', 'KR', shares: 100, price: 1234, w: 50),
      stock('kr2', 'KR', shares: 10, price: 5678, w: 50),
    ], fractional: true);
    final r = Rebalancer.calculate(p)!;
    expect(isWhole(sharesOf(r, 'kr1')), isTrue, reason: '국내는 소수점 주문 불가');
    expect(isWhole(sharesOf(r, 'kr2')), isTrue);
  });

  test('해외 종목은 소수점을 켜면 소수점으로 나온다', () {
    final p = pf([
      stock('us1', 'US', shares: 10, price: 333.33, w: 50),
      stock('us2', 'US', shares: 5, price: 777.77, w: 50),
    ], fractional: true);
    final r = Rebalancer.calculate(p)!;
    // 정확히 목표에 맞으므로 최종 비중이 목표와 같아야 한다
    for (final id in ['us1', 'us2']) {
      final x = r.results.firstWhere((e) => e.id == id);
      expect(x.finalWeight, closeTo(50, 0.5), reason: id);
    }
  });

  test('한 계좌에 국내와 해외가 섞이면 각자 규칙을 따른다', () {
    // 이 사용자의 ISA가 정확히 이 모양이다 — 국내 ETF + 해외주식
    final p = pf([
      stock('kr', 'KR', shares: 1000, price: 13121, w: 50),
      stock('us', 'US', shares: 60, price: 214.72, w: 50),
    ], fractional: true);
    final r = Rebalancer.calculate(p)!;
    expect(isWhole(sharesOf(r, 'kr')), isTrue, reason: '국내는 정수여야 한다');
    expect(sharesOf(r, 'us'), greaterThan(0));
  });

  test('소수점을 끄면 해외도 정수다', () {
    final p = pf([
      stock('us1', 'US', shares: 10, price: 333.33, w: 50),
      stock('kr1', 'KR', shares: 100, price: 1234, w: 50),
    ], fractional: false);
    final r = Rebalancer.calculate(p)!;
    expect(isWhole(sharesOf(r, 'us1')), isTrue);
    expect(isWhole(sharesOf(r, 'kr1')), isTrue);
  });

  test('섞인 계좌에서도 예산을 넘지 않는다 — 잔여 현금이 음수면 안 된다', () {
    final p = pf([
      stock('kr', 'KR', shares: 1000, price: 13121, w: 34),
      stock('us', 'US', shares: 60, price: 214.72, w: 33),
      stock('kr2', 'KR', shares: 500, price: 4070, w: 33),
    ], fractional: true);
    final r = Rebalancer.calculate(p)!;
    expect(r.cash, greaterThanOrEqualTo(0),
        reason: '남는 현금이 음수면 낼 수 없는 계획이다');
  });

  test('국내만 있는 계좌는 소수점 설정과 무관하게 결과가 같다', () {
    final items = [
      stock('a', 'KR', shares: 100, price: 1234, w: 60),
      stock('b', 'KR', shares: 10, price: 5678, w: 40),
    ];
    final on = Rebalancer.calculate(pf(items, fractional: true))!;
    final off = Rebalancer.calculate(pf(items, fractional: false))!;
    for (final id in ['a', 'b']) {
      expect(sharesOf(on, id), sharesOf(off, id), reason: id);
    }
  });
}
