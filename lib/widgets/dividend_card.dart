import 'package:flutter/material.dart';

import '../main.dart';
import '../services/dividend_service.dart';
import '../theme/design_system.dart';
import '../utils/date_label.dart';
import '../utils/money_format.dart';
import '../utils/share_format.dart';

/// 결산 화면의 「배당 (추정)」 한 장.
///
/// 포트 결산은 배당 한 건씩, 전체 결산은 포트별 합계를 보여 준다.
/// **수익률에는 넣지 않는다** — 그래서 제목 옆에 「세전 · 수익률 미포함」을
/// 늘 적고, 물음표를 누르면 왜 어림인지 밝힌다.
///
/// 배당이 하나도 없으면 아무것도 그리지 않는다. 배당을 안 주는 종목만
/// 가진 사람에게 빈 카드는 소음이다.
class DividendCard extends StatefulWidget {
  final DividendEstimate? estimate;

  /// 전체 결산이면 포트별 합계를 줄로 쓴다
  final bool byPortfolio;

  const DividendCard({super.key, required this.estimate, this.byPortfolio = false});

  @override
  State<DividendCard> createState() => _DividendCardState();
}

class _DividendCardState extends State<DividendCard> {
  static const int _collapsedRows = 4;
  bool _expanded = false;

  @override
  void didUpdateWidget(DividendCard old) {
    super.didUpdateWidget(old);
    // 다른 기간으로 넘어가면 접은 상태로 돌아간다
    if (!identical(old.estimate, widget.estimate)) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estimate;
    if (e == null || e.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final lang = dateLang(context);

    final rows = <Widget>[];
    if (widget.byPortfolio && e.byPortfolio.length > 1) {
      for (final p in e.byPortfolio) {
        rows.add(_row(context, p.name, null, fmtMoney(p.amount, e.currency)));
      }
    } else {
      for (final l in e.lines) {
        final per = _fmtPerShare(l.perShare, l.market);
        final sub = l10n.dividendLine(fmtMonthDay(l.exDate, lang), per,
            l10n.sharesCount(l.shares, formatShares(l.shares)));
        rows.add(_row(context, l.name, sub, fmtMoney(l.amount, e.currency)));
      }
    }
    final hidden = rows.length - _collapsedRows;
    final shown =
        _expanded || hidden <= 1 ? rows : rows.sublist(0, _collapsedRows);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 0, 4),
            child: Row(
              children: [
                Text(
                  l10n.dividendTitle,
                  style: TextStyle(
                      fontSize: DS.sectionTitle,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: context.textPrimary),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    l10n.dividendNote,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: l10n.a11yDividendInfo,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.help_outline,
                      size: 18, color: context.textTertiary),
                  onPressed: () => _showInfo(context),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(DS.cardRadius),
              border: Border.all(color: context.cardBorder),
            ),
            padding: const EdgeInsets.fromLTRB(
                DS.cardPaddingH, 14, DS.cardPaddingH, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.dividendTotalLabel,
                        style: TextStyle(
                            fontSize: DS.body,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${fmtMoney(e.total, e.currency)}',
                      style: TextStyle(
                          fontSize: DS.totalAmount,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: context.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: context.dividerColor),
                ...shown,
                if (hidden > 1)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded ? l10n.dividendLess : l10n.dividendMore(hidden),
                        style: TextStyle(
                            fontSize: DS.body,
                            fontWeight: FontWeight.w700,
                            color: context.brand),
                      ),
                    ),
                  ),
                if (e.failed > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      l10n.dividendFailed(e.failed),
                      style: TextStyle(
                          fontSize: DS.body,
                          fontWeight: FontWeight.w600,
                          color: context.warningText),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String name, String? sub, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: context.textPrimary),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: DS.body,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }

  /// 1주당 배당. 미국 배당은 센트 아래까지 오므로(0.267달러) 두 자리로
  /// 자르면 곱이 안 맞아 보인다 — 넷째 자리까지, 끝의 0은 뗀다.
  static String _fmtPerShare(double v, String market) {
    if (market != 'US') return fmtPrice(v, market);
    var s = v.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = '${s}00';
    final dot = s.indexOf('.');
    if (s.length - dot - 1 < 2) s = s.padRight(dot + 3, '0');
    return '\$$s';
  }

  void _showInfo(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dividendInfoTitle),
        content: SingleChildScrollView(child: Text(l10n.dividendInfoBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }
}
