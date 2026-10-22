import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/holdings_scan.dart';
import 'package:rebalancing_app/services/stock_search_service.dart';

/// NH 나무 「주식잔고」 표를 **지어낸 숫자로** 그대로 흉내 낸다.
///
/// 낱말 자리는 실제 캡처(1080px 폭)를 기기에서 읽힌 자리와 같게 잡았다.
/// 실제 캡처로 하는 시험은 `holdings_scan_samples_test.dart`.
class _Screen {
  final words = <OcrWord>[];
  double y = 0;

  void w(String t, double x, double top, {double width = 100}) =>
      words.add(OcrWord(t, x, top, x + width, top + 34));

  void header() {
    w('종목명', 103, 958);
    w('평가손익', 369, 960, width: 123);
    w('잔고수량', 628, 956, width: 160);
    w('매입가', 911, 958, width: 93);
    w('국가', 61, 1035, width: 80);
    w('구분', 150, 1035, width: 80);
    w('수익률', 385, 1039, width: 92);
    w('평가금액', 628, 1037, width: 124);
    w('현재가', 911, 1039, width: 92);
    y = 1102;
  }

  /// 종목 한 칸 — 이름 줄들, 숫자 두 줄, 「국내 현금」.
  void holding(List<List<String>> nameLines, String qty, String value,
      String avg, String cur,
      {String country = '국내', List<String>? splitValue}) {
    final top = y;
    for (var i = 0; i < nameLines.length; i++) {
      var x = 18.0;
      for (final part in nameLines[i]) {
        w(part, x, top + i * 39, width: 80);
        x += 90;
      }
    }
    w('20,000', 340, top + 19, width: 195); // 평가손익 — 안 쓴다
    w(qty, 697, top + 19, width: 98);
    w(avg, 944, top + 19, width: 117);
    final second = top + 96;
    w('3.05%', 425, second, width: 100); // 수익률 — 안 쓴다
    if (splitValue != null) {
      w(splitValue[0], 597, second, width: 140);
      w(splitValue[1], 745, second, width: 50);
    } else {
      w(value, 597, second, width: 198);
    }
    w(cur, 943, second, width: 122);
    w(country, 18, second + 6, width: 51);
    w('현금', 233, second + 6, width: 50);
    y = top + 169;
  }

  void bottomNav() {
    w('홈', 203, 2094, width: 28);
    w('주식', 343, 2071, width: 87);
    w('국내', 896, 2074, width: 60);
    w('현재가', 735, 2115, width: 94);
  }
}

StockSearchResult _s(String t, String n) =>
    StockSearchResult(ticker: t, name: n, market: 'KR');

final _stocks = [
  _s('100001', 'ALPHA 미국테크100액티브'),
  _s('100002', 'BETA 글로벌반도체TOP4 Plus'),
  _s('100003', 'GAMMA 미국배당'),
  _s('100004', 'GAMMA 미국배당커버드콜'),
  _s('100005', 'DELTA 글로벌AI인공지능액티브'),
];

void main() {
  group('표 읽기', () {
    test('꺾인 이름을 이어 붙이고 수량·평가금액·매입가·현재가를 읽는다', () {
      final s = _Screen()..header();
      s.holding([['ALPHA', '미국테크'], ['100액티브']], '5,236', '220,802,120',
          '38,311', '42,170');
      s.bottomNav();
      final shot = parseNamuHoldings(s.words);
      expect(shot.holdings, hasLength(1));
      final h = shot.holdings.single;
      expect(h.name, 'ALPHA 미국테크100액티브');
      expect([h.qty, h.value, h.avgPrice, h.currentPrice],
          [5236, 220802120, 38311, 42170]);
      expect(h.verified, isTrue);
      expect(h.foreign, isFalse);
    });

    test('사이가 떠서 둘로 읽힌 숫자를 하나로 붙인다', () {
      final s = _Screen()..header();
      s.holding([['ALPHA']], '5,236', '', '38,311', '42,170',
          splitValue: ['220,802,1', '20']);
      expect(parseNamuHoldings(s.words).holdings.single.value, 220802120);
    });

    test('숫자를 잘못 읽으면 검산이 걸린다', () {
      final s = _Screen()..header();
      s.holding([['ALPHA']], '5,236', '220,802,120', '38,311', '42,110');
      expect(parseNamuHoldings(s.words).holdings.single.verified, isFalse);
    });

    test('국내가 아니면 해외 종목으로 표시한다', () {
      final s = _Screen()..header();
      s.holding([['ALPHA']], '10', '1,000', '90', '100', country: '해외');
      expect(parseNamuHoldings(s.words).holdings.single.foreign, isTrue);
    });

    test('바닥에서 잘린 종목은 버리고, 아래 메뉴를 종목으로 읽지 않는다', () {
      final s = _Screen()..header();
      s.holding([['ALPHA']], '10', '1,000', '90', '100');
      // 이름과 첫 줄만 보이고 잘렸다
      s.w('GAMMA', 18, s.y, width: 80);
      s.w('7', 697, s.y + 19, width: 50);
      s.bottomNav();
      final shot = parseNamuHoldings(s.words);
      expect(shot.holdings.map((h) => h.name), ['ALPHA']);
      expect(shot.unreadable, isEmpty);
    });

    test('가운데 칸의 숫자가 모자라면 읽지 못한 종목으로 알린다', () {
      final s = _Screen()..header();
      s.holding([['ALPHA']], '10', '1,000', '90', '100');
      final start = s.words.length;
      s.holding([['GAMMA']], '10', '1,000', '90', '100');
      // GAMMA의 현재가를 못 읽었다
      s.words.removeWhere((w) =>
          s.words.indexOf(w) >= start && w.text == '100' && w.left == 943);
      final shot = parseNamuHoldings(s.words);
      expect(shot.holdings.map((h) => h.name), ['ALPHA']);
      expect(shot.unreadable, ['GAMMA']);
    });

    test('머리글이 없으면 잔고 화면이 아니라고 한다', () {
      final shot = parseNamuHoldings(const [OcrWord('매도', 0, 0, 10, 10)]);
      expect(shot.notHoldingsScreen, isTrue);
    });
  });

  group('종목 찾기', () {
    test('같은 이름 — 띄어쓰기는 보지 않는다', () {
      final m = lookupStock('ALPHA미국테크100액티브', _stocks);
      expect(m.kind, NameMatch.exact);
      expect(m.stock!.ticker, '100001');
    });

    test('잘린 이름 — 그렇게 시작하는 종목이 하나면 그것', () {
      final m = lookupStock('BETA 글로벌반도체TOP4', _stocks);
      expect(m.kind, NameMatch.prefix);
      expect(m.stock!.ticker, '100002');
    });

    test('같은 이름이 있으면 더 긴 이름들보다 먼저다', () {
      final m = lookupStock('GAMMA 미국배당', _stocks);
      expect(m.kind, NameMatch.exact);
      expect(m.stock!.ticker, '100003');
    });

    test('그렇게 시작하는 종목이 여럿이면 고르게 한다', () {
      final m = lookupStock('GAMMA 미국', _stocks);
      expect(m.kind, NameMatch.ambiguous);
      expect(m.candidates.map((c) => c.ticker), ['100003', '100004']);
    });

    test('한 글자 잘못 읽은 이름은 가장 가까운 것 — 확인 필요', () {
      final m = lookupStock('DELTA 글로벌A인공지능액티브', _stocks);
      expect(m.kind, NameMatch.fuzzy);
      expect(m.stock!.ticker, '100005');
    });

    test('없는 이름', () {
      expect(lookupStock('없는종목', _stocks).kind, NameMatch.none);
    });
  });

  group('앱과 맞대기', () {
    ScannedHolding h(String name, double qty,
            {double cur = 100, double? value, bool foreign = false}) =>
        ScannedHolding(
            name: name,
            qty: qty,
            avgPrice: 90,
            currentPrice: cur,
            value: value ?? qty * cur,
            foreign: foreign);

    Portfolio pf(List<PortfolioItem> items) =>
        Portfolio(id: 'p', name: 'ISA', items: items);

    PortfolioItem item(String id, String ticker, String name, double qty) =>
        PortfolioItem(id: id, name: name, ticker: ticker, transactions: [
          StockTransaction(
              id: 't$id', date: DateTime(2026, 1, 1), quantity: qty, price: 90)
        ])
          ..syncFromTransactions();

    test('새 종목은 골라 두고, 이미 있는 종목은 수량만 맞대 본다', () {
      final rows = buildHoldingRows([
        HoldingsShot(holdings: [
          h('ALPHA 미국테크100액티브', 10),
          h('BETA 글로벌반도체TOP4', 259),
          h('GAMMA 미국배당', 5),
        ])
      ], pf([
        item('b', '100002', 'BETA 글로벌반도체TOP4 Plus', 262),
        item('g', '100003', 'GAMMA 미국배당', 5),
      ]), _stocks);

      final alpha = rows.firstWhere((r) => r.stock?.ticker == '100001');
      expect(alpha.existing, isNull);
      expect(alpha.preselected, isTrue);

      final beta = rows.firstWhere((r) => r.stock?.ticker == '100002');
      expect(beta.existing!.id, 'b');
      expect(beta.sameQty, isFalse);
      expect(beta.addable, isFalse, reason: '있는 종목은 건드리지 않는다');
      expect(beta.displayName, 'BETA 글로벌반도체TOP4 Plus');

      final gamma = rows.firstWhere((r) => r.stock?.ticker == '100003');
      expect(gamma.sameQty, isTrue);
    });

    test('두 장에 겹친 종목은 한 줄 — 검산이 맞는 쪽을 남긴다', () {
      final rows = buildHoldingRows([
        HoldingsShot(holdings: [h('ALPHA', 10, value: 999)]),
        HoldingsShot(holdings: [h('ALPHA', 10)]),
      ], pf([]), [_s('100001', 'ALPHA')]);
      expect(rows, hasLength(1));
      expect(rows.single.scan.verified, isTrue);
    });

    test('걸리는 데가 있으면 처음에 골라 두지 않는다', () {
      final rows = buildHoldingRows([
        HoldingsShot(holdings: [
          h('ALPHA 미국테크100액티브', 10, value: 999), // 검산 실패
          h('DELTA 글로벌A인공지능액티브', 3), // 이름 짐작
          h('GAMMA 미국', 3), // 여럿
          h('없는종목', 3),
          h('EPSILON 해외주식', 1, foreign: true),
        ])
      ], pf([]), _stocks);
      final byIssue = {for (final r in rows) r.issue: r};
      expect(byIssue.keys, containsAll(HoldingIssue.values));
      for (final r in rows) {
        expect(r.preselected, isFalse, reason: r.scan.name);
      }
      expect(byIssue[HoldingIssue.numbersOff]!.addable, isTrue);
      expect(byIssue[HoldingIssue.nameGuessed]!.addable, isTrue);
      expect(byIssue[HoldingIssue.notFound]!.addable, isFalse);
      expect(byIssue[HoldingIssue.foreign]!.addable, isFalse);
    });

    test('새 종목은 오늘, 오늘 현재가로 매수 1건 — 결산에 평가이익이 몰리지 않는다', () {
      final row = HoldingRow(
          const ScannedHolding(
              name: 'BETA 글로벌반도체TOP4',
              qty: 64,
              avgPrice: 37294,
              currentPrice: 70190,
              value: 4492160),
          lookupStock('BETA 글로벌반도체TOP4', _stocks),
          null);
      final it = newItemFromScan(row, 'n1', DateTime(2026, 10, 22, 15, 30));
      expect(it.name, 'BETA 글로벌반도체TOP4 Plus', reason: '잘리지 않은 이름');
      expect(it.ticker, '100002');
      expect(it.transactions, hasLength(1));
      final tx = it.transactions.single;
      expect(tx.date, DateTime(2026, 10, 22));
      expect(tx.quantity, 64);
      expect(tx.price, 70190, reason: '매입가(37,294)가 아니라 현재가');
      expect(it.shares, 64);
      expect(it.shares * it.currentPrice, 4492160,
          reason: '들어간 날 평가금액 = 산 돈');
    });
  });
}
