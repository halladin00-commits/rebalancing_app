import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme/design_system.dart';

/// 딥그린 헤더 블록.
///
/// 시안에서 AppBar와 그 아래 총자산 영역은 하나의 딥그린 덩어리이고,
/// 그 덩어리 하단이 라운드 28이다. Flutter 기본 `AppBar`로는 이 구조가
/// 안 나오므로 [제목 + 액션] + [하위 내용 slot] + [하단 라운드]를 가진
/// 위젯으로 대신한다.
///
/// `Scaffold.appBar`가 아니라 `body` 최상단에 놓고 쓴다.
class BrandHeader extends StatelessWidget {
  /// 제목 문자열. [titleWidget]을 주면 무시된다.
  final String? title;

  /// 제목 자리를 통째로 대체 (로고 등).
  final Widget? titleWidget;

  /// 제목 글자 크기. 탭 루트는 19/w800, 상세 화면은 17/w700.
  /// 시안 기준 타이틀 행 높이는 48이다.
  final double titleSize;
  final FontWeight titleWeight;

  /// 좌측 위젯 (뒤로가기 등). 없으면 좌측 패딩만 들어간다.
  final Widget? leading;

  /// 우측 액션들.
  final List<Widget> actions;

  /// 제목 행 아래에 붙는 내용 (총자산 헤더, 기간 탭 등).
  final Widget? child;

  /// [child] 주위 패딩.
  final EdgeInsets childPadding;

  const BrandHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.titleSize = 19,
    this.titleWeight = FontWeight.w800,
    this.leading,
    this.actions = const [],
    this.child,
    this.childPadding =
        const EdgeInsets.fromLTRB(DS.screenPaddingH, 4, DS.screenPaddingH, 18),
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark,      // iOS
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.appBarBg,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(DS.headerRadius),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (leading != null)
                      leading!
                    else
                      const SizedBox(width: DS.screenPaddingH),
                    Expanded(
                      child: titleWidget ??
                          Text(
                            title ?? '',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: titleWeight,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                    ...actions,
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              if (child != null) Padding(padding: childPadding, child: child!),
            ],
          ),
        ),
      ),
    );
  }
}
