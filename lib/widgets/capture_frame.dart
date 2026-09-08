import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/design_system.dart';
import 'app_logo.dart';

/// 저장·공유할 그림의 **공통 틀**.
///
/// 캡처는 두 가지로 계속 깨졌다. 이 틀이 둘 다 막는다.
///
/// **1. 배경 없이 찍혀 검게 나온다.**
/// `Screenshot`으로 화면을 그대로 찍으면 배경이 `Scaffold`에 있어서 경계
/// 안에는 아무것도 안 칠해진다. 투명하게 찍히고, JPEG로 저장하면 검은색이
/// 된다. 여기서는 배경을 **틀이 직접 칠한다.**
///
/// **2. 스크롤되는 화면은 보이는 만큼만 찍힌다.**
/// 목록이 화면 밖으로 이어지면 그 아래는 그림에 안 들어간다. 그래서 캡처는
/// **화면을 찍는 게 아니라 다시 그려야 한다** — 스크롤 없이, 전부.
/// 이 틀은 스크롤 위젯을 쓰지 않는다.
///
/// 그림에는 화면의 것 중 **광고·탭바·누를 수 있는 표시**를 뺀다.
/// 그림에서는 누를 수 없으니 화살표가 있으면 거짓말이 된다.
class CaptureFrame extends StatelessWidget {
  /// 딥그린 머리에 들어갈 제목 (`위탁계좌`, `조정 제안`…).
  final String title;

  /// 제목 아래 한 줄. 없으면 안 그린다.
  final String? subtitle;

  /// 머리 안에 더 넣을 것 (금액·타일·추이선 등).
  final Widget? headerBody;

  /// 머리 아래 본문. 스크롤되지 않는 위젯이어야 한다.
  final List<Widget> children;

  /// 그림 너비. 기본값이 지금까지 쓰던 값이다.
  final double width;

  const CaptureFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.headerBody,
    this.children = const [],
    this.width = 380,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      // **배경을 여기서 칠한다.** 이걸 빼면 투명하게 찍혀 검은 그림이 된다.
      color: context.scaffoldBg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appBarBg,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(DS.headerRadius)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: DS.body,
                          fontWeight: FontWeight.w600,
                          color: context.onBrandSecondary)),
                ],
                if (headerBody != null) ...[
                  const SizedBox(height: 14),
                  headerBody!,
                ],
              ]),
        ),
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
      ]),
    );
  }
}

/// 그림 안의 카드 하나. 화면의 카드와 같은 모양.
class CaptureCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsets padding;

  const CaptureCard({
    super.key,
    this.title,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: DS.cardPaddingH),
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) ...[
        Text(title!,
            style: TextStyle(
                fontSize: DS.sectionTitle,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: context.textPrimary)),
        const SizedBox(height: 9),
      ],
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(color: context.cardBorder),
        ),
        padding: padding,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ]);
  }
}
