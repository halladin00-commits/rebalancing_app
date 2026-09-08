import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/main.dart';
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

  /// 칸만 집어낸다 — 종목 사이 구분선도 색 상자라 섞이면 개수·너비가 틀어진다.
  Finder segmentsIn() => find.descendant(
        of: find.byType(WeightBar),
        matching: find.byType(WeightBarSegmentBox),
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

  testWidgets('허용 편차 안인 칸은 트랙 배경색과 달라야 한다', (tester) async {
    // 같은 색이면 모두 정상일 때 막대가 통째로 빈 것처럼 보인다.
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) {
          ctx = c;
          return const Center(
            child: SizedBox(
              width: 300,
              child: WeightBar(
                threshold: 5,
                segments: [
                  WeightSegment(currentWeight: 50, targetWeight: 50),
                  WeightSegment(currentWeight: 50, targetWeight: 50),
                ],
              ),
            ),
          );
        }),
      ),
    ));

    final colors = segmentsIn()
        .evaluate()
        .map((e) => (e.widget as WeightBarSegmentBox).color)
        .toList();
    expect(colors, hasLength(2));
    for (final c in colors) {
      expect(c, isNot(ctx.trackBg), reason: '트랙과 같은 색이면 빈 막대로 보인다');
      expect(c, ctx.weightOkFill);
    }
  });

  testWidgets('허용을 넘으면 어느 쪽이든 같은 경고색', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) {
          ctx = c;
          return const Center(
            child: SizedBox(
              width: 300,
              child: WeightBar(
                threshold: 1,
                segments: [
                  WeightSegment(currentWeight: 60, targetWeight: 50),
                  WeightSegment(currentWeight: 40, targetWeight: 50),
                ],
              ),
            ),
          );
        }),
      ),
    ));

    final colors = segmentsIn()
        .evaluate()
        .map((e) => (e.widget as WeightBarSegmentBox).color)
        .toList();
    // 바로 아래 숫자는 「넘쳤는가」만 색으로 말한다. 막대만 방향을 색으로
    // 나누면, 같은 화면에서 색이 두 가지 뜻을 갖는다.
    //
    // 방향은 색이 아니라 자리가 말한다 — 칸이 세로선(목표)보다 넓으면 초과,
    // 좁으면 미달이다.
    expect(colors[0], ctx.warningText, reason: '초과 — 경고색');
    expect(colors[1], ctx.warningText, reason: '미달도 같은 경고색');
    expect(colors[0], colors[1], reason: '방향에 따라 색이 갈리면 안 된다');
  });
}
