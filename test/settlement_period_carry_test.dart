import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 결산에서 **보던 기간이 이어지는지** 지킨다.
///
/// 전체 결산에서 「37주」를 보다가 포트를 눌렀는데 이번 달이 뜨면, 방금
/// 본 숫자를 다시 찾아 들어가야 한다. **눌러서 들어간 곳은 누른 것의
/// 안쪽**이어야지 딴 데면 안 된다.
///
/// 눈으로는 「원래 그런가 보다」로 넘어가기 쉬운 종류다 — 틀린 화면이
/// 아니라 **엉뚱한 기간의 맞는 화면**이 뜨기 때문이다.
void main() {
  test('포트 결산이 기간을 넘겨받는다', () {
    final pf = File('lib/screens/portfolio_settlement_screen.dart')
        .readAsStringSync();
    expect(pf.contains('final SettlementPeriod? period;'), isTrue,
        reason: '기간을 넘겨받을 자리가 없다');
    expect(pf.contains('final PeriodKey? initialKey;'), isTrue,
        reason: '어느 주/달인지 넘겨받을 자리가 없다');

    // 받아만 두고 안 쓰면 소용없다.
    final i = pf.indexOf('void initState()');
    final body = pf.substring(i, i + 400);
    expect(body.contains('widget.period'), isTrue, reason: '받은 기간을 안 쓴다');
    expect(body.contains('widget.initialKey'), isTrue,
        reason: '받은 기간 키를 안 쓴다');
  });

  test('전체 결산이 보던 기간을 넘긴다', () {
    final all = File('lib/screens/all_settlement_screen.dart').readAsStringSync();
    final i = all.indexOf('PortfolioSettlementScreen(');
    expect(i, isNot(-1), reason: '포트 결산을 여는 곳을 못 찾았다');
    final call = all.substring(i, i + 300);
    expect(call.contains('period: _period'), isTrue,
        reason: '보던 기간 단위를 안 넘긴다 — 늘 이번 달이 뜬다');
    expect(call.contains('initialKey: _selected'), isTrue,
        reason: '보던 주/달을 안 넘긴다');
  });
}
