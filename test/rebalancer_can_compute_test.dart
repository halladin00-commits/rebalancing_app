import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// **"조정 필요 없음"과 "모르겠음"은 다르다.**
///
/// 편차 계산은 시세가 하나라도 없으면 통째로 포기하고 빈 목록을 낸다.
/// 화면이 그걸 "괜찮다"로 읽으면, 시세를 하나도 못 받은 앱이 초록색으로
/// `조정할 종목 없음`이라고 단언한다. 사용자는 확인했다고 믿고 넘어간다.
void main() {
  PortfolioItem item(String id, {required double price, double weight = 50}) =>
      PortfolioItem(
        id: id,
        name: id,
        ticker: id,
        market: 'KR',
        shares: 10,
        avgPrice: 100,
        currentPrice: price,
        targetWeight: weight,
      );

  Portfolio pf(List<PortfolioItem> items) =>
      Portfolio(id: 'p', name: 'p', items: items);

  test('시세가 다 있으면 잴 수 있다', () {
    expect(Rebalancer.canComputeDrift(pf([item('a', price: 100), item('b', price: 200)])), isTrue);
  });

  test('시세가 하나라도 0이면 못 잰다', () {
    final p = pf([item('a', price: 100), item('b', price: 0)]);
    expect(Rebalancer.canComputeDrift(p), isFalse);
    // 여기가 핵심: 못 재는데도 needsAdjusting은 비어 있다
    expect(Rebalancer.needsAdjusting(p), isEmpty,
        reason: '빈 목록만 보고 "괜찮다"고 하면 안 되는 이유');
  });

  test('전 종목 시세가 없어도 못 잰다', () {
    expect(
        Rebalancer.canComputeDrift(
            pf([item('a', price: 0), item('b', price: 0)])),
        isFalse);
  });

  test('보유 종목이 없으면 잴 것이 없는 것이지 못 재는 게 아니다', () {
    expect(Rebalancer.canComputeDrift(pf([])), isTrue);

    final cashOnly = pf([
      PortfolioItem(
          id: 'c',
          name: '예수금',
          ticker: '',
          market: 'KR',
          shares: 1000,
          avgPrice: 1,
          currentPrice: 1,
          isCash: true),
    ]);
    expect(Rebalancer.canComputeDrift(cashOnly), isTrue);
  });

  test('현금은 시세가 없어도 방해하지 않는다', () {
    final p = pf([
      item('a', price: 100),
      PortfolioItem(
          id: 'c',
          name: '예수금',
          ticker: '',
          market: 'KR',
          shares: 500,
          avgPrice: 1,
          currentPrice: 0, // 현금은 currentPrice를 안 쓴다
          isCash: true),
    ]);
    expect(Rebalancer.canComputeDrift(p), isTrue);
  });
}
