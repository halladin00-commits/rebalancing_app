import 'package:flutter/material.dart';

import '../main.dart';
import '../utils/money_format.dart';
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

  /// `9월 손익 · 9.01 – 9.30`.
  final String subtitle;

  /// 진행 중 / 마감.
  final String statusLabel;

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

  // ── 아래 셋은 **반드시 밖에서 받는다** ──
  //
  // 이 카드는 `captureFromWidget`이 만드는 **딴 트리**에서 그려진다. 거기에는
  // Provider도 Localizations도 조상으로 없어서, 안에서 찾으면 빌드가 터지고
  // 릴리즈 빌드에서는 그냥 **회색 사각형**이 저장된다(실제로 그렇게 나왔다).
  final bool isKo;
  final Color positiveColor;
  final Color negativeColor;

  const SettlementCaptureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.absoluteReturn,
    required this.returnRate,
    required this.rateAvailable,
    required this.startValue,
    required this.endValue,
    required this.netCashFlow,
    required this.inProgress,
    required this.currency,
    required this.rowsTitle,
    required this.rows,
    required this.isKo,
    required this.positiveColor,
    required this.negativeColor,
  });

  @override
  Widget build(BuildContext context) {
    final abs = absoluteReturn;
    final up = (abs ?? 0) >= 0;
    final color = up ? positiveColor : negativeColor;

    return Container(
      width: 380,
      color: context.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: context.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$subtitle · $statusLabel',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AppLogo(iconSize: 20, textColor: context.textPrimary),
            ],
          ),
          const SizedBox(height: 14),

          // ── 손익 · 수익률 · 시작/끝 (화면 헤더와 같은 구성) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          abs == null
                              ? '—'
                              : '${up ? '+' : '−'}${fmtMoney(abs.abs(), currency)}',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: abs == null ? context.textHint : color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(isKo ? '수익률 ' : 'return ',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary)),
                    Text(
                      rateAvailable
                          ? '${returnRate >= 0 ? '+' : '−'}${returnRate.abs().toStringAsFixed(2)}%'
                          : '—',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ),
                if (abs != null) ...[
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tile(
                          context,
                          startValue <= 0 && netCashFlow > 0
                              ? (isKo ? '넣은 돈' : 'invested')
                              : (isKo ? '시작 평가금액' : 'start value'),
                          startValue <= 0 && netCashFlow > 0
                              ? netCashFlow
                              : startValue,
                        ),
                        const SizedBox(width: 8),
                        _tile(
                          context,
                          inProgress
                              ? (isKo ? '지금 평가금액' : 'value now')
                              : (isKo ? '마감 평가금액' : 'closing value'),
                          endValue,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(rowsTitle,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.cardBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    _row(context, rows[i], isLast: i == rows.length - 1),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String label, double value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: context.rowBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(fmtMoney(value, currency),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.textPrimary)),
              ),
            ],
          ),
        ),
      );

  Widget _row(BuildContext context, CaptureRow r, {required bool isLast}) {
    final up = r.absoluteReturn >= 0;
    final c = up ? positiveColor : negativeColor;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: context.dividerColor))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r.name,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: context.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text(
              '${up ? '+' : '−'}${fmtMoney(r.absoluteReturn.abs(), currency)}',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: c),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 48,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  r.rateAvailable
                      ? '${r.returnRate >= 0 ? '+' : '−'}${r.returnRate.abs().toStringAsFixed(2)}%'
                      : '—',
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: c),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(children: [
              Text(fmtMoney(r.startValue, currency),
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(Icons.arrow_forward,
                    size: 10, color: context.textTertiary),
              ),
              Text(fmtMoney(r.endValue, currency),
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary)),
            ]),
          ),
        ],
      ),
    );
  }
}
