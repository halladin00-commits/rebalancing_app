import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/widgets/notification_primer.dart';

/// 알림 권한을 묻기 전에 뜨는 안내 창.
///
/// **첫 실행에 한 번뿐이라 눈으로 다시 보기 어렵다.** 앱을 지웠다 깔아야
/// 나오므로, 문구가 바뀌거나 흐름이 틀어져도 개발 중에는 알아채기 힘들다.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: child,
      );

  /// 창을 띄우고 사용자가 무엇을 눌렀는지 돌려받는다.
  Future<bool> tapAndGetAnswer(WidgetTester tester, String button) async {
    late bool answer;
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async => answer = await NotificationPrimer.askFirst(context),
        child: const Text('열기'),
      );
    })));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return answer;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('무엇을 보내는지 적혀 있다', (tester) async {
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => NotificationPrimer.askFirst(context),
        child: const Text('열기'),
      );
    })));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // **실제로 보내는 두 가지가 적혀야 한다.** 「유용한 소식을 보내드려요」
    // 같은 말로는 반사적으로 거부하는 사람을 돌려세우지 못한다.
    expect(find.textContaining('비중'), findsOneWidget);
    expect(find.textContaining('수익률'), findsOneWidget);

    // 반사적으로 거부하는 가장 큰 이유를 직접 없애 준다.
    expect(find.textContaining('광고'), findsOneWidget);

    // 거절이 **제대로 된 선택지로** 보여야 한다.
    expect(find.text('나중에'), findsOneWidget);
    expect(find.text('알림 받기'), findsOneWidget);
  });

  testWidgets('「알림 받기」를 누르면 시스템 창을 띄워도 된다고 답한다',
      (tester) async {
    expect(await tapAndGetAnswer(tester, '알림 받기'), isTrue);
  });

  testWidgets('「나중에」를 누르면 권한을 요청하지 않는다', (tester) async {
    // 안드로이드는 알림 권한 창을 **사실상 한 번만** 띄워 준다. 여기서
    // 거절한 사람에게 그 한 번을 써 버리면, 나중에 더보기에서 알림을 켜려
    // 할 때 시스템 창이 안 뜨고 조용히 실패한다.
    expect(await tapAndGetAnswer(tester, '나중에'), isFalse);
  });

  testWidgets('두 번째 실행부터는 다시 묻지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({'notif_primer_asked': true});

    late bool answer;
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () async =>
            answer = await NotificationPrimer.askFirst(context),
        child: const Text('열기'),
      );
    })));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 매번 물으면 그 자체가 성가신 알림이 된다.
    expect(find.text('알림 받기'), findsNothing);
    expect(answer, isFalse);
  });

  test('안내 없이 권한을 먼저 요청하지 않는다', () {
    // 첫 실행 흐름에서 안내를 빼고 `setUpOnFirstRun`만 남기면, 시스템 창이
    // 아무 설명 없이 먼저 뜬다. 그 순간이 **한 번뿐인 기회**다.
    final main = File('lib/main.dart').readAsStringSync();
    final i = main.indexOf('NotificationPrimer.askFirst');
    final j = main.indexOf('NotificationService.setUpOnFirstRun');
    expect(i, isNot(-1), reason: '첫 실행에 안내 창이 없다');
    expect(j, isNot(-1), reason: '권한 설정 호출이 없다');
    expect(i, lessThan(j), reason: '안내보다 권한 요청이 먼저다 — 순서가 뒤집혔다');
  });
}
