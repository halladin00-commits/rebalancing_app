import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/utils/money_format.dart';

/// 금액 표기는 화면마다 복사돼 있던 탓에 서로 달랐다.
/// 한곳으로 모은 뒤 규칙이 지켜지는지 확인한다.
void main() {
  group('기준통화 금액', () {
    test('원화는 정수 + 천 단위 구분', () {
      expect(fmtMoney(1457695000, 'KRW'), '₩1,457,695,000');
      expect(fmtMoney(999, 'KRW'), '₩999');
      expect(fmtMoney(1000, 'KRW'), '₩1,000');
    });

    test('원화는 소수점을 반올림해 버린다', () {
      expect(fmtMoney(1234.6, 'KRW'), '₩1,235');
    });

    test('달러는 소수 둘째 자리 + 천 단위 구분', () {
      // 이게 빠져 있어 거래 내역에 `$7230.00`으로 나왔다
      expect(fmtMoney(7230, 'USD'), r'$7,230.00');
      expect(fmtMoney(18810.4, 'USD'), r'$18,810.40');
      expect(fmtMoney(215.63, 'USD'), r'$215.63');
    });

    test('음수는 하이픈이 아니라 빼기 기호를 쓴다', () {
      expect(fmtMoney(-9758553, 'KRW'), '−₩9,758,553');
      expect(fmtMoney(-1240.5, 'USD'), '−\$1,240.50');
      expect(fmtMoney(-1, 'KRW').codeUnitAt(0), 0x2212);
    });

    test('0은 부호가 없다', () {
      expect(fmtMoney(0, 'KRW'), '₩0');
    });
  });

  group('종목 단가', () {
    test('시장으로 통화를 정한다', () {
      expect(fmtPrice(134000, 'KR'), '₩134,000');
      expect(fmtPrice(215.63, 'US'), r'$215.63');
    });

    test('현금(CASH)은 원화로 본다', () {
      expect(fmtPrice(500000, 'CASH'), '₩500,000');
    });
  });

  group('부호 있는 손익', () {
    test('양수에는 +를 붙인다', () {
      expect(fmtSigned(347424141, 'KRW'), '+₩347,424,141');
    });

    test('음수는 빼기 기호 하나만 (+−가 겹치지 않는다)', () {
      expect(fmtSigned(-10024389, 'KRW'), '−₩10,024,389');
    });
  });
}
