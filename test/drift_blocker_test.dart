import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// 편차를 못 내는 **이유**를 가린다.
///
/// 이유를 안 가리면 화면이 하나의 문구로 뭉뚱그린다 — 종목이 0개인 포트에
/// `시세를 받으면 편차를 계산합니다`라고 말했다. 사용자는 그 말을 믿고
/// 새로고침을 반복한다. **고칠 수 없는 것을 고치려 들게 만든다.**
void main() {
  PortfolioItem item(String id,
          {double price = 100, double weight = 50, bool cash = false}) =>
      PortfolioItem(
        id: id,
        name: id,
        ticker: cash ? '' : id,
        market: cash ? 'CASH' : 'KR',
        shares: 10,
        avgPrice: 100,
        currentPrice: price,
        targetWeight: weight,
        isCash: cash,
      );

  Portfolio pf(List<PortfolioItem> items) =>
      Portfolio(id: 'p', name: 'p', items: items);

  test('다 갖춰졌으면 막는 것이 없다', () {
    expect(Rebalancer.driftBlocker(pf([item('a'), item('b')])), isNull);
  });

  test('종목이 아예 없으면 noItems — 시세 탓을 하면 안 된다', () {
    expect(Rebalancer.driftBlocker(pf([])), DriftBlocker.noItems);
  });

  test('현금만 있어도 noItems — 현금은 리밸런싱 대상이 아니다', () {
    final cashOnly = pf([item('c', cash: true, weight: 100)]);
    expect(Rebalancer.driftBlocker(cashOnly), DriftBlocker.noItems);
  });

  test('목표 비중이 하나도 없으면 noTargets', () {
    // 목표가 0이면 모든 종목이 "목표보다 많다"가 되어 전부 조정 필요로 보인다.
    final p = pf([item('a', weight: 0), item('b', weight: 0)]);
    expect(Rebalancer.driftBlocker(p), DriftBlocker.noTargets);
  });

  test('시세가 빠졌으면 noPrices', () {
    expect(Rebalancer.driftBlocker(pf([item('a'), item('b', price: 0)])),
        DriftBlocker.noPrices);
  });

  group('이유의 우선순위', () {
    test('종목이 없으면 목표·시세는 묻지 않는다', () {
      // 종목이 없는데 "목표를 정하세요"라고 하면 정할 대상이 없다
      expect(Rebalancer.driftBlocker(pf([])), DriftBlocker.noItems);
    });

    test('목표가 없으면 시세가 있어도 noTargets가 먼저다', () {
      // 시세는 멀쩡한데 "시세를 받으세요"라고 하면 영영 안 풀린다
      final p = pf([item('a', weight: 0, price: 100),
                    item('b', weight: 0, price: 200)]);
      expect(Rebalancer.driftBlocker(p), DriftBlocker.noTargets);
    });

    test('목표도 없고 시세도 없으면 목표를 먼저 말한다', () {
      final p = pf([item('a', weight: 0, price: 0)]);
      expect(Rebalancer.driftBlocker(p), DriftBlocker.noTargets);
    });
  });

  test('canComputeDrift는 종목 없음을 "못 잼"으로 세지 않는다', () {
    // 빈 포트를 "확인 불가"로 세면 헤더가 없는 문제를 있다고 말한다
    expect(Rebalancer.canComputeDrift(pf([])), isTrue);
    expect(Rebalancer.canComputeDrift(pf([item('a'), item('b', price: 0)])),
        isFalse);
    expect(Rebalancer.canComputeDrift(pf([item('a', weight: 0)])), isFalse);
  });
}
