import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 리밸런싱 포트 화면의 **아래쪽 배치**를 지킨다.
///
/// 무슨 일이 있었나
///   「조정 제안 보기」 버튼이 본문 끝, 배너 광고가 그 아래였다. 광고가
///   안 붙는 날에는 광고 자리가 사라지면서 **버튼이 아래로 툭 내려간다.**
///
///   쓰는 사람에게는 광고 사정이 안 보인다. 버튼이 혼자 움직이는 것으로만
///   읽히고, 그 순간 앱이 어설퍼 보인다.
///
///   `bottomNavigationBar`의 마지막 자식은 늘 화면 맨 아래다. 버튼을 거기
///   두면 광고가 붙든 말든 자리가 그대로고, 대신 본문이 밀린다.
void main() {
  test('버튼이 화면 맨 아래에 못 박혀 있다', () {
    final s =
        File('lib/screens/portfolio_rebalance_screen.dart').readAsStringSync();

    final iBottom = s.indexOf('bottomNavigationBar:');
    final iBody = s.indexOf('body:', iBottom);
    final iCta = s.indexOf('_buildCta(context');

    expect(iBottom, isNot(-1));
    expect(iBody, isNot(-1), reason: 'bottomNavigationBar 뒤에 body가 없다');
    expect(iCta, isNot(-1), reason: '버튼을 만드는 곳을 못 찾았다');

    expect(iCta, greaterThan(iBottom),
        reason: '버튼이 bottomNavigationBar 밖에 있다 — 광고가 없어지면 내려간다');
    expect(iCta, lessThan(iBody),
        reason: '버튼이 본문 안에 있다 — 광고가 없어지면 내려간다');
  });

  test('광고가 버튼 위에 있다', () {
    // 마지막 자식이 맨 아래다. 버튼이 마지막이어야 못 박힌다.
    final s =
        File('lib/screens/portfolio_rebalance_screen.dart').readAsStringSync();
    final iBanner = s.indexOf('BottomBannerAd(');
    final iCta = s.indexOf('_buildCta(context');
    expect(iBanner, lessThan(iCta),
        reason: '버튼이 광고보다 위다 — 그러면 광고 유무에 따라 버튼이 움직인다');
  });

  test('버튼과 광고 사이에 선이 있다', () {
    // 광고와 버튼이 맞닿으면 누르려다 광고를 누른다. 구글도 버튼 바로
    // 옆·아래에 광고를 두지 말라고 한다. 경계를 눈에 보이게 둔다.
    final s =
        File('lib/screens/portfolio_rebalance_screen.dart').readAsStringSync();
    final i = s.indexOf('Widget _buildCta');
    final body = s.substring(i, i + 500);
    expect(body.contains('Border('), isTrue,
        reason: '버튼 상자에 경계선이 없다 — 광고와 맞닿아 보인다');
  });
}
