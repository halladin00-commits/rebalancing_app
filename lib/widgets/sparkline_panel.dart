import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/asset_history_service.dart';
import '../theme/design_system.dart';
import 'asset_sparkline.dart';

/// 스파크라인이 보여줄 기간.
///
/// 시안은 12개월 고정이지만, 기록이 하루 한 점이라 12개월만 두면
/// 초반 몇 달은 선이 거의 평평하다. 눌러서 좁혀 볼 수 있게 한다.
enum SparkPeriod {
  week(7),
  month(30),
  quarter(90),
  half(180),
  year(365);

  const SparkPeriod(this.days);
  final int days;
}

/// 딥그린 헤더 안의 자산 추이 패널.
///
/// 자산 탭(총자산)과 포트 상세(포트별)가 같이 쓴다.
///
/// 기록이 모자랄 때 **아무것도 안 보여주다가 어느 날 갑자기 나타나면** 앱이
/// 고장 났다 고쳐진 것처럼 보인다. 그래서 자리는 늘 지키되, 모자란 동안에는
/// 흐리게 깔고 그 위에 언제 채워지는지 적어 둔다.
class SparklinePanel extends StatelessWidget {
  final List<AssetPoint> points;
  final SparkPeriod period;
  final ValueChanged<SparkPeriod> onPeriodChanged;

  /// 우측 아래에 적을 기준 시각 (`08.17 09:41 기준`).
  final String asOf;

  /// 선 색. 오름/내림에 따라 호출부가 정한다.
  final Color color;

  /// 안 켠 날의 자산을 계산해 채우는 중인가.
  ///
  /// 처음 켠 날이나 오래 쉬었다 들어온 날은 종목 수만큼 시세를 받아야 해서
  /// 몇 초 걸린다. 그동안 빈 선을 보여주면 **기록이 없는 것과 구분되지 않는다.**
  final bool building;

  const SparklinePanel({
    super.key,
    required this.points,
    required this.period,
    required this.onPeriodChanged,
    required this.asOf,
    required this.color,
    this.building = false,
  });

  /// 선을 그릴 만큼 점이 있는가.
  bool get _hasEnough => points.length >= AssetHistoryService.minPointsForChart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          // 채우는 중에도 이미 있는 선은 계속 보여준다 — 지웠다 그리면
          // 깜빡이고, 사용자는 뭐가 사라졌다고 읽는다.
          child: _hasEnough
              ? AssetSparkline(points: points, color: color)
              : _buildPlaceholder(context),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _buildPeriodTabs(context)),
          const SizedBox(width: 8),
          Text(asOf,
              style: TextStyle(
                  fontSize: DS.caption,
                  fontWeight: FontWeight.w500,
                  color: context.onBrandSecondary)),
        ]),
      ],
    );
  }

  // ── 기록이 모자랄 때 ──

  Widget _buildPlaceholder(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 예시 선을 깔고 흐리게 — 여기에 무엇이 들어올지 보여준다
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
          child: Opacity(
            opacity: 0.55,
            child: AssetSparkline(points: _sample(), color: color),
          ),
        ),
        Center(
          child: building
              ? _buildBusy(context)
              : Text(
            context.l10n.sparklinePending(AssetHistoryService.minPointsForChart),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: DS.caption,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.9)),
          ),
        ),
      ],
    );
  }

  /// 채우는 중. 왜 비어 있는지 대신 **언제 채워지는지**를 적는다.
  Widget _buildBusy(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white.withValues(alpha: 0.85)),
        ),
        const SizedBox(width: 8),
        Text(
          isKo ? '자산 추이를 계산하는 중' : 'Building asset history',
          style: TextStyle(
              fontSize: DS.caption,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

  /// 흐리게 깔 예시 선. 실제 값이 아니므로 날짜는 아무래도 좋다.
  List<AssetPoint> _sample() {
    const shape = [42.0, 46.0, 40.0, 52.0, 48.0, 60.0, 56.0, 68.0];
    final base = DateTime(2026, 1, 1);
    return [
      for (var i = 0; i < shape.length; i++)
        AssetPoint(base.add(Duration(days: i)), shape[i]),
    ];
  }

  // ── 기간 탭 ──

  Widget _buildPeriodTabs(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      SparkPeriod.week: l10n.spark1w,
      SparkPeriod.month: l10n.spark1m,
      SparkPeriod.quarter: l10n.spark3m,
      SparkPeriod.half: l10n.spark6m,
      SparkPeriod.year: l10n.spark1y,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in SparkPeriod.values)
          GestureDetector(
            onTap: () => onPeriodChanged(p),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // 터치 영역을 벌리되 글자 사이는 좁게 둔다
              padding: const EdgeInsets.fromLTRB(0, 4, 13, 4),
              child: Text(
                labels[p]!,
                style: TextStyle(
                  fontSize: DS.caption,
                  fontWeight: p == period ? FontWeight.w800 : FontWeight.w500,
                  color: p == period ? Colors.white : context.onBrandSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
