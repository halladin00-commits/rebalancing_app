import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_system.dart';

/// 스크롤을 따라 **이어서** 줄어드는 딥그린 헤더.
///
/// 불리언으로 접었다 폈다 하면 두 가지가 같이 나빠진다. 화면이 한 프레임에
/// 팍 바뀌어 갑작스럽고, 접힌 만큼 뷰포트가 커지면서 스크롤할 거리가 줄어
/// 목록이 위로 당겨진다. 슬리버로 두면 둘 다 사라진다 — 손가락을 따라
/// 이어서 줄고, 스크롤 계산은 프레임워크가 맞춘다.
///
/// **불변식: [bodyHeight]는 [body]의 실제 높이와 같아야 한다.**
/// 어긋나면 접힘 비율(t)과 실제로 칠해진 높이가 따로 놀아서, 본문이 사라진
/// **빈 초록 띠**가 남거나 헤더가 중간에 멈춘 것처럼 보인다.
/// 높이는 글자 크기·내용에 따라 달라지므로 [HeaderBody]로 재서 넘긴다.
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
                        // 두 제목을 겹쳐 두고 서로 넘긴다. 한쪽이 다 사라진
                        // 뒤에 다른 쪽이 나타난다 — 겹쳐 보이면 글자가
                        // 두 겹으로 읽힌다.
                        if (t < 0.45)
                          Opacity(
                            opacity: (1 - t / 0.45).clamp(0.0, 1.0),
                            child: expandedTitle,
                          ),
                        if (t > 0.45)
                          Opacity(
                            opacity: ((t - 0.45) / 0.35).clamp(0.0, 1.0),
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
                      // **거의 끝까지 불투명하게 둔다.** 잘려 나가는 것만으로
                      // 이미 사라지는 게 보인다. 일찍 흐려 놓으면 헤더는 아직
                      // 높은데 안은 비어서 **빈 초록 띠**만 남는다.
                      // 마지막 한 뼘에서만 부드럽게 지운다.
                      opacity: ((1 - t) / 0.25).clamp(0.0, 1.0),
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

  // floating / snap 은 일부러 쓰지 않는다.
  //
  // 붙여 보니 헤더 높이가 스크롤 **위치**가 아니라 **움직인 양**을 따라가서,
  // 같은 자리에서도 접힌 정도가 그때그때 달랐다. 스냅 애니메이션은 그 위에
  // 또 얹혀 서로 싸웠다. 지금은 위치만 보고 정해진다 — 같은 자리면 항상
  // 같은 모습이다. 다시 펴려면 맨 위까지 올리면 된다.

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

/// 자식의 실제 높이를 재서 알려준다.
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

/// 헤더 본문 높이를 들고 있는다.
///
/// 재는 대로 바로 넣으면 안 된다. 본문 내용은 나중에 채워지기도 한다 —
/// 스파크라인이 뒤늦게 그려지고, 결산 숫자가 계산을 마치고 들어온다.
/// 그게 **스크롤 도중에** 일어나면 헤더의 최대 높이가 발밑에서 바뀌어
/// 접힘 비율과 실제 높이가 어긋난다. 화면에서는 이렇게 보인다:
/// 헤더가 중간에 멈추거나, 높이는 그대로인데 안이 텅 비거나,
/// 같은 만큼 밀었는데 접히는 양이 매번 다르거나.
///
/// 그래서 **맨 위에 있을 때만** 반영한다. 그 자리에서는 헤더가 다 펴져 있어
/// 높이가 바뀌어도 어긋날 게 없다.
class HeaderBody {
  /// 재기 전에 쓸 어림값.
  double value;

  double? _pending;

  HeaderBody({this.value = 250});

  /// 잰 높이를 반영한다. 반영했으면 true — 부르는 쪽에서 setState 한다.
  bool update(double h, ScrollController c) {
    if ((value - h).abs() < 0.5) {
      _pending = null;
      return false;
    }
    if (c.hasClients && c.offset > 0.5) {
      _pending = h; // 스크롤 중 — 맨 위로 돌아올 때까지 미룬다
      return false;
    }
    value = h;
    _pending = null;
    return true;
  }

  /// 미뤄 둔 높이가 있으면 지금 반영한다. 반영했으면 true.
  bool flush(ScrollController c) {
    final p = _pending;
    if (p == null) return false;
    if (!c.hasClients || c.offset > 0.5) return false;
    value = p;
    _pending = null;
    return true;
  }
}

/// 헤더가 **끝까지** 접히도록 모자란 스크롤 거리를 채우는 슬리버.
///
/// 핀 고정 헤더는 접히면서 (최대−최소)만큼의 스크롤 거리를 스스로 만든다.
/// 그런데 아래 내용이 짧으면 그 거리가 모자라 **반쯤 접힌 채 멈춘다** —
/// 탭 글자가 잘린 상태로 굳어 고장 난 것처럼 보인다.
///
/// 모자란 만큼 목록 끝에 빈 칸을 넣는다. 접히면서 화면이 딱 그만큼 커지므로
/// **다 접었을 때 내용이 화면을 정확히 채운다.**
///
/// 높이는 **레이아웃 중에** 정한다. 예전에는 `maxScrollExtent`를 읽어
/// `setState`로 넣었는데, 그 값이 방금 넣은 빈 칸에 다시 영향을 받아
/// 한 박자씩 어긋났다 — 너무 크면 내용이 헤더 밑으로 밀려 들어가고,
/// 너무 작으면 헤더가 중간에 멈췄다. 여기서는 되먹임이 없다.
class CollapseTailSliver extends StatelessWidget {
  /// 헤더가 접히며 내주는 거리 (= 본문 높이).
  final double collapseRange;

  /// 채워 줄 최대치 — [collapseRange]에 대한 비율.
  ///
  /// 이보다 많이 모자라면 채우기를 포기한다. 채운 만큼 아래가 비기 때문에,
  /// 억지로 채우면 화면 절반이 빈 채로 남는다.
  static const double maxFillRatio = 0.35;

  const CollapseTailSliver({super.key, required this.collapseRange});

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // 앞선 슬리버들의 **스크롤 길이**는 접힘과 무관하게 일정하다.
        // 헤더는 접혀도 스크롤 길이가 maxExtent 그대로라, 접히며 내주는
        // 만큼(collapseRange)을 더해 줘야 실제로 빌 자리가 나온다.
        final needed = constraints.viewportMainAxisExtent -
            constraints.precedingScrollExtent +
            collapseRange;

        // 조금 모자랄 때만 채운다.
        //
        // 채운 만큼 그대로 아래가 빈다 — 이건 맞바꾸는 관계라 둘 다 없앨
        // 수는 없다. 조금 모자란 걸 마저 채우면 헤더가 깔끔하게 닫히고
        // 빈 자리는 눈에 안 띈다. 반대로 많이 모자란 걸 억지로 채우면
        // 화면 절반이 빈 채로 남는다 — 그건 접다 만 헤더보다 나쁘다.
        // 그때는 채우지 않고 **접히는 데까지만** 접는다.
        final gap = (needed <= 0 || needed > collapseRange * maxFillRatio)
            ? 0.0
            : needed;
        return SliverToBoxAdapter(child: SizedBox(height: math.max(0, gap)));
      },
    );
  }
}
