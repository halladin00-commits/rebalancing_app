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

  @override
  void initState() {
    super.initState();
    _ad = AdService.createBanner(
      adUnitId: AdService.mainBannerId,
      size: AdSize.banner,
      onLoaded: () {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: () {
        _ad = null;
      },
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 항상 50px 자리 예약 — 광고가 없으면 빈 공간, 있으면 광고 표시
    return SizedBox(
      width: double.infinity,
      height: kBannerHeight,
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
