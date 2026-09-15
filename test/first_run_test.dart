import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 앱을 **깔고 처음 여는 날**의 흐름을 지킨다.
///
/// 왜 소스를 읽는 시험인가
///   첫 실행은 기기에 한 번뿐이다. 다시 보려면 앱을 지웠다 깔아야 하므로,
///   개발 중에도 검토 중에도 거의 안 보게 된다. 그래서 여기가 틀어져도
///   **한참 모른다.**
void main() {
  late String main_;
  setUpAll(() => main_ = File('lib/main.dart').readAsStringSync());

  test('깔고 처음 여는 날은 앱 오프닝 광고를 띄우지 않는다', () {
    // 온보딩을 넘기고 면책 고지에 동의하고 알림까지 정하고 나서, 이제야
    // 앱을 둘러보려는 참이다. 그 자리에서 전면 광고가 뜨면 지금까지 쌓은
    // 인상이 한 번에 뒤집힌다. **첫인상은 두 번 만들 수 없다.**
    // 상수 **정의**가 아니라 흐름에서 읽는 자리를 찾는다 — 정의는 파일
    // 아래쪽에 있어서, 문자열 값으로 찾으면 늘 광고보다 뒤에 나온다.
    final iFlag = main_.indexOf('getBool(_keyOpenedBefore)');
    final iShow = main_.indexOf('FullScreenAds.show');

    expect(iFlag, isNot(-1), reason: '첫 실행을 가리는 표시가 없다');
    expect(iShow, isNot(-1), reason: '앱 오프닝 광고를 띄우는 호출을 못 찾았다');
    expect(iFlag, lessThan(iShow),
        reason: '광고를 띄운 뒤에 첫 실행을 확인한다 — 순서가 뒤집혔다');

    // 확인만 하고 안 막으면 소용없다. 사이에 빠져나가는 길이 있어야 한다.
    final between = main_.substring(iFlag, iShow);
    expect(between.contains('return'), isTrue,
        reason: '첫 실행인지 보기만 하고 광고를 그대로 띄운다');
  });

  test('표시는 광고를 띄우기 전에 남긴다', () {
    // 나중에 남기면, 그 사이에 앱이 죽었을 때 다음 실행도 첫 실행이 된다.
    // 광고가 영영 안 뜨는 앱이 되는 길이다.
    final iSet = main_.indexOf('setBool(_keyOpenedBefore, true)');
    final iShow = main_.indexOf('FullScreenAds.show');
    expect(iSet, isNot(-1), reason: '표시를 남기지 않는다');
    expect(iSet, lessThan(iShow), reason: '표시를 광고 뒤에 남긴다');
  });

  test('첫 실행 순서 — 고지 · 알림 안내 · 광고', () {
    // 광고가 면책 고지나 알림 안내보다 먼저 뜨면, 앱을 켜자마자 광고부터
    // 보게 된다. 순서가 곧 첫인상이다.
    final iDisclaimer = main_.indexOf('DisclaimerDialog.showIfNeeded');
    final iPrimer = main_.indexOf('NotificationPrimer.askFirst');
    final iShow = main_.indexOf('FullScreenAds.show');

    expect(iDisclaimer, lessThan(iPrimer), reason: '알림 안내가 고지보다 먼저다');
    expect(iPrimer, lessThan(iShow), reason: '광고가 알림 안내보다 먼저다');
  });

  test('하루 한도와 간격이 둘 다 있다', () {
    // **기준 시간만으로는 최악을 못 막는다.** 시장이 출렁이는 날엔 하루에
    // 열 번도 여는데, 그런 날은 방문 간격이 벌어져 있어도 대여섯 번 보게
    // 된다. 정작 자주 들여다보는 날이 가장 불안한 날이다.
    final ads = File('lib/services/full_screen_ads.dart').readAsStringSync();

    expect(ads.contains('dailyCap'), isTrue, reason: '하루 한도가 없다');
    expect(ads.contains('awayEnough'), isTrue, reason: '최소 간격이 없다');

    // 한도를 세는 값은 **저장**해야 한다. 메모리에만 두면 앱을 껐다 켤
    // 때마다 한도가 되살아나서 사실상 한도가 없는 것과 같다.
    final i = ads.indexOf('Future<void> _noteShown()');
    final body = ads.substring(i, i + 500);
    expect(body.contains('setInt'), isTrue,
        reason: '오늘 띄운 횟수를 저장하지 않는다 — 껐다 켜면 한도가 되살아난다');

    // 실제로 띄우는 자리에서 한도를 봐야 한다.
    final j = ads.indexOf('static void showIfReady()');
    final show = ads.substring(j, j + 400);
    expect(show.contains('_quotaLeft'), isTrue,
        reason: '띄우는 자리에서 한도를 안 본다');
  });

  test('광고 숫자들은 빌드할 때 바꿀 수 있다', () {
    // 광고가 과한지는 실기기에서만 알 수 있는데, 확인하려고 1시간을
    // 기다릴 수는 없다. 기본값은 그대로 두고 시험용 빌드만 줄인다.
    final ads = File('lib/services/full_screen_ads.dart').readAsStringSync();
    for (final k in const [
      'AD_AWAY_SECONDS',
      'AD_GRACE_SECONDS',
      'AD_DAILY_CAP',
    ]) {
      expect(ads.contains(k), isTrue, reason: '$k 를 빌드에서 못 바꾼다');
    }
  });
}
