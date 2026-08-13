import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // 리밸런싱 알림
  static const _channelId   = 'rebalancing_reminder';
  static const _channelName = 'Rebalancing Reminder';
  static const _keyEnabled   = 'notif_enabled';
  static const _keyFrequency = 'notif_frequency';
  static const _keyDay       = 'notif_day';
  static const _keyHour      = 'notif_hour';
  static const _keyMinute    = 'notif_minute';
  static const _notifId      = 1001;

  // 결산 알림
  static const _settlementChannelId   = 'settlement_reminder';
  static const _settlementChannelName = 'Settlement Reminder';
  static const _keySettlementWeekly    = 'settlement_notif_weekly';
  static const _keySettlementMonthly   = 'settlement_notif_monthly';
  static const _keySettlementQuarterly = 'settlement_notif_quarterly';
  static const _keySettlementYearly    = 'settlement_notif_yearly';
  static const _settlementWeeklyId  = 2001;
  static const _settlementMonthlyId = 2002;
  static const _settlementYearlyId  = 2007;
  static const _quarterlyIds    = [2003, 2004, 2005, 2006];
  static const _quarterlyMonths = [1, 4, 7, 10];
  static const _settlementHour  = 13;

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final prefs = await SharedPreferences.getInstance();

    // 리밸런싱 알림 복원
    if (prefs.getBool(_keyEnabled) != false) {
      await _schedule(prefs);
    }

    // 결산 알림 복원
    for (final type in ['weekly', 'monthly', 'quarterly', 'yearly']) {
      final key = _settlementKey(type);
      if (prefs.getBool(key) != false) {
        await _scheduleSettlement(type, prefs);
      }
    }
  }

  // ── 리밸런싱 알림 ──

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_keyEnabled) ?? true;

  static Future<String> getFrequency() async =>
      (await SharedPreferences.getInstance()).getString(_keyFrequency) ?? 'weekly';

  static Future<int> getDay() async =>
      (await SharedPreferences.getInstance()).getInt(_keyDay) ?? DateTime.monday;

  static Future<int> getHour() async =>
      (await SharedPreferences.getInstance()).getInt(_keyHour) ?? 13;

  static Future<int> getMinute() async =>
      (await SharedPreferences.getInstance()).getInt(_keyMinute) ?? 0;

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<void> enable(
    String frequency, {
    int day = DateTime.monday,
    int hour = 9,
    int minute = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
    await prefs.setString(_keyFrequency, frequency);
    await prefs.setInt(_keyDay, day);
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    await _schedule(prefs);
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    await _plugin.cancel(_notifId);
  }

  static Future<void> _schedule(SharedPreferences prefs) async {
    final frequency = prefs.getString(_keyFrequency) ?? 'weekly';
    final day    = prefs.getInt(_keyDay) ?? DateTime.monday;
    final hour   = prefs.getInt(_keyHour) ?? 9;
    final minute = prefs.getInt(_keyMinute) ?? 0;
    final isKo   = (prefs.getString('locale') ?? 'ko') == 'ko';

    await _plugin.cancel(_notifId);

    final title = isKo
        ? '리밸런싱 점검 시간이에요! 📊'
        : 'Time to check your portfolio! 📊';
    final body = isKo
        ? '지금 바로 포트폴리오를 확인해보세요.'
        : 'Run a quick rebalancing check today.';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        channelDescription: isKo ? '정기 리밸런싱 알림' : 'Periodic rebalancing reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    final now = tz.TZDateTime.now(tz.local);

    if (frequency == 'weekly') {
      await _plugin.zonedSchedule(
        _notifId, title, body,
        _nextWeekday(now, day, hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } else {
      await _plugin.zonedSchedule(
        _notifId, title, body,
        _nextDayOfMonth(now, day, hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  // ── 결산 알림 ──

  static String _settlementKey(String type) {
    switch (type) {
      case 'weekly':    return _keySettlementWeekly;
      case 'monthly':   return _keySettlementMonthly;
      case 'quarterly': return _keySettlementQuarterly;
      case 'yearly':    return _keySettlementYearly;
      default:          return _keySettlementWeekly;
    }
  }

  static Future<bool> isSettlementEnabled(String type) async =>
      (await SharedPreferences.getInstance()).getBool(_settlementKey(type)) ?? true;

  static Future<void> enableSettlement(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_settlementKey(type), true);
    await _scheduleSettlement(type, prefs);
  }

  static Future<void> disableAllSettlements() async {
    for (final t in ['weekly', 'monthly', 'quarterly', 'yearly']) {
      await disableSettlement(t);
    }
  }

  static Future<void> disableSettlement(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_settlementKey(type), false);
    switch (type) {
      case 'weekly':
        await _plugin.cancel(_settlementWeeklyId);
      case 'monthly':
        await _plugin.cancel(_settlementMonthlyId);
      case 'quarterly':
        for (final id in _quarterlyIds) {
          await _plugin.cancel(id);
        }
      case 'yearly':
        await _plugin.cancel(_settlementYearlyId);
    }
  }

  static Future<void> _scheduleSettlement(
      String type, SharedPreferences prefs) async {
    final isKo = (prefs.getString('locale') ?? 'ko') == 'ko';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _settlementChannelId, _settlementChannelName,
        channelDescription: isKo ? '정기 결산 알림' : 'Periodic settlement reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    final now = tz.TZDateTime.now(tz.local);

    switch (type) {
      case 'weekly':
        final title = isKo ? '주간 결산을 확인해보세요 📊' : 'Check last week\'s performance 📊';
        final body  = isKo ? '지난 한 주 포트폴리오 성과를 분석해보세요.' : 'Review your weekly portfolio performance.';
        await _plugin.cancel(_settlementWeeklyId);
        await _plugin.zonedSchedule(
          _settlementWeeklyId, title, body,
          _nextWeekday(now, DateTime.saturday, _settlementHour, 0),
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );

      case 'monthly':
        final title = isKo ? '월간 결산을 확인해보세요 📊' : 'Check last month\'s performance 📊';
        final body  = isKo ? '지난 달 포트폴리오 성과를 분석해보세요.' : 'Review your monthly portfolio performance.';
        await _plugin.cancel(_settlementMonthlyId);
        await _plugin.zonedSchedule(
          _settlementMonthlyId, title, body,
          _nextDayOfMonth(now, 1, _settlementHour, 0),
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );

      case 'quarterly':
        final title = isKo ? '분기 결산을 확인해보세요 📊' : 'Check last quarter\'s performance 📊';
        final body  = isKo ? '지난 분기 포트폴리오 성과를 분석해보세요.' : 'Review your quarterly portfolio performance.';
        for (var i = 0; i < _quarterlyIds.length; i++) {
          await _plugin.cancel(_quarterlyIds[i]);
          await _plugin.zonedSchedule(
            _quarterlyIds[i], title, body,
            _nextSpecificDate(_quarterlyMonths[i], 1, _settlementHour, 0),
            details,
            androidScheduleMode: AndroidScheduleMode.inexact,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dateAndTime,
          );
        }

      case 'yearly':
        final title = isKo ? '연간 결산을 확인해보세요 📊' : 'Check last year\'s performance 📊';
        final body  = isKo ? '지난 한 해 포트폴리오 성과를 분석해보세요.' : 'Review your yearly portfolio performance.';
        await _plugin.cancel(_settlementYearlyId);
        await _plugin.zonedSchedule(
          _settlementYearlyId, title, body,
          _nextSpecificDate(1, 1, _settlementHour, 0),
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
    }
  }

  // ── 헬퍼 ──

  static tz.TZDateTime _nextWeekday(
      tz.TZDateTime from, int weekday, int hour, int minute) {
    var dt = tz.TZDateTime(tz.local, from.year, from.month, from.day, hour, minute);
    while (dt.weekday != weekday || !dt.isAfter(from)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  static tz.TZDateTime _nextDayOfMonth(
      tz.TZDateTime from, int day, int hour, int minute) {
    try {
      var dt = tz.TZDateTime(tz.local, from.year, from.month, day, hour, minute);
      if (!dt.isAfter(from)) {
        final next = from.month < 12
            ? DateTime(from.year, from.month + 1, day, hour, minute)
            : DateTime(from.year + 1, 1, day, hour, minute);
        dt = tz.TZDateTime(
            tz.local, next.year, next.month, next.day, next.hour, next.minute);
      }
      return dt;
    } catch (_) {
      final next = from.month < 12
          ? DateTime(from.year, from.month + 1, 1, hour, minute)
          : DateTime(from.year + 1, 1, 1, hour, minute);
      return tz.TZDateTime(
          tz.local, next.year, next.month, next.day, next.hour, next.minute);
    }
  }

  static tz.TZDateTime _nextSpecificDate(
      int month, int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var dt = tz.TZDateTime(tz.local, now.year, month, day, hour, minute);
    if (!dt.isAfter(now)) {
      dt = tz.TZDateTime(tz.local, now.year + 1, month, day, hour, minute);
    }
    return dt;
  }
}
