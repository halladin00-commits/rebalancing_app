import 'package:flutter/material.dart';

/// 점선 테두리 상자. Flutter 기본 `Border`는 점선을 지원하지 않는다.
///
/// "포트폴리오 추가"처럼 아직 내용이 없는 자리를 나타낼 때 쓴다.
class DashedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const DashedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.strokeWidth = 1.5,
    this.dashLength = 5,
    this.gapLength = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 둥근 사각형 경로를 따라가며 dash/gap을 번갈아 그린다
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var pos = 0.0;
      while (pos < metric.length) {
        final end = (pos + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(pos, end), paint);
        pos = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
