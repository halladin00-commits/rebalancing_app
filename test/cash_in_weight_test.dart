import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// 예수금을 **비중에서 뺄 수 있게** 한 뒤의 돈 계산.
///
/// 끄면 세 가지가 동시에 성립해야 한다:
///   1. 총 자산에는 그대로 들어간다 — 비중에 안 넣는다고 내 돈이 아닌 게 아니다
///   2. 비중의 분모에서는 빠진다
///   3. 조정에서 통째로 빠진다 — 목표도 없고 **매수 예산으로도 안 쓴다**
///
/// 3번이 특히 중요하다. 「비중에 포함 안 함」이라고 해놓고 앱이 그 돈을 알아서
/// 써 버리면 사용자가 예상 못 한 매수가 나온다.
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

  PortfolioItem cash(double amount,
          {required bool inWeight, double target = 0}) =>
      PortfolioItem(
        id: 'cash',
        name: '예수금',
        market: 'CASH',
        isCash: true,
        inWeight: inWeight,
        targetWeight: target,
        shares: amount,
      );

  Portfolio pf(List<PortfolioItem> items) =>
      Portfolio(id: 'p', name: 'p', items: items);

  group('비중 포함 (기존 동작)', () {
    test('예수금이 분모에 들어간다', () {
      final p = pf([
        stock(id: 'a', target: 50, shares: 10, price: 1000), // 10,000
        cash(10000, inWeight: true, target: 50),
      ]);
      expect(p.totalValue, 20000);
      expect(p.weighedValue, 20000);
      expect(p.weightSum, 100);

      final drifts = Rebalancer.allDrifts(p);
      expect(drifts.length, 2);
      expect(drifts.every((d) => d.drift.abs() < 0.01), isTrue);
    });

    test('없던 데이터는 포함으로 읽힌다', () {
      final json = {
        'id': 'c',
        'name': '현금',
        'isCash': true,
        'shares': 5000,
      };
      expect(PortfolioItem.fromJson(json).inWeight, isTrue);
    });
  });

  group('비중 제외', () {
    test('총 자산에는 남고 비중 분모에서만 빠진다', () {
      final p = pf([
        stock(id: 'a', target: 60, shares: 60, price: 100), // 6,000
        stock(id: 'b', target: 40, shares: 40, price: 100), // 4,000
        cash(10000, inWeight: false),
      ]);
      // 내 돈은 20,000이 맞다
      expect(p.totalValue, 20000);
      // 비중을 나눌 몫은 주식 10,000뿐이다
      expect(p.weighedValue, 10000);
    });

    test('목표 비중 합에서 빠진다 — 주식만으로 100%가 된다', () {
      final p = pf([
        stock(id: 'a', target: 60, shares: 60, price: 100),
        stock(id: 'b', target: 40, shares: 40, price: 100),
        // 예전에 비중을 켜고 쓰던 값이 남아 있어도 세지 않는다
        cash(10000, inWeight: false, target: 25),
      ]);
      expect(p.weightSum, 100);
    });

    test('편차 목록에 안 나온다', () {
      final p = pf([
        stock(id: 'a', target: 60, shares: 60, price: 100),
        stock(id: 'b', target: 40, shares: 40, price: 100),
        cash(10000, inWeight: false),
      ]);
      final drifts = Rebalancer.allDrifts(p);
      expect(drifts.map((d) => d.item.id), ['a', 'b']);
      // 주식 10,000 안에서 60/40 → 편차 0
      expect(drifts.every((d) => d.drift.abs() < 0.01), isTrue);
    });

    test('**매수 예산으로 쓰지 않는다** — 예수금이 있어도 매도로만 조정한다', () {
      // 주식 10,000이 70:30으로 어긋나 있다. 목표는 50:50.
      final p = pf([
        stock(id: 'a', target: 50, shares: 70, price: 100), // 7,000
        stock(id: 'b', target: 50, shares: 30, price: 100), // 3,000
        cash(10000, inWeight: false),
      ]);
      final r = Rebalancer.calculate(p);
      expect(r, isNotNull);

      final d = {for (final x in r!.results) x.id: x.delta};
      // 예수금 10,000을 끌어 썼다면 b를 훨씬 많이 샀을 것이다.
      // 주식 10,000 안에서만 맞추므로 −20주 / +20주다.
      expect(d['a'], closeTo(-20, 0.001));
      expect(d['b'], closeTo(20, 0.001));
      // 결과에 예수금 자체가 없다
      expect(r.results.any((x) => x.isCash), isFalse);
    });

    test('비중을 켜면 같은 포트에서 예수금이 매수 재원으로 쓰인다', () {
      // 바로 위 시험과 **똑같은 포트**인데 예수금만 비중에 넣었다.
      final p = pf([
        stock(id: 'a', target: 50, shares: 70, price: 100), // 7,000
        stock(id: 'b', target: 50, shares: 30, price: 100), // 3,000
        cash(10000, inWeight: true), // 목표 0% → 전부 주식으로
      ]);
      final r = Rebalancer.calculate(p);
      expect(r, isNotNull);

      final d = {for (final x in r!.results) x.id: x.delta};
      // 분모가 20,000이라 목표는 각 10,000. 예수금을 다 써서 **둘 다 매수**다.
      // 껐을 때(−20 / +20)와 정반대다 — 이 차이가 옵션의 전부다.
      expect(d['a'], closeTo(30, 0.001));
      expect(d['b'], closeTo(70, 0.001));
      expect(r.results.any((x) => x.isCash), isTrue);
    });
  });

  group('저장·복원', () {
    test('inWeight와 입력 시각이 저장된다', () {
      final item = cash(1234, inWeight: false)..cashUpdatedAt = 1700000000000;
      final back = PortfolioItem.fromJson(item.toJson());
      expect(back.inWeight, isFalse);
      expect(back.cashUpdatedAt, 1700000000000);
      expect(back.shares, 1234);
    });
  });
}
