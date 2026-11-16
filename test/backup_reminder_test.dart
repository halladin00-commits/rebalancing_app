import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/models/portfolio.dart';
import 'package:rebalancing_app/widgets/backup_reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기록은 폰 한 곳에만 있다. 백업이 오래됐으면 첫 화면이 알린다 —
/// 다만 방금 깐 사람을 조르지 않고, 「나중에」를 누르면 한동안 조용히 있는다.
void main() {
  final now = DateTime(2026, 11, 17, 9);
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  bool due({DateTime? first, DateTime? backup, DateTime? snooze}) =>
      backupReminderDue(
          now: now,
          firstTransaction: first,
          lastBackup: backup,
          snoozedUntil: snooze);

  group('알릴 때인가', () {
    test('거래가 없으면 지킬 것이 없다', () {
      expect(due(), isFalse);
    });

    test('방금 시작한 사람은 조르지 않는다 — 첫 거래가 7일은 지나야 한다', () {
      expect(due(first: daysAgo(6)), isFalse);
      expect(due(first: daysAgo(7)), isTrue);
    });

    test('한 번도 안 했으면 알린다', () {
      expect(due(first: daysAgo(400)), isTrue);
    });

    test('30일 안에 했으면 조용하고, 넘으면 알린다', () {
      expect(due(first: daysAgo(400), backup: daysAgo(29)), isFalse);
      expect(due(first: daysAgo(400), backup: daysAgo(30)), isTrue);
    });

    test('「나중에」를 누르면 그날까지는 조용하다', () {
      final until = now.add(const Duration(days: 3));
      expect(due(first: daysAgo(400), snooze: until), isFalse);
      expect(due(first: daysAgo(400), snooze: daysAgo(1)), isTrue);
    });
  });

  Portfolio pf(DateTime txDate) => Portfolio(id: 'p', name: 'p', items: [
        PortfolioItem(id: 'a', name: 'a', transactions: [
          StockTransaction(id: 't', date: txDate, quantity: 1, price: 100),
        ])
          ..syncFromTransactions(),
      ]);

  test('가장 이른 거래 날짜 — 거래가 없으면 null', () {
    expect(firstTransactionDate([Portfolio(id: 'p', name: 'p', items: [])]),
        isNull);
    expect(firstTransactionDate([pf(daysAgo(3)), pf(daysAgo(90))]),
        daysAgo(90));
  });

  Widget host(List<Portfolio> portfolios) => MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: Scaffold(body: BackupReminder(portfolios: portfolios)),
      );

  final old = DateTime.now().subtract(const Duration(days: 60));

  testWidgets('오래 쓴 사람이 백업한 적이 없으면 알림이 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host([pf(old)]));
    await tester.pumpAndSettle();
    expect(find.text('아직 백업한 적이 없습니다'), findsOneWidget);
    expect(find.text('지금 백업'), findsOneWidget);
  });

  testWidgets('최근에 백업했으면 자리를 차지하지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_backup_at_v1': DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch,
    });
    await tester.pumpWidget(host([pf(old)]));
    await tester.pumpAndSettle();
    expect(find.text('지금 백업'), findsNothing);
    expect(tester.getSize(find.byType(BackupReminder)).height, 0);
  });

  testWidgets('며칠 지났는지 적는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_backup_at_v1': DateTime.now()
          .subtract(const Duration(days: 45, hours: 1))
          .millisecondsSinceEpoch,
    });
    await tester.pumpWidget(host([pf(old)]));
    await tester.pumpAndSettle();
    expect(find.text('백업한 지 45일 지났습니다'), findsOneWidget);
  });

  testWidgets('「나중에」를 누르면 사라지고, 다시 켜도 14일은 안 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host([pf(old)]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(find.text('지금 백업'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('backup_reminder_snooze_until_v1')!);
    expect(until.difference(DateTime.now()).inDays, inInclusiveRange(13, 14));

    // 앱을 다시 켠 것처럼 새로 세운다
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host([pf(old)]));
    await tester.pumpAndSettle();
    expect(find.text('지금 백업'), findsNothing);
  });

  test('첫 화면이 이 알림을 싣는다', () {
    expect(
        File('lib/screens/portfolio_list_screen.dart').readAsStringSync(),
        contains('BackupReminder(portfolios:'));
  });
}
