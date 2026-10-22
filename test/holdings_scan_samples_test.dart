import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/services/holdings_scan.dart';
import 'package:rebalancing_app/services/stock_search_service.dart';

/// **실제 캡처**를 기기에서 읽힌 결과로 시험한다.
///
/// 남의 잔고라 저장소에 넣지 않는다 — `D:\ocr_samples`에만 있다. 없는
/// PC에서는 건너뛴다. 저장소에 들어 있는 시험은 `holdings_scan_test.dart`.
void main() {
  final file = File('D:/ocr_samples/namu_words.json');
  final skip = !file.existsSync() ? '실제 캡처 표본이 이 PC에 없다' : null;

  Map<String, List<OcrWord>> load() {
    final d = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final e in d.entries)
        e.key: [
          for (final w in (e.value['lines'] as List))
            OcrWord(w['t'], (w['b'][0] as num).toDouble(),
                (w['b'][1] as num).toDouble(), (w['b'][2] as num).toDouble(),
                (w['b'][3] as num).toDouble()),
        ]
    };
  }

  List<StockSearchResult> stocks() {
    final raw = File('assets/kr_stocks.json')
        .readAsStringSync()
        .replaceFirst('\uFEFF', '');
    return [
      for (final s in jsonDecode(raw) as List)
        if (s['m'] == 'KS' || s['m'] == 'KQ')
          StockSearchResult(ticker: s['t'], name: s['n'], market: 'KR')
    ];
  }

  test('위탁 잔고 — 두 종목, 검산 일치', () {
    final shot = parseNamuHoldings(load()['71e9688d.jpg']!);
    expect(shot.holdings.map((h) => h.name),
        ['TIME 미국나스닥100액티브', 'TIGER미국배당다우존스']);
    final time = shot.holdings.first;
    expect(time.qty, 5236);
    expect(time.avgPrice, 38311);
    expect(time.currentPrice, 42170);
    expect(time.value, 220802120);
    expect(shot.holdings.every((h) => h.verified), isTrue);
    expect(shot.unreadable, isEmpty);
  }, skip: skip);

  test('ISA 두 장 — 겹친 종목을 합쳐 10개, 모두 검산 일치, 모두 종목을 찾는다',
      () {
    final words = load();
    final shots = [
      parseNamuHoldings(words['7e57791f.jpg']!),
      parseNamuHoldings(words['aad35494.jpg']!),
    ];
    expect(shots[0].holdings.length, 5);
    expect(shots[1].holdings.length, 6);
    final all = [for (final s in shots) ...s.holdings];
    expect(all.where((h) => !h.verified).map((h) => h.name), isEmpty);

    final list = stocks();
    final tickers = <String>{};
    for (final h in all) {
      final m = lookupStock(h.name, list);
      expect(m.stock, isNotNull, reason: h.name);
      expect(m.kind, anyOf(NameMatch.exact, NameMatch.prefix), reason: h.name);
      tickers.add(m.stock!.ticker);
    }
    expect(tickers.length, 10);

    final hum = all.firstWhere((h) => h.name.contains('휴머노'));
    expect(hum.qty, 259);
  }, skip: skip);

  test('거래내역 화면은 잔고 화면이 아니라고 말한다', () {
    final shot = parseNamuHoldings(load()['89d94d30.jpg']!);
    expect(shot.notHoldingsScreen, isTrue);
  }, skip: skip);
}
