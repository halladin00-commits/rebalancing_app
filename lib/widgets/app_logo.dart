import 'package:flutter/material.dart';

/// 「목표 비중」 마크 + REBALANCING 글자.
///
/// 마크는 앱 아이콘과 같은 그림이다 — 네 조각으로 나뉜 고리(포트폴리오)와
/// 가운데 점(목표). 과녁이자 원형 그래프로 읽힌다.
///
/// 예전에는 파랑·초록·노랑·빨강 4색 도넛이었다. 앱 어디에도 없는 색인 데다
/// 구글 로고와 같은 배열이라, 홈 화면에서 본 것과 앱을 열고 보는 것이
/// 이어지지 않았다.
class AppLogo extends StatelessWidget {
  final double iconSize;
  final Color? textColor;

  const AppLogo({super.key, this.iconSize = 26, this.textColor});

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
          child: CustomPaint(painter: TargetMarkPainter(color: fg)),
        ),
        SizedBox(width: iconSize * 0.34),
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
/// 치수는 `tools/make_icons.py`와 같은 비율을 쓴다. 한쪽만 고치면 아이콘과
/// 앱 안 로고가 조금씩 달라지는데, 나란히 놓이는 일이 없어 눈치채기 어렵다.
class TargetMarkPainter extends CustomPainter {
  /// 고리와 가운데 점의 색. 딥그린 헤더 위에서는 흰색, 밝은 배경에서는
  /// 브랜드색을 넣는다.
  final Color color;

  const TargetMarkPainter({required this.color});

  // make_icons.py의 RING_OUTER · RING_WIDTH · DOT · GAP과 같은 값.
  static const _ringOuter = 0.325;
  static const _ringWidth = 0.095;
  static const _dot = 0.072;
  static const _gap = 0.042;

  @override
  void paint(Canvas canvas, Size size) {
    final v = size.width;
    final center = Offset(v / 2, v / 2);
    final outer = _ringOuter * v;
    final stroke = _ringWidth * v;
    final radius = outer - stroke / 2;
    final gap = _gap * v;

    // 십자 틈을 각도로 환산한다. 틈 너비는 어느 크기에서나 같은 비율이라,
    // 반지름이 작아질수록 각도로는 넓어진다 — 그래야 작은 아이콘에서도
    // 네 조각이 붙어 보이지 않는다.
    final half = (gap / 2) / radius;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // 12시·3시·6시·9시에서 갈라 네 조각.
    //
    // 플러터의 각도는 3시가 0이고 시계 방향이 양수다. 그래서 첫 조각은
    // 12시(−π/2)에서 시작해 3시 직전까지 간다.
    const quarter = 1.5707963267948966; // π/2
    for (var i = 0; i < 4; i++) {
      final start = -quarter + half + quarter * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        quarter - half * 2,
        false,
        paint,
      );
    }

    canvas.drawCircle(center, _dot * v, Paint()..color = color);
  }

  @override
  bool shouldRepaint(TargetMarkPainter old) => old.color != color;
}
