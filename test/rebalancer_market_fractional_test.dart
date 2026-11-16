import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// **소수점 스위치 하나가 국내·해외를 같이 정한다** (2026-11-16 사용자 결정).
///
/// 예전에는 국내 종목을 늘 정수로 묶었다. 국내도 소수점 거래가 되는 증권사가
/// 있고, 시장별로 스위치를 나누면 쓰는 사람이 헷갈린다.
///
/// 꺼져 있을 때는 **한 주 단위로만** 사고판다. 가진 수량에 소수점이 붙어
/// 있어도(잔고 캡처가 온주 1주 + 소수점 0.8주를 1.8주로 넣는다) 「0.8주 매도」
/// 같은 낼 수 없는 주문을 내지 않는다.
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

  RebalanceItemResult of(RebalanceResult r, String id) =>
      r.results.firstWhere((x) => x.id == id);

  bool isWhole(double v) => (v - v.roundToDouble()).abs() < 1e-9;

  group('켰을 때', () {
    test('국내 종목도 소수점으로 나온다', () {
      final p = pf([
        stock('kr1', 'KR', shares: 100, price: 1234, w: 50),
        stock('kr2', 'KR', shares: 10, price: 5678, w: 50),
      ], fractional: true);
      final r = Rebalancer.calculate(p)!;
      for (final id in ['kr1', 'kr2']) {
        expect(of(r, id).finalWeight, closeTo(50, 0.01), reason: id);
      }
      expect(isWhole(of(r, 'kr1').newShares), isFalse);
    });

    test('국내와 해외가 섞여도 둘 다 소수점이고 예산을 넘지 않는다', () {
      final p = pf([
        stock('kr', 'KR', shares: 1000, price: 13121, w: 34),
        stock('us', 'US', shares: 60, price: 214.72, w: 33),
        stock('kr2', 'KR', shares: 500, price: 4070, w: 33),
      ], fractional: true);
      final r = Rebalancer.calculate(p)!;
      expect(of(r, 'kr').finalWeight, closeTo(34, 0.01));
      expect(of(r, 'us').finalWeight, closeTo(33, 0.01));
      expect(r.cash, greaterThanOrEqualTo(0),
          reason: '남는 현금이 음수면 낼 수 없는 계획이다');
    });
  });

  group('껐을 때 — 한 주 단위로만', () {
    test('해외도 국내도 정수다', () {
      final p = pf([
        stock('us1', 'US', shares: 10, price: 333.33, w: 50),
        stock('kr1', 'KR', shares: 100, price: 1234, w: 50),
      ], fractional: false);
      final r = Rebalancer.calculate(p)!;
      expect(isWhole(of(r, 'us1').newShares), isTrue);
      expect(isWhole(of(r, 'kr1').newShares), isTrue);
    });

    test('1.8주를 가진 종목 — 거래가 정수 주이고 0.8은 남는다', () {
      // 0.8 / 1.8 / 2.8 / … 만 나올 수 있다
      for (final w in [10.0, 30.0, 50.0, 70.0, 90.0]) {
        final p = pf([
          stock('frac', 'KR', shares: 1.8, price: 50000, w: w),
          stock('other', 'KR', shares: 20, price: 10000, w: 100 - w),
        ], fractional: false);
        final r = Rebalancer.calculate(p)!;
        final x = of(r, 'frac');
        expect(isWhole(x.delta), isTrue,
            reason: '목표 $w%: ${x.delta}주는 낼 수 없는 주문이다');
        expect(x.newShares - x.newShares.floorToDouble(), closeTo(0.8, 1e-9),
            reason: '목표 $w%: 소수점 부분을 건드렸다');
        expect(isWhole(of(r, 'other').delta), isTrue);
        expect(r.cash, greaterThanOrEqualTo(0), reason: '목표 $w%');
      }
    });

    test('목표가 0%면 소수점까지 다 판다', () {
      final p = pf([
        stock('frac', 'KR', shares: 1.8, price: 50000, w: 0),
        stock('other', 'KR', shares: 20, price: 10000, w: 100),
      ], fractional: false);
      final r = Rebalancer.calculate(p)!;
      expect(of(r, 'frac').newShares, 0);
    });

    test('정수로 가진 종목은 예전과 같다 (내림 + 남는 돈으로 한 주씩)', () {
      expect(Rebalancer.wholeStepFloor(10, 12.7), 12);
      expect(Rebalancer.wholeStepFloor(0, 3.2), 3);
      expect(Rebalancer.wholeStepFloor(1.8, 12.7), closeTo(11.8, 1e-9));
      expect(Rebalancer.wholeStepFloor(1.8, 12.9), closeTo(12.8, 1e-9));
      // 목표가 소수점 부분보다 작아도 소수점은 못 판다
      expect(Rebalancer.wholeStepFloor(1.8, 0.3), closeTo(0.8, 1e-9));
    });
  });
}
