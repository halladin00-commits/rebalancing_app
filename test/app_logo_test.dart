import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/widgets/app_logo.dart';

/// 앱 안 로고 마크가 **앱 아이콘과 같은 그림**인지 확인한다.
///
/// 마크는 두 곳에서 따로 그려진다 — 런처 아이콘은 `tools/make_icons.py`가
/// PNG로 굽고, 앱 안 로고는 [TargetMarkPainter]가 매번 그린다. 한쪽만
/// 고치면 조금씩 달라지는데 **나란히 놓이는 일이 없어 눈치채기 어렵다.**
///
/// 그래서 실제로 그려 보고 픽셀을 센다.
void main() {
  /// 마크를 그려 픽셀을 읽는다.
  Future<(ByteData, int)> paintMark(WidgetTester tester, double size) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0E4F49),
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: size,
              height: size,
              color: const Color(0xFF0E4F49),
              child: const CustomPaint(
                painter: TargetMarkPainter(color: Color(0xFF8FE7B0)),
              ),
            ),
          ),
        ),
      ),
    ));

    late ByteData data;
    late int px;
    await tester.runAsync(() async {
      final board =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await board.toImage(pixelRatio: 1);
      px = image.width;
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return (data, px);
  }

  /// 그 자리가 민트인가 (고리·점이 칠해졌는가).
  bool isMint(ByteData d, int px, double fx, double fy) {
    final x = (fx * px).round().clamp(0, px - 1);
    final y = (fy * px).round().clamp(0, px - 1);
    final i = (y * px + x) * 4;
    final r = d.getUint8(i), g = d.getUint8(i + 1);
    // 민트(143,231,176)에 가깝고 딥그린(14,79,73)과는 멀다.
    return g > 150 && r > 80;
  }

  testWidgets('고리가 12·3·6·9시에서 네 조각으로 갈린다', (tester) async {
    final (d, px) = await paintMark(tester, 200);

    // 고리 한가운데를 도는 반지름. 바깥 0.325 − 두께 0.095/2 = 0.2775
    const rr = 0.2775;

    // 45°·135°·225°·315° — 조각 한가운데는 칠해져 있어야 한다.
    const diag = 0.19622; // rr / √2
    expect(isMint(d, px, 0.5 + diag, 0.5 - diag), isTrue, reason: '1사분 조각');
    expect(isMint(d, px, 0.5 + diag, 0.5 + diag), isTrue, reason: '2사분 조각');
    expect(isMint(d, px, 0.5 - diag, 0.5 + diag), isTrue, reason: '3사분 조각');
    expect(isMint(d, px, 0.5 - diag, 0.5 - diag), isTrue, reason: '4사분 조각');

    // 12·3·6·9시 — 틈이라 비어 있어야 한다.
    // 각도가 어긋나면 여기가 칠해지고 위 네 곳이 빈다.
    expect(isMint(d, px, 0.5, 0.5 - rr), isFalse, reason: '12시 틈');
    expect(isMint(d, px, 0.5 + rr, 0.5), isFalse, reason: '3시 틈');
    expect(isMint(d, px, 0.5, 0.5 + rr), isFalse, reason: '6시 틈');
    expect(isMint(d, px, 0.5 - rr, 0.5), isFalse, reason: '9시 틈');
  });

  testWidgets('가운데 점이 있고, 점과 고리 사이는 비어 있다', (tester) async {
    final (d, px) = await paintMark(tester, 200);

    expect(isMint(d, px, 0.5, 0.5), isTrue, reason: '가운데 점');
    // 점 바깥(0.072)과 고리 안쪽(0.230) 사이
    expect(isMint(d, px, 0.5 + 0.15, 0.5), isFalse, reason: '점과 고리 사이');
    // 고리 바깥
    expect(isMint(d, px, 0.5 + 0.42, 0.5), isFalse, reason: '고리 바깥');
  });

  testWidgets('작아져도 네 조각이 안 붙는다', (tester) async {
    // 하단 탭바·목록에 들어가는 크기. 틈이 각도가 아니라 **너비 비율**로
    // 잡혀 있어야 여기서도 갈라져 보인다.
    final (d, px) = await paintMark(tester, 24);
    expect(isMint(d, px, 0.5, 0.5 - 0.2775), isFalse, reason: '12시 틈');
    expect(isMint(d, px, 0.5, 0.5), isTrue, reason: '가운데 점');
  });

  test('아이콘 생성기와 같은 비율을 쓴다', () {
    // 한쪽만 고치면 런처 아이콘과 앱 안 로고가 달라진다.
    final py = File('tools/make_icons.py').readAsStringSync();
    for (final (name, value) in const [
      ('RING_OUTER', '0.325'),
      ('RING_WIDTH', '0.095'),
      ('DOT', '0.072'),
      ('GAP', '0.042'),
    ]) {
      expect(py.contains('$name = $value'), isTrue,
          reason: 'make_icons.py의 $name 이 바뀌었다 — 로고 위젯도 같이 고쳐야 한다');
    }
  });
}
