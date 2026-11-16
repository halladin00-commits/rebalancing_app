import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/services/holdings_scan.dart';

/// 미국 증권사 앱 10곳의 **실제 캡처** 68장을 글자 읽기에 돌린 결과로 본다.
///
/// 남의 잔고가 찍혀 있어 저장소에 넣지 않는다(D:/ocr_samples). 파일이 없는
/// PC에서는 건너뛴다 — 화면 모양별 시험은 holdings_us_layouts_test에 있다.
/// 정답은 캡처를 눈으로 옮겨 적은 것이다(web_us/index_A.md · index_B.md).
void main() {
  final files = [
    File('D:/ocr_samples/words_US_A.json'),
    File('D:/ocr_samples/words_US_B.json'),
  ];
  final skip =
      files.any((f) => !f.existsSync()) ? '실제 캡처 표본이 이 PC에 없다' : null;

  late final Map<String, HoldingsShot> shots = {
    for (final f in files)
      for (final e
          in (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>).entries)
        e.key: parseHoldings([
          for (final w in (e.value['lines'] as List))
            OcrWord(
                w['t'],
                (w['b'][0] as num).toDouble(),
                (w['b'][1] as num).toDouble(),
                (w['b'][2] as num).toDouble(),
                (w['b'][3] as num).toDouble()),
        ])
  };

  /// 캡처 → [티커, 수량]들. 화면에 있는 종목을 빠짐없이, 순서대로.
  const expected = <String, List<(String, double)>>{
    // ── 목록 (Robinhood · SoFi · Fidelity) ──
    'robinhood_01.jpg': [
      ('GLD', 10), ('GO0G', 1), ('VOO', 4), ('TQQQ', 10), ('VTI', 4), //
      ('AAPL', 2), ('ZM', 1),
    ],
    'robinhood_02.jpg': [
      ('AAPL', 0.040578), ('VTI', 0.035214), ('VWO', 0.027273), //
      ('VEA', 0.04681), ('BND', 0.152613), ('SPY', 0.03956),
      ('AMZN', 0.260589), ('ENPH', 0.123105), ('FSLR', 0.08246),
    ],
    'robinhood_04.jpg': [
      ('BITO', 21.63), ('VTI', 1.63), ('VUG', 1.36), ('VBK', 1.52), //
      ('SCHG', 5.23), ('IWP', 3.76), ('DVY', 2.73), ('DIA', 0.915544),
      ('IBUY', 7.09),
    ],
    'robinhood_06.jpg': [
      ('T', 49.73), ('STAG', 27.91), ('MAIN', 22.08), ('ABBV', 16.61), //
      ('KO', 12.56), ('NEE', 12.3), ('AFL', 7.53),
    ],
    // 맨 위 옵션 줄(「SOFI $12.5 Put」)은 종목이 아니다
    'robinhood_10.jpg': [
      ('SOFI', 10000), ('RIOT', 5000), ('SENS', 5000), ('IDEX', 10000), //
      ('CHPT', 400),
    ],
    'robinhood_11.jpg': [
      ('F', 21), ('AMD', 25), ('TWTR', 11), ('BAC', 10), ('VTI', 1), //
      ('TM', 1), ('SGMO', 17), ('HMC', 1),
    ],
    // 아래의 WATCHLIST(수량 줄 없음)는 뺀다
    'robinhood_12.jpg': [
      ('AUPH', 1854), ('ARRY', 595), ('DRYS', 1500), ('AMD', 100), //
    ],
    // 아래의 History 줄들은 종목이 아니다
    'robinhood_08.jpg': [('NVDA', 32.62), ('AMD', 20.78), ('FIP', 346.63)],
    'sofi_01.jpg': [('OWLT', 300), ('NVTA', 100)],
    'fidelity_04.jpeg': [
      ('BAC', 1.685), ('FXAIX', 1.617), ('JEPI', 0.965), ('QQQI', 0.189), //
      ('SCHD', 2.199), ('SPAXX', 303.46), ('SPYD', 0.444), ('VTI', 0.062),
      ('VXUS', 0.278),
    ],
    'fidelity_06.jpeg': [('FSKAX', 0.367), ('SPAXX', 401.34)],
    // 「shares」가 다음 줄로 꺾였다
    'fidelity_07.jpeg': [('FZILX', 439.877), ('FZROX', 1129.587)],

    // ── 겹쳐 적는 표 (Webull · moomoo) ──
    'webull_03.jpg': [
      ('ACST', 200), ('CLSN', 200), ('NIO', 5), ('SNDL', 250), ('ZOM', 250), //
    ],
    'webull_04.jpg': [
      ('AAPL', 50000), ('AMC', 259500), ('AOK', 100000), ('CCIV', 96500), //
      ('GME', 703001),
    ],
    'webull_05.jpg': [('GME', 2)],
    'webull_06.jpg': [('AAPL', 0.73)],
    'moomoo_01.webp': [
      ('ORCL', 70), ('MU', 7), ('VOO', 4), ('PLUG', 50), ('COIN', 1), //
      ('GORO', 100),
    ],
    'moomoo_02.webp': [('ICSH', 2.1908), ('NVDA', 5.4751)],
    // 묶음 줄과 옵션 줄 사이의 주식 한 줄
    'moomoo_04.webp': [('AAPL', 400)],

    // ── 한 줄짜리 표 (E*TRADE · Schwab · Fidelity · IBKR · Merrill) ──
    'etrade_03.jpg': [
      ('FDGRX', 506.579), ('FSELX', 240.107), ('FSPTX', 488.191), //
      ('FTCHX', 100.56), ('FXAIX', 6.276), ('MU', 30.193), ('NASDX', 63.472),
      ('NVDA', 118.05), ('OPTFX', 13.521), ('PRSCX', 86.699),
      ('SLMCX', 19.465), ('VAFAX', 53.887),
    ],
    'etrade_05.jpeg': [('CLM', 16), ('SPYI', 18)],
    'schwab_03.png': [
      ('ZQVX', 37.9508), ('KMRJ', 10.4285), ('TLYQ', 3.0402), //
      ('BRQY', 2.0033), ('DRVO', 5.086), ('SVXX', 1),
    ],
    'fidelity_08.jpeg': [
      ('FBGRX', 0.963), ('FSKAX', 11.57), ('FTIHX', 61.612), //
      ('QQQM', 2.351), ('SCHD', 7.936), ('SPAXX', 14.84),
    ],
    'merrill_02.jpg': [
      ('IIAXX', 97.07), ('BUPXX', 55), ('USIG', 6), ('IUSV', 36), //
      ('IUSG', 18), ('VEA', 28), ('VWO', 18), ('VTWO', 11),
    ],
  };

  test('티커와 수량을 빠짐없이, 화면 순서대로 읽는다', () {
    for (final e in expected.entries) {
      final shot = shots[e.key]!;
      expect(
          [for (final h in shot.holdings) (h.symbol, h.qty)], e.value,
          reason: e.key);
      expect(shot.holdings.every((h) => h.currency == 'USD' && !h.foreign),
          isTrue,
          reason: e.key);
      expect(shot.unreadable, isEmpty, reason: '${e.key} · 못 읽은 줄이 있다');
    }
  }, skip: skip);

  test('표에 수량·현재가·평가금액이 다 있으면 검산이 맞는다', () {
    for (final k in [
      'webull_03.jpg', 'webull_05.jpg', 'webull_06.jpg', //
      'moomoo_01.webp', 'moomoo_02.webp', 'moomoo_04.webp',
    ]) {
      for (final h in shots[k]!.holdings) {
        expect(h.check, NumberCheck.ok, reason: '$k · ${h.symbol}');
      }
    }
    // 「6.08M」처럼 줄여 적은 평가금액은 검산에 못 쓴다
    expect(
        shots['webull_04.jpg']!.holdings.every((h) => h.check == NumberCheck.none),
        isTrue);
  }, skip: skip);

  test('평단가를 읽는다 — 그대로 매수 단가가 된다', () {
    Map<String?, double> avg(String k) =>
        {for (final h in shots[k]!.holdings) h.symbol: h.avgPrice};
    expect(avg('webull_03.jpg'),
        {'ACST': 0.7698, 'CLSN': 0.9399, 'NIO': 57.0, 'SNDL': 0.6102, 'ZOM': 0.3085});
    expect(avg('moomoo_01.webp')['ORCL'], 232.231);
    expect(avg('etrade_05.jpeg'), {'CLM': 8.23, 'SPYI': 51.39});
    expect(avg('etrade_03.jpg')['NVDA'], 96.86);
    expect(avg('fidelity_08.jpeg')['QQQM'], 291.40);
    // 「--」로 적힌 평단가는 없는 것이다
    expect(avg('fidelity_08.jpeg')['FSKAX'], 0);
  }, skip: skip);

  test('섞여 있는 딴 줄 — 읽을 것은 읽고 못 읽은 것은 말한다', () {
    // Webull: 수량 글자를 통째로 놓친 두 줄, 티커를 놓친 한 줄(이름으로 찾는다),
    // 코인 한 줄(티커가 주식 꼴이 아니다)
    final w = shots['webull_01.jpg']!;
    expect([for (final h in w.holdings) h.symbol],
        ['ATER', 'BNGO', 'PTIX', null, null, 'AGI', 'PLTR']);
    expect(w.holdings[4].name, 'Ford Motor');
    expect(w.holdings[4].qty, 1);
    expect(w.unreadable, ['CLNE', 'NIO']);
    expect(w.holdings.every((h) => h.verified), isTrue);

    // IBKR: 티커와 거래소 꼬리표가 붙어 읽힌 줄(「VWRLAEB」)
    final i = shots['ibkr_04.jpg']!;
    expect([for (final h in i.holdings) (h.symbol, h.qty)],
        [('TDIV', 7.0), ('TSWE', 14.0), ('VUSA', 11.0)]);
    expect(i.unreadable, ['VWRLAEB']);

    // Merrill: 수량 대신 옆 칸의 「$52」가 읽힌 줄
    final m = shots['merrill_03.jpg']!;
    expect([for (final h in m.holdings) h.symbol], ['BUPXX']);
    expect(m.unreadable, ['||AXX', 'USIG']);
  }, skip: skip);

  test('수량 칸이 화면 밖인 표는 「수량이 없다」고 한다', () {
    for (final k in [
      'webull_08.jpg', 'moomoo_05.jpg', 'moomoo_06.png', 'moomoo_08.webp', //
      'moomoo_09.webp', 'etrade_01.jpeg', 'etrade_06.jpg', 'fidelity_05.png',
      'fidelity_09.jpeg', 'schwab_01.jpeg', 'schwab_02.jpeg',
    ]) {
      expect(shots[k]!.noQuantity, isTrue, reason: k);
      expect(shots[k]!.holdings, isEmpty, reason: k);
    }
  }, skip: skip);

  test('잔고 목록이 아닌 화면에서 종목을 지어내지 않는다', () {
    for (final k in [
      // 종목 한 개의 상세 화면
      'robinhood_13.png', 'robinhood_14.jpg', 'robinhood_15.png', //
      'robinhood_16.jpg', 'robinhood_17.jpg', 'webull_07.jpg', 'webull_09.jpg',
      'sofi_04.jpg', 'ibkr_02.jpeg', 'ibkr_03.png', 'ibkr_05.jpeg',
      'etrade_02.jpg',
      // 수량이 없는 목록 · 옵션뿐인 표
      'sofi_02.jpg', 'sofi_03.jpg', 'merrill_01.jpeg', 'moomoo_07.webp',
      'fidelity_03.jpeg',
      // 아직 못 읽는 모양 (카드 보기 · 옛 앱 · 네덜란드어 화면)
      'etrade_04.jpeg', 'fidelity_02.jpg', 'schwab_04.jpg', 'public_01.jpg',
      'ibkr_01.jpg',
    ]) {
      final s = shots[k]!;
      expect(s.holdings, isEmpty, reason: k);
      expect(s.unreadable, isEmpty, reason: k);
    }
  }, skip: skip);
}
