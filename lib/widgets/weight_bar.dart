import 'package:flutter/material.dart';

import '../theme/design_system.dart';
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
/// 구간 색은 값의 의미가 없는 구분용이므로 무채색 계열이 아니라
/// 브랜드 팔레트를 순환시켜 쓴다. 손익색과 섞이지 않게 별도 색을 쓴다.
class WeightBar extends StatelessWidget {
  final List<WeightSegment> segments;
  final double height;

  const WeightBar({
    super.key,
    required this.segments,
    this.height = 14,
  });


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
                              color: chartPalette[i % chartPalette.length]),
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
