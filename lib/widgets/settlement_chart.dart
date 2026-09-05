import 'package:flutter/material.dart';
import '../main.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';

/// 결산 차트의 막대 한 칸.
class SettlementBar {
  final PeriodKey key;
  final String label;

  /// 기간 손익. null이면 계산할 수 없는 기간(자료 없음).
  final double? amount;

  /// 아직 끝나지 않은 기간
  final bool inProgress;

  const SettlementBar({
    required this.key,
    required this.label,
    required this.amount,
    this.inProgress = false,
  });
}

/// 기간 선택 컨트롤을 겸하는 결산 막대 차트.
///
/// 기간 칩이나 주차 드롭다운 대신 **차트 자체가 선택 도구**다.
/// 막대를 누르면 그 기간이 선택되고, 왜 그 기간을 골랐는지가
/// 이웃 기간과 함께 화면에 남는다.
class SettlementChart extends StatelessWidget {
  /// **과거 → 최신** 순. `reverse: true`라 오른쪽 끝(최신)이 먼저 보인다.
  final List<SettlementBar> bars;
  final PeriodKey selected;
  final ValueChanged<PeriodKey> onSelect;

  /// 연도가 바뀌는 자리에 점선과 연도 라벨을 넣는다 (분기·연간용).
  final bool showYearBoundary;

  /// 가로 스크롤 컨트롤러. 멈춘 자리를 화면이 읽어 그 구간만 계산한다.
  final ScrollController? controller;

  /// 손을 떼고 멈췄을 때. 창을 옮기는 대신 여기서 계산을 건다.
  final VoidCallback? onSettled;

  const SettlementChart({
    super.key,
    required this.bars,
    required this.selected,
    required this.onSelect,
    this.showYearBoundary = false,
    this.controller,
    this.onSettled,
  });

  /// 막대 한 칸이 차지하는 폭 (막대 + 사이 간격).
  ///
  /// 예전에는 열두 칸을 화면 폭에 나눠 넣고 **한 칸씩** 창을 옮겼다. 한 번
  /// 밀면 한 달만 움직이니 1년을 거슬러 가려면 열두 번을 밀어야 했다.
  /// 폭을 고정하고 띠를 길게 깔아 **그냥 스크롤**하게 한다.
  static const double barPitch = 39.0;
  static const double barWidth = 32.0;

  static const _baseline = 1.0;

  /// 막대 영역 전체 높이 (기준선 위 + 아래)
  static const _barsH = 82.0;

  /// 한쪽에 값이 없을 때 반대쪽에 내주지 않고 남겨두는 최소 높이
  static const _minSide = 12.0;

  /// 위아래 영역을 데이터에 맞춰 나눈다.
  ///
  /// 시안은 양수 60 : 음수 22로 고정돼 있지만, 그러면 **눈금이 서로 달라져**
  /// 손실이 이익보다 커도 짧게 그려진다. 차트가 거짓말을 하지 않도록
  /// 위아래를 실제 최댓값 비율로 나누고 같은 눈금을 쓴다.
  static ({double posH, double negH, double scale}) _layout(
      double maxPos, double maxNeg) {
    if (maxPos <= 0 && maxNeg <= 0) {
      return (posH: _barsH * 0.7, negH: _barsH * 0.3, scale: 0);
    }
    if (maxNeg <= 0) {
      final posH = _barsH - _minSide;
      return (posH: posH, negH: _minSide, scale: posH / maxPos);
    }
    if (maxPos <= 0) {
      final negH = _barsH - _minSide;
      return (posH: _minSide, negH: negH, scale: negH / maxNeg);
    }
    final posH = (_barsH * maxPos / (maxPos + maxNeg))
        .clamp(_minSide, _barsH - _minSide);
    final negH = _barsH - posH;
    // 양쪽이 같은 눈금을 쓰도록 더 빡빡한 쪽에 맞춘다
    final scale = (posH / maxPos) < (negH / maxNeg)
        ? posH / maxPos
        : negH / maxNeg;
    return (posH: posH, negH: negH, scale: scale);
  }

  @override
  Widget build(BuildContext context) {
    double maxPos = 0, maxNeg = 0;
    for (final b in bars) {
      final v = b.amount ?? 0;
      if (v > maxPos) maxPos = v;
      if (-v > maxNeg) maxNeg = -v;
    }
    final lay = _layout(maxPos, maxNeg);

    // 오른쪽 끝(최신)에서 시작해 왼쪽으로 밀면 과거로 간다.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification) onSettled?.call();
        return false;
      },
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        child: Column(
          // 가로 스크롤 안이라 폭이 무한이다 — stretch를 쓰면 레이아웃이 터진다.
          // 칸마다 폭이 정해져 있으므로 늘릴 것도 없다.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _barsH + _baseline,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < bars.length; i++)
                    SizedBox(
                      width: barPitch,
                      child: Center(
                        child: SizedBox(
                          width: barWidth,
                          child: _bar(context, bars[i], lay),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                for (var i = 0; i < bars.length; i++)
                  SizedBox(
                    width: barPitch,
                    child: _label(context, bars[i], i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, SettlementBar b,
      ({double posH, double negH, double scale}) lay) {
    final amount = b.amount;
    final isSelected = b.key == selected;

    final isNegative = (amount ?? 0) < 0;
    final available = isNegative ? lay.negH : lay.posH;
    // 최소 3px — 값이 아주 작아도 막대가 있다는 건 보여야 한다
    final h = amount == null
        ? 0.0
        : (amount.abs() * lay.scale).clamp(3.0, available);

    Color fill;
    if (isSelected) {
      fill = context.barSelected;
    } else if (isNegative) {
      fill = context.barNegative;
    } else {
      fill = context.barSettled;
    }

    return GestureDetector(
      onTap: amount == null ? null : () => onSelect(b.key),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          // 양수 영역
          SizedBox(
            height: lay.posH,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: isNegative || amount == null
                  ? const SizedBox.shrink()
                  : _barBody(context, h, fill, b.inProgress, positive: true),
            ),
          ),
          // 기준선
          Container(
            height: _baseline,
            color: isSelected ? context.textPrimary : context.chartBaseline,
          ),
          // 음수 영역
          SizedBox(
            height: lay.negH,
            child: Align(
              alignment: Alignment.topCenter,
              child: isNegative
                  ? _barBody(context, h, fill, b.inProgress, positive: false)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barBody(BuildContext context, double h, Color fill, bool inProgress,
      {required bool positive}) {
    final radius = positive
        ? const BorderRadius.vertical(top: Radius.circular(5))
        : const BorderRadius.vertical(bottom: Radius.circular(5));

    // 진행 중인 기간은 확정 손익과 섞이지 않게 점선 테두리 + 빈 속으로 둔다
    if (inProgress) {
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: radius,
          border: Border.all(color: context.barInProgress, width: 1.5),
        ),
      );
    }

    return Container(
      height: h,
      decoration: BoxDecoration(color: fill, borderRadius: radius),
    );
  }

  Widget _label(BuildContext context, SettlementBar b, int index) {
    final isSelected = b.key == selected;
    // 분기·연간 차트는 연도가 바뀌는 첫 칸에 연도를 적어
    // 작년 3분기와 올해 3분기가 섞이지 않게 한다
    final showYear = showYearBoundary &&
        (index == 0 || bars[index - 1].key.year != b.key.year);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                b.label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSelected ? 11 : DS.caption,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? context.textPrimary
                      : (b.amount == null
                          ? context.textDisabled
                          : context.textSecondary),
                ),
              ),
            ),
            if (b.inProgress) ...[
              const SizedBox(width: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: context.progressAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        if (showYear)
          // 월간은 칸이 열두 개라 한 칸이 좁다. 그냥 두면 `2025`가
          // `202` / `5`로 쪼개진다 — 줄을 늘리는 대신 글자를 줄인다.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${b.key.year}',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.textDisabled),
            ),
          ),
      ],
    );
  }
}
