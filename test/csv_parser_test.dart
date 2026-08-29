import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/utils/csv_parser.dart';

/// 증권사 CSV를 잘못 읽으면 남의 돈 기록이 조용히 틀어진다.
void main() {
  group('기본', () {
    test('쉼표로 가른다', () {
      expect(parseCsv('a,b,c'), [
        ['a', 'b', 'c']
      ]);
    });

    test('여러 줄', () {
      expect(parseCsv('a,b\nc,d'), [
        ['a', 'b'],
        ['c', 'd']
      ]);
    });

    test('CRLF도 LF와 같이 읽는다', () {
      expect(parseCsv('a,b\r\nc,d\r\n'), [
        ['a', 'b'],
        ['c', 'd']
      ]);
    });

    test('앞뒤 공백은 버린다', () {
      expect(parseCsv(' a , b '), [
        ['a', 'b']
      ]);
    });

    test('빈 줄은 세지 않는다 — 파일 끝 빈 줄이 한 건이 되면 안 된다', () {
      expect(parseCsv('a,b\n\n\nc,d\n\n'), [
        ['a', 'b'],
        ['c', 'd']
      ]);
    });

    test('빈 문자열', () {
      expect(parseCsv(''), isEmpty);
    });
  });

  group('큰따옴표', () {
    test('칸 안의 쉼표를 지킨다', () {
      expect(parseCsv('"삼성전자, 우선주",10'), [
        ['삼성전자, 우선주', '10']
      ]);
    });

    test('안의 큰따옴표는 두 개로 쓴다', () {
      expect(parseCsv('"그는 ""안녕"" 이라 했다",1'), [
        ['그는 "안녕" 이라 했다', '1']
      ]);
    });

    test('칸 안의 줄바꿈을 지킨다', () {
      expect(parseCsv('"첫 줄\n둘째 줄",1'), [
        ['첫 줄\n둘째 줄', '1']
      ]);
    });

    test('빈 칸', () {
      expect(parseCsv('a,,c'), [
        ['a', '', 'c']
      ]);
    });
  });

  test('엑셀이 붙인 BOM을 떼어낸다 — 첫 열 이름이 안 맞는 원인', () {
    const withBom = '﻿날짜,종목명\n2026.08.12,SPY';
    expect(parseCsv(withBom), [
      ['날짜', '종목명'],
      ['2026.08.12', 'SPY']
    ]);
    expect(parseCsv(withBom).first.first, '날짜');
  });

  group('구분자 짐작', () {
    test('쉼표', () => expect(guessDelimiter('a,b,c\n1,2,3'), ','));
    test('탭', () => expect(guessDelimiter('a\tb\tc'), '\t'));
    test('세미콜론 — 유럽 로캘 엑셀', () {
      expect(guessDelimiter('a;b;c'), ';');
    });
    test('갈라지지 않으면 쉼표로 본다', () {
      expect(guessDelimiter('한 칸뿐'), ',');
    });
    test('빈 파일', () => expect(guessDelimiter(''), ','));
  });

  test('실제 증권사 파일 모양', () {
    const raw = '﻿"거래일자","종목명","구분","수량","단가"\r\n'
        '"2026-08-12","TIGER 미국배당다우존스","매수","1,200","11,235"\r\n'
        '"2026-08-06","삼성전자, 우선주","매도","50","72,300"\r\n';
    final rows = parseCsv(raw, delimiter: guessDelimiter(raw));
    expect(rows.length, 3);
    expect(rows[0], ['거래일자', '종목명', '구분', '수량', '단가']);
    expect(rows[1][1], 'TIGER 미국배당다우존스');
    expect(rows[2][1], '삼성전자, 우선주', reason: '따옴표 안 쉼표로 칸이 밀렸다');
    expect(rows[1][3], '1,200');
  });
}
