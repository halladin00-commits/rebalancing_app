import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/services/holdings_scan.dart';
import 'package:rebalancing_app/services/stock_search_service.dart';

/// 여러 증권사의 **실제 캡처**를 기기에서 읽힌 결과로 시험한다.
///
/// 웹에서 모은 남의 잔고라 저장소에 넣지 않는다 — `D:\ocr_samples`에만
/// 있다(`tools/ocr_probe.sh`로 만든다). 없는 PC에서는 건너뛴다.
///
/// `DUMP=파일` 환경변수를 주면 읽은 결과를 그 파일에 적는다 — 새 캡처를
/// 넣었을 때 눈으로 훑어보는 용도.
void main() {
  final files = [
    File('D:/ocr_samples/words_A.json'),
    File('D:/ocr_samples/words_B.json'),
  ];
  final skip =
      files.any((f) => !f.existsSync()) ? '실제 캡처 표본이 이 PC에 없다' : null;

  Map<String, List<OcrWord>> load() => {
        for (final f in files)
          for (final e
              in (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)
                  .entries)
            e.key: [
              for (final w in (e.value['lines'] as List))
                OcrWord(
                    w['t'],
                    (w['b'][0] as num).toDouble(),
                    (w['b'][1] as num).toDouble(),
                    (w['b'][2] as num).toDouble(),
                    (w['b'][3] as num).toDouble()),
            ]
      };

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

  test('읽은 결과를 적는다', () {
    final out = Platform.environment['DUMP'];
    if (out == null) return;
    final list = stocks();
    final b = StringBuffer();
    for (final e in load().entries) {
      final shot = parseHoldings(e.value);
      b.writeln('== ${e.key}'
          '${shot.notHoldingsScreen ? '  [잔고 화면 아님]' : ''}'
          '${shot.noQuantity ? '  [수량 없음]' : ''}');
      for (final h in shot.holdings) {
        final m = lookupStock(h.name, list);
        b.writeln('  ${h.check.name.padRight(6)} '
            '${h.foreign ? 'F' : ' '}${h.priceDerived ? 'd' : ' '} '
            'q=${h.qty} cur=${h.currentPrice.toStringAsFixed(1)} '
            'val=${h.value.toStringAsFixed(0)} avg=${h.avgPrice} '
            '| ${h.name} → ${m.kind.name} ${m.stock?.name ?? ''}');
      }
      for (final u in shot.unreadable) {
        b.writeln('  UNREADABLE "$u"');
      }
    }
    File(out).writeAsStringSync(b.toString());
  }, skip: skip);

  // 캡처마다 [종목 수량들]. 이름은 남의 잔고라 적지 않는다 — 수량이 차례로
  // 맞으면 종목을 빠뜨리거나 칸을 헷갈리지 않은 것이다. 해외로 표시된
  // 종목은 뺀다(넣지 않는 것들이다).
  const expected = <String, List<double>>{
    // 표
    'kiwoom_01.jpg': [10, 2, 6, 10, 146, 20, 23, 50],
    'kiwoom_02.jpg': [8, 76, 23, 89],
    'kiwoom_05.jpg': [26, 37, 200, 550],
    'mirae_01.jpg': [50, 142],
    'mirae_02.png': [25, 74, 27, 26],
    'koreainv_03.jpg': [429, 824, 165, 725, 393],
    'koreainv_04.jpg': [1, 80, 1294, 110],
    'samsung_03.jpg': [1302, 890],
    'kb_02.jpg': [145, 5, 5, 18],
    'shinhan_01.jpg': [24, 13, 92, 400, 1],
    'daishin_01.png': [6],
    'daishin_02.jpg': [11, 14, 1, 34, 12, 9, 26],
    'hana_01.png': [7, 185, 55, 20, 215, 42, 17],
    'yuanta_01.jpg': [1],
    'nh_02.jpg': [0.809196, 1, 1, 0.19144, 1.014478],
    'nh_05.jpg': [1, 2, 1, 1],
    'nh_06.jpg': [15, 17, 2, 25, 25],
    // 카드
    'kb_01.png': [1, 1],
    'kb_03.jpg': [26, 326, 76],
    'mirae_03.jpg': [12, 6, 149],
    // 목록
    'toss_01.jpg': [1, 181, 1],
    'toss_02.jpg': [60],
    'toss_04.jpg': [104, 54, 165, 5, 1],
    'toss_06.jpg': [17],
    'kakaopay_01.jpg': [3.163, 13, 1, 0.1195],
    'shinhan_04.jpg': [20],
  };

  test('증권사별 캡처 — 종목을 빠뜨리지 않고 수량 칸을 헷갈리지 않는다', () {
    final words = load();
    for (final e in expected.entries) {
      final shot = parseHoldings(words[e.key]!);
      expect(shot.holdings.where((h) => !h.foreign).map((h) => h.qty), e.value,
          reason: e.key);
    }
  }, skip: skip);

  test('수량 × 현재가 = 평가금액이 화면에 다 있는 캡처는 모두 검산이 맞는다', () {
    final words = load();
    for (final k in [
      'kiwoom_01.jpg', 'kiwoom_02.jpg', 'kiwoom_05.jpg', 'mirae_01.jpg',
      'mirae_02.png', 'shinhan_01.jpg', 'daishin_01.png', 'daishin_02.jpg',
      'hana_01.png', 'kb_01.png', 'mirae_03.jpg', 'shinhan_04.jpg',
      'nh_02.jpg', 'nh_06.jpg',
    ]) {
      final shot = parseHoldings(words[k]!);
      expect(shot.holdings.where((h) => !h.verified).map((h) => h.name),
          isEmpty, reason: k);
    }
  }, skip: skip);

  test('수량 칸이 없는 화면은 그렇다고 말한다', () {
    final words = load();
    for (final k in [
      'samsung_01.jpg', 'samsung_02.png', 'samsung_04.jpg',
      'koreainv_05.jpg', 'nh_07.png',
    ]) {
      final shot = parseHoldings(words[k]!);
      expect(shot.noQuantity, isTrue, reason: k);
      expect(shot.holdings, isEmpty, reason: k);
    }
  }, skip: skip);

  test('해외 종목이 국내 종목으로 잘못 찾아지지 않는다', () {
    // 토스·카카오페이·미니스탁의 해외 종목 이름(「인텔」「쿠팡」「SCHD」)이
    // 비슷한 국내 종목(「인텔리안테크」「쿠콘」「SHD」)으로 짐작되면 안 된다
    final words = load();
    final list = stocks();
    for (final k in [
      'etc_01.jpg', 'etc_02.jpg', 'etc_03.jpg', 'kakaopay_02.png',
      'kakaopay_03.png', 'toss_02.jpg', 'toss_05.jpg',
      'toss_07.png', 'toss_08.jpg',
    ]) {
      final shot = parseHoldings(words[k]!);
      expect(shot.notHoldingsScreen, isFalse, reason: k);
      for (final h in shot.holdings) {
        final m = lookupStock(h.name, list);
        if (m.stock == null) continue;
        expect(m.kind, NameMatch.exact, reason: '$k · ${h.name}');
      }
    }
  }, skip: skip);

  test('국내 종목은 이름으로 종목을 찾는다', () {
    final words = load();
    final list = stocks();
    const delisted = {'ACETDF2050액티브적격'};
    // 옛 이름(KINDEX·KBSTAR·ARIRANG·KOSEF)과 해외 종목이 섞인 캡처는 뺐다
    for (final k in [
      'kiwoom_01.jpg', 'kiwoom_02.jpg', 'koreainv_03.jpg', 'samsung_03.jpg',
      'shinhan_01.jpg', 'kb_01.png', 'kb_03.jpg', 'mirae_03.jpg',
      'toss_01.jpg', 'toss_04.jpg', 'nh_05.jpg',
      'nh_06.jpg', 'shinhan_04.jpg',
    ]) {
      for (final h in parseHoldings(words[k]!).holdings) {
        if (h.foreign) continue;
        // 캡처가 찍힌 뒤 상장폐지된 종목 — 목록에 없는 것이 맞다
        if (delisted.contains(h.name)) continue;
        final m = lookupStock(h.name, list);
        expect(m.stock, isNotNull, reason: '$k · ${h.name}');
      }
    }
  }, skip: skip);
}
