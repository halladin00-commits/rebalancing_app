import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/services/asset_history_service.dart';
import 'package:rebalancing_app/widgets/sparkline_panel.dart';

/// 캡처에 들어가는 추이선은 **기간과 기준 시각을 달고 나간다.**
///
/// 그림은 남한테 보여주는 것이다. 선만 있고 며칠치인지 없으면 일주일인지
/// 1년인지 모르고, 언제 시세인지 없으면 받는 쪽이 낡은 값을 최신으로 읽는다.
/// 받는 쪽은 새로고침을 눌러 볼 수도 없다.
void main() {
  List<AssetPoint> points() {
    final base = DateTime(2026, 8, 1);
    return [
      for (var i = 0; i < 10; i++)
        AssetPoint(base.add(Duration(days: i)), 100.0 + i),
    ];
  }

  Future<void> pump(WidgetTester tester, {required bool forCapture}) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SparklinePanel(
          forCapture: forCapture,
          points: points(),
          period: SparkPeriod.month,
          onPeriodChanged: forCapture ? null : (_) {},
          asOf: '09.08 07:37 기준',
          color: const Color(0xFF4CAF50),
        ),
      ),
    ));
  }

  testWidgets('캡처에도 기간과 기준 시각이 남는다', (tester) async {
    await pump(tester, forCapture: true);

    expect(find.text('1개월'), findsOneWidget,
        reason: '며칠치 선인지 없으면 선 모양만 남고 뜻이 없다');
    expect(find.text('09.08 07:37 기준'), findsOneWidget,
        reason: '언제 시세인지 없으면 받는 쪽이 낡은 값을 최신으로 읽는다');
  });

  testWidgets('캡처에서는 누를 수 있다는 표시를 뺀다', (tester) async {
    await pump(tester, forCapture: true);

    // 기간 칩의 단계 막대는 「눌러서 다음으로」라는 뜻이다.
    // 그림에는 누를 데가 없다 — 목록의 `>`를 그림에서 빼는 것과 같다.
    expect(find.byKey(const ValueKey('sparkLevel0')), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('화면에서는 눌러서 기간을 바꿀 수 있다', (tester) async {
    await pump(tester, forCapture: false);

    expect(find.text('1개월'), findsOneWidget);
    expect(find.byKey(const ValueKey('sparkLevel0')), findsOneWidget);
  });

  test('캡처가 추이선을 맨몸으로 그리지 않는다', () {
    // `AssetSparkline`을 직접 쓰면 선만 나오고 기간·기준 줄이 빠진다.
    // 실제로 그렇게 나가서 지적을 받았다.
    for (final path in const [
      'lib/screens/portfolio_list_screen.dart',
      'lib/screens/portfolio_detail_screen.dart',
    ]) {
      final s = File(path).readAsStringSync();
      expect(s.contains('AssetSparkline('), isFalse,
          reason: '$path 가 추이선을 맨몸으로 그린다 — SparklinePanel을 쓴다');
    }
  });
}
