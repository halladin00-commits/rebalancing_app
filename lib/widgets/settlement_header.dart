import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/settlement_service.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';

/// 결산 헤더의 「무엇을 얼마나」 부분.
///
/// 예전에는 큰 금액 하나와 퍼센트만 있었다. 그 숫자가 **무엇의 값인지**,
/// **얼마에서 얼마가 된 것인지**가 없어서, 처음 보는 사람은 읽을 수가 없다.
/// 전체 결산 탭과 포트별 결산이 같은 모양이어야 해서 한 곳에 둔다.
class SettlementHeaderBody extends StatelessWidget {
  /// 이 기간이 무엇인지 — `8월`, `36주`, `3분기`, `2026년`.
  final String periodLabel;

  /// 기간 손익 (기준통화).
  final double? absoluteReturn;

  /// 기간 수익률. [rateAvailable]이 거짓이면 낼 수 없는 값이다.
  final double returnRate;
  final bool rateAvailable;

  /// 기간 시작·끝 평가금액. 얼마에서 얼마가 됐는지.
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
        // 무엇의 값인지. 큰 숫자만 있으면 읽는 사람이 짐작해야 한다.
        Text(
          isKo ? '$periodLabel 손익' : '$periodLabel P&L',
          style: TextStyle(
              fontSize: DS.body,
              fontWeight: FontWeight.w600,
              color: context.onBrandSecondary),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            abs == null
                ? '—'
                : '${up ? '+' : '−'}${fmtMoney(abs.abs(), currency)}',
            style: TextStyle(
              fontSize: DS.displayAmount,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              height: 1.08,
              color: abs == null ? context.onBrandSecondary : color,
            ),
          ),
        ),
        if (abs == null)
          ...[if (fallback != null) ...[const SizedBox(height: 6), fallback!]]
        else ...[
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rateAvailable
                    ? '${returnRate >= 0 ? '+' : '−'}${returnRate.abs().toStringAsFixed(2)}%'
                    : '—',
                style: TextStyle(
                    fontSize: DS.sectionTitle,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
              if (netCashFlow.abs() > 1) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isKo
                        ? '넣고 뺀 돈 ${fmtMoney(netCashFlow.abs(), currency)}은 빼고'
                        : 'excludes ${fmtMoney(netCashFlow.abs(), currency)} in/out',
                    style: TextStyle(
                        fontSize: DS.body,
                        fontWeight: FontWeight.w600,
                        color: context.onBrandSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.13)),
          const SizedBox(height: 9),
          _basis(context, isKo),
        ],
      ],
    );
  }

  /// 얼마에서 얼마가 됐는지.
  ///
  /// 기간이 시작될 때 가진 게 없었으면(그 사이에 만든 포트) 기초자산이 0이라
  /// `시작 ₩0`이 된다. 그때 수익률의 기준은 **넣은 돈**이므로 그렇게 적는다 —
  /// 화면과 계산이 같은 것을 가리켜야 한다.
  Widget _basis(BuildContext context, bool isKo) {
    final fromNothing = startValue <= 0 && netCashFlow > 0;
    final fromLabel = fromNothing
        ? (isKo ? '넣은 돈' : 'invested')
        : (isKo ? '시작' : 'start');
    final fromValue = fromNothing ? netCashFlow : startValue;
    final toLabel = inProgress ? (isKo ? '지금' : 'now') : (isKo ? '끝' : 'end');

    final labelStyle = TextStyle(
        fontSize: DS.caption,
        fontWeight: FontWeight.w600,
        color: context.onBrandSecondary);
    const valueStyle = TextStyle(
        fontSize: DS.body, fontWeight: FontWeight.w700, color: Colors.white);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(children: [
        Text(fromLabel, style: labelStyle),
        const SizedBox(width: 5),
        Text(fmtMoney(fromValue, currency), style: valueStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward,
              size: 13, color: context.onBrandSecondary),
        ),
        Text(toLabel, style: labelStyle),
        const SizedBox(width: 5),
        Text(fmtMoney(endValue, currency), style: valueStyle),
      ]),
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

String _monthName(int m) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][(m - 1).clamp(0, 11)];
