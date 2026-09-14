import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/widgets/brand_stat_tile.dart';

/// 손익 타일이 **한 벌만 존재하는지** 지킨다.
///
/// 무슨 일이 있었나
///   같은 모양의 타일을 네 군데가 각자 그리고 있었다 — 자산 탭·포트 상세·
///   종목 상세, 그리고 캡처. 배열을 두 줄로 고쳤는데 자산 탭만 바뀌고
///   나머지 셋이 세 줄로 남아, 화면을 옮길 때마다 다른 앱처럼 보였다.
///
///   **나란히 놓고 볼 일이 없어 눈으로는 안 걸린다.** 사용자가 폰에서
///   화면을 옮겨 다니다 찾았다. 같은 실수가 캡처에서도 따로 있었다.
void main() {
  /// 손익 타일이 있는 화면들. 새 화면이 생기면 여기에 더한다.
  const screens = [
    'lib/screens/portfolio_list_screen.dart',
    'lib/screens/portfolio_detail_screen.dart',
    'lib/screens/item_detail_screen.dart',
  ];

  test('화면이 손익 타일을 손으로 그리지 않는다', () {
    final offenders = <String>[];
    for (final path in screens) {
      final s = File(path).readAsStringSync();

      // 공용 위젯을 쓰고 있는가
      if (!s.contains('BrandStatTile(')) {
        offenders.add('$path — BrandStatTile 을 안 쓴다');
        continue;
      }
      // 옛 복사본의 흔적 — 딥그린 타일 배경을 직접 칠하는 곳
      if (s.contains('Colors.black.withValues(alpha: 0.10)')) {
        offenders.add('$path — 타일 배경을 직접 칠한다 (복사본이 남아 있다)');
      }
    }
    expect(offenders, isEmpty,
        reason: '손익 타일 복사본이다. 고치면 한 곳만 바뀌고 나머지가 남는다:\n'
            '  ${offenders.join('\n  ')}');
  });

  testWidgets('이름표와 퍼센트가 한 줄, 금액이 그 아래 오른쪽', (tester) async {
    // 배열이 세 줄로 되돌아가면 딥그린 헤더가 다시 화면의 3분의 1을 먹는다.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0E4F49),
        body: Row(children: [
          Expanded(
            child: BrandStatTile(
              label: '평가손익',
              amount: 205705773,
              pct: 14.86,
              currency: 'KRW',
              pnlColors: PnlColorNotifier(),
            ),
          ),
        ]),
      ),
    ));

    final label = tester.getRect(find.text('평가손익'));
    final pct = tester.getRect(find.text('+14.86%'));
    final amount = tester.getRect(find.textContaining('205,705,773'));

    // 이름표와 퍼센트는 같은 줄, 퍼센트가 오른쪽
    expect((label.center.dy - pct.center.dy).abs(), lessThan(2),
        reason: '이름표와 퍼센트가 다른 줄에 있다');
    expect(pct.left, greaterThan(label.left),
        reason: '퍼센트가 이름표 오른쪽에 있어야 한다');

    // 금액은 그 아래 줄
    expect(amount.top, greaterThan(label.bottom - 2),
        reason: '금액이 이름표 줄에 붙어 있다');

    // 금액은 오른쪽으로 맞춘다 — 두 타일의 값이 같은 선에 선다
    expect((amount.right - pct.right).abs(), lessThan(3),
        reason: '금액이 오른쪽 정렬이 아니다');
  });

  testWidgets('값이 없으면 두 자리 모두 「—」', (tester) async {
    // 살 때 값을 모르는 종목이 섞이면 손익을 못 낸다. 0으로 적으면
    // **손익이 0인 것처럼 보인다** — 그건 아는 값이다.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          Expanded(
            child: BrandStatTile(
              label: '평가손익',
              amount: null,
              pct: null,
              currency: 'KRW',
              pnlColors: PnlColorNotifier(),
            ),
          ),
        ]),
      ),
    ));

    expect(find.text('—'), findsNWidgets(2));
    expect(find.textContaining('0'), findsNothing,
        reason: '모르는 값을 0으로 적으면 안 된다');
  });
}
