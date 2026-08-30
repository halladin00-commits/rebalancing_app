import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/services/settlement_service.dart';

/// 마감된 기간의 결산을 디스크에 저장한다.
///
/// 저장했다 되살린 값이 조금이라도 달라지면 **틀린 수익률이 조용히 남는다.**
/// 다시 계산하지 않으므로 아무도 눈치채지 못한다. 그래서 왕복을 못 박는다.
void main() {
  SettlementItemContribution contrib(String id) => SettlementItemContribution(
        itemId: id,
        name: '종목 $id',
        startValue: 1234567.89,
        endValue: 2345678.91,
        contribution: 12.345,
        itemReturnPct: -7.654,
        itemAbsoluteReturn: -98765.43,
      );

  SettlementResult sample({
    bool rateAvailable = true,
    List<SettlementItemContribution>? contributions,
  }) =>
      SettlementResult(
        period: SettlementPeriod.quarterly,
        key: const PeriodKey(2025, 3),
        periodStart: DateTime(2025, 7, 1),
        periodEnd: DateTime(2025, 9, 30),
        startValue: 1000000.5,
        endValue: 1234567.75,
        absoluteReturn: 234567.25,
        returnRate: 23.456789,
        rateAvailable: rateAvailable,
        netCashFlow: -50000.125,
        isCurrentPeriod: false,
        contributions: contributions ?? [contrib('a'), contrib('b')],
      );

  /// 실제 저장 경로와 같게 — JSON 문자열을 거쳐 되살린다.
  SettlementResult roundTrip(SettlementResult r) =>
      SettlementResult.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);

  group('결산 결과 왕복', () {
    test('금액과 수익률이 한 자리도 달라지지 않는다', () {
      final a = sample();
      final b = roundTrip(a);
      expect(b.startValue, a.startValue);
      expect(b.endValue, a.endValue);
      expect(b.absoluteReturn, a.absoluteReturn);
      expect(b.returnRate, a.returnRate);
      expect(b.netCashFlow, a.netCashFlow);
    });

    test('기간이 그대로다', () {
      final a = sample();
      final b = roundTrip(a);
      expect(b.period, a.period);
      expect(b.key.year, a.key.year);
      expect(b.key.sub, a.key.sub);
      expect(b.periodStart, a.periodStart);
      expect(b.periodEnd, a.periodEnd);
    });

    test('수익률을 낼 수 없다는 표시가 살아남는다', () {
      // 이걸 잃으면 "계산 불가"가 "0%"로 둔갑한다 — 가장 위험한 손실이다.
      expect(roundTrip(sample(rateAvailable: false)).rateAvailable, isFalse);
      expect(roundTrip(sample(rateAvailable: true)).rateAvailable, isTrue);
    });

    test('되살린 것은 늘 마감된 기간이다', () {
      // 진행 중인 기간은 애초에 저장하지 않는다. 되살릴 때 true로 오면
      // 화면이 "진행 중"이라 잘못 말한다.
      expect(roundTrip(sample()).isCurrentPeriod, isFalse);
    });

    test('종목별 기여가 개수와 값 모두 그대로다', () {
      final a = sample();
      final b = roundTrip(a);
      expect(b.contributions.length, a.contributions.length);
      for (var i = 0; i < a.contributions.length; i++) {
        final x = a.contributions[i], y = b.contributions[i];
        expect(y.itemId, x.itemId);
        expect(y.name, x.name);
        expect(y.startValue, x.startValue);
        expect(y.endValue, x.endValue);
        expect(y.contribution, x.contribution);
        expect(y.itemReturnPct, x.itemReturnPct);
        expect(y.itemAbsoluteReturn, x.itemAbsoluteReturn);
      }
    });

    test('기여가 없어도 죽지 않는다', () {
      expect(roundTrip(sample(contributions: [])).contributions, isEmpty);
    });

    test('음수와 0도 그대로 돌아온다', () {
      final a = SettlementResult(
        period: SettlementPeriod.weekly,
        key: const PeriodKey(2026, 1),
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 7),
        startValue: 0,
        endValue: 0,
        absoluteReturn: -12345.67,
        returnRate: -99.99,
        rateAvailable: false,
        netCashFlow: 0,
        isCurrentPeriod: false,
        contributions: const [],
      );
      final b = roundTrip(a);
      expect(b.startValue, 0);
      expect(b.absoluteReturn, -12345.67);
      expect(b.returnRate, -99.99);
      expect(b.rateAvailable, isFalse);
    });
  });

  test('옛 형식이 섞여 있어도 되살릴 수 있다 — rateAvailable 없는 경우', () {
    // 저장 형식이 바뀌어도 앱이 죽지 않아야 한다. 없으면 true로 본다.
    final j = sample().toJson()..remove('ra');
    expect(SettlementResult.fromJson(j).rateAvailable, isTrue);
  });
}
