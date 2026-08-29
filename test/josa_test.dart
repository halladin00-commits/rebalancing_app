import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/utils/josa.dart';

/// 종목명 뒤에 붙는 조사가 `이(가)` 처럼 두 개로 나오지 않고 하나만 나와야 한다.
void main() {
  group('한글 종목명', () {
    test('받침 있으면 이/은/을/과', () {
      expect(withJosa('삼성전자', Josa.iGa), '삼성전자가'); // 자 = 받침 없음
      expect(withJosa('반도체', Josa.iGa), '반도체가');
      expect(withJosa('현대차', Josa.iGa), '현대차가');
      expect(withJosa('한국전력', Josa.iGa), '한국전력이'); // 력 = ㄱ 받침
      expect(withJosa('삼성물산', Josa.eunNeun), '삼성물산은');
      expect(withJosa('카카오', Josa.eunNeun), '카카오는');
      expect(withJosa('네이버', Josa.eulReul), '네이버를');
      expect(withJosa('한국전력', Josa.eulReul), '한국전력을');
    });

    test('시안에서 잘못 나왔던 문구', () {
      // `TIGER 반도체이(가) 목표보다 많습니다` → `TIGER 반도체가`
      expect(withJosa('TIGER 반도체', Josa.iGa), 'TIGER 반도체가');
    });
  });

  group('영문 종목명 — 한국어로 읽은 끝소리 기준', () {
    test('모음으로 끝나면 받침 없음', () {
      expect(withJosa('SPY', Josa.iGa), 'SPY가'); // 와이
      expect(withJosa('QQQ', Josa.iGa), 'QQQ가'); // 큐
      expect(withJosa('VOO', Josa.eunNeun), 'VOO는'); // 오
      expect(withJosa('IVV', Josa.eulReul), 'IVV를'); // 브이
    });

    test('L·R은 ㄹ 받침, M·N은 다른 받침', () {
      expect(withJosa('SCHD', Josa.iGa), 'SCHD가'); // 디
      expect(withJosa('XLK', Josa.iGa), 'XLK가'); // 케이
      expect(withJosa('SPDR', Josa.iGa), 'SPDR이'); // 알
      expect(withJosa('SOXL', Josa.eulReul), 'SOXL을'); // 엘
      expect(withJosa('IWM', Josa.iGa), 'IWM이'); // 엠
    });
  });

  group('숫자로 끝나는 종목명', () {
    test('받침 없는 숫자 2·4·5·9', () {
      expect(withJosa('KODEX 자동차', Josa.iGa), 'KODEX 자동차가');
      expect(withJosa('TIGER 2', Josa.iGa), 'TIGER 2가'); // 이
      expect(withJosa('KODEX 500', Josa.iGa), 'KODEX 500이'); // 오백
    });

    test('ㄹ 받침 숫자 1·7·8', () {
      expect(withJosa('KODEX 200', Josa.iGa), 'KODEX 200이'); // 이백
      expect(withJosa('테마 11', Josa.eulReul), '테마 11을'); // 십일
    });
  });

  group('으로/로 — ㄹ 받침 뒤에서는 로', () {
    test('받침 없으면 로', () {
      expect(withJosa('카카오', Josa.euro), '카카오로');
    });
    test('ㄹ 받침이면 로', () {
      expect(withJosa('서울', Josa.euro), '서울로');
      expect(withJosa('SPDR', Josa.euro), 'SPDR로');
    });
    test('다른 받침이면 으로', () {
      expect(withJosa('한국전력', Josa.euro), '한국전력으로');
      expect(withJosa('IWM', Josa.euro), 'IWM으로');
    });
  });

  group('뒤에 붙은 괄호·따옴표는 건너뛴다', () {
    test('소리는 그 앞 글자에서 난다', () {
      expect(withJosa('삼성전자(우)', Josa.iGa), '삼성전자(우)가'); // 우
      expect(withJosa('한국전력(1)', Josa.iGa), '한국전력(1)이'); // 일
    });
  });

  test('영어 화면에서는 조사를 붙이지 않는다', () {
    expect(withJosa('Samsung', Josa.iGa, korean: false), 'Samsung');
    expect(withJosa('삼성전자', Josa.iGa, korean: false), '삼성전자');
  });

  test('빈 이름이어도 죽지 않는다', () {
    expect(withJosa('', Josa.iGa), '가');
    expect(withJosa('...', Josa.iGa), '...가');
  });
}
