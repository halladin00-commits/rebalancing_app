import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/holdings_scan.dart';
import 'package:rebalancing_app/services/stock_search_service.dart';

/// 영어 증권사 앱(미국)의 잔고 화면 — 화면 **모양**별로 읽는지 본다.
///
/// 자리와 낱말은 실제 캡처를 글자 읽기에 돌린 결과에서 따왔고, 티커와 숫자는
/// 지어낸 것이다(실제 캡처는 저장소 밖에만 둔다 — holdings_us_samples_test).
///
/// 한 줄은 `세로 | 가로:낱말  가로:낱말`.
List<OcrWord> _screen(String spec, {double h = 34}) {
  final words = <OcrWord>[];
  for (final line in spec.split('\n')) {
    final bar = line.indexOf('|');
    if (bar < 0) continue;
    final cy = double.parse(line.substring(0, bar).trim());
    for (final tok in line.substring(bar + 1).trim().split(RegExp(r'\s{2,}'))) {
      final c = tok.indexOf(':');
      if (c < 0) continue;
      final x = double.parse(tok.substring(0, c));
      final text = tok.substring(c + 1);
      words.add(OcrWord(text, x, cy - h / 2, x + text.length * h * 0.55,
          cy + h / 2));
    }
  }
  return words;
}

StockSearchResult _us(String t, String n) =>
    StockSearchResult(ticker: t, name: n, market: 'US');

final _usList = [
  _us('AAA', 'Alpha Corp'),
  _us('BBBB', 'Beta Holdings Inc.'),
  _us('GOOG', 'Gamma Inc. Class C'),
  _us('F', 'Fourth Motor Company'),
  _us('BRK-B', 'Big Rock Inc.'),
  _us('ZED', 'Zed Technologies Inc.'),
];

Portfolio _pf() => Portfolio(id: 'p', name: 'p', currency: 'USD', items: []);

void main() {
  group('겹쳐 적는 표 (두 값이 한 칸에)', () {
    // 머리글 「Mkt Value/Qty」 — 위가 평가금액, 아래가 수량
    const valueOnTop = '''
 500 | 40:My  117:Positions  324:(3)
 600 | 37:Symbol  375:Mkt  433:Value/Qty  658:Open  752:P&L  871:Last/Avg  996:Price
 698 | 42:AAA  509:72.00  717:-185.60  993:4.500
 748 | 42:Alpha  148:Corp  573:16  742:-72.05%  994:\$  1018:16.10
 857 | 46:BBBB  508:44.52  740:-26.28  994:3.710
 909 | 45:Beta  162:Holdings  573:12  741:-37.15%  1010:\$  1034:5.90
1017 | 46:ZED  510:388.40  717:-168.80  996:19.42
1068 | 44:Zed  157:Technologies...  571:20  743:-30.29%  994:\$  1016:27.86
''';

    test('머리글이 값의 위아래를 정한다 — 평가금액이 위', () {
      final shot = parseHoldings(_screen(valueOnTop, h: 38));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'BBBB', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [16, 12, 20]);
      expect(shot.holdings.map((h) => h.value), [72.0, 44.52, 388.4]);
      expect(shot.holdings.map((h) => h.currentPrice), [4.5, 3.71, 19.42]);
      expect(shot.holdings.map((h) => h.avgPrice), [16.10, 5.90, 27.86]);
      expect(shot.holdings.every((h) => h.currency == 'USD'), isTrue);
      expect(shot.holdings.every((h) => h.check == NumberCheck.ok), isTrue);
      expect(shot.holdings.every((h) => !h.foreign), isTrue);
    });

    test('같은 앱의 옛 화면 — 「Qty/Mkt Value」는 수량이 위', () {
      final shot = parseHoldings(_screen('''
 893 | 39:Symbol  366:Qty/Mkt  496:Value  612:Last/Avg  751:Price  885:Open  978:P&L
1003 | 38:AAA  508:200  691:0.7742  978:+0.88
1056 | 38:Alpha  151:Corp  473:154.84  696:\$0.7698  971:+0.57%
1178 | 40:ZED  508:250  718:1.415  954:+118.78
1232 | 40:Zed  472:353.75  696:\$0.9399  950:+50.55%
''', h: 38));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [200, 250]);
      expect(shot.holdings.map((h) => h.value), [154.84, 353.75]);
      expect(shot.holdings.every((h) => h.check == NumberCheck.ok), isTrue);
    });

    test('이름이 위, 티커가 아래인 앱 — 「NVIDIA / NVDA」처럼 둘 다 대문자여도', () {
      final shot = parseHoldings(_screen('''
 852 | 43:Symbol  362:MV/QTY  533:Price/Cost  701:Todays  806:P/L
 950 | 44:Alpha  360:11,645.55  566:166.365  754:+752.16
 999 | 44:AAA  481:70  597:232.231
1081 | 45:ZEDCO  369:3,030.30  562:432.900  764:+44.38
1128 | 44:ZED  498:7  611:377.93
1213 | 43:Beta  130:Hold...  372:2,530.37  561:632.593  791:+7.49
1261 | 43:BBBB  496:4  609:634.81
''', h: 33));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'ZED', 'BBBB']);
      expect(shot.holdings.map((h) => h.qty), [70, 7, 4]);
      expect(shot.holdings.map((h) => h.avgPrice), [232.231, 377.93, 634.81]);
      expect(shot.holdings.every((h) => h.verified), isTrue);
    });

    test('수량을 못 읽은 줄은 「못 읽었다」고 한다 — 옆 칸 값을 끌어오지 않는다', () {
      final shot = parseHoldings(_screen('''
 600 | 37:Symbol  375:Mkt  433:Value/Qty  658:Open  752:P&L  871:Last/Avg  996:Price
 698 | 42:AAA  509:72.00  717:-185.60  993:4.500
 748 | 42:Alpha  148:Corp  573:16  742:-72.05%  1018:16.10
 857 | 46:BBBB  508:77.08  740:-49.08  994:38.54
 909 | 45:Beta  162:Holdings  741:-38.90%  1034:63.08
''', h: 38));
      expect(shot.holdings.map((h) => h.symbol), ['AAA']);
      expect(shot.unreadable, ['BBBB']);
    });

    test('옵션 줄과 묶음 줄은 종목이 아니다', () {
      final shot = parseHoldings(_screen('''
1164 | 55:Symbol  486:MV/Qty  671:Price/Cost  863:Today's  1019:P/L
1294 | 55:Alpha(4)  445:68,363.00  750:166.03  943:+328.00
1513 | 104:Quote  344:Closing  480:Out  660:Options  952:Hidden
1641 | 103:Alpha  458:66,412.00  753:166.03  945:+328.00
1699 | 103:AAA  585:400  773:84.734
1808 | 103:AAA  225:PUT  481:3,180.00  797:7.95  993:+0.00
1869 | 104:240419  229:172.5  630:4  779:168.06
1977 | 103:AAA  223:CALL  473:-1,215.00  792:4.05  993:+0.00
2036 | 104:240531  229:170  617:-3  782:157.85
''', h: 40));
      expect(shot.holdings.map((h) => h.symbol), ['AAA']);
      expect(shot.holdings.single.qty, 400);
      expect(shot.unreadable, isEmpty);
    });

    test('「6.08M」처럼 줄여 적은 값은 검산에 쓰지 않는다', () {
      final shot = parseHoldings(_screen('''
 893 | 39:Symbol  366:Qty/Mkt  496:Value  612:Last/Avg  751:Price  885:Open  978:P&L
1003 | 38:AAA  490:50,000  691:121.70  930:-365,000.00
1056 | 38:Alpha  490:6.08M  680:\$  696:129.000  971:-5.66%
''', h: 38));
      final h = shot.holdings.single;
      expect(h.qty, 50000);
      expect(h.check, NumberCheck.none);
    });
  });

  group('한 줄짜리 표', () {
    test('머리글이 두 줄에 걸친 표 (「Price / Paid」)', () {
      final shot = parseHoldings(_screen('''
 656 | 791:Price  1066:Market
 676 | 61:SymbolA  510:Qty
 700 | 804:Paid  1089:Value
 852 | 49:AAA  385:506.579  749:40.27  925:\$25,258.03
1000 | 49:BBBB  395:240.107  746:30.99  952:\$11,131.36
1151 | 49:ZED  394:6.276  760:166.45  933:\$1,500.84
2742 | 63:Accounts  311:Watch  414:Lists  618:Trade  866:Markets  1150:Menu
''', h: 44));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'BBBB', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [506.579, 240.107, 6.276]);
      // 「Price Paid」는 산 값(평단가)이다. 현재가는 평가금액 ÷ 수량
      expect(shot.holdings.map((h) => h.avgPrice), [40.27, 30.99, 166.45]);
      expect(shot.holdings.first.currentPrice, closeTo(49.86, 0.01));
      expect(shot.holdings.every((h) => h.priceDerived), isTrue);
    });

    test('표 밑의 안내문을 종목으로 읽지 않는다', () {
      final shot = parseHoldings(_screen('''
 966 | 584:Price  819:Last  1002:Total
 993 | 43:Symbol  432:Qty
1016 | 596:Paid  807:Price  982:Gain
1120 | 44:AAA  372:16.00  576:8.23  798:8.09  981:-2.20
1278 | 44:BBBB  372:18.00  552:51.39  774:50.94  984:-8.04
1471 | 230:As  292:of  343:07:08  459:AM  538:EDT  625:07/24/2025
1572 | 423:Disclosures
1840 | 496:1
''', h: 40));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'BBBB']);
      expect(shot.holdings.map((h) => h.currentPrice), [8.09, 50.94]);
      expect(shot.holdings.map((h) => h.avgPrice), [8.23, 51.39]);
      expect(shot.unreadable, isEmpty);
    });

    test('티커 밑에 꺾인 이름이 놓인 표 — 이름 줄을 종목으로 읽지 않는다', () {
      final shot = parseHoldings(_screen('''
 737 | 54:Instrument  533:Last  623:Change  795:Position  1035:P&L
 817 | 51:AAA  148:AEB  468:44.440  658:-0.060  930:7  1053:0.86
 878 | 51:ALPHA  147:DEV  195:MKT  249:DVD  299:L...  671:-0.13%
 960 | 50:ZED  166:AEB  468:35.530  658:-0.460  910:14  1053:2.39
1021 | 51:ZEDCO  145:WRLD  216:EQL  264:WGT..  669:-1.28%
1398 | 53:Cash  134:Balances
1482 | 55:EUR  140:Cash  818:4.69  929:Market  1028:Value
''', h: 36));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [7, 14]);
      expect(shot.holdings.map((h) => h.currentPrice), [44.44, 35.53]);
      expect(shot.unreadable, isEmpty, reason: '이름 줄·예수금 줄이 종목으로 읽혔다');
    });

    test('티커가 숫자 줄 위에 따로 적힌 표 (이름 머리글이 화면 밖)', () {
      final shot = parseHoldings(_screen('''
 758 | 158:Value  351:%  399:of  449:ACct  726:Qty  901:Avg.  974:Cost  1145:Tota
 848 | 56:INDIVIDUAL  992:6  1007:positions
 956 | 71:\$5,040.26
1057 | 123:AAA
1134 | 112:\$303.51  409:6.02%  687:0.963  904:\$311.53  1157:\$30
1231 | 23:O  121:BBBB
1313 | 75:\$2,490.90  385:49.42%  689:11.57
1414 | 123:ZED**
1494 | 76:\$1,248.87  385:24.78%  663:61.612  926:\$18.94  1117:\$1,1
''', h: 40));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'BBBB', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [0.963, 11.57, 61.612]);
      expect(shot.holdings.map((h) => h.avgPrice), [311.53, 0, 18.94]);
      expect(shot.holdings.first.value, 303.51);
    });

    test('수량 자리의 「\$52」는 수량이 아니다 — 옆 칸에서 온 금액이다', () {
      final shot = parseHoldings(_screen('''
 603 | 49:Security  632:Quantity
 705 | 52:AAA  694:97.07
 756 | 51:ALPHA  158:OF  215:AMERICA,
 901 | 51:BBBB  746:55
1198 | 52:ZED  1120:\$52
''', h: 40));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'BBBB']);
      expect(shot.unreadable, ['ZED']);
      // 화면에 가격이 없다 — 시세로 채운다
      expect(shot.holdings.every((h) => h.currentPrice == 0), isTrue);
    });
  });

  group('목록 (「N shares」)', () {
    test('티커 · 수량 · 오른쪽 값 — 값은 가격인지 평가금액인지 모른다', () {
      final shot = parseHoldings(_screen('''
 168 | 524:\$8,197.68
 233 | 395:Individual·  611:Stocks  744:&  767:ETFs
 386 | 76:AAA
 417 | 969:\$32.68
 452 | 75:21.63  181:shares
 626 | 73:BBBB
 657 | 958:\$344.8O
 691 | 74:1.36  158:shares
 865 | 73:ZED
 897 | 958:\$397.64
 930 | 74:0.915544  248:shares
''', h: 42));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'BBBB', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [21.63, 1.36, 0.915544]);
      // 0을 O로 읽은 「$344.8O」
      expect(shot.holdings.map((h) => h.currentPrice), [32.68, 344.80, 397.64]);
      expect(shot.holdings.every((h) => h.priceMaybeValue), isTrue);
      expect(shot.holdings.every((h) => h.check == NumberCheck.none), isTrue);
    });

    test('오른쪽이 손익·등락률이면 가격으로 쓰지 않는다', () {
      final shot = parseHoldings(_screen('''
 386 | 51:AAA
 406 | 572:-\$7.80
 434 | 50:10  85:shares
 545 | 50:BBBB
 567 | 559:+0.43%
 594 | 61:1  70:share  150:(
''', h: 26));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'BBBB']);
      expect(shot.holdings.map((h) => h.qty), [10, 1]);
      expect(shot.holdings.every((h) => h.currentPrice == 0), isTrue);
      expect(shot.holdings.every((h) => !h.priceMaybeValue), isTrue);
    });

    test('옵션 줄 · 관심 종목 · 쉼표 든 수량 · 대문자 SHARES', () {
      final shot = parseHoldings(_screen('''
 311 | 88:AAA  169:\$12.5  281:Put
 339 | 683:+12.85%
 371 | 74:1/19/24  201:Exp  265:·  281:30  330:Sells
 595 | 74:Stocks
 754 | 73:AAA
 781 | 694:-1.56%
 813 | 74:10,000  188:shares
 994 | 76:ZED
1020 | 865:\$3.70
1053 | 74:1854  173:SHARES
1300 | 74:WATCHLIST
1400 | 76:BBBB  865:\$140.08
''', h: 40));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [10000, 1854]);
    });

    test('「shares」가 다음 줄로 꺾여도 수량을 읽는다', () {
      final shot = parseHoldings(_screen('''
1171 | 233:AAA  587:\$7,477.90
1242 | 233:439.877  415:shares  670:+\$0.00
1358 | 235:ZED
1382 | 555:\$30,385.89
1422 | 237:1,129.587  899:+0.00%
1484 | 234:shares
''', h: 40));
      expect(shot.holdings.map((h) => h.symbol), ['AAA', 'ZED']);
      expect(shot.holdings.map((h) => h.qty), [439.877, 1129.587]);
      expect(shot.holdings.map((h) => h.currentPrice), [7477.90, 30385.89]);
    });
  });

  group('읽을 수 없는 화면은 그렇다고 말한다', () {
    test('수량 칸을 옆으로 밀어 둔 표 → 「수량이 없다」', () {
      final shot = parseHoldings(_screen('''
 795 | 26:Symbol  495:Gain  582:\$  723:Day  796:Chng  898:\$
 917 | 32:AAA  389:+\$1,837.36  728:+\$588.80
1064 | 32:BBBB  415:+\$382.80  738:-\$325.60
''', h: 40));
      expect(shot.noQuantity, isTrue);
      expect(shot.holdings, isEmpty);
    });

    test('종목 한 개의 상세 화면은 잔고 화면이 아니다', () {
      final shot = parseHoldings(_screen('''
 300 | 60:Your  150:Position
 400 | 60:Shares  620:Market  760:Value
 450 | 60:219.706013  620:\$2,640.87
 560 | 60:Avg  130:Cost  620:Portfolio  800:Diversity
 610 | 60:\$8.17  620:87.38%
 720 | 60:Today's  200:Return  700:+\$845.87  900:(+47.12%)
''', h: 36));
      expect(shot.notHoldingsScreen, isTrue);
      expect(shot.holdings, isEmpty);
    });

    test('한글이 없는 화면을 한국 앱 화면으로 읽지 않는다', () {
      final shot = parseHoldings(_screen('''
 100 | 60:Welcome  260:back
 200 | 60:Balance  620:1,234.56
 300 | 60:0.134181  300:points  700:12.5
'''));
      expect(shot.notHoldingsScreen, isTrue);
    });
  });

  test('머리글이 화면 밖으로 밀린 둘째 장은 첫 장의 칸 자리로 읽는다', () {
    const first = '''
 852 | 43:Symbol  362:MV/QTY  533:Price/Cost  701:Todays  806:P/L
 950 | 44:Alpha  360:11,645.55  566:166.365  754:+752.16
 999 | 44:AAA  481:70  597:232.231
1081 | 45:Zedco  369:3,030.30  562:432.900  764:+44.38
1128 | 44:ZED  498:7  611:377.93
''';
    const second = '''
 161 | 56:Universal  150:Account  240:(5716)
 243 | 21:Assets  128:Orders  201:(4)  261:History
 297 | 44:Beta  130:Hold...  372:2,530.37  561:632.593  791:+7.49
 345 | 43:BBBB  496:4  609:634.81
 429 | 44:Gamma  360:1,663.65  566:166.365  754:-12.00
 478 | 44:GOOG  481:10  597:150.00
''';
    // 따로 읽으면 둘째 장은 못 읽는다
    expect(parseHoldings(_screen(second, h: 33)).notHoldingsScreen, isTrue);

    final shots =
        parseHoldingsShots([_screen(first, h: 33), _screen(second, h: 33)]);
    expect(shots[0].holdings.map((h) => h.symbol), ['AAA', 'ZED']);
    expect(shots[1].holdings.map((h) => h.symbol), ['BBBB', 'GOOG']);
    expect(shots[1].holdings.map((h) => h.qty), [4, 10]);
    expect(shots[1].holdings.every((h) => h.verified), isTrue);
    expect(shots[1].unreadable, isEmpty, reason: '위쪽 탭 줄이 종목으로 읽혔다');
  });

  group('종목 찾기 — 티커로', () {
    ScannedHolding h(String? symbol, {String name = ''}) => ScannedHolding(
        name: name.isEmpty ? (symbol ?? '') : name,
        symbol: symbol,
        currency: 'USD',
        qty: 1,
        avgPrice: 0,
        currentPrice: 10,
        value: 10);

    test('똑같은 티커면 그 종목이다', () {
      final m = lookupUsStock(h('AAA'), _usList);
      expect(m.kind, NameMatch.exact);
      expect(m.stock!.ticker, 'AAA');
      expect(lookupUsStock(h('F'), _usList).stock!.ticker, 'F');
    });

    test('「GO0G」 — 글자를 숫자로 읽은 티커는 짐작하고 확인을 받는다', () {
      final m = lookupUsStock(h('GO0G'), _usList);
      expect(m.kind, NameMatch.fuzzy);
      expect(m.stock!.ticker, 'GOOG');
    });

    test('「BRK.B」는 목록의 「BRK-B」다', () {
      expect(lookupUsStock(h('BRK.B'), _usList).stock!.ticker, 'BRK-B');
    });

    test('목록에 없는 티커는 못 찾은 것이다 — 비슷한 것으로 짐작하지 않는다', () {
      expect(lookupUsStock(h('AAB'), _usList).kind, NameMatch.none);
      expect(lookupUsStock(h('DOGEUSD'), _usList).kind, NameMatch.none);
    });

    test('티커를 못 읽은 줄은 이름으로 찾는다', () {
      final m = lookupUsStock(h(null, name: 'Fourth Motor'), _usList);
      expect(m.stock!.ticker, 'F');
      expect(m.kind, NameMatch.prefix);
    });
  });

  group('넣기 — 달러 종목', () {
    HoldingRow rowOf(ScannedHolding s, {Map<String, double> live = const {}}) =>
        buildHoldingRows([
          HoldingsShot(holdings: [s])
        ], _pf(), const [], usStocks: _usList)
            .single
            .withLive(live);

    const pill = ScannedHolding(
        name: 'AAA',
        symbol: 'AAA',
        currency: 'USD',
        qty: 21,
        avgPrice: 0,
        currentPrice: 236.46,
        value: 236.46,
        priceMaybeValue: true,
        check: NumberCheck.none);

    test('오른쪽 값이 시세와 같으면 가격이다 — 수량은 확인을 받는다', () {
      final r = rowOf(pill, live: {'AAA': 240});
      expect(r.price, 236.46);
      expect(r.issues, [HoldingIssue.numbersUnchecked]);
      expect(r.addable, isTrue);
      expect(r.preselected, isFalse);
    });

    test('오른쪽 값 ÷ 수량이 시세와 같으면 평가금액이다 — 수량까지 맞춰 본 셈이다', () {
      final r = rowOf(pill, live: {'AAA': 11.3});
      expect(r.price, closeTo(11.26, 0.001));
      expect(r.value, closeTo(236.46, 0.001));
      expect(r.issues, isEmpty);
      expect(r.preselected, isTrue);
    });

    test('어느 쪽과도 안 맞으면 다른 종목일 수 있다', () {
      final r = rowOf(pill, live: {'AAA': 55});
      expect(r.issues, contains(HoldingIssue.priceOff));
      expect(r.preselected, isFalse);
    });

    test('시세를 못 받았으면 넣지 못한다 — 얼마인지 모른다', () {
      final r = rowOf(pill);
      expect(r.price, isNull);
      expect(r.issues, contains(HoldingIssue.noPrice));
      expect(r.addable, isFalse);
    });

    test('화면에 가격이 없는 줄은 받은 시세로 넣는다', () {
      const s = ScannedHolding(
          name: 'AAA',
          symbol: 'AAA',
          currency: 'USD',
          qty: 0.040578,
          avgPrice: 0,
          currentPrice: 0,
          value: 0,
          check: NumberCheck.none);
      final r = rowOf(s, live: {'AAA': 189.5});
      expect(r.price, 189.5);
      expect(r.addable, isTrue);
      final it = newItemFromScan(r, 'n1', DateTime(2026, 11, 17));
      expect(it.market, 'US');
      expect(it.ticker, 'AAA');
      expect(it.shares, 0.040578);
      expect(it.currentPrice, 189.5);
      expect(it.transactions.single.price, 189.5);
    });

    test('평단가가 읽혔으면 평단가로 기록한다', () {
      const s = ScannedHolding(
          name: 'Alpha Corp',
          symbol: 'AAA',
          currency: 'USD',
          qty: 16,
          avgPrice: 16.10,
          currentPrice: 4.5,
          value: 72);
      final r = rowOf(s, live: {'AAA': 4.6});
      expect(r.issues, isEmpty);
      final it = newItemFromScan(r, 'n1', DateTime(2026, 11, 17));
      expect(it.transactions.single.price, 16.10);
      expect(it.currentPrice, 4.5);
      expect(it.market, 'US');
    });

    test('시세를 받을 종목은 시장과 함께 넘긴다', () {
      final r = rowOf(pill);
      expect(priceTickers([r]), {'AAA': 'US'});
    });

    test('한 화면에 두 줄로 나뉜 같은 종목은 더한다 (신용 몫 + 현금 몫)', () {
      const a = ScannedHolding(
          name: 'AAA',
          symbol: 'AAA',
          currency: 'USD',
          qty: 2,
          avgPrice: 0,
          currentPrice: 1376.88,
          value: 1376.88,
          priceMaybeValue: true,
          check: NumberCheck.none);
      const b = ScannedHolding(
          name: 'AAA',
          symbol: 'AAA',
          currency: 'USD',
          qty: 0.529,
          avgPrice: 0,
          currentPrice: 364.18,
          value: 364.18,
          priceMaybeValue: true,
          check: NumberCheck.none);
      final r = buildHoldingRows([
        const HoldingsShot(holdings: [a, b])
      ], _pf(), const [], usStocks: _usList)
          .single
          .withLive({'AAA': 688.4});
      expect(r.scan.qty, closeTo(2.529, 1e-9));
      expect(r.price, closeTo(688.44, 0.01));
      expect(r.issues, isEmpty);
    });
  });
}
