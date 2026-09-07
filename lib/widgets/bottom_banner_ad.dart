import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// 모든 화면 하단 공통 배너 광고 위젯.
/// - 광고 로드 전후 관계없이 항상 kBannerHeight(50px)를 예약 → 레이아웃 변화 없음
/// - SafeArea는 Scaffold body가 이미 처리하므로 별도 사용 안 함
class BottomBannerAd extends StatefulWidget {
  /// 어느 자리의 배너인가. AdMob 리포트가 자리별로 나뉜다.
  final AdSlot slot;

  const BottomBannerAd({super.key, this.slot = AdSlot.main});

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

/// 배너 광고 높이 상수 (FAB bottomOffset과 공유)
const double kBannerHeight = 50.0;

/// 배너 자리의 세 가지 상태.
///
/// 예전에는 「떴다 / 안 떴다」 둘로만 갈랐다. 그러면 **불러오는 중**과
/// **실패**가 같은 취급을 받아, 광고가 붙을 때마다 화면이 아래에서 밀려
/// 올라온다 — 페이지를 옮길 때마다 새로 불러오므로 매번 그랬다.
enum BannerSlotState {
  /// 요청해 놓고 기다리는 중. **자리를 잡아 둔다** — 곧 올 것이 알기
  /// 때문에 미리 비워 두면 튀지 않는다.
  loading,

  /// 붙었다. 자리는 이미 잡혀 있으므로 그림만 채운다.
  shown,

  /// 안 붙는다. **자리를 없앤다** — 오지 않을 것을 위해 빈 띠를 남기면
  /// 스낵바 아래가 이유 없이 비어 보인다.
  failed,
}

/// 그 상태에서 잡을 높이.
///
/// 판단을 한 곳에 모아 둔다. 눈으로만 보이는 종류의 버그라
/// 「둘로 가르기」로 되돌아가도 아무도 모른다.
double bannerSlotHeight(BannerSlotState state, double adHeight) =>
    state == BannerSlotState.failed ? 0 : adHeight;

/// 한 번 알아낸 적응형 배너 높이. **화면마다 다시 묻지 않는다.**
///
/// 크기를 묻는 건 비동기라, 답이 오기 전에는 어림값(50)으로 자리를 잡는다.
/// 화면을 옮길 때마다 다시 물으면 그 어림값에서 실제 높이로 한 번씩 움직인다
/// — 작지만 페이지를 넘길 때마다 생긴다. 기기 폭은 안 바뀌므로 한 번이면 된다.
double? _cachedAdHeight;

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;
  bool _requested = false;
  Timer? _timeout;

  /// 실제로 잡을 높이. 적응형 크기를 못 받으면 예전 고정 높이를 쓴다.
  late double _height = _cachedAdHeight ?? kBannerHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 폭을 알아야 적응형 크기를 물어볼 수 있다 — initState에서는 못 한다.
    if (_requested) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    // **적응형 배너.** 320×50 고정보다 기기 폭을 꽉 채워 단가가 높다.
    // 세로 고정 앱이라 방향은 portrait로 묻는다.
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait, width);
    if (!mounted) return;
    if (size != null) {
      _height = size.height.toDouble();
      _cachedAdHeight = _height;
    }

    _ad = AdService.createBanner(
      adUnitId: AdService.bannerIdFor(widget.slot),
      size: size ?? AdSize.banner,
      onLoaded: () {
        if (mounted) {
          setState(() {
            _loaded = true;
            _failed = false; // 시간을 넘겨 늦게 왔어도 보여준다
          });
        }
      },
      onFailed: () {
        _ad = null;
        // **반드시 다시 그린다.** 예전에는 여기서 그냥 두었다 — 어차피
        // 자리가 없었으니까. 이제는 자리를 잡고 기다리므로, 실패를 알려
        // 주지 않으면 빈 띠가 영영 남는다.
        if (mounted) setState(() => _failed = true);
      },
    );
    if (mounted) setState(() {});

    // **답이 없을 때를 막는다.** 성공도 실패도 안 오면(네트워크가 죽어
    // 요청이 매달려 있는 등) 자리가 영영 빈 채로 남는다. 그건 이 변경이
    // 없애려던 것보다 나쁘다.
    _timeout = Timer(const Duration(seconds: 8), () {
      if (mounted && !_loaded) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **기다리는 동안에도 자리를 잡아 둔다.**
    //
    // 광고는 페이지를 옮길 때마다 새로 불러온다. 자리를 안 잡아 두면
    // 붙는 순간마다 화면이 아래에서 밀려 올라와, 쓰는 도중에 레이아웃이
    // 계속 바뀐다. 미리 비워 두면 붙어도 아무 일도 안 일어난다.
    //
    // 안 붙는 것으로 판명되면 그때 접는다 — 오지 않을 것을 위해 빈 띠를
    // 남기면, 스낵바가 그 위에 떠서 알림 아래가 이유 없이 비어 보인다.
    final show = _loaded && _ad != null;
    final state = _failed
        ? BannerSlotState.failed
        : (show ? BannerSlotState.shown : BannerSlotState.loading);

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: bannerSlotHeight(state, _height),
        child: show
            ? Center(
                child: SizedBox(
                  width: _ad!.size.width.toDouble(),
                  height: _ad!.size.height.toDouble(),
                  child: AdWidget(ad: _ad!),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
