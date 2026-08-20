import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/services/settlement_service.dart';
import 'package:rebalancing_app/widgets/settlement_chart.dart';

/// 결산 차트는 보기용이 아니라 **기간 선택 컨트롤**이다.
/// 막대를 눌렀을 때 그 기간이 선택되는지, 계산할 수 없는 기간이
/// 눌리지 않는지를 확인한다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<SettlementBar> bars,
    required PeriodKey selected,
    required ValueChanged<PeriodKey> onSelect,
    bool showYearBoundary = false,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PnlColorNotifier(),
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SettlementChart(
                bars: bars,
                selected: selected,
                onSelect: onSelect,
                showYearBoundary: showYearBoundary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<SettlementBar> monthBars() => const [
        SettlementBar(key: PeriodKey(2026, 3), label: '3월', amount: 120000),
        SettlementBar(key: PeriodKey(2026, 4), label: '4월', amount: -50000),
        SettlementBar(key: PeriodKey(2026, 5), label: '5월', amount: 300000),
        SettlementBar(key: PeriodKey(2026, 6), label: '6월', amount: 80000),
        SettlementBar(key: PeriodKey(2026, 7), label: '7월', amount: 200000),
        SettlementBar(
            key: PeriodKey(2026, 8), label: '8월', amount: 40000, inProgress: true),
      ];

  testWidgets('막대 6칸과 라벨을 그린다', (tester) async {
    await pump(tester,
        bars: monthBars(),
        selected: const PeriodKey(2026, 7),
        onSelect: (_) {});

    for (final label in ['3월', '4월', '5월', '6월', '7월', '8월']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('막대를 누르면 그 기간이 선택된다', (tester) async {
    PeriodKey? picked;
    await pump(tester,
        bars: monthBars(),
        selected: const PeriodKey(2026, 7),
        onSelect: (k) => picked = k);

    await tester.tap(find.text('4월'), warnIfMissed: false);
    await tester.pump();
    // 라벨이 아니라 막대 영역을 눌러야 한다 — 막대는 라벨 위에 있다
    picked = null;
    final chartBox = tester.getRect(find.byType(SettlementChart));
    // 두 번째 칸의 가로 중앙, 막대 영역(위쪽) 안
    final x = chartBox.left + chartBox.width * (1.5 / 6);
    await tester.tapAt(Offset(x, chartBox.top + 40));
    await tester.pump();

    expect(picked, const PeriodKey(2026, 4));
  });

  testWidgets('자료가 없는 기간(amount null)은 눌러도 선택되지 않는다', (tester) async {
    PeriodKey? picked;
    await pump(
      tester,
      bars: const [
        SettlementBar(key: PeriodKey(2026, 7), label: '7월', amount: 100),
        SettlementBar(key: PeriodKey(2026, 8), label: '8월', amount: null),
      ],
      selected: const PeriodKey(2026, 7),
      onSelect: (k) => picked = k,
    );

    final chartBox = tester.getRect(find.byType(SettlementChart));
    await tester.tapAt(
        Offset(chartBox.left + chartBox.width * 0.75, chartBox.top + 40));
    await tester.pump();

    expect(picked, isNull);
  });

  testWidgets('손실 기간은 기준선 아래로 그린다', (tester) async {
    await pump(
      tester,
      bars: const [
        SettlementBar(key: PeriodKey(2026, 6), label: '6월', amount: 100000),
        SettlementBar(key: PeriodKey(2026, 7), label: '7월', amount: -100000),
      ],
      selected: const PeriodKey(2026, 6),
      onSelect: (_) {},
    );

    // 양수 막대의 아래끝이 음수 막대의 위끝보다 위(또는 같은 자리)에 있어야 한다.
    // 위아래 영역 높이는 데이터에 따라 달라지므로 고정값에 기대지 않는다.
    final bodies = find
        .descendant(
            of: find.byType(SettlementChart), matching: find.byType(Container))
        .evaluate()
        .map((e) => e.renderObject as RenderBox)
        .where((r) => r.size.height > 2 && r.size.width > 10)
        .map((r) => (
              top: r.localToGlobal(Offset.zero).dy,
              bottom: r.localToGlobal(Offset.zero).dy + r.size.height,
            ))
        .toList()
      ..sort((a, b) => a.top.compareTo(b.top));

    expect(bodies.length, greaterThanOrEqualTo(2));
    expect(bodies.first.bottom, lessThanOrEqualTo(bodies.last.top + 2));
  });

  testWidgets('진행 중인 기간에는 점 표시가 붙는다', (tester) async {
    await pump(tester,
        bars: monthBars(),
        selected: const PeriodKey(2026, 7),
        onSelect: (_) {});

    // 진행 중 점은 4x4 원
    final dots = find
        .descendant(
            of: find.byType(SettlementChart), matching: find.byType(Container))
        .evaluate()
        .map((e) => (e.renderObject as RenderBox).size)
        .where((s) => s.width == 4 && s.height == 4)
        .toList();

    expect(dots, hasLength(1));
  });

  testWidgets('연도 경계에 연도를 적는다', (tester) async {
    await pump(
      tester,
      showYearBoundary: true,
      bars: const [
        SettlementBar(key: PeriodKey(2025, 3), label: '3분기', amount: 100),
        SettlementBar(key: PeriodKey(2025, 4), label: '4분기', amount: 200),
        SettlementBar(key: PeriodKey(2026, 1), label: '1분기', amount: 300),
      ],
      selected: const PeriodKey(2026, 1),
      onSelect: (_) {},
    );

    // 첫 칸(2025)과 연도가 바뀌는 칸(2026)에만 연도가 붙는다
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('모든 값이 0이어도 예외 없이 그린다 — 0으로 나누기 방지', (tester) async {
    await pump(
      tester,
      bars: const [
        SettlementBar(key: PeriodKey(2026, 6), label: '6월', amount: 0),
        SettlementBar(key: PeriodKey(2026, 7), label: '7월', amount: 0),
      ],
      selected: const PeriodKey(2026, 7),
      onSelect: (_) {},
    );

    expect(tester.takeException(), isNull);
    expect(find.text('7월'), findsOneWidget);
  });

  testWidgets('손실이 이익보다 크면 손실 막대가 더 길다 — 양쪽이 같은 눈금', (tester) async {
    await pump(
      tester,
      bars: const [
        SettlementBar(key: PeriodKey(2026, 6), label: '6월', amount: 2000000),
        SettlementBar(key: PeriodKey(2026, 7), label: '7월', amount: -7500000),
      ],
      selected: const PeriodKey(2026, 7),
      onSelect: (_) {},
    );

    final heights = find
        .descendant(
            of: find.byType(SettlementChart), matching: find.byType(Container))
        .evaluate()
        .map((e) => e.renderObject as RenderBox)
        .where((r) => r.size.height > 2 && r.size.width > 10)
        .map((r) => r.size.height)
        .toList()
      ..sort();

    expect(heights.length, greaterThanOrEqualTo(2));
    // 손실(7.5M)이 이익(2M)의 약 3.75배이므로 막대도 그만큼 길어야 한다.
    // 고정 비율(60:22)을 쓰면 오히려 짧아져 차트가 거짓말을 한다.
    expect(heights.last / heights.first, greaterThan(2.5));
  });
}
