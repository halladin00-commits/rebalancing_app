import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/settlement_service.dart';

/// 결산은 거래 내역을 더해 그 시점 보유량을 구한다. 그래서 지금 보유 중이라도
/// 그 기간까지의 거래 기록이 없으면 조용히 0으로 잡힌다.
/// 그 종목을 찾아내는지 확인한다 — 못 찾으면 사용자는 틀린 수익률을 맞는 줄 안다.
void main() {
  PortfolioItem stock({
    required String id,
    double shares = 100,
    double price = 10000,
    List<StockTransaction> txs = const [],
  }) =>
      PortfolioItem(
        id: id,
        name: id,
        ticker: id,
        market: 'KR',
        shares: shares,
        currentPrice: price,
        transactions: [...txs],
      );

  StockTransaction buy(DateTime d, double qty, double price) =>
      StockTransaction(
          id: '${d.millisecondsSinceEpoch}', date: d, quantity: qty, price: price);

  Portfolio pf(List<PortfolioItem> items) =>
      Portfolio(id: 'p', name: 'p', items: items);

  // 지난달 — 이미 마감된 기간이라 effectiveEnd가 기간 끝으로 고정된다
  final now = DateTime.now();
  final lastMonth = now.month == 1
      ? PeriodKey(now.year - 1, 12)
      : PeriodKey(now.year, now.month - 1);

  group('결산 제외 판별', () {
    test('그 기간 전에 산 종목은 제외되지 않는다', () {
      final range = SettlementService.periodRange(
          SettlementPeriod.monthly, lastMonth);
      final item = stock(
          id: 'a',
          txs: [buy(range.start.subtract(const Duration(days: 30)), 100, 9000)]);

      final excluded = SettlementService.excludedItems(
          pf([item]), SettlementPeriod.monthly, lastMonth);
      expect(excluded, isEmpty);
    });

    test('그 기간 안에 산 종목도 제외되지 않는다 — 정상적인 중도 매수다', () {
      final range = SettlementService.periodRange(
          SettlementPeriod.monthly, lastMonth);
      final item = stock(
          id: 'a',
          txs: [buy(range.start.add(const Duration(days: 3)), 100, 9000)]);

      final excluded = SettlementService.excludedItems(
          pf([item]), SettlementPeriod.monthly, lastMonth);
      expect(excluded, isEmpty);
    });

    test('거래 기록이 없으면 제외로 잡는다', () {
      final item = stock(id: 'a'); // 수량만 있고 거래 없음
      final excluded = SettlementService.excludedItems(
          pf([item]), SettlementPeriod.monthly, lastMonth);
      expect(excluded.map((i) => i.id), ['a']);
    });

    test('거래가 그 기간보다 나중이면 제외로 잡는다', () {
      // 옛 데이터가 오늘 날짜 거래 하나로 마이그레이션된 경우
      final item = stock(id: 'a', txs: [buy(now, 100, 9000)]);
      final excluded = SettlementService.excludedItems(
          pf([item]), SettlementPeriod.monthly, lastMonth);
      expect(excluded.map((i) => i.id), ['a']);
    });

    test('현금은 제외 대상이 아니다', () {
      final cash = PortfolioItem(
          id: 'c', name: '현금', market: 'CASH', isCash: true, shares: 500000);
      final excluded = SettlementService.excludedItems(
          pf([cash]), SettlementPeriod.monthly, lastMonth);
      expect(excluded, isEmpty);
    });

    test('보유 수량이 0이면 제외 대상이 아니다 — 알릴 것이 없다', () {
      final item = stock(id: 'a', shares: 0);
      final excluded = SettlementService.excludedItems(
          pf([item]), SettlementPeriod.monthly, lastMonth);
      expect(excluded, isEmpty);
    });
  });

  group('제외 금액', () {
    test('현재가 × 보유 수량을 더한다', () {
      final a = stock(id: 'a', shares: 100, price: 10000);
      final b = stock(id: 'b', shares: 20, price: 5000);
      final value = SettlementService.excludedValue(pf([a, b]), [a, b]);
      expect(value, 100 * 10000 + 20 * 5000);
    });

    test('원화 포트의 미국 종목은 환율로 환산한다', () {
      final us = PortfolioItem(
          id: 'u', name: 'u', market: 'US', shares: 10, currentPrice: 100);
      final p = Portfolio(
          id: 'p', name: 'p', currency: 'KRW', exchangeRate: 1400, items: [us]);
      expect(SettlementService.excludedValue(p, [us]), 10 * 100 * 1400);
    });
  });
}
