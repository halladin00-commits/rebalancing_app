import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';

/// 기여 한 줄 — **화면과 캡처가 같이 쓴다.**
///
/// 왜 위젯으로 뽑았나
///   같은 줄을 세 곳이 따로 그리고 있었다. 결산 두 화면과 캡처 판이다.
///   캡처 쪽은 손으로 옮겨 적은 **줄어든 판**이라, 기여도 막대와
///   「기여 86% (+3.48%p)」가 통째로 빠져 있었다. 글자 크기와 색도
///   조금씩 달랐다(14 vs DS.rowName, textSecondary vs textTertiary).
///
///   눈으로만 보이는 차이라 예외도 로그도 안 남는다. 앱에서 그림을 꺼내
///   나란히 놓고 봐야 안다. 실제로 일곱 번 어긋났고 매번 사용자가 먼저
///   찾았다. 같은 것을 두 번 그리는 한 또 어긋난다.
///
/// 캡처 나무에는 **Provider도 Localizations도 없다.** 그래서 색과 말은
/// 밖에서 받는다 — 여기서 `context.watch`나 `l10n`을 부르면 캡처가 죽는다.
class ContributionRow extends StatelessWidget {
  final String name;

  /// 기간 손익 (통화 기준 금액).
  final double absoluteReturn;

  /// 기간 수익률 (%).
  final double returnRate;

  /// 수익률을 낼 수 없으면 `—`로 적는다. 0%와 「모른다」는 다르다.
  final bool rateAvailable;

  final double startValue;
  final double endValue;

  /// 이 줄이 기간 손익 전체에서 차지하는 몫 (0~1). **막대 길이**다.
  final double share;

  /// 포트 수익률에 보탠 값 (%p).
  final double contribution;

  final String currency;
  final bool isKo;
  final Color positiveColor;
  final Color negativeColor;

  /// 마지막 줄에는 아래 선을 긋지 않는다.
  final bool isLast;

  /// 누르면 들어가는 줄에만 준다. **캡처에서는 null이다** —
  /// 그림에서는 못 누르니 화살표가 있으면 거짓말이 된다.
  final VoidCallback? onTap;

  const ContributionRow({
    super.key,
    required this.name,
    required this.absoluteReturn,
    required this.returnRate,
    required this.rateAvailable,
    required this.startValue,
    required this.endValue,
    required this.share,
    required this.contribution,
    required this.currency,
    required this.isKo,
    required this.positiveColor,
    required this.negativeColor,
    this.isLast = false,
    this.onTap,
  });

  /// `₩5,206,640 → ₩5,180,120` — 이 줄의 근거.
  ///
  /// 손익만 보여주면 그 크기를 가늠할 기준이 없다. 10만 원이 큰지 작은지는
  /// 원금이 정한다.
  Widget _basisLine(BuildContext context) {
    final style = TextStyle(
        fontSize: DS.caption,
        fontWeight: FontWeight.w600,
        color: context.textTertiary);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(children: [
        Text(fmtMoney(startValue, currency), style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child:
              Icon(Icons.arrow_forward, size: 11, color: context.textTertiary),
        ),
        Text(fmtMoney(endValue, currency), style: style),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPos = absoluteReturn >= 0;
    final color = isPos ? positiveColor : negativeColor;
    final sign = isPos ? '+' : '−';
    final s = share.clamp(0.0, 1.0);

    final body = Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: context.dividerColor))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                      fontSize: DS.rowName,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: context.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$sign${fmtMoney(absoluteReturn.abs(), currency)}',
                style: TextStyle(
                    fontSize: DS.rowAmount,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: color),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                // 칸 너비는 행끼리 맞추려고 고정이다. 네 자리 수익률
                // (+4178.77%)은 이 폭을 넘겨 **두 줄로 쪼개졌다.**
                // 줄을 늘리는 대신 글자를 줄인다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    rateAvailable
                        ? '${returnRate >= 0 ? '+' : '−'}'
                            '${returnRate.abs().toStringAsFixed(2)}%'
                        : '—',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                        fontSize: DS.returnPct,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right,
                    size: 18, color: context.textTertiary),
            ],
          ),
          const SizedBox(height: 3),
          _basisLine(context),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DS.barTrackRadius),
                  child: SizedBox(
                    height: DS.barTrackHeight,
                    // Stack + FractionallySizedBox를 쓰면 자식 없는 ColoredBox의
                    // 세로 크기가 0이 되어 막대가 안 보인다. flex로 나눈다.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: (s * 1000).round(),
                          child: ColoredBox(color: color),
                        ),
                        Expanded(
                          flex: ((1 - s) * 1000).round(),
                          child: ColoredBox(color: context.trackBg),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 기여도는 무채색 — 손익만 색을 쓴다
              Text(
                isKo
                    ? '기여 ${(s * 100).toStringAsFixed(0)}%'
                        ' (${contribution >= 0 ? '+' : '−'}'
                        '${contribution.abs().toStringAsFixed(2)}%p)'
                    : '${(s * 100).toStringAsFixed(0)}%'
                        ' (${contribution >= 0 ? '+' : '−'}'
                        '${contribution.abs().toStringAsFixed(2)}pp)',
                style: TextStyle(
                    fontSize: DS.caption,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );

    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}
