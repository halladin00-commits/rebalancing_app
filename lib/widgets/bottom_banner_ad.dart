import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// 모든 화면 하단 공통 배너 광고 위젯.
/// - 광고 로드 전후 관계없이 항상 kBannerHeight(50px)를 예약 → 레이아웃 변화 없음
/// - SafeArea는 Scaffold body가 이미 처리하므로 별도 사용 안 함
class BottomBannerAd extends StatefulWidget {
  const BottomBannerAd({super.key});

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

/// 배너 광고 높이 상수 (FAB bottomOffset과 공유)
const double kBannerHeight = 50.0;

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  /// 실제로 잡을 높이. 적응형 크기를 못 받으면 예전 고정 높이를 쓴다.
  double _height = kBannerHeight;

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
    if (size != null) _height = size.height.toDouble();

    _ad = AdService.createBanner(
      adUnitId: AdService.mainBannerId,
      size: size ?? AdSize.banner,
      onLoaded: () {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: () {
        _ad = null;
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 광고가 없어도 자리를 비워 둔다 — 뒤늦게 떠서 화면이 튀지 않게.
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: (_loaded && _ad != null)
          ? Center(
              child: SizedBox(
                width: _ad!.size.width.toDouble(),
                height: _ad!.size.height.toDouble(),
                child: AdWidget(ad: _ad!),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
