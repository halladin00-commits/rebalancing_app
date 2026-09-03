import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/asset_backfill_service.dart';

/// 안 켠 날의 자산을 거래 내역 + 그날 종가로 되짚는다.
///
/// 기록만 쌓으면 선이 **접속 기록**이 된다. 되짚은 값이 그날 실제 자산과
/// 맞아야 채우는 의미가 있다.
void main() {
  final d1 = DateTime(2026, 3, 2); // 월
  final d2 = DateTime(2026, 3, 3);
  final d3 = DateTime(2026, 3, 4);

  PortfolioItem item({
    required String id,
    String market = 'KR',
    List<StockTransaction> tx = const [],
  }) =>
      PortfolioItem(
        id: id,
        name: id,
        ticker: id,
        market: market,
        shares: tx.fold(0.0, (s, t) => s + t.quantity),
        transactions: List.of(tx),
      );

  StockTransaction buy(DateTime date, double qty, double price) =>
      StockTransaction(
        id: '$date-$qty',
        date: date,
        quantity: qty,
        price: price,
      );

  test('보유 수량 × 그날 종가로 총자산을 낸다', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      items: [
        item(id: 'a', tx: [buy(d1, 10, 1000)]),
      ],
    );

    final out = buildDailyAssets(
      portfolios: [pf],
      closesByItemId: {
        'a': {d1: 1000, d2: 1100, d3: 900},
      },
      from: d1,
      to: d3,
    );

    expect(out.map((e) => e.totalKrw).toList(), [10000, 11000, 9000]);
    expect(out.first.byPortfolio['p1'], 10000);
  });

  test('기간 중에 산 종목은 산 날부터 잡힌다', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      items: [
        item(id: 'a', tx: [buy(d1, 10, 1000)]),
        item(id: 'b', tx: [buy(d3, 5, 2000)]),
      ],
    );

    final out = buildDailyAssets(
      portfolios: [pf],
      closesByItemId: {
        'a': {d1: 1000, d2: 1000, d3: 1000},
        'b': {d1: 2000, d2: 2000, d3: 2000},
      },
      from: d1,
      to: d3,
    );

    // d1·d2는 a만, d3부터 b가 더해진다
    expect(out.map((e) => e.totalKrw).toList(), [10000, 10000, 20000]);
  });

  test('판 만큼 줄어든다', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      items: [
        item(id: 'a', tx: [buy(d1, 10, 1000), buy(d3, -4, 1000)]),
      ],
    );

    final out = buildDailyAssets(
      portfolios: [pf],
      closesByItemId: {
        'a': {d1: 1000, d2: 1000, d3: 1000},
      },
      from: d1,
      to: d3,
    );
    expect(out.map((e) => e.totalKrw).toList(), [10000, 10000, 6000]);
  });

  test('휴장일은 마지막 종가를 끌고 온다 — 그날만 자산이 꺼지지 않게', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      items: [
        item(id: 'kr', tx: [buy(d1, 10, 1000)]),
        item(id: 'us', market: 'US', tx: [buy(d1, 1, 100)]),
      ],
    );

    // d2는 국내 휴장 — us만 값이 있다
    final out = buildDailyAssets(
      portfolios: [pf],
      closesByItemId: {
        'kr': {d1: 1000, d3: 1000},
        'us': {d1: 100, d2: 100, d3: 100},
      },
      from: d1,
      to: d3,
    );

    // 환율 기본값이 곱해지므로 국내분만 따로 확인한다
    expect(out.length, 3);
    final krPart = out.map((e) => e.totalKrw - 100 * pf.exchangeRate).toList();
    for (final v in krPart) {
      expect(v, closeTo(10000, 0.001));
    }
  });

  test('해외 종목은 포트 환율로 원화 환산한다', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      exchangeRate: 1300,
      items: [
        item(id: 'us', market: 'US', tx: [buy(d1, 2, 50)]),
      ],
    );

    final out = buildDailyAssets(
      portfolios: [pf],
      closesByItemId: {
        'us': {d1: 50},
      },
      from: d1,
      to: d1,
    );
    expect(out.single.totalKrw, closeTo(2 * 50 * 1300, 0.001));
  });

  test('아무것도 안 산 날은 점을 남기지 않는다 — 0에서 솟는 선 방지', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      items: [
        item(id: 'a', tx: [buy(d3, 10, 1000)]),
      ],
    );

    final out = buildDailyAssets(
      portfolios: [pf],
      closesByItemId: {
        'a': {d1: 1000, d2: 1000, d3: 1000},
      },
      from: d1,
      to: d3,
    );
    expect(out.length, 1);
    expect(out.single.date, d3);
  });

  test('예수금은 지금 잔액을 모든 날에 같이 더한다 — 선의 모양은 안 바뀐다', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      items: [
        item(id: 'a', tx: [buy(d1, 10, 1000)]),
        PortfolioItem(id: 'cash', name: '예수금', isCash: true, shares: 500),
      ],
    );

    final out = buildDailyAssets(
      portfolios: [pf],
      closesByItemId: {
        'a': {d1: 1000, d2: 1100},
      },
      from: d1,
      to: d2,
    );
    expect(out.map((e) => e.totalKrw).toList(), [10500, 11500]);
    // 차이는 종가 변화 그대로다
    expect(out[1].totalKrw - out[0].totalKrw, 1000);
  });

  test('첫 거래일을 찾는다', () {
    final pf = Portfolio(
      id: 'p1',
      name: '위탁',
      currency: 'KRW',
      items: [
        item(id: 'a', tx: [buy(d3, 1, 1), buy(d1, 1, 1)]),
        item(id: 'b', tx: [buy(d2, 1, 1)]),
      ],
    );
    expect(AssetBackfillService.firstTransactionDay([pf]), d1);
    expect(AssetBackfillService.firstTransactionDay([]), isNull);
  });
}
