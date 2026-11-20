import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/dividend_service.dart';

/// 배당 추정 — 결산에 따로 보여 주는 값. 수익률에는 넣지 않는다.
void main() {
  StockTransaction tx(DateTime d, double q, [double p = 10000]) =>
      StockTransaction(id: '${d.millisecondsSinceEpoch}$q', date: d, quantity: q, price: p);

  PortfolioItem item(String ticker, String market, List<StockTransaction> txs) =>
      PortfolioItem(
          id: ticker, name: ticker, ticker: ticker, market: market, transactions: txs);

  setUp(DividendService.resetForTest);

  group('야후 응답에서 날짜 읽기', () {
    test('국내 종목: UTC 0시로 와도 거래소 날짜(한국)로 자른다', () {
      // 2026-10-29 00:00 UTC, gmtoffset +9h → 한국 10월 29일
      final ts = DateTime.utc(2026, 10, 29).millisecondsSinceEpoch ~/ 1000;
      final ev = DividendService.parseChart({
        'chart': {
          'result': [
            {
              'meta': {'gmtoffset': 32400},
              'events': {
                'dividends': {
                  '$ts': {'date': ts, 'amount': 136.0}
                }
              }
            }
          ]
        }
      })!;
      expect(ev.single.exDate, DateTime(2026, 10, 29));
      expect(ev.single.perShare, 136.0);
    });

    test('미국 종목: 뉴욕 장 시작 시각으로 와도 그날로 자른다', () {
      // 2026-09-23 13:30 UTC = 뉴욕 09:30, gmtoffset −4h
      final ts = DateTime.utc(2026, 9, 23, 13, 30).millisecondsSinceEpoch ~/ 1000;
      final ev = DividendService.parseChart({
        'chart': {
          'result': [
            {
              'meta': {'gmtoffset': -14400},
              'events': {
                'dividends': {
                  '$ts': {'date': ts, 'amount': 0.267}
                }
              }
            }
          ]
        }
      })!;
      expect(ev.single.exDate, DateTime(2026, 9, 23));
    });

    test('배당이 없는 종목은 빈 목록, 없는 종목은 null', () {
      expect(
          DividendService.parseChart({
            'chart': {
              'result': [
                {'meta': {'gmtoffset': 0}}
              ]
            }
          }),
          isEmpty);
      expect(DividendService.parseChart({'chart': {'result': null}}), isNull);
    });
  });

  group('기간 안의 배당 고르기', () {
    final pf = Portfolio(id: 'p', name: 'p', items: []);
    final ev = [
      DividendEvent(DateTime(2026, 7, 30), 183),
      DividendEvent(DateTime(2026, 10, 29), 136),
    ];

    test('배당락일 전까지 가진 수량 × 1주당 배당', () {
      final it = item('069500', 'KR', [tx(DateTime(2026, 1, 5, 10), 50)]);
      final lines = DividendService.linesFor(
          pf, it, ev, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(lines.single.shares, 50);
      expect(lines.single.amount, 50 * 136);
    });

    test('배당락일에 산 주식은 못 받는다', () {
      final it = item('069500', 'KR', [
        tx(DateTime(2026, 1, 5), 50),
        tx(DateTime(2026, 10, 29, 10), 20), // 배당락일 장중 매수
      ]);
      final lines = DividendService.linesFor(
          pf, it, ev, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(lines.single.shares, 50);
    });

    test('배당락일에 판 주식은 받는다', () {
      final it = item('069500', 'KR', [
        tx(DateTime(2026, 1, 5), 50),
        tx(DateTime(2026, 10, 29, 10), -50), // 배당락일에 전부 매도
      ]);
      final lines = DividendService.linesFor(
          pf, it, ev, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(lines.single.shares, 50);
    });

    test('기간 첫날과 마지막 날의 배당락일도 들어간다', () {
      final it = item('069500', 'KR', [tx(DateTime(2026, 1, 5), 10)]);
      expect(
          DividendService.linesFor(
                  pf, it, ev, DateTime(2026, 10, 29), DateTime(2026, 10, 29))
              .length,
          1);
      expect(
          DividendService.linesFor(
                  pf, it, ev, DateTime(2026, 10, 30), DateTime(2026, 11, 30))
              .length,
          0);
    });

    test('배당락일에 갖고 있지 않았으면 없다', () {
      final it = item('069500', 'KR', [tx(DateTime(2026, 8, 1), 10)]);
      final lines = DividendService.linesFor(
          pf, it, ev, DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      expect(lines, isEmpty);
    });

    test('원화 계좌의 미국 종목은 그 계좌 환율로 원화가 된다', () {
      final krw = Portfolio(id: 'k', name: 'k', exchangeRate: 1400, items: []);
      final it = item('SCHD', 'US', [tx(DateTime(2026, 1, 5), 100, 27)]);
      final lines = DividendService.linesFor(krw, it,
          [DividendEvent(DateTime(2026, 9, 23), 0.25)], DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(lines.single.perShare, 0.25); // 1주당은 종목 통화 그대로
      expect(lines.single.amount, closeTo(100 * 0.25 * 1400, 1e-6));
    });
  });

  group('받아서 합치기', () {
    String chart(List<(DateTime, double)> divs, {int offset = 32400}) =>
        json.encode({
          'chart': {
            'result': [
              {
                'meta': {'gmtoffset': offset},
                'events': {
                  'dividends': {
                    for (final d in divs)
                      '${d.$1.millisecondsSinceEpoch ~/ 1000}': {
                        'date': DateTime.utc(d.$1.year, d.$1.month, d.$1.day)
                                .millisecondsSinceEpoch ~/
                            1000,
                        'amount': d.$2,
                      }
                  }
                }
              }
            ]
          }
        });

    test('같은 종목은 한 번만 받는다 · 못 받은 종목은 센다', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (req.url.path.contains('069500.KS')) {
          return http.Response(chart([(DateTime(2026, 10, 29), 136)]), 200);
        }
        return http.Response('{"chart":{"result":null}}', 404);
      });
      final a = item('069500', 'KR', [tx(DateTime(2026, 1, 5), 10)]);
      final b = item('BROKEN', 'US', [tx(DateTime(2026, 1, 5), 1)]);
      final pf1 = Portfolio(id: '1', name: '1', items: [a, b]);
      final pf2 = Portfolio(id: '2', name: '2',
          items: [item('069500', 'KR', [tx(DateTime(2026, 1, 5), 5)])]);

      final r = await http.runWithClient(
          () => DividendService.estimateCombined(
              [pf1, pf2], 'KRW', DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
          () => client);
      expect(r.total, 15 * 136);
      expect(r.failed, 1);
      expect(r.byPortfolio.map((p) => p.id), ['1', '2']);
      // 069500은 .KS 한 번, BROKEN은 한 번 — 같은 종목을 두 번 받지 않는다
      expect(calls, 2);
    });

    test('달러로 합치면 원화 계좌 배당은 평균 환율로 나눈다', () async {
      final client = MockClient((req) async =>
          http.Response(chart([(DateTime(2026, 10, 29), 1400)]), 200));
      final k = Portfolio(id: 'k', name: 'k', exchangeRate: 1400,
          items: [item('005930', 'KR', [tx(DateTime(2026, 1, 5), 1)])]);
      final r = await http.runWithClient(
          () => DividendService.estimateCombined(
              [k], 'USD', DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
          () => client);
      expect(r.total, closeTo(1.0, 1e-9)); // ₩1,400 ÷ 1,400
      expect(r.currency, 'USD');
    });

    test('기간이 끝나기 전에 거래가 없던 종목은 묻지도 않는다', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(chart([]), 200);
      });
      final later = item('069500', 'KR', [tx(DateTime(2026, 11, 5), 10)]);
      final pf = Portfolio(id: 'p', name: 'p', items: [later]);
      await http.runWithClient(
          () => DividendService.estimate(
              pf, DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
          () => client);
      expect(calls, 0);
    });
  });
}
