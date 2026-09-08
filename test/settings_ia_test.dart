import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/services/notification_service.dart';
import 'package:rebalancing_app/widgets/time_wheel_sheet.dart';

void main() {
  /// 주석에서는 「쓰면 안 된다」고 설명하므로, 코드 줄만 본다.
  String codeOf(String path) => LineSplitter.split(File(path).readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//'))
      .join(' ');

  group('더보기 탭에는 앱 전체 설정만 둔다', () {
    final more = codeOf('lib/screens/more_screen.dart');

    test('탭만 바꾸는 줄을 두지 않는다', () {
      // `포트폴리오 · 종목 관리`와 `목표 비중 · 허용 편차`는 눌러도 설정이
      // 열리지 않고 자산 탭·리밸런싱 탭으로 갈 뿐이었다. 하단 탭바로 한 번에
      // 가는 곳을 설정 목록에 또 늘어놓으면, 무엇을 설정하는 줄인지 한 번
      // 눌러 봐야 안다.
      expect(more.contains('onNavigateToTab'), isFalse,
          reason: '더보기에서 탭으로만 보내는 줄은 설정이 아니다');
    });

    test('계좌별 설정을 더보기에 두지 않는다', () {
      // 소수점 매매가 되는지는 증권사·계좌마다 다르다. 더보기에 있으면
      // 어느 계좌 이야기인지 화면에서 드러나지 않는다.
      expect(more.contains('FractionalSettingsScreen'), isFalse);
      final settings = codeOf('lib/screens/portfolio_settings_screen.dart');
      expect(settings.contains('fractionalEnabled'), isTrue,
          reason: '소수점 거래는 계좌 설정 화면에 있어야 한다');
      expect(settings.contains('fractionalRounding'), isTrue);
    });
  });

  group('결산 알림은 13시 고정', () {
    test('고를 수 있게 두지 않는다', () {
      expect(NotificationService.settlementHour, 13);
      expect(NotificationService.settlementMinute, 0);

      final screen = codeOf('lib/screens/notification_settings_screen.dart');
      expect(screen.contains('_pickSettlementTime'), isFalse,
          reason: '결산 알림 시각을 고르는 자리가 남아 있다');
      // 미국장 금요일 마감이 20~21시 UTC다. 13시면 어느 시간대에서 보든
      // 마감 뒤지만 9시로 당기면 UTC+13 이상에서 마감 전에 걸린다 —
      // 고를 수 있게 두면 틀린 값을 고를 수 있었다.
    });

    test('예전에 다른 시각을 골라 둔 사람의 예약을 옮기는 통로가 있다', () {
      // 시각을 고정해도 **이미 예약된 알림은 예전 시각 그대로 뜬다.**
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains('rescheduleSettlementsAtFixedHour'), isTrue,
          reason: '앱을 켤 때 옮기지 않으면 예전 시각 알림이 계속 온다');
    });
  });

  group('리밸런싱 알림 시각은 굴려서 고른다', () {
    testWidgets('오전·오후 / 시 / 분이 한 화면에 같이 있다', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: TimeWheelSheet(initial: TimeOfDay(hour: 9, minute: 0)),
        ),
      ));

      // 시계 다이얼은 시를 고르면 분 화면으로 넘어가는 두 단계였다.
      expect(find.text('오전'), findsOneWidget);
      expect(find.text('9'), findsWidgets);
      expect(find.text('00'), findsWidgets);
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
    });

    testWidgets('취소하면 아무것도 안 돌려준다', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => TimeWheelSheet.show(
                    context, const TimeOfDay(hour: 9, minute: 0)),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.byType(TimeWheelSheet), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(TimeWheelSheet), findsNothing);
    });

    test('시계 다이얼을 더는 쓰지 않는다', () {
      final screen = codeOf('lib/screens/notification_settings_screen.dart');
      expect(screen.contains('showTimePicker'), isFalse);
    });
  });

  test('편차 색은 방향이 아니라 「손봐야 하나」만 말한다', () {
    // 비중은 합이 100%로 묶여 있어 한 종목이 초과면 다른 종목은 반드시
    // 미달이다 — 열 종목이 전부 오른 날에도 절반은 미달로 나온다.
    // 방향에 손익 색을 쓰면 같은 줄에서 손익과 편차가 다른 색을 말한다.
    final s = codeOf('lib/screens/portfolio_rebalance_screen.dart');
    expect(s.contains('d.drift >= 0 ? context.danger'), isFalse,
        reason: '편차 색이 방향에 따라 갈린다');
  });
}
