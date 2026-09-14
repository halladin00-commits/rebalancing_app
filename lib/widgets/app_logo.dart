import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 「목표 비중」 마크 + REBALANCING 글자.
///
/// 마크는 앱 아이콘과 **같은 그림**이다 — 세 조각으로 나뉜 고리와 가운데 점.
/// 과녁이자 원형 그래프로 읽힌다.
///
/// 예전에는 파랑·초록·노랑·빨강 4색 도넛이었다. 앱 어디에도 없는 색인 데다
/// 구글 로고와 같은 배열이라, 홈 화면에서 본 것과 앱을 열고 보는 것이
/// 이어지지 않았다.
class AppLogo extends StatelessWidget {
  final double iconSize;

  /// 글자 색. 안 주면 흰색.
  final Color? textColor;

  /// 마크도 글자와 같은 한 가지 색으로 그린다.
  ///
  /// 아주 작을 때(24px 이하) 쓴다. 조각을 나눠 봐야 안 보인다.
  final bool mono;

  /// 크림 바탕에 놓인다.
  ///
  /// 민트(#8FE7B0)를 크림 위에 그대로 쓰면 대비가 **1.39:1**이라 형태가
  /// 안 읽힌다. 색을 뒤집어 딥그린으로 그린다.
  final bool onLight;

  const AppLogo({
    super.key,
    this.iconSize = 26,
    this.textColor,
    this.mono = false,
    this.onLight = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: CustomPaint(
            painter: mono
                ? TargetMarkPainter(accent: fg, light: fg, fill: true)
                : (onLight
                    ? const TargetMarkPainter.onLight(fill: true)
                    : const TargetMarkPainter(fill: true)),
          ),
        ),
        SizedBox(width: iconSize * 0.30),
        Text(
          'REBALANCING',
          style: TextStyle(
            fontSize: iconSize * 0.70,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: iconSize * 0.08,
          ),
        ),
      ],
    );
  }
}

/// 앱 아이콘과 같은 마크.
///
/// 치수는 `tools/make_icons.py`와 **같은 비율**을 쓴다. 한쪽만 고치면
/// 아이콘과 앱 안 로고가 조금씩 달라지는데, 나란히 놓이는 일이 없어
/// 눈치채기 어렵다. `test/app_logo_test.dart`가 두 곳을 맞춰 둔다.
class TargetMarkPainter extends CustomPainter {
  /// 오른쪽 조각의 색.
  final Color accent;

  /// 아래·왼쪽 조각의 색.
  final Color light;

  /// 가운데 점. 안 주면 [accent]를 따른다.
  ///
  /// 크림 바탕에서는 강조 조각이 연한 색이라 점까지 연하면 안 보인다.
  /// 그래서 밝은 바탕 판만 점을 따로 정한다.
  final Color? dotColor;

  /// 마크가 상자를 **꽉 채우게** 한다.
  ///
  /// 아이콘 자산에서는 마크가 타일 안에 여백을 두고 앉는다(바깥 반지름이
  /// 타일의 0.307). 로고 잠금 구성에는 타일이 없으므로 그 여백을 그대로
  /// 두면 마크만 39% 작아지고, 글자와의 간격도 그만큼 벌어진다.
  /// 실제로 그렇게 나가서 「크기와 간격 비율이 부자연스럽다」는 지적을 받았다.
  final bool fill;

  /// 딥그린 바탕용. 민트 조각 + 크림 조각 + 민트 점.
  const TargetMarkPainter({
    this.accent = const Color(0xFF8FE7B0),
    this.light = const Color(0xFFFBF8F1),
    this.dotColor,
    this.fill = false,
  });

  /// 크림 바탕용. 색을 뒤집는다.
  ///
  /// 강조 조각은 앱에 이미 있는 `weightOkFill`(#A9C7BF)을 쓴다 — 새 색을
  /// 들이지 않으려고. 크림 대비는 1.71:1로 약하지만 옆 조각이 딥그린이라
  /// 형태는 그 대비가 잡아 준다.
  const TargetMarkPainter.onLight({this.fill = false})
      : accent = const Color(0xFFA9C7BF),
        light = const Color(0xFF0E4F49),
        dotColor = const Color(0xFF0E4F49);

  // make_icons.py의 RING_OUTER · RING_INNER · DOT · GAP과 같은 값.
  static const ringOuter = 0.307;
  static const ringInner = 0.190;
  static const dot = 0.058;
  static const gap = 0.0355;

  /// 틈이 놓이는 자리. 12시가 0이고 시계 방향.
  static const gaps = [0.0, 120.0, 240.0];

  @override
  void paint(Canvas canvas, Size size) {
    final v = size.width;
    final c = Offset(v / 2, v / 2);
    // 꽉 채울 때는 바깥 반지름이 상자의 절반이 되도록 전체를 키운다.
    // 비율은 그대로라 아이콘과 같은 그림이 나온다.
    final k = fill ? 0.5 / ringOuter : 1.0;
    final outer = ringOuter * k * v;
    final inner = ringInner * k * v;

    // 고리 = 큰 원에서 작은 원을 뺀 것.
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: outer))
      ..addOval(Rect.fromCircle(center: c, radius: inner));

    // 틈은 **폭이 일정한 홈**이다. 부채꼴로 내면 중심으로 갈수록 좁아져
    // 양 변이 벌어진다 — 시안은 평행하다.
    final slots = Path();
    final half = gap * k * v / 2;
    final reach = outer * 1.2;
    for (final deg in gaps) {
      final a = deg * math.pi / 180;
      final ux = math.sin(a), uy = -math.cos(a); // 밖으로
      final vx = math.cos(a), vy = math.sin(a); // 그와 직각
      slots
        ..moveTo(c.dx + vx * half, c.dy + vy * half)
        ..lineTo(c.dx + ux * reach + vx * half, c.dy + uy * reach + vy * half)
        ..lineTo(c.dx + ux * reach - vx * half, c.dy + uy * reach - vy * half)
        ..lineTo(c.dx - vx * half, c.dy - vy * half)
        ..close();
    }

    // 12시부터 시계 방향으로 오른쪽 → 아래 → 왼쪽.
    // 오른쪽 조각만 진한 색이고 나머지 둘은 밝은 색이다.
    final colors = [accent, light, light];
    for (var i = 0; i < 3; i++) {
      final start = gaps[i];
      var end = gaps[(i + 1) % 3];
      if (end <= start) end += 360;

      final wedge = Path()..moveTo(c.dx, c.dy);
      wedge
        ..arcTo(
          Rect.fromCircle(center: c, radius: outer),
          (start - 90) * math.pi / 180,
          (end - start) * math.pi / 180,
          false,
        )
        ..close();

      final seg = Path.combine(
        PathOperation.difference,
        Path.combine(PathOperation.intersect, ring, wedge),
        slots,
      );
      canvas.drawPath(seg, Paint()..color = colors[i]);
    }

    // 홈보다 **나중에** 그린다. 먼저 그리면 홈이 점을 가른다.
    canvas.drawCircle(c, dot * k * v, Paint()..color = dotColor ?? accent);
  }

  @override
  bool shouldRepaint(TargetMarkPainter old) =>
      old.accent != accent ||
      old.light != light ||
      old.dotColor != dotColor ||
      old.fill != fill;
}
