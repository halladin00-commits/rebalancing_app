import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/widgets/weight_bar.dart';

/// 비중 막대는 자식 없는 `ColoredBox`를 `Row`에 넣어 그린다.
/// 세로 정렬을 stretch로 잡지 않으면 높이가 0이 되어 **아무것도 안 보인다**
/// (실기기에서 실제로 겪은 증상). 색 구간이 실제로 그려지는지 확인한다.
void main() {
  Future<void> pump(WidgetTester tester, List<WeightSegment> segments) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 300, child: WeightBar(segments: segments)),
          ),
        ),
      ),
    );
  }

  /// Scaffold 배경 등 바깥 위젯이 섞이지 않도록 WeightBar 하위로 한정한다.
  Finder segmentsIn() => find.descendant(
        of: find.byType(WeightBar),
        matching: find.byType(ColoredBox),
      );

  Finder markersIn() => find.descendant(
        of: find.byType(WeightBar),
        matching: find.byType(DecoratedBox),
      );

  testWidgets('색 구간이 실제 높이를 갖는다', (tester) async {
    await pump(tester, const [
      WeightSegment(currentWeight: 40, targetWeight: 35),
      WeightSegment(currentWeight: 60, targetWeight: 65),
    ]);

    expect(segmentsIn(), findsNWidgets(2));

    for (final el in segmentsIn().evaluate()) {
      final size = (el.renderObject as RenderBox).size;
      expect(size.height, greaterThan(0), reason: '구간 높이가 0이면 화면에 안 보인다');
      expect(size.width, greaterThan(0));
    }
  });

  testWidgets('구간 너비가 현재 비중에 비례한다', (tester) async {
    await pump(tester, const [
      WeightSegment(currentWeight: 25, targetWeight: 50),
      WeightSegment(currentWeight: 75, targetWeight: 50),
    ]);

    final sizes = segmentsIn()
        .evaluate()
        .map((e) => (e.renderObject as RenderBox).size.width)
        .toList();

    expect(sizes[1] / sizes[0], closeTo(3.0, 0.05)); // 75 : 25
  });

  testWidgets('구간이 없으면 높이만 차지하고 아무것도 그리지 않는다', (tester) async {
    await pump(tester, const []);
    expect(segmentsIn(), findsNothing);
  });

  testWidgets('현재 비중이 모두 0이면 그리지 않는다 — 0으로 나누기 방지', (tester) async {
    await pump(tester, const [
      WeightSegment(currentWeight: 0, targetWeight: 50),
      WeightSegment(currentWeight: 0, targetWeight: 50),
    ]);
    expect(segmentsIn(), findsNothing);
  });

  testWidgets('목표 비중 경계마다 세로선을 긋는다 (마지막 100% 경계 제외)', (tester) async {
    await pump(tester, const [
      WeightSegment(currentWeight: 30, targetWeight: 30),
      WeightSegment(currentWeight: 30, targetWeight: 30),
      WeightSegment(currentWeight: 40, targetWeight: 40),
    ]);

    // 구간 3개 → 경계 2개 (30%, 60%)
    expect(markersIn(), findsNWidgets(2));
  });
}
