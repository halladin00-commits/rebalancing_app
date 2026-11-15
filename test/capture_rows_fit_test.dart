import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/widgets/settlement_capture_card.dart';

/// 결산 그림은 긴 목록을 다 싣지 못한다. 그렇다고 **앞에서 몇 줄만** 남기면
/// 번 순서로 늘어선 목록에서는 가장 많이 잃은 종목부터 사라진다 —
/// 10종목 ISA의 그림에서 손실 1·2위(합쳐 −23만 원)가 빠져 있었다.
void main() {
  CaptureRow row(String name, double pnl) => CaptureRow(
        name: name,
        absoluteReturn: pnl,
        returnRate: 0,
        rateAvailable: true,
        startValue: 0,
        endValue: 0,
        share: 0,
        contribution: 0,
      );

  // 번 순서 — 화면의 종목별 기여와 같은 차례
  List<CaptureRow> sorted(List<double> pnl) => [
        for (var i = 0; i < pnl.length; i++) row('종목$i', pnl[i]),
      ]..sort((a, b) => b.absoluteReturn.compareTo(a.absoluteReturn));

  test('그 10종목 ISA는 이제 전부 실린다', () {
    final all = sorted([
      286890, 281940, 205120, 187950, 120060, 109560, 37575, -84360,
      -100000, -130925, //
    ]);
    final fit = fitCaptureRows(all);
    expect(fit.rows.length, 10);
    expect(fit.hidden, 0);
  });

  test('스무 줄까지는 자르지 않는다', () {
    final fit = fitCaptureRows(sorted([for (var i = 0; i < 20; i++) i * 10.0]));
    expect(fit.rows.length, 20);
    expect(fit.hidden, 0);
    expect(captureMaxRows, 20);
  });

  test('넘치면 금액이 작은 줄을 뺀다 — 가장 많이 잃은 종목은 남는다', () {
    final all = sorted([
      for (var i = 1; i <= 15; i++) i * 1000.0, // 번 종목 15
      -50, -70, 30, // 작은 것 셋 — 빠져야 한다
      for (var i = 1; i <= 5; i++) -i * 2000.0, // 잃은 종목 5
    ]);
    expect(all.length, 23);

    final fit = fitCaptureRows(all);
    expect(fit.rows.length, 20);
    expect(fit.hidden, 3);
    expect(fit.hiddenSum, closeTo(-90, 1e-9));

    final kept = fit.rows.map((r) => r.absoluteReturn).toList();
    expect(kept, contains(-10000), reason: '가장 많이 잃은 종목이 빠졌다');
    expect(kept, contains(15000));
    expect(kept, isNot(contains(-50)));

    // 차례는 받은 그대로
    expect(kept, [...kept]..sort((a, b) => b.compareTo(a)));

    // 그림 속 금액을 다 더하면 전체와 같다
    final total = all.fold(0.0, (s, r) => s + r.absoluteReturn);
    expect(kept.fold(0.0, (s, v) => s + v) + fit.hiddenSum,
        closeTo(total, 1e-6));
  });

  test('결산 화면이 줄을 미리 자르지 않는다', () {
    for (final f in [
      'lib/screens/all_settlement_screen.dart',
      'lib/screens/portfolio_settlement_screen.dart',
    ]) {
      expect(File(f).readAsStringSync().contains('.take('), isFalse,
          reason: '$f 가 줄을 잘라 넘긴다 — 카드가 고르게 전부 넘겨야 한다');
    }
    expect(
        File('lib/widgets/settlement_capture_card.dart').readAsStringSync(),
        contains('captureOthersSum'),
        reason: '뺀 줄의 합계를 그림에 안 적는다');
  });
}
