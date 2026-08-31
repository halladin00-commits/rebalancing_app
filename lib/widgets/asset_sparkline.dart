import 'package:flutter/material.dart';
import '../services/asset_history_service.dart';

/// 딥그린 헤더 안에 들어가는 총자산 추이 미니 그래프.
///
/// 눈금도 값도 없다 — 방향만 보여주는 용도다.
/// 점이 [AssetHistoryService.minPointsForChart] 미만이면 호출부에서 아예 그리지 않는다.
class AssetSparkline extends StatelessWidget {
  final List<AssetPoint> points;
  final Color color;
  final double height;

  const AssetSparkline({
    super.key,
    required this.points,
    required this.color,
    this.height = 46,
    this.semanticsLabel,
  });

  /// 스크린 리더에게 읽어줄 문장. 없으면 시작→끝 값으로 만든다.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    // 캔버스에 그린 선은 스크린 리더에게 아무것도 아니다.
    // 이 선이 말하려는 건 "얼마에서 얼마로"다 — 그걸 문장으로 준다.
    final label = semanticsLabel ??
        (points.length < 2
            ? ''
            : '${points.first.totalKrw.round()} → ${points.last.totalKrw.round()}');

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Semantics(
        label: label,
        image: true,
        child: ExcludeSemantics(
          child: CustomPaint(painter: _SparklinePainter(points, color)),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<AssetPoint> points;
  final Color color;

  _SparklinePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((p) => p.totalKrw).toList();
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);

    // 값이 모두 같으면 가운데 수평선으로 그린다 (0으로 나누기 방지)
    if (hi - lo < 1) {
      lo -= 1;
      hi += 1;
    }

    // 선이 위아래 모서리에 닿지 않도록 여백을 둔다
    const padTop = 6.0;
    const padBottom = 4.0;
    final usableH = size.height - padTop - padBottom;

    Offset at(int i) {
      final x = points.length == 1
          ? 0.0
          : size.width * (i / (points.length - 1));
      final t = (values[i] - lo) / (hi - lo); // 0(최저) ~ 1(최고)
      final y = padTop + usableH * (1 - t);
      return Offset(x, y);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      final p = at(i);
      line.lineTo(p.dx, p.dy);
    }

    // 선 아래 그라데이션 채움
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}
