import 'package:flutter/material.dart';

import 'settlement_header.dart';

import '../main.dart';
import '../utils/money_format.dart';
import '../theme/design_system.dart';
import 'settlement_chart.dart';

import '../services/settlement_service.dart';
import 'app_logo.dart';

/// 기여 한 줄. 포트별이든 종목별이든 같은 모양으로 그린다.
class CaptureRow {
  final String name;
  final double absoluteReturn;
  final double returnRate;
  final bool rateAvailable;
  final double startValue;
  final double endValue;

  const CaptureRow({
    required this.name,
    required this.absoluteReturn,
    required this.returnRate,
    required this.rateAvailable,
    required this.startValue,
    required this.endValue,
  });
}

/// 저장·공유할 결산 이미지.
///
/// 화면과 **같은 것을 보여준다.** 예전에는 손익 하나와 종목 이름·금액만 담아,
/// 공유한 그림이 앱에서 보던 화면과 아예 달랐다. 수익률도 없고 얼마에서
/// 얼마가 됐는지도 없어 받은 사람이 크기를 가늠할 수 없었다.
///
/// 광고와 탭바만 뺀다 — 그건 화면의 것이지 결산의 것이 아니다.
class SettlementCaptureCard extends StatelessWidget {
  /// `📈 위탁계좌` 또는 `전체 결산`.
  final String title;

  /// `9월` — 화면 머리글이 「$periodLabel 손익 · $rangeLabel」로 조립한다.
  final String periodLabel;

  /// `9.01 – 9.30`.
  final String rangeLabel;

  final double? absoluteReturn;
  final double returnRate;
  final bool rateAvailable;
  final double startValue;
  final double endValue;
  final double netCashFlow;
  final bool inProgress;
  final String currency;

  /// 기여 목록 제목 — `포트별 기여` / `종목별 기여`.
  final String rowsTitle;
  final List<CaptureRow> rows;

  /// 화면에 있는 막대그래프. 없으면 그리지 않는다.
  ///
  /// 화면의 절반을 차지하는 요소라 빠지면 다른 그림이 된다 —
  /// 「이번 달 얼마」만 남고 「지난 달들과 견주면 어떤가」가 사라진다.
  final List<SettlementBar> bars;
  final PeriodKey? selectedBar;
  final bool showYearBoundary;

  /// 차트 카드 위에 적는 기간 (`2026.09.01 – 09.30`).
  final String chartRangeLabel;

  // ── 아래 셋은 **반드시 밖에서 받는다** ──
  //
  // 이 카드는 `captureFromWidget`이 만드는 **딴 트리**에서 그려진다. 거기에는
  // Provider도 Localizations도 조상으로 없어서, 안에서 찾으면 빌드가 터지고
  // 릴리즈 빌드에서는 그냥 **회색 사각형**이 저장된다(실제로 그렇게 나왔다).
  final bool isKo;

  /// 기여 목록(**밝은 카드 위**)에 쓰는 손익색.
  final Color positiveColor;
  final Color negativeColor;

  /// 머리글(**딥그린 위**)에 쓰는 손익색 묶음.
  ///
  /// 위 둘과 다른 색이다 — 밝은 바탕용 진한 색을 딥그린에 쓰면 대비가
  /// 무너진다. 실제로 그렇게 나가 있었다.
  final PnlColorNotifier pnlColors;

  const SettlementCaptureCard({
    super.key,
    required this.title,
    required this.periodLabel,
    required this.rangeLabel,
    required this.absoluteReturn,
    required this.returnRate,
    required this.rateAvailable,
    required this.startValue,
    required this.endValue,
    required this.netCashFlow,
    required this.inProgress,
    required this.currency,
    required this.rowsTitle,
    this.bars = const [],
    this.selectedBar,
    this.showYearBoundary = false,
    this.chartRangeLabel = '',
    required this.rows,
    required this.isKo,
    required this.positiveColor,
    required this.negativeColor,
    required this.pnlColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      color: context.scaffoldBg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── 딥그린 헤더 (화면과 같은 블록) ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appBarBg,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(DS.headerRadius)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              const AppLogo(iconSize: 18, textColor: Colors.white),
            ]),
            const SizedBox(height: 14),
            // **화면과 같은 위젯을 쓴다.**
            //
            // 예전에는 여기에 같은 머리글을 손으로 옮겨 적었다. 그 사이
            // 조용히 갈라져서, 캡처만 **밝은 바탕용 손익색**을 딥그린 위에
            // 쓰고(대비가 무너진다) 금액 크기·자간·「수익률」 라벨 색까지
            // 달라졌다. 나란히 놓고 볼 일이 없어 사용자가 지적할 때까지
            // 몰랐다 — 이 앱에서 네 번째다.
            //
            // 색은 넘겨받는다. 캡처는 Provider가 없는 딴 트리에서 그려진다.
            SettlementHeaderBody(
              periodLabel: periodLabel,
              rangeLabel: rangeLabel,
              absoluteReturn: absoluteReturn,
              returnRate: returnRate,
              rateAvailable: rateAvailable,
              startValue: startValue,
              endValue: endValue,
              netCashFlow: netCashFlow,
              partial: false,
              inProgress: inProgress,
              currency: currency,
              pnlColors: pnlColors,
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── 막대그래프 (화면의 카드와 같은 모양) ──
            if (bars.isNotEmpty && selectedBar != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(DS.cardRadius),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chartRangeLabel,
                          style: TextStyle(
                              fontSize: DS.sectionTitle,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: context.textPrimary)),
                      const SizedBox(height: 10),
                      SettlementChart(
                        bars: bars,
                        selected: selectedBar!,
                        onSelect: (_) {},
                        showYearBoundary: showYearBoundary,
                      ),
                    ]),
              ),
              const SizedBox(height: 14),
            ],

            // ── 기여 ──
            if (rows.isNotEmpty) ...[
              Text(rowsTitle,
                  style: TextStyle(
                      fontSize: DS.sectionTitle,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: context.textPrimary)),
              const SizedBox(height: 9),
              Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(DS.cardRadius),
                  border: Border.all(color: context.cardBorder),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: DS.cardPaddingH),
                child: Column(children: [
                  for (var i = 0; i < rows.length; i++)
                    _row(context, rows[i], isLast: i == rows.length - 1),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, CaptureRow r, {required bool isLast}) {
    final up = r.absoluteReturn >= 0;
    final color = up ? positiveColor : negativeColor;
    String money(double v) => fmtMoney(v, currency);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: context.dividerColor))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r.name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('${up ? '+' : '−'}${money(r.absoluteReturn.abs())}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 8),
          Text(
              r.rateAvailable
                  ? '${r.returnRate >= 0 ? '+' : '−'}'
                      '${r.returnRate.abs().toStringAsFixed(2)}%'
                  : '—',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 3),
        Text('${money(r.startValue)}  →  ${money(r.endValue)}',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.textSecondary)),
      ]),
    );
  }
}
