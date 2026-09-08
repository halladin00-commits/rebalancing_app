import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/widgets/capture_frame.dart';

/// 저장·공유할 그림이 조용히 망가지는 두 가지를 막는다.
///
/// 둘 다 **앱을 켜서 눈으로 보기 전에는 모른다.** 예외도 안 나고 로그도
/// 안 남는다. 실제로 둘 다 사용자가 받은 그림에서 발견됐다.
///
///   1. 배경을 안 칠하면 투명하게 찍히고, JPEG로 저장되며 **검은 그림**이 된다
///   2. 스크롤 위젯을 쓰면 화면 밖 내용이 **잘려서** 안 들어간다
void main() {
  /// `captureFromWidget`은 **화면 크기와 무관하게** 위젯 트리 크기로 그린다.
  /// 시험에서도 넉넉한 판을 깔아야 실제와 같은 조건이 된다.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ));
  }

  testWidgets('배경을 칠한다 — 안 칠하면 검은 그림이 된다', (tester) async {
    await pump(
      tester,
      const CaptureFrame(title: '위탁계좌', children: [Text('내용')]),
    );

    // 틀의 가장 바깥 Container가 색을 들고 있어야 한다.
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(CaptureFrame),
        matching: find.byType(Container),
      ).first,
    );
    expect(box.color, isNotNull,
        reason: '배경이 없으면 투명하게 찍혀 검은 그림이 저장된다');
    expect(box.color!.a, 1.0, reason: '반투명이면 여전히 배경이 비친다');
  });

  testWidgets('스크롤 위젯을 쓰지 않는다 — 쓰면 화면 밖이 잘린다', (tester) async {
    await pump(
      tester,
      CaptureFrame(
        title: '조정 제안',
        children: [for (var i = 0; i < 30; i++) Text('주문 $i')],
      ),
    );

    // ListView·SingleChildScrollView가 끼면 보이는 만큼만 그려져
    // 목록 아래가 그림에서 사라진다.
    expect(
        find.descendant(
            of: find.byType(CaptureFrame), matching: find.byType(Scrollable)),
        findsNothing,
        reason: '캡처는 화면을 찍는 게 아니라 전부 다시 그려야 한다');
  });

  testWidgets('내용이 길어도 전부 그린다', (tester) async {
    await pump(
      tester,
      CaptureFrame(
        title: '조정 제안',
        children: [for (var i = 0; i < 30; i++) Text('주문 $i')],
      ),
    );

    // 화면 밖으로 넘어가도 위젯 트리에는 다 있어야 한다 —
    // captureFromWidget은 화면 크기가 아니라 트리 크기로 그린다.
    expect(find.text('주문 0'), findsOneWidget);
    expect(find.text('주문 29'), findsOneWidget);
  });

  testWidgets('머리·부제·본문이 다 나온다', (tester) async {
    await pump(
      tester,
      const CaptureFrame(
        title: '위탁계좌',
        subtitle: '9월 손익',
        headerBody: Text('₩1,000'),
        children: [CaptureCard(title: '구성 종목', children: [Text('ETF')])],
      ),
    );

    expect(find.text('위탁계좌'), findsOneWidget);
    expect(find.text('9월 손익'), findsOneWidget);
    expect(find.text('₩1,000'), findsOneWidget);
    expect(find.text('구성 종목'), findsOneWidget);
    expect(find.text('ETF'), findsOneWidget);
  });
}
