import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/services/asset_history_service.dart';
import 'package:rebalancing_app/widgets/sparkline_panel.dart';

/// 기간 칩 다섯 대신 버튼 하나를 눌러 넘긴다.
///
/// 한 바퀴 돌아 제자리로 오지 않으면 마지막 기간에서 막힌다 — 1년까지 갔다가
/// 1주로 돌아올 방법이 없어진다.
void main() {
  test('짧은 기간에서 긴 기간 순으로 넘어간다', () {
    expect(SparkPeriod.week.next, SparkPeriod.month);
    expect(SparkPeriod.month.next, SparkPeriod.quarter);
    expect(SparkPeriod.quarter.next, SparkPeriod.half);
    expect(SparkPeriod.half.next, SparkPeriod.year);
  });

  test('마지막에서 처음으로 돌아온다', () {
    expect(SparkPeriod.year.next, SparkPeriod.week);
  });

  test('다섯 번 누르면 제자리 — 빠지는 기간이 없다', () {
    var p = SparkPeriod.week;
    final seen = <SparkPeriod>{};
    for (var i = 0; i < SparkPeriod.values.length; i++) {
      seen.add(p);
      p = p.next;
    }
    expect(p, SparkPeriod.week);
    expect(seen, SparkPeriod.values.toSet());
  });

  test('기간이 길어지는 순서로 정의돼 있다', () {
    for (var i = 1; i < SparkPeriod.values.length; i++) {
      expect(SparkPeriod.values[i].days,
          greaterThan(SparkPeriod.values[i - 1].days));
    }
  });

  testWidgets('단계 표시가 다섯 칸이고, 지금 기간만 밝다', (tester) async {
    // 회전 화살표를 쓰면 바로 옆 새로고침 버튼과 같은 뜻으로 읽힌다.
    // 필요한 건 「몇 단계 중 몇 번째인지」다.
    Future<void> pumpAt(SparkPeriod p) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(
          backgroundColor: const Color(0xFF0E4F49),
          body: SparklinePanel(
            points: const <AssetPoint>[],
            period: p,
            onPeriodChanged: (_) {},
            asOf: '09.04 08:43 기준',
            color: const Color(0xFF8FE7B0),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    for (final p in SparkPeriod.values) {
      await pumpAt(p);
      final bright = <int>[];
      final long = <int>[];
      for (var i = 0; i < SparkPeriod.values.length; i++) {
        final f = find.byKey(ValueKey('sparkLevel$i'));
        expect(f, findsOneWidget, reason: '단계 수만큼 줄이 있어야 한다');
        final c = tester.widget<Container>(f);
        if ((c.decoration as BoxDecoration).color == Colors.white) bright.add(i);
        if (c.constraints?.maxWidth == 11.0) long.add(i);
      }
      expect(bright, [p.index], reason: '밝은 줄은 지금 기간 자리 하나뿐이다');
      // 색을 못 가려도 길이로 읽혀야 한다
      expect(long, [p.index], reason: '긴 줄도 지금 기간 자리 하나뿐이다');
    }
  });
}
