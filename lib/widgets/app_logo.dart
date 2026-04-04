import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 미니 도넛 (슬림 링) + REBALANCING 텍스트 로고
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
          child: CustomPaint(painter: _SlimRingPainter()),
        ),
        SizedBox(width: iconSize * 0.30),
        Text(
          'REBALANCING',
          style: TextStyle(
            fontSize: iconSize * 0.70,   // 이전 0.58 → 0.70 (더 크게)
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: iconSize * 0.08, // 이전 0.13 → 0.08 (자간 줄임)
          ),
        ),
      ],
    );
  }
}

/// 슬림 4색 링 (% 없음, stroke 방식 → 텍스트와 균형 맞음)
class _SlimRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 링의 중심 반지름 / 두께
    final r  = size.width * 0.40;
    final sw = size.width * 0.20;  // 슬림 두께

    final slices = [
      [const Color(0xFF3B82F6), -90.0, 126.0],  // 파랑 35%
      [const Color(0xFF22C55E),  36.0, 108.0],  // 초록 30%
      [const Color(0xFFF59E0B), 144.0,  72.0],  // 노랑 20%
      [const Color(0xFFEF4444), 216.0,  54.0],  // 빨강 15%
    ];

    for (final s in slices) {
      final color = s[0] as Color;
      final start = (s[1] as double) * math.pi / 180;
      final sweep = (s[2] as double) * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(_SlimRingPainter _) => false;
}
