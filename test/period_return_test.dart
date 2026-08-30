import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/services/settlement_service.dart';

/// 기간 수익률의 **정의 하나**.
///
/// 전에는 전체 결산 헤더가 `손익 ÷ 기초자산`, 바로 밑 포트별 행이
/// Modified Dietz였다. 매매가 없는 달은 두 식이 같아 안 드러나고,
/// 리밸런싱한 달에만 어긋났다. 실기기에서 헤더 `—`와 그 밑 `+4178.77%`가
/// 같이 떴다. 세 자리가 모두 이 함수를 지나게 했으니 여기서 지킨다.
void main() {
  ({double rate, bool available}) r({
    required double abs,
    required double start,
    double wcf = 0,
    double netCF = 0,
  }) =>
      periodReturn(
        absoluteReturn: abs,
        startValue: start,
        weightedCashFlow: wcf,
        netCashFlow: netCF,
      );

  group('기초자산이 있으면 Modified Dietz', () {
    test('매매가 없으면 단순 수익률과 같다 — 여태 안 드러난 이유', () {
      final x = r(abs: 10, start: 100);
      expect(x.available, isTrue);
      expect(x.rate, closeTo(10.0, 1e-9));
    });

    test('기간 중 입금은 분모에 가중치만큼만 들어간다', () {
      // 100으로 시작, 기간 절반 지점에 100 입금 → 분모 150
      final x = r(abs: 15, start: 100, wcf: 50, netCF: 100);
      expect(x.rate, closeTo(10.0, 1e-9));
    });

    test('입금을 분모에 안 넣으면 수익률이 부풀려진다 — 그래서 Dietz다', () {
      // 같은 상황을 옛 식(손익 ÷ 기초자산)으로 재면 15%가 나온다
      expect(15 / 100 * 100, 15.0);
      expect(r(abs: 15, start: 100, wcf: 50, netCF: 100).rate,
          closeTo(10.0, 1e-9));
    });

    test('많이 팔아 분모가 0 이하가 되면 못 낸다', () {
      final x = r(abs: 5, start: 100, wcf: -150, netCF: -150);
      expect(x.available, isFalse);
      expect(x.rate, 0);
    });
  });

  group('기초자산이 0이면 넣은 돈 대비', () {
    test('기간 안에 처음 사면 순입금이 분모다', () {
      // 696,117,104을 넣어 1,522,310,938을 벌었다 → +218.69%
      final x = r(
          abs: 1522310938, start: 0, wcf: 144000000, netCF: 696117104);
      expect(x.available, isTrue);
      expect(x.rate, closeTo(218.68, 0.02));
    });

    test('Dietz를 그대로 쓰면 +2000%대가 나온다 — 그래서 규칙을 나눴다', () {
      // 실기기에서 실제로 본 값. 분모가 기간의 일부만 남는다.
      const dietz = 1175070000 / 58185000 * 100;
      expect(dietz, greaterThan(2000));
      // 같은 상황을 넣은 돈 대비로 재면 사람이 아는 수가 나온다
      expect(r(abs: 1175070000, start: 0, wcf: 58185000, netCF: 281200000).rate,
          closeTo(417.88, 0.02));
    });

    test('기초도 0이고 넣은 것도 없으면 못 낸다', () {
      expect(r(abs: 0, start: 0).available, isFalse);
      expect(r(abs: 100, start: 0, netCF: 0).available, isFalse);
    });

    test('기초가 0인데 순매도면 못 낸다 — 없던 걸 팔 수는 없다', () {
      expect(r(abs: 10, start: 0, netCF: -50).available, isFalse);
    });
  });

  test('손실도 같은 규칙으로 나온다', () {
    expect(r(abs: -20, start: 100).rate, closeTo(-20.0, 1e-9));
    expect(r(abs: -50, start: 0, netCF: 100).rate, closeTo(-50.0, 1e-9));
  });

  test('못 낼 때 0%를 내보내지 않는다 — "정말 0%"와 구분돼야 한다', () {
    final x = r(abs: 999, start: 0, netCF: 0);
    expect(x.available, isFalse);
    expect(x.rate, 0, reason: 'available이 false일 때만 0이고, 화면은 —를 쓴다');
  });
}
