import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/services/ad_service.dart';

/// 광고 단위 ID는 틀려도 앱이 멀쩡히 돌아간다. 테스트 단위가 섞여 들어가면
/// 광고는 그대로 뜨는데 수익만 0이 되고, 눈으로는 절대 못 잡는다.
/// 출시를 막을 종류의 실수라 여기서 잡는다.
void main() {
  /// 구글이 공개한 테스트 게시자 ID. 여기서 나오는 광고는 돈이 안 된다.
  const testPublisher = 'ca-app-pub-3940256099942544';

  test('출시 설정에서 구글 테스트 광고 단위가 나오면 안 된다', () {
    for (final slot in AdSlot.values) {
      expect(AdService.bannerIdFor(slot), isNot(startsWith(testPublisher)),
          reason: '$slot 배너가 테스트 단위다');
    }
    expect(AdService.exitBannerId, isNot(startsWith(testPublisher)),
        reason: '종료 배너가 테스트 단위다');
    expect(AdService.appOpenId, isNot(startsWith(testPublisher)),
        reason: '앱 오프닝이 테스트 단위다');
  });

  test('자리마다 광고 단위가 서로 달라야 한다', () {
    // 둘이 같으면 AdMob 리포트가 다시 뭉쳐 찍힌다 — 자리별로 나눈 의미가 없다.
    final ids = {for (final s in AdSlot.values) AdService.bannerIdFor(s)};
    expect(ids.length, AdSlot.values.length,
        reason: '배너 단위가 겹친다: $ids');
  });

  test('모든 광고 단위가 우리 게시자 계정이어야 한다', () {
    const publisher = 'ca-app-pub-7508564356740806/';
    for (final slot in AdSlot.values) {
      expect(AdService.bannerIdFor(slot), startsWith(publisher));
    }
    expect(AdService.exitBannerId, startsWith(publisher));
    expect(AdService.appOpenId, startsWith(publisher));
  });
}
