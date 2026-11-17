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

  group('환율 칩은 환산이 실제로 일어날 때만', () {
    PortfolioItem it(String m) => PortfolioItem(
        id: m, name: m, ticker: m, market: m, shares: 1, currentPrice: 1);

    test('달러 계좌의 미국 종목만 달러로 보면 환율이 안 낀다', () {
      final u = Portfolio(id: 'u', name: 'u', currency: 'USD', items: [it('US')]);
      expect(SettlementService.needsExchangeRate([u], 'USD'), isFalse);
      // 원화로 보면 합계에서 환산한다
      expect(SettlementService.needsExchangeRate([u], 'KRW'), isTrue);
    });

    test('원화 계좌의 국내 종목만 원화로 보면 환율이 안 낀다', () {
      final k = Portfolio(id: 'k', name: 'k', items: [it('KR')]);
      expect(SettlementService.needsExchangeRate([k], 'KRW'), isFalse);
    });

    test('원화 계좌에 미국 종목이 있으면 평가금액에 환율이 낀다', () {
      final k = Portfolio(id: 'k', name: 'k', items: [it('KR'), it('US')]);
      expect(SettlementService.needsExchangeRate([k], 'KRW'), isTrue);
    });

    test('달러 계좌에 국내 종목이 있어도 마찬가지', () {
      final u = Portfolio(id: 'u', name: 'u', currency: 'USD', items: [it('KR')]);
      expect(SettlementService.needsExchangeRate([u], 'USD'), isTrue);
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
