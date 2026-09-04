import 'package:flutter/services.dart';
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
  static const _keySettlementHour   = 'settlement_notif_hour';
  static const _keySettlementMinute = 'settlement_notif_minute';

  /// 첫 실행에 권한을 물어봤는가.
  ///
  /// 예전에는 기본값이 **켬**인데 권한은 안 물어봤다. 그래서 설정 화면은
  /// 켜져 있다고 하는데 알림은 한 번도 오지 않았고, **껐다 다시 켜야**
  /// 시스템이 권한을 물었다. 스위치가 사실과 다른 상태였다.
  static const _keyPermissionAsked = 'notif_permission_asked_v1';

  /// 시스템 알림 설정을 여는 통로. 권한을 두 번 거부하면 안드로이드가
  /// 더 이상 창을 띄우지 않아서, 직접 보내주는 수밖에 없다.
  static const _channel = MethodChannel('com.xaxavoo.rebalancing/settings');

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final prefs = await SharedPreferences.getInstance();

    // **켜 둔 것만** 되살린다. 예전에는 값이 없으면 켠 것으로 쳤는데,
    // 권한을 물어본 적이 없어 실제로는 아무것도 오지 않았다.
    if (prefs.getBool(_keyEnabled) == true) {
      await _schedule(prefs);
    }
    for (final type in settlementTypes) {
      if (prefs.getBool(_settlementKey(type)) == true) {
        await _scheduleSettlement(type, prefs);
      }
    }
  }

  static const settlementTypes = ['weekly', 'monthly', 'quarterly', 'yearly'];

  // ── 권한 ──

  /// 첫 실행에 한 번 묻고, 답에 따라 기본값을 정한다.
  ///
  /// 허용하면 켠 채로, 거부하면 끈 채로 시작한다. **스위치가 켜져 있는데
  /// 알림은 안 오는 상태**를 만들지 않는 것이 핵심이다. 거부한 사람이
  /// 나중에 스위치를 켜면 그때 시스템이 다시 묻는다.
  ///
  /// 이미 쓰던 사람의 선택은 건드리지 않는다 — 값이 없는 항목만 채운다.
  static Future<bool> setUpOnFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyPermissionAsked) == true) return await isGranted();

    final granted = await requestPermission();
    await prefs.setBool(_keyPermissionAsked, true);

    if (!prefs.containsKey(_keyEnabled)) {
      await prefs.setBool(_keyEnabled, granted);
    }
    for (final t in settlementTypes) {
      final k = _settlementKey(t);
      if (!prefs.containsKey(k)) await prefs.setBool(k, granted);
    }

    if (prefs.getBool(_keyEnabled) == true) await _schedule(prefs);
    for (final t in settlementTypes) {
      if (prefs.getBool(_settlementKey(t)) == true) {
        await _scheduleSettlement(t, prefs);
      }
    }
    return granted;
  }

  /// 시스템에서 이 앱의 알림이 켜져 있는가.
  ///
  /// 앱 안의 스위치와 별개다. 사용자가 휴대폰 설정에서 꺼 버리면 앱은
  /// 켜져 있다고 믿는 채로 아무것도 못 보낸다 — 화면에서 알려줘야 한다.
  static Future<bool> isGranted() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  /// 이 앱의 시스템 알림 설정 화면을 연다.
  static Future<void> openSystemSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {
      // 못 열어도 앱은 멀쩡하다 — 사용자가 직접 찾아가는 수밖에
    }
  }

  // ── 리밸런싱 알림 ──

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_keyEnabled) ?? false;

  static Future<String> getFrequency() async =>
      (await SharedPreferences.getInstance()).getString(_keyFrequency) ?? 'weekly';

  static Future<int> getDay() async =>
      (await SharedPreferences.getInstance()).getInt(_keyDay) ?? DateTime.monday;

  static Future<int> getHour() async =>
      (await SharedPreferences.getInstance()).getInt(_keyHour) ?? 9;

  static Future<int> getMinute() async =>
      (await SharedPreferences.getInstance()).getInt(_keyMinute) ?? 0;

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// 안 넘긴 값은 **그대로 둔다.**
  ///
  /// 예전에는 기본값으로 덮어써서, 주기만 바꿔도 사용자가 고른 요일·시간이
  /// 월요일 9시로 되돌아갔다.
  static Future<void> enable(
    String frequency, {
    int? day,
    int? hour,
    int? minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
    await prefs.setString(_keyFrequency, frequency);
    if (day != null) await prefs.setInt(_keyDay, day);
    if (hour != null) await prefs.setInt(_keyHour, hour);
    if (minute != null) await prefs.setInt(_keyMinute, minute);
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
        nextWeekday(now, day, hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } else {
      await _plugin.zonedSchedule(
        _notifId, title, body,
        nextDayOfMonth(now, day, hour, minute),
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

  /// 결산 알림 시각. 네 가지에 같이 적용된다 — 종류마다 따로 두면
  /// 고를 것만 늘고, 실제로 다르게 쓸 이유가 없다.
  static Future<int> getSettlementHour() async =>
      (await SharedPreferences.getInstance()).getInt(_keySettlementHour) ?? 9;

  static Future<int> getSettlementMinute() async =>
      (await SharedPreferences.getInstance()).getInt(_keySettlementMinute) ?? 0;

  /// 시각을 바꾸고, 켜져 있는 알림을 새 시각으로 다시 예약한다.
  static Future<void> setSettlementTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySettlementHour, hour);
    await prefs.setInt(_keySettlementMinute, minute);
    for (final t in settlementTypes) {
      if (prefs.getBool(_settlementKey(t)) == true) {
        await _scheduleSettlement(t, prefs);
      }
    }
  }

  static Future<bool> isSettlementEnabled(String type) async =>
      (await SharedPreferences.getInstance()).getBool(_settlementKey(type)) ?? false;

  static Future<void> enableSettlement(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_settlementKey(type), true);
    await _scheduleSettlement(type, prefs);
  }

  static Future<void> disableAllSettlements() async {
    for (final t in settlementTypes) {
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
    final h = prefs.getInt(_keySettlementHour) ?? 9;
    final m = prefs.getInt(_keySettlementMinute) ?? 0;

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
          // 주 결산은 월~일이다. **토요일은 아직 그 주가 안 끝났다** —
          // 다 끝난 다음 날인 월요일에 알린다.
          nextWeekday(now, DateTime.monday, h, m),
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
          nextDayOfMonth(now, 1, h, m),
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
            nextSpecificDate(_quarterlyMonths[i], 1, h, m),
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
          nextSpecificDate(1, 1, h, m),
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
    }
  }

  // ── 헬퍼 ──

  /// [from] **뒤**의 가장 가까운 [weekday] 요일 [hour]:[minute].
  ///
  /// 같은 요일이라도 시각이 이미 지났으면 다음 주로 넘긴다.
  static tz.TZDateTime nextWeekday(
      tz.TZDateTime from, int weekday, int hour, int minute) {
    var dt = tz.TZDateTime(tz.local, from.year, from.month, from.day, hour, minute);
    while (dt.weekday != weekday || !dt.isAfter(from)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  /// [from] 뒤의 가장 가까운 매월 [day]일 [hour]:[minute].
  ///
  /// **없는 날짜를 넘기지 말 것.** 31일을 달라고 하면 Dart가 조용히 다음 달로
  /// 넘겨 버려서(2월 31일 → 3월 3일), 사용자가 고른 날과 다른 날에 울린다.
  /// 그래서 화면에서는 28일까지만 고르게 한다.
  static tz.TZDateTime nextDayOfMonth(
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

  static tz.TZDateTime nextSpecificDate(
      int month, int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var dt = tz.TZDateTime(tz.local, now.year, month, day, hour, minute);
    if (!dt.isAfter(now)) {
      dt = tz.TZDateTime(tz.local, now.year + 1, month, day, hour, minute);
    }
    return dt;
  }
}
