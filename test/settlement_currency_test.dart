import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/services/settlement_service.dart';

/// **결산 탭(전체 합산)이 「합계 표시 통화」를 따른다.**
///
/// 예전에는 원화로 박혀 있었다. 달러 계좌만 있는 사람이 합계 통화를 USD로
/// 둬도 결산 탭에서만 ₩로 봤다 — 홈 합계와 포트별 결산은 달러인데.
///
/// 합산은 포트마다 `combineFx`를 곱해 더한다. 여기서 그 비율을 본다.
void main() {
  Portfolio pf(String id, String cur, double rate) => Portfolio(
      id: id, name: id, currency: cur, exchangeRate: rate, items: []);

  group('원화로 합칠 때 — 예전 식 그대로', () {
    test('달러 포트는 그 포트의 환율을 곱한다', () {
      final usd = pf('u', 'USD', 1400);
      expect(SettlementService.combineFx(usd, [usd], 'KRW'), 1400);
    });

    test('원화 포트는 그대로', () {
      final krw = pf('k', 'KRW', 1400);
      expect(SettlementService.combineFx(krw, [krw], 'KRW'), 1);
    });
  });

  group('달러로 합칠 때', () {
    test('달러 포트는 그대로 — 포트별 결산과 숫자가 똑같다', () {
      // 환율이 포트마다 조금씩 달라도 달러 금액에는 환율이 끼지 않는다
      final a = pf('a', 'USD', 1335), b = pf('b', 'USD', 1342);
      expect(SettlementService.combineFx(a, [a, b], 'USD'), 1);
      expect(SettlementService.combineFx(b, [a, b], 'USD'), 1);
    });

    test('원화 포트는 전 포트 환율 평균으로 나눈다 — 홈 합계와 같은 값', () {
      final k = pf('k', 'KRW', 1300), u = pf('u', 'USD', 1400);
      expect(SettlementService.averageRate([k, u]), 1350);
      expect(SettlementService.combineFx(k, [k, u], 'USD'), closeTo(1 / 1350, 1e-12));
    });

    test('받은 환율이 없으면 1370으로 나눈다 (홈과 같은 기본값)', () {
      final k = pf('k', 'KRW', 0);
      expect(SettlementService.combineFx(k, [k], 'USD'), closeTo(1 / 1370, 1e-12));
    });
  });

  test('합산 수익률은 통화와 무관하다 — 같은 비율이 분자·분모에 곱해진다', () {
    // 원화 포트 하나: 기초 1,350,000원 → 손익 +135,000원 (10%)
    // 달러로 보면 기초 $1,000 → 손익 +$100. 수익률은 그대로 10%.
    final k = pf('k', 'KRW', 1350);
    final fx = SettlementService.combineFx(k, [k], 'USD');
    final r = periodReturn(
        absoluteReturn: 135000 * fx,
        startValue: 1350000 * fx,
        weightedCashFlow: 0,
        netCashFlow: 0);
    expect(r.rate, closeTo(10, 1e-9));
  });
}
