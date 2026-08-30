import 'package:flutter/material.dart';

import '../main.dart';

/// 비중 막대 한 구간.
class WeightSegment {
  /// 현재 비중 (%)
  final double currentWeight;

  /// 목표 비중 (%)
  final double targetWeight;

  const WeightSegment({
    required this.currentWeight,
    required this.targetWeight,
  });
}

/// 포트폴리오의 현재 비중을 색 구간으로 잇고,
/// **목표 비중이 끝나는 자리마다 세로선**을 그어 어긋난 정도를 한눈에 보여준다.
///
/// **구간 색에는 뜻이 있다.** 목표를 넘은 종목은 경고색, 모자란 종목은
/// 브랜드색, 허용 편차 안이면 회색이다.
///
/// 전에는 팔레트를 순서대로 돌려 썼는데, 어느 색이 어느 종목인지 알 방법이
/// 없었다 — 범례도 없고 눌러도 반응이 없었다. 색은 화면에서 가장 강한
/// 신호다. 뜻 없이 쓰면 사용자는 뜻을 찾느라 시간을 쓰고, 없다는 걸 알고
/// 나면 **다음부터는 다른 색도 안 믿는다.**
class WeightBar extends StatelessWidget {
  final List<WeightSegment> segments;
  final double height;

  /// 허용 편차(%p). 이 안에 들면 회색으로 둔다 — 손댈 일이 없다는 뜻이다.
  final double threshold;

  const WeightBar({
    super.key,
    required this.segments,
    this.height = 14,
    this.threshold = 0,
  });

  /// 이 구간이 목표에서 얼마나 벗어났는지에 따른 색.
  Color _colorFor(BuildContext context, WeightSegment s) {
    final drift = s.currentWeight - s.targetWeight;
    if (threshold > 0 && drift.abs() < threshold) return context.trackBg;
    if (drift > 0) return context.warningText;
    return context.brand;
  }


  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return SizedBox(height: height);

    const trackH = 10.0;
    final totalCurrent =
        segments.fold(0.0, (s, e) => s + e.currentWeight.clamp(0, 100));
    if (totalCurrent <= 0) return SizedBox(height: height);

    // 목표 비중이 끝나는 누적 지점들 (마지막 경계는 100%라 그리지 않는다)
    final markers = <double>[];
    var acc = 0.0;
    for (var i = 0; i < segments.length - 1; i++) {
      acc += segments[i].targetWeight;
      if (acc > 0 && acc < 100) markers.add(acc);
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            children: [
              Positioned(
                top: (height - trackH) / 2,
                left: 0,
                right: 0,
                height: trackH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(trackH / 2),
                  child: Row(
                    // Positioned가 높이를 확정해 주므로 stretch로 채운다.
                    // 이게 없으면 자식 없는 ColoredBox의 세로 크기가 0이 된다.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < segments.length; i++)
                        Expanded(
                          flex: (segments[i].currentWeight.clamp(0, 100) * 1000)
                              .round()
                              .clamp(0, 100000),
                          child: ColoredBox(
                              color: _colorFor(context, segments[i])),
                        ),
                    ],
                  ),
                ),
              ),
              for (final m in markers)
                Positioned(
                  left: (w * m / 100).clamp(0.0, w - 2),
                  top: 0,
                  width: 2,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: context.textPrimary.withValues(alpha: 0.6),
                          blurRadius: 0,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
