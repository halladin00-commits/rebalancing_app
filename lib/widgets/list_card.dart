import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/design_system.dart';

/// 시안의 목록 카드 · 행 문법.
///
/// 자산 탭의 포트폴리오 목록과 포트 상세의 구성 종목 목록은 **같은 문법**을 쓴다.
/// 화면마다 행을 따로 그리면 서로 다른 앱처럼 보이므로 여기 한 곳에 둔다.
///
/// 시안 기준(v12a · v12b):
/// - 카드: 흰 배경, 라운드 20, 좌우 패딩 18, 그림자 `0 1px 2px rgba(22,19,15,.05)`
/// - 행: 세로 패딩 12~14, 행 사이 1px `#EFEADC` 구분선 (마지막 행은 없음)
/// - 우측: 금액 15/700/−0.3 위, 그 아래 `전일대비 11/600 무채색` + `누적 12.5/700 손익색`

/// 흰 카드에 [rows]를 구분선으로 이어 담는다.
class ListCard extends StatelessWidget {
  final List<Widget> rows;

  const ListCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(
            height: 1, thickness: 1, color: context.dividerColor));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D16130F), // rgba(22,19,15,.05)
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DS.cardPaddingH),
        child: Column(children: children),
      ),
    );
  }
}

/// 목록 카드 안의 한 행.
///
/// [leading]은 이름 왼쪽에 붙는 것(시장 칩 등), [subtitle]은 이름 아래 보조 줄
/// (`₩21,450 · 220주`). [dayText]는 전일대비(무채색), [returnText]/[returnColor]는
/// 누적 수익률(손익색). 없으면 그 자리를 비운다.
class ListRow extends StatelessWidget {
  final Widget? leading;
  final String title;

  /// 이름 크기. 포트 행은 15.5, 종목 행은 14.5.
  final double titleSize;
  final Widget? subtitle;
  final String amount;
  final String? dayText;
  final String? returnText;
  final Color? returnColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsets padding;

  const ListRow({
    super.key,
    this.leading,
    required this.title,
    this.titleSize = 15.5,
    this.subtitle,
    required this.amount,
    this.dayText,
    this.returnText,
    this.returnColor,
    this.onTap,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: TextStyle(
        fontSize: titleSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: context.textPrimary,
      ),
      overflow: TextOverflow.ellipsis,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading == null)
                    titleWidget
                  else
                    Row(children: [
                      leading!,
                      const SizedBox(width: 6),
                      Expanded(child: titleWidget),
                    ]),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: DS.rowAmount,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: context.textPrimary,
                  ),
                ),
                if (dayText != null || returnText != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // 전일대비는 방향만 알려주는 보조값 — 무채색으로 둬서
                      // 손익색을 쓰는 누적 수익률과 섞이지 않게 한다.
                      if (dayText != null)
                        Text(dayText!,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary)),
                      if (dayText != null && returnText != null)
                        const SizedBox(width: 8),
                      if (returnText != null)
                        Text(returnText!,
                            style: TextStyle(
                                fontSize: DS.returnPct,
                                fontWeight: FontWeight.w700,
                                color: returnColor ?? context.textPrimary)),
                    ],
                  ),
                ],
              ],
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null) ...[
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(4, 0),
                child: Icon(Icons.chevron_right,
                    size: 20, color: context.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 목록 위에 붙는 섹션 제목. 좌측 제목 13/800, 우측 부가 11.5/600.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: DS.sectionTitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: context.textPrimary)),
          const Spacer(),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
        ],
      ),
    );
  }
}

/// 시장 칩 (KR · US · 현금). 시안: 10.5/800, 라운드 5, 패딩 3×5.
class MarketChip extends StatelessWidget {
  final String market; // 'KR' | 'US' | 'CASH'
  final String label;

  const MarketChip({super.key, required this.market, required this.label});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (market) {
      'US' => (context.chipUsText, context.chipUsBg),
      'CASH' => (context.chipCashText, context.chipCashBg),
      _ => (context.chipKrText, context.chipKrBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: DS.caption, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}
