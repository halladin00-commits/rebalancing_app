import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/settlement_service.dart';

/// 잔고만 넣고 시작한 포트는 지금까지의 평가손익이 넣은 날의 기간에 몰린다.
/// 결산 화면이 「거래 내역이 하루치뿐」이라고 알려야 한다 — 그 조건을 본다.
void main() {
  PortfolioItem item(String id, List<DateTime> buys, {bool cash = false}) =>
      PortfolioItem(
        id: id,
        name: id,
        isCash: cash,
        shares: cash ? 1000 : 0,
        transactions: [
          for (var i = 0; i < buys.length; i++)
            StockTransaction(
                id: '$id$i', date: buys[i], quantity: 1, price: 100),
        ],
      )..syncFromTransactions();

  Portfolio pf(List<PortfolioItem> items) =>
      Portfolio(id: 'p', name: 'p', items: items);

  final d1 = DateTime(2026, 11, 16, 9, 30);
  final d1Later = DateTime(2026, 11, 16, 15, 0);
  final d2 = DateTime(2026, 11, 17);

  test('모든 거래가 같은 날이면 하루치다 — 시각이 달라도', () {
    expect(
        SettlementService.hasOneDayOfHistory(
            pf([item('a', [d1]), item('b', [d1Later])])),
        isTrue);
  });

  test('다른 날 거래가 하나라도 있으면 아니다', () {
    expect(
        SettlementService.hasOneDayOfHistory(
            pf([item('a', [d1]), item('b', [d2])])),
        isFalse);
    expect(SettlementService.hasOneDayOfHistory(pf([item('a', [d1, d2])])),
        isFalse);
  });

  test('종목이 없거나 예수금뿐이면 알릴 것이 없다', () {
    expect(SettlementService.hasOneDayOfHistory(pf([])), isFalse);
    expect(
        SettlementService.hasOneDayOfHistory(
            pf([item('cash', [], cash: true)])),
        isFalse);
  });

  test('두 결산 화면이 이 안내를 띄운다', () {
    for (final f in [
      'lib/screens/all_settlement_screen.dart',
      'lib/screens/portfolio_settlement_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('hasOneDayOfHistory'), reason: f);
      expect(src, contains('HistoryHintBanner'), reason: f);
    }
  });
}
