import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/screens/item_form_screen.dart';
import 'package:rebalancing_app/utils/rebalancer.dart';

/// **검색에 없어 직접 입력한 종목은 시세를 받을 길이 없다.**
///
/// 예전에는 포트의 「시세 자동」이 켜져 있으면(기본값) 종목 입력 화면이
/// 현재가 칸을 숨겼다. 직접 입력한 종목은 현재가가 0으로 저장됐고, 현재가
/// 0인 종목이 하나라도 있으면 편차 계산이 통째로 멈춘다 — 종목 하나를
/// 손으로 넣었다는 이유로 그 포트의 조정 제안이 영영 안 나왔다.
///
/// 이제 현재가 칸은 **시세를 받을 수 없는 종목에만** 나온다. 포트 설정의
/// 시세 스위치는 없앴다.
void main() {
  group('왜 고쳤나', () {
    PortfolioItem listed() => PortfolioItem(
        id: 'a',
        name: 'a',
        ticker: '005930',
        market: 'KR',
        shares: 10,
        currentPrice: 100,
        targetWeight: 50);

    test('현재가 0인 직접 입력 종목 하나가 포트 전체의 편차 계산을 막는다', () {
      final manual = PortfolioItem(
          id: 'm', name: '비상장', shares: 10, currentPrice: 0, targetWeight: 50);
      final pf = Portfolio(id: 'p', name: 'p', items: [listed(), manual]);
      expect(Rebalancer.canComputeDrift(pf), isFalse);
    });

    test('현재가를 넣으면 계산된다', () {
      final manual = PortfolioItem(
          id: 'm', name: '비상장', shares: 10, currentPrice: 80, targetWeight: 50);
      final pf = Portfolio(id: 'p', name: 'p', items: [listed(), manual]);
      expect(Rebalancer.canComputeDrift(pf), isTrue);
    });
  });

  Widget host(Widget child) => MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: child,
      );

  Future<void> open(WidgetTester tester, Widget form) async {
    tester.view.physicalSize = const Size(411, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(form));
    await tester.pumpAndSettle();
  }

  /// 라벨 옆의 입력칸.
  Finder fieldOf(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(TextField));

  testWidgets('검색으로 고른 종목에는 현재가 칸이 없다 — 시세가 채운다', (tester) async {
    await open(
        tester,
        ItemFormScreen(
          preset: PortfolioItem(
              id: 'x',
              name: '삼성전자',
              ticker: '005930',
              market: 'KR',
              currentPrice: 70000),
          onSave: (_) {},
        ));
    expect(find.text('평단가'), findsOneWidget);
    expect(find.text('현재가'), findsNothing);
  });

  testWidgets('직접 입력하는 종목에는 현재가 칸이 있고, 비우면 저장되지 않는다',
      (tester) async {
    PortfolioItem? saved;
    await open(tester, ItemFormScreen(onSave: (i) => saved = i));
    expect(find.text('현재가'), findsOneWidget);

    await tester.enterText(fieldOf('종목명'), '비상장 주식');
    await tester.enterText(fieldOf('보유 수량'), '10');
    await tester.enterText(fieldOf('평단가'), '5000');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(saved, isNull, reason: '현재가 없이 저장되면 조정 제안이 막힌다');
    expect(find.text('0보다 크게 입력해 주세요'), findsOneWidget);

    await tester.enterText(fieldOf('현재가'), '6000');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.currentPrice, 6000);
    expect(saved!.ticker, isEmpty);
  });

  testWidgets('직접 입력한 종목은 고칠 때도 현재가 칸이 나온다', (tester) async {
    await open(
        tester,
        ItemFormScreen(
          item: PortfolioItem(
              id: 'm', name: '비상장', shares: 10, avgPrice: 5000, currentPrice: 0),
          onSave: (_) {},
        ));
    expect(find.text('현재가'), findsOneWidget);
  });

  group('없앤 설정', () {
    test('옛 저장본의 반올림·시세 자동 값은 읽지 않고, 다시 쓰지도 않는다', () {
      final pf = Portfolio.fromJson({
        'id': 'p',
        'name': 'p',
        'priceAuto': false,
        'fractionalEnabled': true,
        'fractionalRounding': 'minDeviation',
        'items': [],
      });
      expect(pf.fractionalEnabled, isTrue);
      final out = pf.toJson();
      expect(out.containsKey('priceAuto'), isFalse);
      expect(out.containsKey('fractionalRounding'), isFalse);
    });

    test('소수점 수량은 늘 예산 안쪽으로 내림한다', () {
      // 300을 1:1:1로 나누면 종목당 100 → 가격 30이면 3.3333…주.
      // 반올림이든 내림이든 3.3333이라, 올림이 생기는 값으로 잰다:
      // 가격 70 → 1.428571… → 내림 1.4285 (반올림이면 1.4286)
      PortfolioItem s(String id) => PortfolioItem(
          id: id,
          name: id,
          ticker: id,
          market: 'US',
          shares: 0,
          currentPrice: 70,
          targetWeight: 100 / 3);
      final pf = Portfolio(
          id: 'p',
          name: 'p',
          currency: 'USD',
          fractionalEnabled: true,
          rebalancingThreshold: 0,
          additionalInvestment: 300,
          items: [s('a'), s('b'), s('c')]);
      final rb = Rebalancer.calculate(pf)!;
      for (final x in rb.results.where((x) => !x.isCash)) {
        expect(x.newShares, closeTo(1.4285, 1e-9));
      }
      expect(rb.cash, greaterThanOrEqualTo(0));
    });
  });
}
