import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/widgets/collapsing_header.dart';

/// 헤더 축약은 눈으로만 보이는 버그가 나기 쉽다 — 예외도 안 나고 로그도
/// 안 남는다. 실기기에서 나온 증상을 그대로 숫자로 박아 둔다.
///
/// 헤더 높이를 직접 재는 대신 **헤더 바로 아래 내용이 어디에 있는지**를
/// 본다. 사용자가 실제로 보는 것이 그것이다 — 내용이 헤더 밑에 딱 붙어
/// 멈추는지, 헤더 밑으로 밀려 들어가 가려지는지.
void main() {
  const topInset = 0.0;
  const titleH = 50.0;
  const bodyH = 200.0;
  const maxExtent = topInset + titleH + bodyH; // 250
  const minExtent = topInset + titleH; // 50
  const range = maxExtent - minExtent; // 200 — 접히며 내주는 거리

  // testWidgets 기본 화면은 800x600이다.
  const viewport = 600.0;

  const contentKey = ValueKey('content');

  Widget app(ScrollController c, double contentHeight) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: c,
          slivers: [
            const SliverPersistentHeader(
              pinned: true,
              delegate: CollapsingHeaderDelegate(
                bodyHeight: bodyH,
                topInset: topInset,
                titleHeight: titleH,
                background: Color(0xFF123456),
                expandedTitle: Text('펼침'),
                collapsedTitle: Text('접힘'),
                body: SizedBox(height: bodyH),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(key: contentKey, height: contentHeight),
            ),
            const CollapseTailSliver(collapseRange: range),
          ],
        ),
      ),
    );
  }

  double contentTop(WidgetTester t) => t.getRect(find.byKey(contentKey)).top;

  group('빈 칸(CollapseTailSliver)', () {
    // 끝까지 접으려면 (화면 − 접힌헤더 − 내용)만큼 더 스크롤할 거리가 있어야
    // 한다. 그만큼 빈 칸을 넣으면 아래가 딱 그만큼 빈다 — 맞바꾸는 관계다.
    // 조금 모자랄 때만 채우고, 많이 모자라면 접히는 데까지만 접는다.
    const fillCap = range * CollapseTailSliver.maxFillRatio; // 70

    testWidgets('조금 모자라면 채워서 헤더가 끝까지 접힌다', (tester) async {
      // needed = 600 − 50 − 490 = 60 ≤ 70 → 채운다
      final c = ScrollController();
      await tester.pumpWidget(app(c, 490));
      await tester.pumpAndSettle();

      expect(c.position.maxScrollExtent, closeTo(range, 0.5));

      c.jumpTo(c.position.maxScrollExtent);
      await tester.pumpAndSettle();
      // 내용이 접힌 헤더 바로 밑에 선다 — 작으면 가려진 것, 크면 덜 접힌 것.
      expect(contentTop(tester), closeTo(minExtent, 0.5));
      c.dispose();
    });

    testWidgets('많이 모자라면 억지로 채우지 않는다 — 화면 절반이 빈다',
        (tester) async {
      // needed = 600 − 50 − 400 = 150 > 70 → 채우지 않는다
      const content = 400.0;
      final c = ScrollController();
      await tester.pumpWidget(app(c, content));
      await tester.pumpAndSettle();

      // 빈 칸 0 → 접히는 데까지만 (200 중 50)
      expect(fillCap, 70);
      expect(c.position.maxScrollExtent,
          closeTo(maxExtent + content - viewport, 0.5));
      expect(c.position.maxScrollExtent, lessThan(range));

      // 끝까지 밀어도 내용이 헤더 밑으로 가려지지는 않는다
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(contentTop(tester), greaterThanOrEqualTo(minExtent - 0.5));
      c.dispose();
    });

    testWidgets('내용이 길면 빈 칸을 넣지 않는다', (tester) async {
      final c = ScrollController();
      const content = 800.0;
      await tester.pumpWidget(app(c, content));
      await tester.pumpAndSettle();

      // 빈 칸 0 → maxExtent + 내용 − 화면
      expect(c.position.maxScrollExtent,
          closeTo(maxExtent + content - viewport, 0.5));
      c.dispose();
    });
  });

  group('접힘은 스크롤 위치만 따른다', () {
    testWidgets('같은 자리로 돌아오면 같은 모습이다', (tester) async {
      final c = ScrollController();
      await tester.pumpWidget(app(c, 800));
      await tester.pumpAndSettle();

      c.jumpTo(100);
      await tester.pumpAndSettle();
      final first = contentTop(tester);

      c.jumpTo(400); // 더 내려갔다가
      await tester.pumpAndSettle();
      c.jumpTo(100); // 같은 자리로 되돌아온다
      await tester.pumpAndSettle();

      // floating이면 「움직인 양」을 따라가서 이 둘이 달라진다 —
      // 같은 자리인데 접힌 정도가 그때그때 다르게 보였다.
      expect(contentTop(tester), closeTo(first, 0.5));
      c.dispose();
    });
  });

  group('HeaderBody — 스크롤 중 높이 변경은 미룬다', () {
    testWidgets('맨 위에서는 바로 반영한다', (tester) async {
      final c = ScrollController();
      await tester.pumpWidget(app(c, 800));
      await tester.pumpAndSettle();

      final body = HeaderBody(value: 100);
      expect(body.update(180, c), isTrue);
      expect(body.value, 180);
      c.dispose();
    });

    testWidgets('스크롤 중에는 미뤘다가 맨 위로 돌아올 때 반영한다', (tester) async {
      final c = ScrollController();
      await tester.pumpWidget(app(c, 800));
      await tester.pumpAndSettle();

      final body = HeaderBody(value: 100);
      c.jumpTo(150);
      await tester.pumpAndSettle();

      // 접히는 도중에 최대 높이가 바뀌면 접힘 비율과 실제 높이가 어긋난다.
      expect(body.update(180, c), isFalse);
      expect(body.value, 100, reason: '스크롤 중인데 바로 바꿨다');
      expect(body.flush(c), isFalse, reason: '아직 맨 위가 아니다');

      c.jumpTo(0);
      await tester.pumpAndSettle();
      expect(body.flush(c), isTrue);
      expect(body.value, 180);
      c.dispose();
    });

    testWidgets('차이가 미미하면 미뤄 둔 것도 없앤다', (tester) async {
      final c = ScrollController();
      await tester.pumpWidget(app(c, 800));
      await tester.pumpAndSettle();

      final body = HeaderBody(value: 100);
      c.jumpTo(150);
      await tester.pumpAndSettle();
      body.update(180, c); // 미뤄 둔다
      body.update(100.2, c); // 결국 원래 값과 같다
      c.jumpTo(0);
      await tester.pumpAndSettle();

      expect(body.flush(c), isFalse);
      expect(body.value, 100);
      c.dispose();
    });
  });
}
