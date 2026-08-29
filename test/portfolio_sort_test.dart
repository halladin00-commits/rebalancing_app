import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/screens/portfolio_reorder_screen.dart';

/// 자산 탭의 포트폴리오 정렬 (시안 v16c).
///
/// 드래그는 에뮬레이터에서 `adb input`으로 재현되지 않아 눈으로만 봤다.
/// 순서를 정하는 계산은 여기서 지킨다.
void main() {
  /// [shares]주를 [price]에 사고 지금 [now]가 된 종목 하나짜리 포트.
  Portfolio pf(
    String name, {
    required double shares,
    required double avg,
    required double now,
    String currency = 'KRW',
    double fx = 1370,
  }) =>
      Portfolio(
        id: name,
        name: name,
        currency: currency,
        exchangeRate: fx,
        items: [
          PortfolioItem(
            id: '$name-i',
            name: 'i',
            ticker: 'i',
            market: currency == 'USD' ? 'US' : 'KR',
            shares: shares,
            avgPrice: avg,
            currentPrice: now,
          ),
        ],
      );

  List<String> names(List<Portfolio> l) => l.map((p) => p.name).toList();

  test('직접 배치는 준 순서를 그대로 돌려준다', () {
    final list = [
      pf('c', shares: 1, avg: 100, now: 100),
      pf('a', shares: 1, avg: 100, now: 100),
      pf('b', shares: 1, avg: 100, now: 100),
    ];
    expect(names(sortPortfolios(list, PortfolioSort.manual)), ['c', 'a', 'b']);
  });

  test('원본 목록을 건드리지 않는다', () {
    final list = [
      pf('small', shares: 1, avg: 100, now: 100),
      pf('big', shares: 10, avg: 100, now: 100),
    ];
    sortPortfolios(list, PortfolioSort.value);
    expect(names(list), ['small', 'big'], reason: 'provider의 순서가 바뀌었다');
  });

  group('금액순', () {
    test('큰 것부터', () {
      final list = [
        pf('작음', shares: 1, avg: 100, now: 100), // 100
        pf('큼', shares: 10, avg: 100, now: 100), // 1,000
        pf('중간', shares: 5, avg: 100, now: 100), // 500
      ];
      expect(names(sortPortfolios(list, PortfolioSort.value)),
          ['큼', '중간', '작음']);
    });

    test('달러 포트는 원화로 환산해 견준다', () {
      // $100 × 1370 = ₩137,000 > ₩100,000. 액면(100 < 100,000)으로 비교하면
      // 달러 포트가 늘 아래로 간다.
      final list = [
        pf('원화', shares: 1, avg: 100000, now: 100000),
        pf('달러', shares: 1, avg: 100, now: 100, currency: 'USD'),
      ];
      expect(names(sortPortfolios(list, PortfolioSort.value)), ['달러', '원화']);
    });
  });

  group('수익률순', () {
    test('높은 것부터', () {
      final list = [
        pf('10%', shares: 1, avg: 100, now: 110),
        pf('50%', shares: 1, avg: 100, now: 150),
        pf('손실', shares: 1, avg: 100, now: 90),
      ];
      expect(names(sortPortfolios(list, PortfolioSort.returnRate)),
          ['50%', '10%', '손실']);
    });

    test('금액이 아니라 비율로 견준다', () {
      // 큰 포트가 조금 오른 것보다, 작은 포트가 많이 오른 쪽이 위다.
      final list = [
        pf('크고 조금', shares: 1000, avg: 100, now: 101), // +1%
        pf('작고 많이', shares: 1, avg: 100, now: 200), // +100%
      ];
      expect(names(sortPortfolios(list, PortfolioSort.returnRate)),
          ['작고 많이', '크고 조금']);
    });

    test('원금을 모르는 포트는 맨 뒤로 — 0%로 치면 손실 포트보다 위에 선다', () {
      final noCost = Portfolio(id: 'x', name: '원금없음', items: [
        PortfolioItem(
            id: 'x-i',
            name: 'i',
            ticker: 'i',
            market: 'KR',
            shares: 10,
            avgPrice: 0,
            currentPrice: 100),
      ]);
      final list = [
        noCost,
        pf('손실', shares: 1, avg: 100, now: 90),
        pf('이익', shares: 1, avg: 100, now: 110),
      ];
      expect(names(sortPortfolios(list, PortfolioSort.returnRate)),
          ['이익', '손실', '원금없음']);
    });

    test('빈 포트도 죽지 않는다', () {
      final empty = Portfolio(id: 'e', name: '빈것', items: []);
      final list = [empty, pf('이익', shares: 1, avg: 100, now: 110)];
      expect(names(sortPortfolios(list, PortfolioSort.returnRate)),
          ['이익', '빈것']);
    });
  });

  test('포트가 없거나 하나뿐이어도 죽지 않는다', () {
    for (final s in PortfolioSort.values) {
      expect(sortPortfolios(const [], s), isEmpty);
      final one = [pf('하나', shares: 1, avg: 100, now: 100)];
      expect(names(sortPortfolios(one, s)), ['하나']);
    }
  });
}
