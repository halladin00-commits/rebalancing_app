import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';
import 'package:rebalancing_app/utils/share_format.dart';

/// 소수점 거래는 포트폴리오별 설정이고, 기본값은 온주(1주 단위) 거래다.
/// 켰을 때 목표 비중에 정확히 맞는지, 껐을 때 예전 동작이 그대로인지,
/// 그리고 잔여 현금이 음수가 되지 않는지를 확인한다.
///
/// **종목을 해외(US)로 둔다.** 소수점 매매는 계좌가 아니라 시장이 정하고,
/// 국내 상장 종목은 소수점 주문이 안 되기 때문이다. 계좌 통화도 USD로 두어
/// 환산이 끼어들지 않게 했다 — 숫자는 예전 KR/KRW 구성과 똑같다.
/// 국내 종목이 설정과 무관하게 정수로 나오는지는
/// `rebalancer_market_fractional_test.dart`가 지킨다.
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
        market: 'US',
        targetWeight: target,
        shares: shares,
        currentPrice: price,
      );

  Portfolio pf(
    List<PortfolioItem> items, {
    bool fractional = false,
    double threshold = 0,
    double additional = 0,
    bool commission = false,
    double commissionRate = 0.015,
  }) =>
      Portfolio(
        id: 'p',
        name: 'p',
        currency: 'USD',
        items: items,
        fractionalEnabled: fractional,
        rebalancingThreshold: threshold,
        additionalInvestment: additional,
        commissionEnabled: commission,
        commissionRate: commissionRate,
      );

  /// 값이 딱 떨어지지 않는 구성 — 온주로는 목표에 정확히 못 맞춘다.
  List<PortfolioItem> awkward() => [
        stock(id: 'a', target: 33.34, shares: 7, price: 137000),
        stock(id: 'b', target: 33.33, shares: 40, price: 21350),
        stock(id: 'c', target: 33.33, shares: 3, price: 289400),
      ];

  group('기본값', () {
    test('새 포트폴리오는 소수점 거래가 꺼져 있다', () {
      expect(Portfolio(id: 'p', name: 'p').fractionalEnabled, isFalse);
    });

    test('예전 저장 데이터에는 이 키가 없다 — 온주 거래로 읽힌다', () {
      final restored = Portfolio.fromJson({
        'id': 'p',
        'name': 'p',
        'items': <dynamic>[],
      });
      expect(restored.fractionalEnabled, isFalse);
    });

    test('켠 값은 저장·복원을 거쳐도 유지된다', () {
      final saved = pf(awkward(), fractional: true).toJson();
      expect(Portfolio.fromJson(saved).fractionalEnabled, isTrue);
    });
  });

  group('꺼져 있을 때 — 온주 거래', () {
    test('목표 수량이 모두 정수다', () {
      final r = Rebalancer.calculate(pf(awkward()))!;
      for (final x in r.results) {
        expect(x.newShares, x.newShares.roundToDouble(),
            reason: '${x.id}가 정수가 아니다: ${x.newShares}');
      }
    });

    test('목표 비중에 정확히는 못 맞는다 — 소수점 거래를 켜야 하는 이유', () {
      final r = Rebalancer.calculate(pf(awkward()))!;
      final worst = r.results
          .map((x) => (x.finalWeight - 33.333).abs())
          .reduce((a, b) => a > b ? a : b);
      expect(worst, greaterThan(0.5));
    });
  });

  group('켜져 있을 때 — 소수점 거래', () {
    test('모든 종목이 목표 비중에 사실상 정확히 맞는다', () {
      final items = awkward();
      final r = Rebalancer.calculate(pf(items, fractional: true))!;
      for (final x in r.results) {
        final target = items.firstWhere((i) => i.id == x.id).targetWeight;
        expect((x.finalWeight - target).abs(), lessThan(0.01),
            reason: '${x.id}: 목표 $target% → 결과 ${x.finalWeight}%');
      }
    });

    test('잔여 현금이 거의 남지 않는다', () {
      final r = Rebalancer.calculate(pf(awkward(), fractional: true))!;
      // 온주로는 수십만 원이 남는 구성이다
      expect(r.cash, lessThan(1000));
      expect(r.cash, greaterThanOrEqualTo(0));
    });

    test('수수료를 켜도 잔여 현금이 음수가 되지 않는다', () {
      // 소수점 거래는 내림에서 남는 돈이 없어, 수수료를 미리 빼두지 않으면
      // 배분 합계가 총액을 넘어 현금이 마이너스가 된다.
      final r = Rebalancer.calculate(
          pf(awkward(), fractional: true, commission: true, commissionRate: 0.5))!;
      expect(r.cash, greaterThanOrEqualTo(0));
      expect(r.commission, greaterThan(0));

      final invested = r.results.fold<double>(
          0, (sum, x) => x.isCash ? sum + x.newCashAmount : sum + x.newShares * _priceOf(x.id));
      expect(invested + r.commission, lessThanOrEqualTo(r.total + 1));
    });

    test('추가 투자금도 목표 비중대로 나뉜다', () {
      final items = awkward();
      final r = Rebalancer.calculate(
          pf(items, fractional: true, additional: 5000000))!;
      for (final x in r.results) {
        final target = items.firstWhere((i) => i.id == x.id).targetWeight;
        expect((x.finalWeight - target).abs(), lessThan(0.01));
      }
    });

    test('허용 편차 안의 종목은 소수점 거래에서도 건드리지 않는다', () {
      // a 52% / b 48%, 목표 50:50 → 편차 ±2%p. 임계값 3%p면 둘 다 잠긴다.
      final r = Rebalancer.calculate(pf([
        stock(id: 'a', target: 50, shares: 52, price: 10000),
        stock(id: 'b', target: 50, shares: 48, price: 10000),
      ], fractional: true, threshold: 3))!;

      for (final x in r.results) {
        expect(x.delta, 0, reason: '${x.id}가 잠기지 않았다');
      }
    });

    test('일부만 잠겨도 소수점 거래가 예산을 넘지 않는다', () {
      // b를 **사용자가 체크에서 뺐다** — 35만을 그대로 붙잡는다.
      // a·c만 조정 대상이다. 잠긴 몫을 두 번 세면 없는 돈으로 사게 된다.
      //
      // (허용 편차로는 더 이상 잠기지 않는다 — 밴드는 방아쇠일 뿐이다.
      //  잠기는 경우는 사용자가 직접 뺐을 때뿐이라 그렇게 시험한다.)
      final portfolio = pf([
        stock(id: 'a', target: 34, shares: 60, price: 10000),
        stock(id: 'b', target: 33, shares: 35, price: 10000),
        stock(id: 'c', target: 33, shares: 5, price: 10000),
      ], fractional: true);
      final r = Rebalancer.calculate(portfolio, excludeIds: {'b'})!;

      expect({for (final x in r.results) x.id: x.delta}['b'], 0,
          reason: '잠긴 종목이 거래됐다');

      var net = 0.0;
      for (final x in r.results) {
        if (x.isCash) continue;
        final item = portfolio.items.firstWhere((i) => i.id == x.id);
        net += x.delta * item.currentPrice;
      }
      expect(net, lessThanOrEqualTo(0), reason: '없는 돈으로 사는 계획이다');
    });

    test('임계값을 넘은 종목만 소수점으로 조정된다', () {
      final r = Rebalancer.calculate(pf([
        stock(id: 'a', target: 50, shares: 60, price: 10000),
        stock(id: 'b', target: 50, shares: 40, price: 10000),
      ], fractional: true, threshold: 3))!;

      final byId = {for (final x in r.results) x.id: x};
      expect(byId['a']!.delta, lessThan(0)); // 과다 → 매도
      expect(byId['b']!.delta, greaterThan(0)); // 부족 → 매수
    });

    test('이미 목표에 맞는 종목은 거래가 잡히지 않는다 — 부동소수 찌꺼기 방지', () {
      final r = Rebalancer.calculate(pf([
        stock(id: 'a', target: 50, shares: 50, price: 10000),
        stock(id: 'b', target: 50, shares: 50, price: 10000),
      ], fractional: true))!;

      for (final x in r.results) {
        expect(x.delta, 0);
      }
    });
  });

  group('수량 표기', () {
    test('정수는 소수점을 붙이지 않는다', () {
      expect(formatShares(12000), '12000');
      expect(formatShares(0), '0');
    });

    test('끝자리 0은 털어낸다 — 3.4500이 아니라 3.45', () {
      expect(formatShares(3.45), '3.45');
      expect(formatShares(3.4), '3.4');
      expect(formatShares(0.5), '0.5');
    });

    test('자릿수를 넘는 값은 잘라낸다', () {
      expect(formatShares(3.456789), '3.4568');
    });

    test('버림은 예산을 넘지 않는다', () {
      expect(floorShares(3.99999), 3.9999);
      expect(floorShares(2.0), 2.0);
    });
  });
}

double _priceOf(String id) => switch (id) {
      'a' => 137000,
      'b' => 21350,
      'c' => 289400,
      _ => 0,
    };
