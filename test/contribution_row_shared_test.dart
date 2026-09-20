import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/widgets/contribution_row.dart';

/// 기여 한 줄은 **화면과 캡처가 같은 위젯**을 써야 한다.
///
/// 일곱 번째로 어긋났을 때 만들었다. 캡처가 화면을 손으로 옮겨 적고 있어서,
/// 기여도 막대와 「기여 86% (+3.48%p)」가 통째로 빠진 채 그림이 나갔다.
/// 글자 크기와 색도 조금씩 달랐다.
///
/// 이런 차이는 **예외도 로그도 안 남는다.** 앱에서 그림을 꺼내 화면과
/// 나란히 놓고 봐야 안다. 그래서 매번 사용자가 먼저 찾았다.
void main() {
  group('캡처 판이 기여 줄을 따로 그리지 않는다', () {
    final source =
        File('lib/widgets/settlement_capture_card.dart').readAsStringSync();

    /// `_row` 본문만 잘라 낸다.
    ///
    /// **매개변수의 중괄호를 본문으로 착각하면 안 된다.** `{required bool
    /// isLast}`가 먼저 나와서, 그냥 첫 `{`를 잡으면 본문이 아니라 그 한 줄만
    /// 잘린다. 그러면 무엇을 찾든 「없다」가 나와 시험이 거짓으로 통과한다 —
    /// 실제로 처음 이렇게 짰다가 TextStyle 검사가 엉뚱하게 통과했다.
    String rowBody() {
      final start = source.indexOf('Widget _row(');
      expect(start, isNot(-1), reason: '_row 를 못 찾았다 — 이름이 바뀌었나');
      final open = source.indexOf(') {', start) + 2;
      expect(open, greaterThan(start), reason: '본문 여는 자리를 못 찾았다');
      var depth = 0;
      for (var k = open; k < source.length; k++) {
        if (source[k] == '{') depth++;
        if (source[k] == '}') {
          depth--;
          if (depth == 0) return source.substring(open, k);
        }
      }
      fail('_row 본문을 못 잘랐다');
    }

    test('공용 위젯을 부른다', () {
      expect(rowBody(), contains('ContributionRow('),
          reason: '캡처가 기여 줄을 직접 그리고 있다. 화면이 쓰는 위젯을 부를 것');
    });

    test('글자 모양을 스스로 정하지 않는다', () {
      // 손으로 옮겨 적기 시작하는 자리가 늘 여기다 — 크기·굵기·색을
      // 캡처에서 따로 쓰면 화면과 조금씩 벌어진다.
      expect(rowBody(), isNot(contains('TextStyle(')),
          reason: '캡처가 글자 모양을 따로 정하고 있다. 화면과 어긋난다');
    });

    test('막대와 기여도를 넘겨준다', () {
      final body = rowBody();
      expect(body, contains('share:'), reason: '막대 길이가 안 넘어간다');
      expect(body, contains('contribution:'), reason: '기여 %p가 안 넘어간다');
    });
  });

  group('기여 줄이 실제로 그리는 것', () {
    Widget host({required bool tappable}) => MaterialApp(
          home: Scaffold(
            body: ContributionRow(
              name: 'TIME 미국나스닥100액티브',
              absoluteReturn: 11859540,
              returnRate: 5.06,
              rateAvailable: true,
              startValue: 234441900,
              endValue: 246301440,
              share: 0.86,
              contribution: 3.48,
              currency: 'KRW',
              isKo: true,
              positiveColor: const Color(0xFF0E7C5A),
              negativeColor: const Color(0xFFB4442A),
              onTap: tappable ? () {} : null,
            ),
          ),
        );

    testWidgets('기여 막대와 「기여 86% (+3.48%p)」가 들어 있다', (tester) async {
      await tester.pumpWidget(host(tappable: false));

      expect(find.text('기여 86% (+3.48%p)'), findsOneWidget,
          reason: '캡처에서 통째로 빠져 있던 줄이다');

      // 막대는 색 칸 두 개(찬 쪽 + 트랙)로 그린다
      final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(boxes.length, greaterThanOrEqualTo(2), reason: '기여도 막대가 없다');
    });

    testWidgets('근거 줄과 금액·수익률이 들어 있다', (tester) async {
      await tester.pumpWidget(host(tappable: false));
      expect(find.text('+5.06%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget,
          reason: '「얼마 → 얼마」의 화살표');
    });

    testWidgets('캡처에는 화살표를 두지 않는다 — 그림에서는 못 누른다', (tester) async {
      await tester.pumpWidget(host(tappable: false));
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.pumpWidget(host(tappable: true));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget,
          reason: '화면에서는 눌러 들어가므로 화살표가 있어야 한다');
    });
  });
}
