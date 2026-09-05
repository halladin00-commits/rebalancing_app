import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';

/// 결산 헤더의 「어느 기간에 얼마」 부분.
///
/// 큰 금액 하나와 퍼센트만 있으면, 그 숫자가 **무엇의 값인지** 알 수 없다.
/// 그렇다고 줄을 계속 아래로 쌓으면 헤더만 길어진다. 세 층으로 나눈다.
///
///   1. 어느 기간인지          `9월 손익 · 9.01 – 9.30`    (+ 진행 중/마감)
///   2. 얼마인지               `−₩690,530` ······ `−0.18%`  좌우로
///   3. 무엇에서 무엇이 됐는지  `시작` / `지금` 타일 두 개
///
/// 자산 탭의 `평가손익 · 전일대비` 타일과 같은 모양이라, 처음 보는 화면이
/// 아니게 된다.
class SettlementHeaderBody extends StatelessWidget {
  /// 이 기간이 무엇인지 — `8월`, `36주`, `3분기`, `2026년`.
  final String periodLabel;

  /// 기간의 실제 날짜 — `9.01 – 9.30`.
  final String rangeLabel;

  /// 기간 손익 (기준통화).
  final double? absoluteReturn;

  /// 기간 수익률. [rateAvailable]이 거짓이면 낼 수 없는 값이다.
  final double returnRate;
  final bool rateAvailable;

  /// 기간 시작·끝 평가금액.
  final double startValue;
  final double endValue;

  /// 기간 중 넣고 뺀 돈. 수익률에서 빼는 값이라 있으면 밝힌다.
  final double netCashFlow;

  /// 아직 다 못 받은 값인가. 확정된 것처럼 보이면 안 된다.
  final bool partial;

  /// 진행 중인 기간인가. 끝값의 이름이 달라진다 (`지금` vs `끝`).
  final bool inProgress;

  final String currency;

  /// 손익이 없을 때(계산 불가) 대신 그릴 것.
  final Widget? fallback;

  const SettlementHeaderBody({
    super.key,
    required this.periodLabel,
    required this.rangeLabel,
    required this.absoluteReturn,
    required this.returnRate,
    required this.rateAvailable,
    required this.startValue,
    required this.endValue,
    required this.netCashFlow,
    required this.partial,
    required this.inProgress,
    required this.currency,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';
    final pnl = context.watch<PnlColorNotifier>();
    final abs = absoluteReturn;
    final up = (abs ?? 0) >= 0;
    final color = (up ? pnl.onBrandPositive : pnl.onBrandNegative)
        .withValues(alpha: partial ? 0.45 : 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _periodLine(context, isKo),
        const SizedBox(height: 4),
        if (abs == null) ...[
          Text('—',
              style: TextStyle(
                  fontSize: DS.displayAmount,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.08,
                  color: context.onBrandSecondary)),
          if (fallback != null) ...[const SizedBox(height: 6), fallback!],
        ] else ...[
          // 금액과 퍼센트를 좌우로 — 세로로 쌓으면 한 줄이 그냥 비어 있다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${up ? '+' : '−'}${fmtMoney(abs.abs(), currency)}',
                    style: TextStyle(
                      fontSize: DS.displayAmount,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1.08,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 퍼센트에 이름이 없으면 무엇의 비율인지 알 수 없다 —
              // 비중일 수도, 기여도일 수도 있는 화면이다.
              Text(isKo ? '수익률 ' : 'return ',
                  style: TextStyle(
                      fontSize: DS.caption,
                      fontWeight: FontWeight.w600,
                      color: context.onBrandSecondary)),
              Text(
                rateAvailable
                    ? '${returnRate >= 0 ? '+' : '−'}${returnRate.abs().toStringAsFixed(2)}%'
                    : '—',
                style: TextStyle(
                    fontSize: DS.sectionTitle,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _basisTiles(context, isKo),
          if (netCashFlow.abs() > 1) ...[
            const SizedBox(height: 7),
            Text(
              isKo
                  ? '넣고 뺀 돈 ${fmtMoney(netCashFlow.abs(), currency)}은 수익률에서 뺐습니다'
                  : 'Excludes ${fmtMoney(netCashFlow.abs(), currency)} moved in or out',
              style: TextStyle(
                  fontSize: DS.caption,
                  fontWeight: FontWeight.w600,
                  color: context.onBrandSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ],
    );
  }

  /// `9월 손익 · 9.01 – 9.30` + 진행 중/마감.
  ///
  /// 어느 기간을 보고 있는지가 헤더에 없으면, 막대를 눌러 옮겨 놓고도
  /// 지금 무엇을 보는 중인지 매번 차트에서 다시 찾아야 한다.
  Widget _periodLine(BuildContext context, bool isKo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            isKo ? '$periodLabel 손익 · $rangeLabel' : '$periodLabel · $rangeLabel',
            style: TextStyle(
                fontSize: DS.body,
                fontWeight: FontWeight.w600,
                color: context.onBrandSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(DS.chipRadius),
          ),
          child: Text(
            inProgress
                ? (isKo ? '진행 중' : 'in progress')
                : (isKo ? '마감' : 'closed'),
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// 얼마에서 얼마가 됐는지 — 자산 탭의 손익 타일과 같은 모양.
  ///
  /// 기간이 시작될 때 가진 게 없었으면(그 사이에 만든 포트) 기초자산이 0이라
  /// `시작 ₩0`이 된다. 그때 수익률의 기준은 **넣은 돈**이므로 그렇게 적는다 —
  /// 화면과 계산이 같은 것을 가리켜야 한다.
  Widget _basisTiles(BuildContext context, bool isKo) {
    final fromNothing = startValue <= 0 && netCashFlow > 0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `시작`·`끝`만으로는 **무엇의** 시작인지 안 보인다. 이 앱은 이미
          // `평가금액`이라는 말을 쓰고 있으니(포트 상세 헤더) 그걸 붙인다.
          _tile(
            context,
            fromNothing
                ? (isKo ? '넣은 돈' : 'invested')
                : (isKo ? '시작 평가금액' : 'start value'),
            fromNothing ? netCashFlow : startValue,
          ),
          const SizedBox(width: 9),
          _tile(
            context,
            inProgress
                ? (isKo ? '지금 평가금액' : 'value now')
                : (isKo ? '마감 평가금액' : 'closing value'),
            endValue,
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String label, double value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: DS.caption,
                    fontWeight: FontWeight.w600,
                    color: context.onBrandSecondary)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                fmtMoney(value, currency),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 기간 하나를 사람이 부르는 이름으로 — `8월`, `36주`, `3분기`, `2026년`.
String settlementPeriodLabel(
    BuildContext context, SettlementPeriod period, PeriodKey key) {
  final isKo = Localizations.localeOf(context).languageCode == 'ko';
  switch (period) {
    case SettlementPeriod.weekly:
      return isKo ? '${key.sub}주' : 'week ${key.sub}';
    case SettlementPeriod.monthly:
      return isKo ? '${key.sub}월' : _monthName(key.sub);
    case SettlementPeriod.quarterly:
      return isKo ? '${key.sub}분기' : 'Q${key.sub}';
    case SettlementPeriod.yearly:
      return isKo ? '${key.year}년' : '${key.year}';
  }
}

/// `9.01 – 9.30`. 해가 바뀌는 기간이면 연도를 붙인다.
String settlementRangeLabel(DateTime a, DateTime b) {
  String md(DateTime d) => '${d.month}.${d.day.toString().padLeft(2, '0')}';
  return a.year == b.year
      ? '${md(a)} – ${md(b)}'
      : '${a.year}.${md(a)} – ${b.year}.${md(b)}';
}

String _monthName(int m) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][(m - 1).clamp(0, 11)];
