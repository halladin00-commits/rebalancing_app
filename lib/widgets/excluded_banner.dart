import 'package:flutter/material.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';

/// 결산 제외 띠 (시안 v22a).
///
/// 결산 숫자가 일부 종목을 빼고 계산된 값인데 그 사실이 화면 어디에도
/// 없으면, 사용자는 틀린 숫자를 맞는 줄 알고 본다. 한 줄로 밝힌다.
///
/// 혼내는 톤으로 쓰지 않는다 — 간편 입력은 잘못이 아니라 선택이었고,
/// 자산·리밸런싱에서는 아무 손해가 없다. 결산만 못 할 뿐이다.
class ExcludedBanner extends StatelessWidget {
  final List<PortfolioItem> items;

  /// 제외된 종목의 평가액 합계. 이미 서식이 입혀진 문자열.
  final String amountText;

  /// `전환` 링크를 눌렀을 때. null이면 링크를 감춘다.
  final VoidCallback? onFix;

  const ExcludedBanner({
    super.key,
    required this.items,
    required this.amountText,
    this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, size: 16, color: context.warningText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.excludedFromSettlement(items.length, amountText),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: context.warningText),
          ),
        ),
        if (onFix != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFix,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Text(l10n.excludedFixLink,
                  style: TextStyle(
                      fontSize: DS.body,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationColor: context.warningText,
                      color: context.warningText)),
            ),
          ),
        ],
      ]),
    );
  }
}

/// 제외 사유를 자세히 알려주는 시트. 띠의 `전환`이 연다.
Future<void> showExcludedSheet(
  BuildContext context, {
  required List<PortfolioItem> items,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet(
    context: context,
    backgroundColor: context.scaffoldBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD6CFBC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.excludedSheetTitle,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.excludedSheetBody,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(DS.tileRadius),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              children: [
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      Expanded(
                        child: Text(i.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(l10n.excludedNoHistory,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.textTertiary)),
                    ]),
                  ),
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}
