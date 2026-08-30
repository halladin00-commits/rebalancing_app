import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/settlement_service.dart';

/// 기간 경계는 자정인데 거래에는 **시각**이 붙어 있다.
///
/// 전에는 기간 시작 보유량을 `holdingsAt(시작 − 1일)`로 셌다. 그러면
/// `시작 − 1일 00:00` 이후의 거래가 전부 빠져 **직전 하루치가 통째로 사라진다.**
/// 실제 데이터에서 8/23 12:20에 산 종목이 8/24 시작 주에 "원래 없던 것"이
/// 되어, 산 금액 전부가 그 주의 손익으로 잡혔다.
void main() {
  StockTransaction tx(DateTime d, double q) =>
      StockTransaction(id: d.toIso8601String(), date: d, quantity: q, price: 100);

  PortfolioItem withTx(List<StockTransaction> txs) => PortfolioItem(
        id: 'a',
        name: 'a',
        ticker: 'a',
        market: 'KR',
        shares: txs.fold(0.0, (s, t) => s + t.quantity),
        avgPrice: 100,
        currentPrice: 100,
        transactions: txs,
      );

  group('기간 시작 보유량', () {
    test('전날 장중에 산 것은 이미 들고 있는 것이다', () {
      // 이것이 실제로 틀렸던 경우다
      final item = withTx([tx(DateTime(2026, 8, 23, 12, 20), 100)]);
      final weekStart = DateTime(2026, 8, 24);
      expect(SettlementService.holdingsBefore(item, weekStart), 100);
    });

    test('기간이 시작하는 순간의 거래는 아직 안 센다 — 그건 기간 안의 거래다', () {
      final item = withTx([tx(DateTime(2026, 8, 24), 100)]);
      expect(SettlementService.holdingsBefore(item, DateTime(2026, 8, 24)), 0);
    });

    test('기간 시작 뒤의 거래는 안 센다', () {
      final item = withTx([tx(DateTime(2026, 8, 25, 9), 100)]);
      expect(SettlementService.holdingsBefore(item, DateTime(2026, 8, 24)), 0);
    });

    test('여러 건이 섞여 있어도 경계 앞의 것만 더한다', () {
      final item = withTx([
        tx(DateTime(2026, 7, 1), 10),
        tx(DateTime(2026, 8, 23, 23, 59), 5),
        tx(DateTime(2026, 8, 24, 0, 1), 100),
      ]);
      expect(SettlementService.holdingsBefore(item, DateTime(2026, 8, 24)), 15);
    });

    test('매도도 그대로 반영된다', () {
      final item = withTx([
        tx(DateTime(2026, 7, 1), 10),
        tx(DateTime(2026, 8, 23, 10), -4),
      ]);
      expect(SettlementService.holdingsBefore(item, DateTime(2026, 8, 24)), 6);
    });
  });

  group('기간 끝', () {
    test('마지막 날 장중 거래도 기간에 든다', () {
      // 끝을 자정으로 잡으면 마지막 날 거래가 통째로 빠진다
      final end = DateTime(2026, 8, 31);
      final item = withTx([tx(DateTime(2026, 8, 31, 14, 30), 50)]);
      expect(
          SettlementService.holdingsBefore(
              item, SettlementService.endExclusive(end)),
          50);
    });

    test('다음 날 거래는 안 든다', () {
      final end = DateTime(2026, 8, 31);
      final item = withTx([tx(DateTime(2026, 9, 1, 0, 1), 50)]);
      expect(
          SettlementService.holdingsBefore(
              item, SettlementService.endExclusive(end)),
          0);
    });

    test('endExclusive는 시각을 털고 다음 날 자정을 준다', () {
      expect(SettlementService.endExclusive(DateTime(2026, 8, 31, 17, 45)),
          DateTime(2026, 9, 1));
    });
  });

  test('한 거래는 정확히 한 기간에만 든다 — 경계가 겹치거나 비지 않는다', () {
    // 8월의 끝과 9월의 시작이 같은 순간을 가리켜야 한다
    final augEnd = SettlementService.endExclusive(DateTime(2026, 8, 31));
    final sepStart =
        SettlementService.periodRange(SettlementPeriod.monthly,
            const PeriodKey(2026, 9)).start;
    expect(augEnd, sepStart);
  });
}
