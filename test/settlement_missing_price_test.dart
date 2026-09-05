import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/settlement_service.dart';

/// 그 기간에 갖고 있지 않던 종목은 **빠뜨린 게 아니다.**
///
/// 「지금 들고 있다」는 이유로 시세 누락에 세면, 작년에 산 종목 하나 때문에
/// 그 이전 달이 전부 `덜 받은 값`이 된다. 덜 받은 값은 캐시하지 않으므로
/// 결산 탭을 열 때마다 그 달들을 처음부터 다시 계산했다.
void main() {
  test('보유 시작 전에는 그 종목이 계산 대상이 아니다', () {
    final bought = DateTime(2026, 6, 10);
    final item = PortfolioItem(
      id: 'a',
      name: 'a',
      ticker: 'a',
      market: 'KR',
      shares: 10,
      transactions: [
        StockTransaction(id: 't1', date: bought, quantity: 10, price: 1000),
      ],
    );

    // 5월 한 달: 사기 전이라 시작·끝 보유량이 둘 다 0
    final mayStart = DateTime(2026, 5, 1);
    final juneStart = DateTime(2026, 6, 1);
    expect(SettlementService.holdingsBefore(item, mayStart), 0);
    expect(SettlementService.holdingsBefore(item, juneStart), 0);

    // 7월: 시작·끝 모두 보유 중
    final julStart = DateTime(2026, 7, 1);
    final augStart = DateTime(2026, 8, 1);
    expect(SettlementService.holdingsBefore(item, julStart), 10);
    expect(SettlementService.holdingsBefore(item, augStart), 10);
  });

  test('산 달은 시작 0 · 끝 보유 — 계산 대상이다', () {
    final bought = DateTime(2026, 6, 10);
    final item = PortfolioItem(
      id: 'a',
      name: 'a',
      ticker: 'a',
      market: 'KR',
      shares: 10,
      transactions: [
        StockTransaction(id: 't1', date: bought, quantity: 10, price: 1000),
      ],
    );
    final start = SettlementService.holdingsBefore(item, DateTime(2026, 6, 1));
    final end = SettlementService.holdingsBefore(
        item, SettlementService.endExclusive(DateTime(2026, 6, 30)));
    expect(start, 0);
    expect(end, 10);
    // 둘 다 0이 아니므로 이 달은 건너뛰지 않는다
    expect(start == 0 && end == 0, isFalse);
  });
}
