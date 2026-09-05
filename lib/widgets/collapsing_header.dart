import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_system.dart';

/// 스크롤을 따라 **이어서** 줄어드는 딥그린 헤더.
///
/// 불리언으로 접었다 폈다 하면 두 가지가 같이 나빠진다. 화면이 한 프레임에
/// 팍 바뀌어 갑작스럽고, 접힌 만큼 뷰포트가 커지면서 스크롤할 거리가 줄어
/// 목록이 위로 당겨진다. 그걸 막으려고 목록 아래에 그만큼 여백을 돌려주면
/// 이번에는 마지막 카드 밑이 한 화면 가까이 비어 버린다.
///
/// 슬리버로 두면 셋 다 사라진다 — 손가락을 따라 이어서 줄고, 스크롤 계산은
/// 프레임워크가 맞추고, 여백을 만들어 낼 일이 없다.
class CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// 제목 행 아래에 붙어 접히며 사라지는 부분의 높이.
  final double bodyHeight;

  /// 상태바 높이. 헤더가 그 뒤까지 칠한다.
  final double topInset;

  /// 제목 행 높이. 큰 글씨 설정에서 48을 넘을 수 있어 받아 둔다.
  final double titleHeight;

  /// 다 펼쳤을 때 제목 자리 (로고 등).
  final Widget expandedTitle;

  /// 다 접었을 때 제목 자리 (총자산 한 줄 등).
  final Widget collapsedTitle;

  /// 접히며 사라지는 본문.
  final Widget body;

  /// 제목 행 왼쪽 (뒤로가기 등). 없으면 좌측 패딩만.
  final Widget? leading;

  /// 제목 행 오른쪽 버튼들.
  final List<Widget> actions;

  final Color background;

  const CollapsingHeaderDelegate({
    required this.bodyHeight,
    required this.topInset,
    required this.titleHeight,
    required this.expandedTitle,
    required this.collapsedTitle,
    required this.body,
    required this.background,
    this.leading,
    this.actions = const [],
  });

  @override
  double get maxExtent => topInset + titleHeight + bodyHeight;

  @override
  double get minExtent => topInset + titleHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final range = maxExtent - minExtent;
    // 0 = 다 펼침, 1 = 다 접힘
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark, // iOS
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(DS.headerRadius),
        ),
        child: ColoredBox(
          color: background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topInset),
              SizedBox(
                height: titleHeight,
                child: Row(children: [
                  if (leading != null)
                    leading!
                  else
                    const SizedBox(width: DS.screenPaddingH),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // 두 제목을 겹쳐 두고 서로 넘긴다. 자리를 주고받는
                        // 것이라 한쪽이 사라지는 동안 다른 쪽이 나타나야 한다.
                        if (t < 1)
                          Opacity(
                            opacity: (1 - t * 1.8).clamp(0.0, 1.0),
                            child: expandedTitle,
                          ),
                        if (t > 0)
                          Opacity(
                            opacity: ((t - 0.45) / 0.55).clamp(0.0, 1.0),
                            child: collapsedTitle,
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                  const SizedBox(width: 4),
                ]),
              ),
              // 남은 높이만큼만 보인다. 본문은 제자리에 그대로 있고 제목 행
              // 밑으로 밀려 들어가며 잘린다 — 글자가 찌그러지지 않는다.
              Expanded(
                child: ClipRect(
                  // 높이를 **묶지 않는다.** bodyHeight로 묶으면 본문이 그 값에
                  // 맞춰 그려지고, 그 값을 다시 재게 되어 어림값이 그대로 굳는다.
                  // 자연 높이로 그린 뒤 남는 만큼만 보여준다.
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Opacity(
                      opacity: (1 - t * 1.35).clamp(0.0, 1.0),
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(CollapsingHeaderDelegate old) =>
      old.bodyHeight != bodyHeight ||
      old.topInset != topInset ||
      old.titleHeight != titleHeight ||
      old.background != background ||
      old.leading != leading ||
      old.expandedTitle != expandedTitle ||
      old.collapsedTitle != collapsedTitle ||
      old.body != body ||
      old.actions != actions;
}

/// 자식의 실제 높이를 한 번 재서 알려준다.
///
/// 헤더 본문 높이는 글자 크기 설정과 내용에 따라 달라져 상수로 박을 수 없다.
/// 박아 두면 큰 글씨에서 잘리거나 작은 글씨에서 빈 자리가 생긴다.
class MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeight;

  const MeasureSize({super.key, required this.child, required this.onHeight});

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  final _key = GlobalKey();
  double? _last;

  void _report() {
    final h = _key.currentContext?.size?.height;
    if (h == null || h <= 0) return;
    if (_last != null && (_last! - h).abs() < 0.5) return;
    _last = h;
    widget.onHeight(h);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
