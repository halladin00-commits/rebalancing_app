import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/screens/onboarding_screen.dart';
import 'package:rebalancing_app/widgets/weight_bar.dart';

/// 첫 실행 화면.
///
/// 여기서 막히면 사용자는 앱을 지운다. 그런데 온보딩은 **한 번만 보이므로**
/// 개발 중에 다시 보려면 앱 데이터를 지워야 하고, 그래서 화면이 넘치거나
/// 쪽이 안 넘어가도 한참 모른다. 시험이 매번 대신 본다.
void main() {
  // LocaleProvider는 저장된 값이 없으면 **기기 언어**를 따라간다. 시험
  // 환경은 영어라 그냥 두면 영문 화면이 그려진다.
  setUp(() => SharedPreferences.setMockInitialValues({'locale': 'ko'}));

  Future<void> open(WidgetTester tester, {Size size = const Size(360, 640)}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PortfolioProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(onComplete: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('1쪽은 기능 나열이 아니라 앱이 하는 일을 말한다', (tester) async {
    await open(tester);

    // 예전에는 아이콘 셋에 홍보 문구를 얹었다. 지금은 앱이 대신 해 주는
    // 계산을 말하고, 그 자리에서 **실제 비중 막대**를 보여준다.
    expect(find.textContaining('목표에서'), findsOneWidget);
    expect(find.byType(WeightBar), findsOneWidget,
        reason: '앱이 실제로 그리는 막대를 보여줘야 말이 통한다');
    expect(find.textContaining('세로선이 목표 비중'), findsOneWidget);
  });

  testWidgets('세 쪽이 순서대로 넘어간다', (tester) async {
    await open(tester);

    await tester.tap(find.text('어떻게 쓰는지 보기'));
    await tester.pumpAndSettle();
    expect(find.text('세 걸음이면 됩니다'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('어떻게 시작할까요'), findsOneWidget);
  });

  testWidgets('1쪽에서 바로 시작으로 건너뛴다', (tester) async {
    await open(tester);

    // 설명을 안 읽고 싶은 사람을 붙잡아 두면 안 된다.
    await tester.tap(find.text('바로 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('어떻게 시작할까요'), findsOneWidget);
  });

  testWidgets('2쪽이 앱의 말을 가르친다', (tester) async {
    await open(tester);
    await tester.tap(find.text('어떻게 쓰는지 보기'));
    await tester.pumpAndSettle();

    // 리밸런싱 탭에서 막히는 건 기능을 몰라서가 아니라 말을 몰라서다.
    expect(find.textContaining('목표 비중'), findsWidgets);
    expect(find.textContaining('허용 편차'), findsWidgets);
    expect(find.text('허용 ±0.5%p'), findsOneWidget);
    // 사고파는 앱이 아니라는 것도 여기서 밝힌다. 목록 아래라 굴려서 본다.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('주문은 증권사에서'), findsOneWidget);
  });

  testWidgets('템플릿 카드에 이모지가 없고 비중 막대가 있다', (tester) async {
    await open(tester);
    await tester.tap(find.text('바로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('올웨더 포트폴리오'), findsOneWidget);
    // 개편하며 아이콘·이모지를 다 걷어냈다. 여기만 남아 있었다.
    for (final e in const ['🌤️', '💎', '🌍']) {
      expect(find.textContaining(e), findsNothing, reason: '$e 가 남아 있다');
    }
    // 대신 그 템플릿의 목표 비중을 막대로 보여준다.
    expect(find.textContaining('S&P500 30%'), findsOneWidget);
  });

  testWidgets('고른 개수가 시작 버튼에 나온다', (tester) async {
    await open(tester);
    await tester.tap(find.text('바로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('직접 만들기'), findsOneWidget);
    await tester.tap(find.text('올웨더 포트폴리오'));
    await tester.pumpAndSettle();
    expect(find.text('1개 담고 시작하기'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 안 넘친다', (tester) async {
    // 세로 짧은 기기에서 글자가 잘리거나 노란 줄무늬가 뜨면 첫인상이 끝난다.
    await open(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('어떻게 쓰는지 보기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('템플릿 비중 막대가 실제로 칠해진다 (높이 0으로 안 사라진다)',
      (tester) async {
    // `Row`의 기본 crossAxisAlignment는 center라 자식에게 **느슨한 높이**를
    // 준다. 자식 없는 `ColoredBox`는 그럼 높이 0이 되어 통째로 사라지는데,
    // 예외도 경고도 안 난다. 실기기 캡처를 확대해 보고서야 알았다.
    //
    // 이 앱에서 같은 함정을 다섯 번째 밟았다.
    //
    // **크기를 재는 것으로는 못 잡는다.** 바깥 상자(SizedBox)는 늘 높이가
    // 있고 사라지는 건 그 안의 칸이다. 그래서 진짜로 그려 보고 픽셀을 센다.
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 200,
              child: AllocationBar(weights: [30, 40, 30]),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    late int painted, total;
    await tester.runAsync(() async {
      final board =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await board.toImage(pixelRatio: 1);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      total = image.width * image.height;
      painted = 0;
      for (var i = 0; i < total; i++) {
        final r = data.getUint8(i * 4);
        final g = data.getUint8(i * 4 + 1);
        final b = data.getUint8(i * 4 + 2);
        final a = data.getUint8(i * 4 + 3);
        // 흰 바탕도 아니고 투명도 아닌 칸 = 실제로 칠해진 막대
        if (a > 20 && !(r > 245 && g > 245 && b > 245)) painted++;
      }
    });

    expect(total, greaterThan(0));
    expect(painted / total, greaterThan(0.5),
        reason: '막대가 안 칠해졌다 — 칸이 높이 0으로 사라진 것이다');
  });
}
