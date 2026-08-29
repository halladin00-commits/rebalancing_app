import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/import_analyzer.dart';
import 'package:rebalancing_app/services/import_columns.dart';
import 'package:rebalancing_app/utils/csv_parser.dart';

/// 가져오기에서 가장 위험한 건 **조용히 잘못 들어가는 것**이다.
/// 그래서 저장하기 전에 몇 건이 들어가고 몇 건이 왜 빠지는지 세어 둔다.
void main() {
  PortfolioItem item(String id, String name, String ticker,
          {List<StockTransaction>? txs}) =>
      PortfolioItem(
        id: id,
        name: name,
        ticker: ticker,
        market: 'US',
        transactions: txs,
      );

  Portfolio pf([List<PortfolioItem>? items]) => Portfolio(
        id: 'p',
        name: 'p',
        items: items ??
            [
              item('i1', 'Vanguard S&P 500', 'VOO'),
              item('i2', 'Apple', 'AAPL'),
            ],
      );

  List<List<String>> table(String csv) =>
      parseCsv(csv, delimiter: guessDelimiter(csv));

  group('숫자 읽기', () {
    test('쉼표와 통화 기호를 걷어낸다', () {
      expect(ImportAnalyzer.parseNumber('1,200'), 1200);
      expect(ImportAnalyzer.parseNumber('₩11,235'), 11235);
      expect(ImportAnalyzer.parseNumber(r'$512.40'), 512.40);
    });
    test('괄호 음수는 크기만 본다 — 매수·매도는 구분 칸이 정한다', () {
      expect(ImportAnalyzer.parseNumber('(50)'), 50);
      expect(ImportAnalyzer.parseNumber('-50'), 50);
    });
    test('읽을 수 없으면 null', () {
      expect(ImportAnalyzer.parseNumber(''), isNull);
      expect(ImportAnalyzer.parseNumber('-'), isNull);
      expect(ImportAnalyzer.parseNumber('없음'), isNull);
    });
  });

  group('날짜 읽기', () {
    test('여러 표기', () {
      expect(ImportAnalyzer.parseDate('2026.08.12'), DateTime(2026, 8, 12));
      expect(ImportAnalyzer.parseDate('2026-08-12'), DateTime(2026, 8, 12));
      expect(ImportAnalyzer.parseDate('2026/8/12'), DateTime(2026, 8, 12));
      expect(ImportAnalyzer.parseDate('20260812'), DateTime(2026, 8, 12));
    });
    test('엑셀 날짜 시리얼', () {
      expect(ImportAnalyzer.parseDate('45000'), DateTime(2023, 3, 15));
    });
    test('말이 안 되는 날짜는 거절한다', () {
      expect(ImportAnalyzer.parseDate('2026.13.01'), isNull);
      expect(ImportAnalyzer.parseDate('그저께'), isNull);
      expect(ImportAnalyzer.parseDate(''), isNull);
    });
  });

  group('매수·매도 읽기', () {
    test('한국어·영어', () {
      expect(ImportAnalyzer.parseSide('매수'), true);
      expect(ImportAnalyzer.parseSide('현금매수'), true);
      expect(ImportAnalyzer.parseSide('Buy'), true);
      expect(ImportAnalyzer.parseSide('매도'), false);
      expect(ImportAnalyzer.parseSide('SELL'), false);
    });
    test('모르면 null — 넘겨짚지 않는다', () {
      expect(ImportAnalyzer.parseSide('입금'), isNull);
      expect(ImportAnalyzer.parseSide(''), isNull);
    });
  });

  test('티커의 거래소 꼬리표를 뗀다', () {
    expect(ImportAnalyzer.normalizeTicker('SCHD.US'), 'SCHD');
    expect(ImportAnalyzer.normalizeTicker('voo'), 'VOO');
    expect(ImportAnalyzer.normalizeTicker('069500'), '069500');
  });

  group('열 이름 찾기', () {
    test('표준 양식', () {
      final c = ColumnMap.detect(table('날짜,종목명,티커,시장,유형,수량,단가\n'
          '2026.08.12,Apple,AAPL,US,매수,3,224.10'));
      expect(c.fromHeader, true);
      expect(c[ImportField.date], 0);
      expect(c[ImportField.qty], 5);
      expect(c.dataStartRow, 1);
    });

    test('증권사 파일 — 이름도 순서도 다르다', () {
      final c = ColumnMap.detect(table(
          '거래일자,구분,종목명,체결수량,체결단가\n2026-08-12,매수,Apple,3,224.10'));
      expect(c.fromHeader, true);
      expect(c[ImportField.date], 0);
      expect(c[ImportField.type], 1);
      expect(c[ImportField.name], 2);
      expect(c[ImportField.qty], 3);
      expect(c[ImportField.price], 4);
    });

    test('안내 문구가 앞에 붙어 있어도 찾는다', () {
      final c = ColumnMap.detect(table('OO증권 거래내역 조회 결과\n'
          '조회기간: 2026.01.01 ~ 2026.08.31\n'
          '거래일,종목명,구분,수량,단가\n'
          '2026.08.12,Apple,매수,3,224.10'));
      expect(c.fromHeader, true);
      expect(c.dataStartRow, 3);
    });

    test('못 알아보면 표준 양식 순서로 본다', () {
      final c = ColumnMap.detect(table('2026.08.12,Apple,AAPL,US,매수,3,224.10'));
      expect(c.fromHeader, false);
      expect(c.dataStartRow, 0);
      expect(c[ImportField.date], 0);
    });
  });

  group('계획 만들기', () {
    test('찾은 종목은 가져올 것으로 센다', () {
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.08.12,Apple,AAPL,US,매수,3,224.10\n'
              '2026.08.06,Vanguard S&P 500,VOO,US,매도,5,512.40'),
          'x.csv',
          pf());
      expect(plan.importCount, 2);
      expect(plan.totalRows, 2);
      expect(plan.buyCount, 1);
      expect(plan.sellCount, 1);
      expect(plan.itemCount, 2);
    });

    test('티커가 없으면 종목명으로 찾는다', () {
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.08.12,Apple,,US,매수,3,224.10'),
          'x.csv',
          pf());
      expect(plan.importCount, 1);
      expect(plan.ready.first.matchedItemId, 'i2');
    });

    test('없는 종목은 연결 대상으로 뺀다 — 몰래 만들지 않는다', () {
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.08.12,Schwab US Dividend,SCHD.US,US,매수,3,28.42\n'
              '2026.08.11,Schwab US Dividend,SCHD.US,US,매수,2,28.10\n'
              '2026.08.10,JPMorgan Equity,JEPI,US,매수,1,55.00'),
          'x.csv',
          pf());
      expect(plan.importCount, 0);
      expect(plan.unlinked.length, 3);
      expect(plan.unmatchedItems.length, 2, reason: '티커별로 묶어야 한다');
      final schd = plan.unmatchedItems.firstWhere((u) => u.ticker == 'SCHD');
      expect(schd.rowCount, 2);
    });

    test('연결하면 가져올 것으로 옮겨간다', () {
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.08.12,Schwab US Dividend,SCHD,US,매수,3,28.42'),
          'x.csv',
          pf());
      final linked = plan.withLinks({'SCHD': 'i1'});
      expect(linked.importCount, 1);
      expect(linked.unlinked, isEmpty);
      expect(linked.ready.first.matchedItemId, 'i1');
    });

    test('이미 있는 거래는 건너뛴다', () {
      final withTx = pf([
        item('i1', 'Vanguard S&P 500', 'VOO', txs: [
          StockTransaction(
              id: 't1',
              date: DateTime(2026, 6, 18),
              quantity: 1,
              price: 500.0),
        ]),
      ]);
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.06.18,Vanguard S&P 500,VOO,US,매수,1,500\n'
              '2026.08.12,Vanguard S&P 500,VOO,US,매수,2,510'),
          'x.csv',
          withTx);
      expect(plan.duplicates.length, 1);
      expect(plan.importCount, 1);
      expect(plan.totalRows, 2);
    });

    test('수량이 같아도 매도면 다른 거래다', () {
      final withTx = pf([
        item('i1', 'Vanguard S&P 500', 'VOO', txs: [
          StockTransaction(
              id: 't1', date: DateTime(2026, 6, 18), quantity: 1, price: 500.0),
        ]),
      ]);
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.06.18,Vanguard S&P 500,VOO,US,매도,1,500'),
          'x.csv',
          withTx);
      expect(plan.duplicates, isEmpty);
      expect(plan.importCount, 1);
    });

    test('못 읽은 줄은 이유와 줄 번호를 남긴다', () {
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '어제,Apple,AAPL,US,매수,3,224\n'
              '2026.08.12,Apple,AAPL,US,입금,3,224\n'
              '2026.08.11,Apple,AAPL,US,매수,없음,224'),
          'x.csv',
          pf());
      expect(plan.skipped.length, 3);
      expect(plan.skipped[0].rowNumber, 2);
      expect(plan.skipped[0].reason, contains('거래일'));
      expect(plan.skipped[1].reason, contains('매수·매도'));
      expect(plan.skipped[2].reason, contains('수량'));
    });

    test('38 / 42 처럼 전체와 가져올 건수를 따로 센다', () {
      final withTx = pf([
        item('i2', 'Apple', 'AAPL', txs: [
          StockTransaction(
              id: 't1', date: DateTime(2026, 7, 1), quantity: 1, price: 200.0),
        ]),
      ]);
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.08.12,Apple,AAPL,US,매수,3,224\n' // 가져옴
              '2026.07.01,Apple,AAPL,US,매수,1,200\n' // 중복
              '2026.08.10,JPMorgan,JEPI,US,매수,1,55\n' // 연결 필요
              '어제,Apple,AAPL,US,매수,3,224'), // 못 읽음
          'x.csv',
          withTx);
      expect(plan.importCount, 1);
      expect(plan.totalRows, 4);
      expect(plan.duplicates.length, 1);
      expect(plan.unlinked.length, 1);
      expect(plan.skipped.length, 1);
    });

    test('기간과 미리보기 정렬', () {
      final plan = ImportAnalyzer.buildPlan(
          table('날짜,종목명,티커,시장,유형,수량,단가\n'
              '2026.03.11,Apple,AAPL,US,매수,1,180\n'
              '2026.08.12,Apple,AAPL,US,매수,3,224'),
          'x.csv',
          pf());
      expect(plan.dateRange!.from, DateTime(2026, 3, 11));
      expect(plan.dateRange!.to, DateTime(2026, 8, 12));
      expect(plan.previewNewestFirst.first.date, DateTime(2026, 8, 12));
    });

    test('열을 못 찾으면 그렇다고 말한다 — 0건 성공으로 끝내지 않는다', () {
      final plan =
          ImportAnalyzer.buildPlan(table('아무말,대잔치\n하나,둘'), 'x.csv', pf());
      expect(plan.importCount, 0);
      expect(plan.skipped, isNotEmpty);
    });

    test('시장 칸이 없으면 티커 모양으로 짐작한다', () {
      final plan = ImportAnalyzer.buildPlan(
          table('거래일,종목명,티커,구분,수량,단가\n'
              '2026.08.12,삼성전자,005930,매수,10,72300'),
          'x.csv',
          pf());
      expect(plan.unlinked.first.market, 'KR', reason: '숫자 6자리는 한국이다');
    });
  });
}
