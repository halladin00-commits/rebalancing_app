import 'dart:io';
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
          // 매수·매도 시연이 사용자가 고른 오름·내림색을 따른다.
          ChangeNotifierProvider(create: (_) => PnlColorNotifier()),
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

    // 처음 여는 사람은 이 앱이 뭐 하는 앱인지도 모른다. 첫 문장이
    // **무엇을 하는 앱인지**부터 말해야 한다.
    expect(find.textContaining('포트폴리오를'), findsWidgets);
    expect(find.textContaining('비중대로 관리합니다'), findsOneWidget);
    // 「목표 비중」을 이미 아는 사람에게만 통하는 말로 시작하지 않는다.
    expect(find.textContaining('목표에서'), findsNothing);
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
  testWidgets('좌우로 쓸어서도 넘어간다', (tester) async {
    // 아래에 점을 찍어 두면 쓸어 넘길 수 있다고 읽힌다. 점은 있는데
    // 버튼으로만 넘어가면 손이 한 번 헛돈다.
    await open(tester);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('세 걸음이면 됩니다'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('어떻게 시작할까요'), findsOneWidget);

    // 뒤로도 쓸린다
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('세 걸음이면 됩니다'), findsOneWidget);
  });
  test('첫 실행 안내는 손이 덜 가는 순서가 아니라 쓸모 순서로 놓는다', () {
    // ① 직접 거래 기록 — 결산 탭의 기간별 손익까지 나오는 유일한 길
    // ② 보유 현황만 빠르게 — 자산·리밸런싱은 되지만 결산은 안 나온다
    // ③ 거래내역 파일 올리기 — 가장 빠르지만 PC가 있어야 한다
    //
    // 파일 올리기가 맨 위에 있으면 PC 없는 사람이 첫 줄에서 막힌다.
    final src =
        File('lib/screens/portfolio_list_screen.dart').readAsStringSync();
    final start = src.indexOf('Widget _buildFirstRun');
    final body = src.substring(start, start + 2500);

    final order = ['firstRunRecordTitle', 'firstRunQuickTitle', 'firstRunUploadTitle']
        .map(body.indexOf)
        .toList();
    expect(order.every((i) => i >= 0), isTrue, reason: '세 갈래를 못 찾았다');
    expect(order[0] < order[1], isTrue, reason: '직접 기록이 맨 위여야 한다');
    expect(order[1] < order[2], isTrue, reason: '파일 올리기가 맨 아래여야 한다');
  });
}
