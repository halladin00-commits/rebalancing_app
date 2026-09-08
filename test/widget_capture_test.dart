import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 캡처용 판이 **내용 길이만큼** 잡히는지 확인한다.
///
/// 여기서 두 가지가 조용히 망가진 적이 있다.
///
///  1. **잘림.** 예전에는 `captureFromWidget`에 높이를 어림해서 넘겼다.
///     종목 세 개짜리 포트에 `120 + 3 * 90 = 390`을 넘겼는데 실제로는 더
///     길어서, 저장된 그림이 첫 종목 중간에서 끊겼다. 예외가 안 난다.
///
///  2. **무한 크기.** 세로를 열려고 `OverflowBox(maxHeight: double.infinity)`
///     를 씌웠는데, `Positioned(left:, top:)` 아래는 제약이 없으므로
///     "가능한 한 크게"가 **무한**이 됐다. 디버그 빌드는 assert로 걸리지만
///     릴리즈 빌드는 조용히 잘못된 변환 행렬을 만들고, 그 판을 그리려다
///     **앱이 멈춘다.** 실기기에서 ANR로 확인했다.
///
/// 그림을 실제로 굽지 않고 **판 크기만** 잰다. 크기가 맞으면 잘리지 않고,
/// 유한하면 멈추지 않는다 — 두 가지를 한 번에 가른다.
void main() {
  /// `captureWidget`이 오버레이에 꽂는 것과 **같은 구조**를 세운다.
  /// 이 구조가 바뀌면 여기도 같이 바꿔야 한다.
  Future<Size> layoutSize(WidgetTester tester, Widget child,
      {double width = 380}) async {
    // 화면 판은 일부러 작게 잡는다 — 내용이 판보다 길 때가 요점이다.
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        Positioned(
          left: -10000,
          top: 0,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: width,
              child: RepaintBoundary(key: key, child: child),
            ),
          ),
        ),
      ]),
    ));

    final box = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return box.size;
  }

  testWidgets('화면(600)보다 긴 내용도 판이 통째로 잡힌다', (tester) async {
    // 줄 하나가 100 → 20줄이면 2000. 화면 판(600)의 세 배가 넘는다.
    final size = await layoutSize(
      tester,
      Container(
        width: 380,
        color: const Color(0xFFFFFBF5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 20; i++) const SizedBox(height: 100),
          ],
        ),
      ),
    );

    expect(size.width, 380);
    expect(size.height, 2000,
        reason: '화면 높이(600)에서 잘렸다 — 목록 아래가 그림에서 사라진다');
  });

  testWidgets('판 크기가 유한하다 — 무한이면 앱이 멈춘다', (tester) async {
    final size = await layoutSize(
      tester,
      Container(
        width: 380,
        color: const Color(0xFFFFFBF5),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [SizedBox(height: 200)],
        ),
      ),
    );

    expect(size.height.isFinite, isTrue,
        reason: '판이 무한이면 그리다가 앱이 멈춘다 (ANR)');
    expect(size.height, 200);
  });

  test('captureWidget이 OverflowBox로 세로를 열지 않는다', () {
    // 위 두 시험은 구조를 베껴 세운 것이라, 정작 진짜 코드가 바뀌면 못 잡는다.
    // 문제가 됐던 위젯이 다시 들어오지 않는지 소스에서 확인한다.
    final source = File('lib/utils/widget_capture.dart').readAsStringSync();
    // 주석에서는 「쓰면 안 된다」고 설명하므로, 코드 줄만 본다.
    final code = source
        .split(RegExp(r'\r?\n'))
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains('OverflowBox'), isFalse,
        reason: 'OverflowBox로 세로를 열면 판이 무한이 되어 앱이 멈춘다');
    expect(code.contains('SizedBox('), isTrue,
        reason: '가로는 SizedBox로 못박아야 한다');
  });
}
