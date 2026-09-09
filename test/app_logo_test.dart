import 'dart:io';
import 'dart:math' as math;
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
/// 실제로 그려 보고 픽셀을 센다. 눈으로 옮겨 그렸다가 조각 수(4등분 vs
/// 3등분)도 비율도 틀린 적이 있다.
void main() {
  const bg = Color(0xFF0E4F49);

  Future<(ByteData, int)> paint(WidgetTester tester, double size) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: bg,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: size,
              height: size,
              color: bg,
              child: const CustomPaint(painter: TargetMarkPainter()),
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

  /// 그 자리가 무슨 색인가 — 'bg' 바탕 · 'accent' 민트 · 'light' 크림.
  String at(ByteData d, int px, double fx, double fy) {
    final x = (fx * px).round().clamp(0, px - 1);
    final y = (fy * px).round().clamp(0, px - 1);
    final i = (y * px + x) * 4;
    final r = d.getUint8(i), g = d.getUint8(i + 1), b = d.getUint8(i + 2);
    if (r > 220 && g > 220 && b > 210) return 'light';
    if (g > 170 && r < 200) return 'accent';
    return 'bg';
  }

  /// 12시를 0으로 하고 시계 방향 각도의 좌표 (반지름은 비율).
  (double, double) polar(double deg, double r) {
    final a = deg * 3.141592653589793 / 180;
    return (0.5 + r * math.sin(a), 0.5 - r * math.cos(a));
  }

  const ringMid = (TargetMarkPainter.ringOuter + TargetMarkPainter.ringInner) / 2;

  testWidgets('고리가 세 조각이고, 오른쪽만 진한 색이다', (tester) async {
    final (d, px) = await paint(tester, 240);

    // 조각 한가운데 — 12시부터 시계 방향으로 오른쪽(60°) · 아래(180°) · 왼쪽(300°)
    for (final (deg, want) in const [
      (60.0, 'accent'),
      (180.0, 'light'),
      (300.0, 'light'),
    ]) {
      final (fx, fy) = polar(deg, ringMid);
      expect(at(d, px, fx, fy), want,
          reason: '$deg° 조각이 $want 이어야 한다');
    }
  });

  testWidgets('틈이 12·4·8시 세 곳이다 (네 곳이 아니다)', (tester) async {
    final (d, px) = await paint(tester, 240);

    for (final deg in TargetMarkPainter.gaps) {
      final (fx, fy) = polar(deg, ringMid);
      expect(at(d, px, fx, fy), 'bg', reason: '$deg° 는 틈이어야 한다');
    }
    // 90°·270° 는 4등분이었을 때의 틈 자리. 지금은 조각이 있어야 한다.
    for (final deg in const [90.0, 270.0]) {
      final (fx, fy) = polar(deg, ringMid);
      expect(at(d, px, fx, fy), isNot('bg'),
          reason: '$deg° 에 틈이 있으면 4등분으로 잘못 그린 것이다');
    }
  });

  testWidgets('틈의 양 변이 평행하다', (tester) async {
    // 부채꼴로 자르면 중심으로 갈수록 좁아진다. 시안은 폭이 일정한 홈이라
    // 안쪽에서 잰 폭과 바깥에서 잰 폭이 같아야 한다.
    final (d, px) = await paint(tester, 480);

    double widthAt(double r) {
      var count = 0;
      for (var t = -12.0; t <= 12.0; t += 0.1) {
        final (fx, fy) = polar(t, r);
        if (at(d, px, fx, fy) == 'bg') count++;
      }
      // 센 각도 → 호 길이 (반지름 비율 기준)
      return count * 0.1 * 3.141592653589793 / 180 * r;
    }

    final nearInner = widthAt(TargetMarkPainter.ringInner + 0.012);
    final nearOuter = widthAt(TargetMarkPainter.ringOuter - 0.012);
    expect(nearInner, greaterThan(0.02));
    expect(nearOuter / nearInner, closeTo(1.0, 0.12),
        reason: '부채꼴로 자르면 이 비가 1.4쯤 된다 — 폭이 일정한 홈이어야 한다');
  });

  testWidgets('가운데 점이 있고 틈에 안 갈린다', (tester) async {
    final (d, px) = await paint(tester, 240);

    expect(at(d, px, 0.5, 0.5), 'accent', reason: '가운데 점');
    // 12시 틈이 점을 지나간다면 점 위쪽이 바탕색이 된다.
    final (fx, fy) = polar(0, TargetMarkPainter.dot * 0.6);
    expect(at(d, px, fx, fy), 'accent', reason: '홈이 점을 가르면 안 된다');
    // 점과 고리 사이는 비어 있다
    final (gx, gy) = polar(60, (TargetMarkPainter.dot + TargetMarkPainter.ringInner) / 2);
    expect(at(d, px, gx, gy), 'bg', reason: '점과 고리 사이');
  });

  test('아이콘 생성기와 같은 비율을 쓴다', () {
    // 한쪽만 고치면 런처 아이콘과 앱 안 로고가 달라진다.
    final py = File('tools/make_icons.py').readAsStringSync();
    for (final (name, value) in const [
      ('RING_OUTER', '0.307'),
      ('RING_INNER', '0.190'),
      ('DOT', '0.058'),
      ('GAP', '0.0355'),
    ]) {
      expect(py.contains('$name = $value'), isTrue,
          reason: 'make_icons.py의 $name 이 바뀌었다 — 로고 위젯도 같이 고쳐야 한다');
    }
    expect(TargetMarkPainter.ringOuter, 0.307);
    expect(TargetMarkPainter.ringInner, 0.190);
    expect(TargetMarkPainter.dot, 0.058);
    expect(TargetMarkPainter.gap, 0.0355);
    // 조각은 셋이고 틈은 120도 간격이다
    expect(py.contains('GAPS = (0.0, 120.0, 240.0)'), isTrue);
    expect(TargetMarkPainter.gaps, [0.0, 120.0, 240.0]);
    expect(py.contains("SEGMENT_ROLES = ('accent', 'light', 'light')"), isTrue);
  });
}
