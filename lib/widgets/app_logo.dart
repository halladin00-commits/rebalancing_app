import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 앱바 / 스플래시에서 쓰는 미니 도넛 + REBALANCING 로고
class AppLogo extends StatelessWidget {
  final double iconSize;
  const AppLogo({super.key, this.iconSize = 26});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: CustomPaint(painter: _MiniDonutPainter()),
        ),
        SizedBox(width: iconSize * 0.32),
        Text(
          'REBALANCING',
          style: TextStyle(
            fontSize: iconSize * 0.58,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: iconSize * 0.13,
          ),
        ),
      ],
    );
  }
}

class _MiniDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;

    // 파이 슬라이스 (useCenter=true 로 채움, 중앙원으로 구멍 뚫기)
    final slices = [
      [const Color(0xFF3B82F6), -90.0, 126.0],
      [const Color(0xFF22C55E),  36.0, 108.0],
      [const Color(0xFFF59E0B), 144.0,  72.0],
      [const Color(0xFFEF4444), 216.0,  54.0],
    ];

    for (final s in slices) {
      final color  = s[0] as Color;
      final start  = (s[1] as double) * math.pi / 180;
      final sweep  = (s[2] as double) * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep, true,
        Paint()..color = color,
      );
    }

    // 중앙 구멍 (네이비로 채움)
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.54,
      Paint()..color = const Color(0xFF0F172A),
    );
  }

  @override
  bool shouldRepaint(_MiniDonutPainter _) => false;
}
