import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/holdings_scan.dart';
import 'package:rebalancing_app/services/stock_search_service.dart';

/// 증권사마다 다른 잔고 화면을 **화면 모양으로** 읽는지 본다.
///
/// 아래 화면들은 실제 캡처를 기기에서 읽힌 결과의 **자리(좌표)를 그대로**
/// 두고 종목 이름과 숫자만 지어낸 것으로 바꾼 것이다. 실제 캡처는 남의
/// 잔고라 저장소에 넣지 않는다(`holdings_web_samples_test.dart`가 이 PC에
/// 있는 실제 캡처로 따로 본다).
///
/// 줄마다 `위 | 왼쪽:낱말  왼쪽:낱말 …` 이다.
List<OcrWord> _screen(String text, {double h = 28}) {
  final out = <OcrWord>[];
  for (final line in text.split('\n')) {
    if (!line.contains('|')) continue;
    final top = double.parse(line.substring(0, line.indexOf('|')).trim());
    for (final tok in line.substring(line.indexOf('|') + 1).trim().split(
        RegExp(r'\s{2,}'))) {
      final i = tok.indexOf(':');
      final left = double.parse(tok.substring(0, i));
      final t = tok.substring(i + 1);
      // 한글은 정사각형에 가깝고 영문·숫자는 그 절반 남짓이다
      final w = t.runes.fold<double>(
          0, (s, r) => s + (r > 0x2E80 ? 0.9 : 0.55) * h);
      out.add(OcrWord(t, left, top, left + w, top + h));
    }
  }
  return out;
}

void main() {
  group('표', () {
    test('종목명이 두 줄 사이 가운데에 따로 적히는 화면 (키움)', () {
      final shot = parseHoldings(_screen('''
 414 | 55:투자도구  464:융자별  609:융자합  758:2줄
 507 | 331:매입가  520:보유수량  735:평가손익
 538 | 95:종목명
 564 | 332:현재가  521:가능수량  748:수익률
 633 | 327:268,000  629:10  736:-747,564
 660 | 48:ALPHA
 690 | 330:193,700  628:10  746:-27.89%
 760 | 298:1,733,000  648:2  733:-919,994
 788 | 48:GAMMA
 814 | 300:1,276,000  648:2  746:-26.54%
1022 | 48:DELTA글로벌  328:368,750  628:10  733:-664,560
1067 | 51:AI  327:303,000  629:10  746:-18,02%
1663 | 31:지수채팅  153:코스피  421:5,584.55  621:424.26  789:7.06%
1770 | 197:관심종목  373:현재가  520:주문  632:차트  745:계좌
'''));
      expect(shot.holdings.map((h) => h.name),
          ['ALPHA', 'GAMMA', 'DELTA글로벌AI']);
      expect(shot.holdings.map((h) => h.qty), [10, 2, 10]);
      expect(shot.holdings.map((h) => h.avgPrice), [268000, 1733000, 368750]);
      expect(shot.holdings.map((h) => h.currentPrice),
          [193700, 1276000, 303000]);
      // 평가금액 칸이 없는 화면 — 보유수량 = 가능수량으로 수량을 맞춰 본다
      expect(shot.holdings.every((h) => h.verified), isTrue);
      // 맨 아래 지수 띠는 종목이 아니다
      expect(shot.unreadable, isEmpty);
    });

    test('쪼개져 읽힌 손익을 수익률로 잘못 보지 않는다', () {
      // 「+2,915,408」이 「+2,91」「5,408」로 읽혔다. 「2,91」을 수익률로 보면
      // 첫 줄을 둘째 줄로 알고 짝이 밀린다
      final shot = parseHoldings(_screen('''
 746 | 390:매입가  610:보유수량  850:평가손익
 780 | 104:종목명
 816 | 388:현재가  611:가능수량  888:수익률
1202 | 62:ALPHA  252:레  388:76,048  709:200  839:+2,91  949:5,408
1268 | 60:버리지  386:90,650  709:200  854:+19.17%
''', h: 34));
      expect(shot.holdings.single.name, 'ALPHA 레버리지');
      expect(shot.holdings.single.qty, 200);
      expect(shot.unreadable, isEmpty);
    });

    test('이름 밑에도 숫자 칸이 있는 화면 (미래에셋·신한)', () {
      final shot = parseHoldings(_screen('''
 172 | 33:매입금액  262:5,188,980  486:평가손익  723:-156,288
 272 | 33:평가금액  260:5,032,692  476:수익률(%)  792:-3.01
 499 | 132:종목명  391:평가손익  592:평가금액  768:현재가
 562 | 29:주문가능  204:보유수량  382:수익률(%)  580:매입금액  767:평균단가
 640 | 28:ALPHA  156:미국테크  418:-2,335  581:1,173,415  761:23,470
 700 | 112:50  287:50  436:-0.20  581:1,175,750  761:23,517
 799 | 28:BETA  155:글로벌1(  379:-153,953  579:3,859,277  761:27,180
 858 | 94:142  269:142  437:-3.84  578:4,013,230  761:28,264
'''));
      expect(shot.holdings.map((h) => h.name), ['ALPHA 미국테크', 'BETA 글로벌1(']);
      expect(shot.holdings.map((h) => h.qty), [50, 142]);
      expect(shot.holdings.map((h) => h.currentPrice), [23470, 27180]);
      expect(shot.holdings.map((h) => h.avgPrice), [23517, 28264]);
      // 평가금액이 수수료만큼 모자라도 맞는 것으로 본다
      expect(shot.holdings.every((h) => h.verified), isTrue);
    });

    test('「주문가능/보유수량」을 「25/25」로 적는 화면', () {
      final shot = parseHoldings(_screen('''
 429 | 87:종목명  275:현재가  440:평가금액  622:평가손익
 483 | 14:주문가능  110:/  127:보유수량  265:매입단가  425:매입금액  611:손익률(%)
 556 | 63:ALPHA  115:미국테크100  283:85,050  439:2,126,250  632:119,005
 576 | 127:25/  187:25  283:80,290  438:2,007,155  682:5.93
 658 | 62:GAMMA  121:미국배당  285:14,250  440:1,054,500  647:67,075
 678 | 128:74/74  285:13,344  464:987,395  681:6.79
''', h: 19));
      expect(shot.holdings.map((h) => h.qty), [25, 74]);
      expect(shot.holdings.every((h) => h.verified), isTrue);
    });

    test('현재가 칸이 없는 화면은 평가금액 ÷ 수량 — 위에서 잘린 종목은 넘긴다', () {
      final shot = parseHoldings(_screen('''
 661 | 319:평가손익  562:보유수량  697:수  768:매도가
 697 | 81:종목명
 736 | 334:수익률  562:평가금액  811:비중
 780 | 27:잘린종목  350:1.99%  549:1,790,205  803:4.369
 825 | 26:ALPHA  98:미국나  335:8,091,635  653:429  858:42
 866 | 27:스닥100  350:141.99%  549:13,790,205  803:24.369
 964 | 14:GAMMA  128:미국  319:11,100,080  653:824  870:82.
1008 | 27:S&P500  351:100.91%  547:22,099,680  803:39.049
'''));
      expect(shot.holdings.map((h) => h.name),
          ['ALPHA 미국나스닥100', 'GAMMA 미국S&P500']);
      expect(shot.holdings.map((h) => h.qty), [429, 824]);
      expect(shot.holdings.map((h) => h.currentPrice), [32145, 26820]);
      expect(shot.holdings.every((h) => h.priceDerived), isTrue);
      // 맞춰 볼 숫자가 없다 — 틀렸다는 게 아니라 모른다
      expect(shot.holdings.every((h) => h.check == NumberCheck.none), isTrue);
      expect(shot.unreadable, isEmpty);
    });

    test('한 글자 수량을 놓쳤으면 평가금액 ÷ 현재가로 셈하고 확인을 받는다', () {
      final shot = parseHoldings(_screen('''
 678 | 70:종목명  247:평가손익  413:잔고수량  597:매입가
 732 | 80:구분  256:수익률  412:평가금액  597:현재가
 785 | 16:ALPHA  292:2,950  507:1  623:29,200
 841 | 15:현금  270:10.10%  436:32,150  622:32,150
1125 | 16:GAMMA  113:200  306:-640  622:43,190
1180 | 15:현금  277:-1.48%  435:42,550  622:42,550
''', h: 24));
      expect(shot.holdings.map((h) => h.name), ['ALPHA', 'GAMMA 200']);
      expect(shot.holdings.map((h) => h.qty), [1, 1]);
      expect(shot.holdings.first.check, NumberCheck.ok);
      expect(shot.holdings.last.check, NumberCheck.none);
    });

    test('보유수량과 매도가능이 나란한 화면 — 숫자를 왼쪽 끝으로 맞추지 않는다', () {
      // 숫자는 머리글 가운데나 오른쪽 끝에 놓인다. 왼쪽 끝으로 대 보면
      // 보유수량 「110」이 옆 칸(매도가능)으로 넘어가 「110110」이 된다
      final shot = parseHoldings(_screen('''
 506 | 108:종목명  298:평가손익  429:수  492:보유수량  636:수매도가능수링
 569 | 95:매매구분  312:수익률  492:평가금액  724:비중
1021 | 78:ALPHA  140:미국테크  346:57,325  596:110  802:110
1067 | 79:현금  352:3.87%  511:1,538,350  763:6.04%
''', h: 26));
      expect(shot.holdings.single.qty, 110);
      expect(shot.holdings.single.currentPrice, 13985);
      expect(shot.holdings.single.verified, isTrue);
    });

    test('화면 아래 안내문이 마지막 종목 이름에 붙지 않는다', () {
      final shot = parseHoldings(_screen('''
 664 | 85:종목명  269:평가손익  452:잔고수량  651:매입가
 722 | 56:국가  163:구분  281:수익률  452:평가금액  649:현재가
1152 | 25:ALPHA  330:-101  463:2  673:28,870
1218 | 25:국내  156:현금  300:-1.83%  500:56,900  673:28,450
1280 | 27:GAMMA  332:-994  448:1  672:48,382
1341 | 25:국내  156:현금  301:-2.03%  482:47,600  672:47,600
1415 | 40:0  90:23:00-03:00  254::  282:잔고,  344:순자산액등  461:변동여부
''', h: 24));
      expect(shot.holdings.map((h) => h.name), ['ALPHA', 'GAMMA']);
    });

    test('수량 칸이 없는 화면은 수량이 없다고 말한다', () {
      final shot = parseHoldings(_screen('''
 756 | 71:종목명  431:수익률  653:평가금액
 864 | 71:ALPHA  415:6.80%  634:2,484,900
 982 | 71:GAMMA  403:-2.40%  634:2,350,000
'''));
      expect(shot.holdings, isEmpty);
      expect(shot.noQuantity, isTrue);
      expect(shot.notHoldingsScreen, isFalse);
    });

    test('외화로 적힌 화면은 해외 종목으로 표시한다', () {
      final shot = parseHoldings(_screen('''
 730 | 160:종목명  481:현재가  665:원화평가손익
 793 | 46:주문가능  246:보유수량  467:평균단가  696:수익률(%)
 867 | 13:애플  122:AAPL  477:189.8400  722:128,539
 932 | 157:5  357:5  477:170.1360  762:11.58
'''));
      expect(shot.holdings.single.foreign, isTrue);
    });
  });

  group('카드', () {
    test('이름 밑에 이름표와 값이 놓이는 화면 (KB)', () {
      final shot = parseHoldings(_screen('''
 189 | 78:출금가능금액  458:1,483  598:총평가손익  863:-448,458
 253 | 98:당일실현손익  530:0  599:총매입금액  848:3,101,814
1032 | 74:ALPHA  893:현금
1133 | 79:평가손익  391:-53,903  600:매도가능  1032:1
1193 | 79:손익률  369:-12.10  508:%  600:평균단가  897:445.000
1261 | 78:매입금  388:445,000  601:보유잔고  1032:1
1322 | 79:평가금  388:393,000  603:현재가  900:393.000
1392 | 79:매수수수료  472:530  601:매도제비용  949:1.373
1489 | 135:자동주문  508:매수  882:매도
1637 | 75:GAMMA  200:자동차  894:현금
1734 | 78:평가손익  416:-3,591  601:매도가능  1032:1
1798 | 79:손익률  369:-10.37  509:%  601:평균단가  922:34,600
1862 | 78:매입금  412:34,600  601:보유잔고  1032:1
1925 | 78:평가금  413:31,150  614:현재가  922:31,150
''', h: 36));
      expect(shot.holdings.map((h) => h.name), ['ALPHA', 'GAMMA 자동차']);
      expect(shot.holdings.map((h) => h.qty), [1, 1]);
      // 「393.000」 — 쉼표를 점으로 읽었다
      expect(shot.holdings.map((h) => h.currentPrice), [393000, 31150]);
      expect(shot.holdings.every((h) => h.verified), isTrue);
    });

    test('접힌 카드 — 매도가능과 평균단가뿐이면 손익으로 현재가를 셈한다', () {
      final shot = parseHoldings(_screen('''
  34 | 60:ALPHA  715:현금
 115 | 57:평가손익  310:240,695  482:매도가능  804:26
 167 | 72:손익률  309:22.18  405:%  481:평균단가  736:41,763
 250 | 109:자동주문  422:매수  706:매도
 366 | 60:GAMMA  186:자동차  715:현금
 444 | 58:평가손익  294:-370,056  483:매도가능  784:326
 497 | 64:손익률  314:-9.76%  483:평균단가  739:11,618
''', h: 30));
      expect(shot.holdings.map((h) => h.name), ['ALPHA', 'GAMMA 자동차']);
      expect(shot.holdings.map((h) => h.qty), [26, 326]);
      expect(shot.holdings.first.currentPrice, closeTo(51020.6, 0.5));
      expect(shot.holdings.every((h) => h.priceDerived), isTrue);
      expect(shot.holdings.every((h) => h.check == NumberCheck.none), isTrue);
    });

    test('「보유수량/매입단가 12/19,565」로 적는 화면', () {
      final shot = parseHoldings(_screen('''
 326 | 59:ALPHA  182:미국테크
 403 | 58:매입금액  655:234,780
 457 | 57:보유수량/매입단가  580:12/19,565
 519 | 57:평가금액  620:228,120
 575 | 586:6,660원(-2.84%)
 651 | 573:매수  703:매도
 815 | 59:GAMMA  182:미국배당
 891 | 44:매입금액  646:121,680A
 947 | 57:보유수량/매입단가  589:6주/  662:20,280원
1012 | 57:평가금액  608:116,670l
'''));
      expect(shot.holdings.map((h) => h.qty), [12, 6]);
      expect(shot.holdings.map((h) => h.avgPrice), [19565, 20280]);
      expect(shot.holdings.map((h) => h.value), [228120, 116670]);
      // 수량 × 매입단가 = 매입금액
      expect(shot.holdings.every((h) => h.verified), isTrue);
    });
  });

  group('목록', () {
    test('이름 / 13주 / 평가금 (토스·카카오페이)', () {
      final shot = parseHoldings(_screen('''
 312 | 52:가나다순  394:현재가  490:평가금
 433 | 45:국내주식  621:보기
 502 | 150:ALPHA  534:119,600
 549 | 150:1주  497:+21,000  593:(21.2%)
 620 | 152:BETA
 681 | 39:나스닥  135:글로벌반도체성장기업  493:3,288,770원
 711 | 498:-118,106  609:(3.4%)
 760 | 150:181주
 986 | 45:해외주식  621:보기
1053 | 140:베이커  239:휴즈  550:\$677.42
1099 | 149:10.599645  511:+66.42  594:(10.8%)
''', h: 24));
      expect(shot.holdings.map((h) => h.name),
          ['ALPHA', 'BETA글로벌반도체성장기업', '베이커 휴즈']);
      expect(shot.holdings.map((h) => h.qty), [1, 181, 10.599645]);
      expect(shot.holdings.map((h) => h.value).take(2), [119600, 3288770]);
      expect(shot.holdings[1].currentPrice, 18170);
      expect(shot.holdings.every((h) => h.priceDerived), isTrue);
      expect(shot.holdings.every((h) => h.check == NumberCheck.none), isTrue);
      // 「해외주식」 밑의 종목은 해외 종목이다 — 넣지 않는다
      expect(shot.holdings.map((h) => h.foreign), [false, false, true]);
    });

    test('「원」을 %로 읽은 평가금을 손익으로 보지 않는다', () {
      final shot = parseHoldings(_screen('''
 854 | 214:ALPHA  743:14,309,353%/
 915 | 193:60주  773:-603,113  925:(4.0%)
''', h: 34));
      expect(shot.holdings.single.value, 14309353);
    });

    test('평가금이 이름과 수량 사이 줄에 있고 「내 평균」이 따라오는 화면', () {
      final shot = parseHoldings(_screen('''
 890 | 80:엔비디아
 919 | 819:854,475
 959 | 80:3.163*
 984 | 683:+11.04%  844:(84,998원)
1010 | 68:내  124:평균  200:243,274원
1116 | 80:ALPHA  218:미국테크
1142 | 818:324,155
1184 | 82:13주
1204 | 681:+10.90%  843:(31,885원)
1236 | 67:내평균  210:22,482원
1340 | 80:GAMMA
1366 | 844:90,500
1406 | 81:1주
1434 | 694:-11.10%  844:(11,300원)
''', h: 30));
      // 「3.163*」 — 소수점 수량의 「주」를 딴 글자로 읽었다
      expect(shot.holdings.map((h) => h.name),
          ['엔비디아', 'ALPHA 미국테크', 'GAMMA']);
      expect(shot.holdings.map((h) => h.qty), [3.163, 13, 1]);
      expect(shot.holdings.map((h) => h.value), [854475, 324155, 90500]);
    });

    test('현재가가 따로 적힌 화면 — 오른쪽 숫자(1주 평균)를 평가금으로 쓰지 않는다',
        () {
      final shot = parseHoldings(_screen('''
 640 | 50:종목명  321:총수익  538:1주평균  716:금액
 741 | 64:ALPHA  356:+26.7%  626:168,030
 803 | 68:104주  282:4,680,520원  544:현재가  642:213,500원
 886 | 64:GAMMA
 916 | 358:-11.5%  640:98,833
 945 | 66:200
 967 | 341:614,667  565:현재가  662:87,465원
1003 | 66:54주
1412 | 46:DELTA하이닉  580:2,089,000%
1447 | 357:-39.6%
1480 | 65:스  718:현재가
1500 | 344:828,715
1538 | 68:1주  612:1,263,000%
'''));
      expect(shot.holdings.map((h) => h.name),
          ['ALPHA', 'GAMMA200', 'DELTA하이닉스']);
      expect(shot.holdings.map((h) => h.qty), [104, 54, 1]);
      expect(
          shot.holdings.map((h) => h.currentPrice), [213500, 87465, 1263000]);
      expect(shot.holdings.every((h) => !h.priceDerived), isTrue);
    });

    test('정렬·보기 전환 줄을 첫 종목 이름에 붙이지 않는다', () {
      final shot = parseHoldings(_screen('''
 610 | 76:전체  162:4  254:한국  342:2  436:미국  522:2
 758 | 65:평가금액  248:순  610:\$원  761:평가금  905:현재가
 890 | 80:ALPHA
 919 | 819:854,475
 959 | 80:13주
 984 | 683:+11.04%  844:(84,998원)
''', h: 30));
      expect(shot.holdings.single.name, 'ALPHA');
      expect(shot.holdings.single.value, 854475);
    });

    test('다음 종목의 수량을 못 읽어도 그 종목의 현재가를 집지 않는다', () {
      final shot = parseHoldings(_screen('''
 640 | 50:종목명  321:총수익  538:1주  600:평균  716:금액
1412 | 46:ALPHA하이닉  580:2,089,000
1447 | 357:-39.6%
1480 | 65:스  718:현재가
1500 | 344:828,715
1538 | 68:1주  612:1,263,000
1612 | 67:GAMMA
1643 | 358:-10.3%  641:25,040
1671 | 65:고배당주
1700 | 330:118.951  564:현재가  662:22,460원
'''));
      expect(shot.holdings.single.name, 'ALPHA하이닉스');
      expect(shot.holdings.single.currentPrice, 1263000);
    });

    test('「현금 20주」 밑에 이름표가 있는 화면 — 수량 × 현재가로 맞춰 본다', () {
      final shot = parseHoldings(_screen('''
 888 | 63:현금  227:종목명  313:순  556:일괄매도
1014 | 52:ALPHA  145:금리플러스액티브(합성)  591:20,443,440
1070 | 52:현금  117:20주  605:3,100  717:(+0.02%).
1173 | 52:매수금액  231:20,440,340  477:평균단가  677:1,022,017
1223 | 52:평가금액  239:20,443,440  476:현재가  690:1,022,172
'''));
      final h = shot.holdings.single;
      expect(h.name, 'ALPHA 금리플러스액티브(합성)');
      expect(h.qty, 20);
      expect(h.currentPrice, 1022172);
      expect(h.verified, isTrue);
    });
  });

  test('잔고 화면이 아니면 아니라고 말한다', () {
    final shot = parseHoldings(_screen('''
  46 | 44:주문내역  200:체결  340:미체결
 194 | 52:매수  201:삼성전자  548:10주  716:체결
'''));
    // 「10주」가 있어도 이름이 될 줄이 없다
    expect(shot.holdings, isEmpty);
  });

  group('앱과 맞대기', () {
    final stocks = [
      StockSearchResult(ticker: '1', name: 'ALPHA 전자', market: 'KR'),
    ];
    final pf = Portfolio(id: 'p', name: 'ISA', items: []);

    ScannedHolding h(double qty,
            {NumberCheck check = NumberCheck.ok, bool derived = false}) =>
        ScannedHolding(
            name: 'ALPHA 전자',
            qty: qty,
            avgPrice: 90,
            currentPrice: 100,
            value: qty * 100,
            priceDerived: derived,
            check: check);

    test('우선주를 보통주로 짐작하지 않는다', () {
      final list = [
        StockSearchResult(ticker: '1', name: '한국알파지주', market: 'KR'),
        StockSearchResult(ticker: '2', name: '델타전자우', market: 'KR'),
      ];
      // 목록에 우선주가 없다 — 한 글자 차이인 보통주로 가면 안 된다
      expect(lookupStock('한국알파지주우', list).kind, NameMatch.none);
      // 우선주끼리는 잘못 읽은 글자를 짐작한다
      expect(lookupStock('델타전지우', list).stock?.ticker, '2');
    });

    test('짧은 이름은 짐작하지 않는다 — 해외 종목이 국내 종목으로 간다', () {
      final list = [
        StockSearchResult(ticker: '1', name: '쿠콘', market: 'KR'),
        StockSearchResult(ticker: '2', name: '인텔리안테크', market: 'KR'),
      ];
      expect(lookupStock('쿠팡', list).kind, NameMatch.none);
      // 그렇게 시작하는 종목이 하나뿐이어도 짧으면 고르게 한다
      final intel = lookupStock('인텔', list);
      expect(intel.kind, NameMatch.ambiguous);
      expect(intel.stock, isNull);
    });

    test('한 장 안에서 같은 종목이 두 줄이면 더한다 (현금 + 소수점)', () {
      final rows = buildHoldingRows([
        HoldingsShot(holdings: [h(1), h(0.809196)])
      ], pf, stocks);
      expect(rows.single.scan.qty, closeTo(1.809196, 1e-9));
      expect(rows.single.scan.value, closeTo(180.9196, 1e-6));
      expect(rows.single.conflictQtys, isEmpty);
      expect(rows.single.preselected, isTrue);
    });

    test('다른 장에서 같은 종목이 다른 수량이면 더하지 않고 어긋났다고 한다', () {
      final rows = buildHoldingRows([
        HoldingsShot(holdings: [h(1)]),
        HoldingsShot(holdings: [h(3)]),
      ], pf, stocks);
      expect(rows.single.conflictQtys, [1, 3]);
      expect(rows.single.addable, isFalse);
    });

    test('맞춰 보지 못한 수량은 골라 두지 않는다 — 시세가 뒷받침하면 고른다', () {
      final row = buildHoldingRows([
        HoldingsShot(holdings: [h(13, check: NumberCheck.none, derived: true)])
      ], pf, stocks).single;
      expect(row.issues, [HoldingIssue.numbersUnchecked]);
      expect(row.addable, isTrue);
      expect(row.preselected, isFalse);

      // 평가금액 ÷ 수량이 지금 시세와 맞는다 = 수량이 맞다
      final near = row.withLive({'1': 101});
      expect(near.issues, isEmpty);
      expect(near.preselected, isTrue);

      final far = row.withLive({'1': 150});
      expect(far.issues, contains(HoldingIssue.numbersUnchecked));
      expect(far.preselected, isFalse);
    });

    test('현재가를 화면에서 읽은 것은 시세가 맞아도 수량을 맞춰 본 것이 아니다', () {
      final row = buildHoldingRows([
        HoldingsShot(holdings: [h(13, check: NumberCheck.none)])
      ], pf, stocks).single.withLive({'1': 100});
      expect(row.issues, [HoldingIssue.numbersUnchecked]);
    });
  });
}
