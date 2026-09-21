import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/design_system.dart';

/// `매도 대금            +₩2,408,750` — 이름과 금액을 한 줄에.
///
/// **화면과 캡처가 같이 쓴다.** 예전에는 두 곳이 각자 같은 모양의 지역
/// 함수를 들고 있었고, 그 사이 글자 크기가 화면 11.5 대 캡처 12.5로
/// 갈라졌다. 나란히 놓고 볼 일이 없어 아무도 몰랐다.
class MoneyLine extends StatelessWidget {
  final String label;
  final String value;

  /// 금액 색. 안 주면 본문색 — 더하고 빼는 줄에만 색을 쓴다.
  final Color? color;

  /// 합계 줄처럼 힘을 줘야 하는 줄.
  final bool bold;

  /// 줄 사이를 띄울지. 카드 안에서는 띄우고, 목록 안에서는 붙인다.
  final EdgeInsetsGeometry padding;

  const MoneyLine({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final weight = bold ? FontWeight.w700 : FontWeight.w600;
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: DS.body,
                  fontWeight: weight,
                  color: bold ? context.textPrimary : context.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: DS.body,
                fontWeight: weight,
                color: color ?? context.textPrimary)),
      ]),
    );
  }
}
