import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/screens/transaction_history_screen.dart';

/// 거래 내역의 종목·연도 거르기.
///
/// 1년쯤 쓰면 거래가 수백 건이라 스크롤로는 못 찾는다.
void main() {
  StockTransaction tx(String id, DateTime d, double q) =>
      StockTransaction(id: id, date: d, quantity: q, price: 100);

  PortfolioItem item(String id, String name, List<StockTransaction> txs) =>
      PortfolioItem(
        id: id,
        name: name,
        ticker: id,
        market: 'KR',
        shares: 10,
        avgPrice: 100,
        currentPrice: 110,
        transactions: txs,
      );

  final nvidia = item('a', 'NVIDIA', [
    tx('a1', DateTime(2025, 3, 4), 5),
    tx('a2', DateTime(2026, 1, 9), -2),
  ]);
  final apple = item('b', 'Apple', [tx('b1', DateTime(2026, 5, 20), 3)]);
  final cash = PortfolioItem(
    id: 'c',
    name: '예수금',
    ticker: '',
    market: 'KR',
    shares: 1000,
    avgPrice: 1,
    currentPrice: 1,
    isCash: true,
  );

  final pf = Portfolio(id: 'p', name: '내 포트', items: [nvidia, apple, cash]);

  test('현금은 거래 목록에 안 들어간다', () {
    final all = collectTransactions(pf);
    expect(all.length, 3);
    expect(all.any((e) => e.item.isCash), isFalse);
  });

  test('최신순으로 온다 — 훑는 순서가 곧 시간 역순이다', () {
    final all = collectTransactions(pf);
    expect(all.map((e) => e.tx.id).toList(), ['b1', 'a2', 'a1']);
  });

  test('거래가 있는 해만, 최신순으로', () {
    expect(transactionYears(collectTransactions(pf)), [2026, 2025]);
  });

  group('거르기', () {
    final all = collectTransactions(pf);

    test('아무것도 안 주면 그대로다', () {
      expect(filterTransactions(all).length, 3);
    });

    test('종목만', () {
      final r = filterTransactions(all, itemId: 'a');
      expect(r.map((e) => e.tx.id).toList(), ['a2', 'a1']);
    });

    test('연도만', () {
      final r = filterTransactions(all, year: 2026);
      expect(r.map((e) => e.tx.id).toList(), ['b1', 'a2']);
    });

    test('종목과 연도를 같이 — 둘 다 맞아야 남는다', () {
      final r = filterTransactions(all, itemId: 'a', year: 2026);
      expect(r.map((e) => e.tx.id).toList(), ['a2']);
    });

    test('맞는 게 없으면 빈 목록이지 예외가 아니다', () {
      expect(filterTransactions(all, itemId: 'b', year: 2025), isEmpty);
      expect(filterTransactions(all, itemId: '없는종목'), isEmpty);
    });

    test('거른 뒤에도 최신순이 유지된다', () {
      final r = filterTransactions(all, year: 2026);
      for (var i = 1; i < r.length; i++) {
        expect(r[i - 1].tx.date.isAfter(r[i].tx.date), isTrue);
      }
    });

    test('연도 칸은 고른 종목 기준이어야 한다 — 빈 해를 만들지 않는다', () {
      // Apple은 2026년에만 샀다. 종목을 Apple로 좁히면 2025 칸은
      // 눌러도 빈 목록이므로 애초에 만들지 않는다.
      final byApple = filterTransactions(all, itemId: 'b');
      expect(transactionYears(byApple), [2026]);
    });
  });

  test('거래가 하나도 없는 포트도 죽지 않는다', () {
    final empty = Portfolio(id: 'e', name: '빈것', items: [cash]);
    expect(collectTransactions(empty), isEmpty);
    expect(transactionYears(const []), isEmpty);
    expect(filterTransactions(const [], itemId: 'x', year: 2026), isEmpty);
  });
}
