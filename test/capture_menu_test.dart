import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/widgets/app_menu.dart';

/// 우상단 [캡처]는 **버튼 바로 아래에서** 펼쳐진다.
///
/// 예전에는 화면 아래에서 시트가 올라왔다. 바로 옆 ⋮ 메뉴는 버튼 밑에서
/// 열리는데 캡처만 반대편 끝에서 열리니, 나란히 붙은 두 버튼이 서로 다르게
/// 동작했다. 게다가 시트는 하단 네비바에 가려지는 함정이 따로 있어서
/// 실제로 한 번 당했다.
void main() {
  Widget host(Widget child) => MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: AppBar(actions: [child])),
      );

  testWidgets('누르면 저장·공유 두 줄이 나온다', (tester) async {
    var saved = 0, shared = 0;
    await tester.pumpWidget(host(CaptureMenu(
      onSave: () => saved++,
      onShare: () => shared++,
    )));

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(find.text('이미지 저장'), findsOneWidget);
    expect(find.text('이미지 공유'), findsOneWidget);

    await tester.tap(find.text('이미지 저장'));
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(shared, 0);
  });

  testWidgets('만드는 중에는 뱅글이가 돌고 다시 안 눌린다', (tester) async {
    var saved = 0;
    await tester.pumpWidget(host(CaptureMenu(
      busy: true,
      onSave: () => saved++,
      onShare: () {},
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsNothing);

    // 뱅글이가 끝없이 돌므로 pumpAndSettle은 안 끝난다. 몇 프레임만 돌린다.
    await tester.tap(find.byType(CaptureMenu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('이미지 저장'), findsNothing,
        reason: '만드는 중에 또 누르면 두 번 만든다');
    expect(saved, 0);
  });

  test('캡처를 바텀시트로 여는 화면이 남아 있지 않다', () {
    // 화면 하나만 고치고 나머지를 「같은 구성이니 됐겠지」로 넘기면
    // 어디는 아래에서 올라오고 어디는 버튼 밑에서 열리게 된다.
    for (final f in Directory('lib/screens').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      expect(s.contains('_showCaptureSheet'), isFalse,
          reason: '${f.path} 가 캡처를 아직 시트로 연다');
      expect(s.contains('_showMainCaptureSheet'), isFalse,
          reason: '${f.path} 가 캡처를 아직 시트로 연다');
    }
  });
}
