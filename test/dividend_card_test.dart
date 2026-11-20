import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/services/dividend_service.dart';
import 'package:rebalancing_app/widgets/dividend_card.dart';

/// 결산 화면의 「배당 (추정)」 카드.
void main() {
  Widget host(Widget child, {String lang = 'ko'}) => MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  DividendLine line(String name, String market, double per, double shares,
          double amount, [int day = 29]) =>
      DividendLine(
          itemId: name,
          name: name,
          market: market,
          exDate: DateTime(2026, 10, day),
          perShare: per,
          shares: shares,
          amount: amount);

  testWidgets('배당이 없으면 아무것도 안 그린다', (t) async {
    await t.pumpWidget(host(const DividendCard(
        estimate: DividendEstimate(
            total: 0, lines: [], failed: 0, currency: 'KRW'))));
    expect(find.text('배당 (추정)'), findsNothing);
    await t.pumpWidget(host(const DividendCard(estimate: null)));
    expect(find.text('배당 (추정)'), findsNothing);
  });

  testWidgets('합계 · 한 건씩 · 세전 표시', (t) async {
    await t.pumpWidget(host(DividendCard(
        estimate: DividendEstimate(
            total: 6800 + 3500,
            lines: [
              line('KODEX 200', 'KR', 136, 50, 6800),
              line('SCHD', 'US', 0.25, 10, 3500, 23),
            ],
            failed: 0,
            currency: 'KRW'))));
    expect(find.text('배당 (추정)'), findsOneWidget);
    expect(find.text('세전 · 수익률 미포함'), findsOneWidget);
    expect(find.text('+₩10,300'), findsOneWidget);
    expect(find.text('10.29 · ₩136 × 50주'), findsOneWidget);
    // 미국 1주당은 센트 아래도 보인다
    expect(find.text('10.23 · \$0.25 × 10주'), findsOneWidget);
  });

  testWidgets('다섯 건이 넘으면 접고, 더 보기로 편다', (t) async {
    await t.pumpWidget(host(DividendCard(
        estimate: DividendEstimate(
            total: 6,
            lines: [for (var i = 1; i <= 6; i++) line('E$i', 'KR', 1, 1, 1, i)],
            failed: 0,
            currency: 'KRW'))));
    expect(find.text('E5'), findsNothing);
    await t.tap(find.text('2건 더 보기'));
    await t.pump();
    expect(find.text('E6'), findsOneWidget);
  });

  testWidgets('영어 · 받지 못한 종목 알림 · 물음표 설명', (t) async {
    await t.pumpWidget(host(
        DividendCard(
            estimate: DividendEstimate(
                total: 4.67,
                lines: [line('SCHD', 'US', 0.267, 17.5, 4.67)],
                failed: 1,
                currency: 'USD')),
        lang: 'en'));
    expect(find.text('Dividends (estimate)'), findsOneWidget);
    expect(find.text('+\$4.67'), findsOneWidget);
    expect(find.text('Oct 29 · \$0.267 × 17.5 shares'), findsOneWidget);
    expect(find.text('1 holding left out — no dividend data'), findsOneWidget);
    await t.tap(find.byTooltip('About the dividend estimate'));
    await t.pumpAndSettle();
    expect(find.text('About the dividend estimate'), findsWidgets);
    expect(find.textContaining('Before tax.'), findsOneWidget);
  });

  testWidgets('전체 결산: 포트가 둘 이상이면 포트별 합계', (t) async {
    await t.pumpWidget(host(DividendCard(
        byPortfolio: true,
        estimate: DividendEstimate(
            total: 300,
            lines: [line('A', 'KR', 1, 100, 100), line('B', 'KR', 1, 200, 200)],
            failed: 0,
            currency: 'KRW',
            byPortfolio: const [
              (id: '2', name: 'ISA', amount: 200),
              (id: '1', name: '연금저축', amount: 100),
            ]))));
    expect(find.text('ISA'), findsOneWidget);
    expect(find.text('연금저축'), findsOneWidget);
    expect(find.text('₩200'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });
}
