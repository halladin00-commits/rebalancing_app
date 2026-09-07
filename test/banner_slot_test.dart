import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/widgets/bottom_banner_ad.dart';

/// 배너 자리를 언제 잡고 언제 접는가.
///
/// 눈으로만 보이는 종류의 규칙이라 코드로 박아 둔다. 예전에는 「떴다 /
/// 안 떴다」 둘로만 갈랐는데, 그러면 **불러오는 중**이 실패와 같은 취급을
/// 받아 광고가 붙을 때마다 화면이 밀려 올라왔다. 페이지를 옮길 때마다 새로
/// 불러오므로 쓰는 내내 그랬다.
void main() {
  const h = 62.0;

  test('불러오는 중에도 자리를 잡는다 — 붙어도 화면이 안 튄다', () {
    expect(bannerSlotHeight(BannerSlotState.loading, h), h);
  });

  test('붙으면 같은 높이 — 잡아 둔 자리에 그림만 채운다', () {
    expect(bannerSlotHeight(BannerSlotState.shown, h),
        bannerSlotHeight(BannerSlotState.loading, h));
  });

  test('안 붙으면 접는다 — 빈 띠를 남기면 스낵바 아래가 비어 보인다', () {
    expect(bannerSlotHeight(BannerSlotState.failed, h), 0);
  });

  test('접는 것은 실패했을 때뿐이다', () {
    // 「둘로 가르기」로 되돌아가면 loading이 0이 되어 여기서 걸린다.
    final collapsed = BannerSlotState.values
        .where((s) => bannerSlotHeight(s, h) == 0)
        .toList();
    expect(collapsed, [BannerSlotState.failed]);
  });
}
