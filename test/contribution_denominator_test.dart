import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/services/settlement_service.dart';

/// 기여 %p를 다 더하면 기간 수익률이 되어야 한다.
///
/// 안 그러면 화면에서 `+16.45%` 밑에 `+50.21%p`와 `+5.41%p`가 나란히
/// 놓이고, 어느 쪽을 믿어야 할지 알 수 없다.
void main() {
  double sumOfContributions(
    List<double> parts, {
    required double startValue,
    required double weightedCashFlow,
    required double netCashFlow,
  }) {
    final d = contributionDenominator(
      startValue: startValue,
      weightedCashFlow: weightedCashFlow,
      netCashFlow: netCashFlow,
    );
    return parts.fold(0.0, (s, p) => s + p / d * 100);
  }

  test('기초자산이 있는 기간 — 기여 합 = 기간 수익률', () {
    const start = 100000000.0;
    const weighted = 20000000.0;
    const net = 30000000.0;
    final parts = [3000000.0, 1000000.0];
    final abs = parts.fold(0.0, (s, p) => s + p);

    final rate = periodReturn(
      absoluteReturn: abs,
      startValue: start,
      weightedCashFlow: weighted,
      netCashFlow: net,
    );
    expect(rate.available, isTrue);
    expect(
      sumOfContributions(parts,
          startValue: start, weightedCashFlow: weighted, netCashFlow: net),
      closeTo(rate.rate, 1e-9),
    );
  });

  test('기간 중에 만든 포트 — 기초자산 0이면 넣은 돈이 분모', () {
    const start = 0.0;
    const weighted = 5000000.0;
    const net = 268507351.0;
    final parts = [39261945.0, 4234374.0];
    final abs = parts.fold(0.0, (s, p) => s + p);

    final rate = periodReturn(
      absoluteReturn: abs,
      startValue: start,
      weightedCashFlow: weighted,
      netCashFlow: net,
    );
    expect(
      sumOfContributions(parts,
          startValue: start, weightedCashFlow: weighted, netCashFlow: net),
      closeTo(rate.rate, 1e-9),
    );
  });

  test('기초자산만 분모로 쓰면 합이 어긋난다 — 회귀 방지', () {
    const start = 1000000.0;
    const weighted = 250000000.0;
    const net = 268507351.0;
    final parts = [39261945.0, 4234374.0];
    final abs = parts.fold(0.0, (s, p) => s + p);

    final rate = periodReturn(
      absoluteReturn: abs,
      startValue: start,
      weightedCashFlow: weighted,
      netCashFlow: net,
    );
    final wrong = parts.fold(0.0, (s, p) => s + p / start * 100);
    expect(wrong, greaterThan(rate.rate * 10));
    expect(
      sumOfContributions(parts,
          startValue: start, weightedCashFlow: weighted, netCashFlow: net),
      closeTo(rate.rate, 1e-9),
    );
  });
}
