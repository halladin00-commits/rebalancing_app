import 'package:flutter/foundation.dart';
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

  /// 「말일」을 고른 경우에 쓰는 자리들.
  ///
  /// 말일은 달마다 날짜가 달라서(28·29·30·31) 「매월 n일」 반복으로는 못
  /// 나타낸다. 그래서 앞으로 열두 달치를 **하나씩** 미리 잡아 둔다.
  /// 앱을 켤 때마다 `initialize`가 다시 채우므로, 쓰는 동안에는 늘 1년치가
  /// 앞서 잡혀 있다.
  static const _monthEndIds = [
    1010, 1011, 1012, 1013, 1014, 1015,
    1016, 1017, 1018, 1019, 1020, 1021,
  ];

  /// 「매월 말일」을 뜻하는 값. 1~28과 겹치지 않는 수면 된다.
  static const lastDayOfMonth = 99;

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
  /// 결산 알림은 **13시 고정**이다.
  ///
  /// 예전에는 고를 수 있었는데, 다르게 쓸 이유가 없으면서 틀린 값을 고를
  /// 수는 있었다. 미국장 금요일 마감이 20~21시 UTC라 13시면 어느 시간대에서
  /// 보든 마감 뒤지만, 9시로 당기면 UTC+13 이상에서 마감 전에 걸린다.
  ///
  /// 예전 판에서 다른 시각을 골라 둔 사람이 있으므로, 켜져 있는 알림은
  /// [rescheduleSettlementsAtFixedHour]가 앱을 켤 때 13시로 다시 잡는다.
  static const settlementHour   = 13;
  static const settlementMinute = 0;

  /// 예전 판이 쓰던 키. 지금은 **읽지도 쓰지도 않는다.**
  /// 되돌릴 일이 있을까 봐 지우지는 않는다.
  static const _keySettlementHourLegacy = 'settlement_notif_hour';

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
      // 상태바 아이콘은 **알파만** 쓴다. 컬러 런처 아이콘을 그대로 넘기면
      // 안드로이드 5 이상에서 실루엣만 남아 **흰 덩어리**로 뭉갠다 —
      // 지금까지 알림에 정체 모를 흰 동그라미가 뜨던 이유다.
      android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        _pending = resp.payload;
        tapped.value = resp.payload;
      },
    );

    // 앱이 꺼져 있다가 알림으로 켜졌으면 위 콜백보다 화면이 늦게 뜬다.
    // 그때는 여기서 읽어 둬야 눌러서 들어온 사실이 사라지지 않는다.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pending = launch!.notificationResponse?.payload;
    }

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

  // ── 눌러서 들어온 길 ──
  //
  // 알림을 눌렀는데 그냥 앱이 열리기만 하면, 무엇을 보라고 부른 건지 사용자가
  // 다시 찾아 들어가야 한다. 어느 알림이었는지 payload에 싣고, 화면이 준비되면
  // 그 자리로 데려간다.

  /// 리밸런싱 점검 알림.
  static const payloadRebalance = 'rebalance';

  /// 결산 알림. `settlement:weekly` 처럼 종류를 붙인다.
  static const payloadSettlementPrefix = 'settlement:';

  static String? _pending;

  /// 앱이 떠 있을 때 누른 경우. 셸이 듣고 있다가 옮겨 간다.
  static final ValueNotifier<String?> tapped = ValueNotifier<String?>(null);

  /// 꺼져 있다가 알림으로 켜진 경우. **한 번만** 가져간다.
  static String? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }


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
    await _cancelRebalance();
  }

  /// 리밸런싱 알림 자리를 모두 비운다.
  ///
  /// 말일은 열두 자리를 쓴다. 하나만 지우면 나머지 열한 개가 살아남아,
  /// 껐는데도 계속 울린다.
  static Future<void> _cancelRebalance() async {
    await _plugin.cancel(_notifId);
    for (final id in _monthEndIds) {
      await _plugin.cancel(id);
    }
  }

  static Future<void> _schedule(SharedPreferences prefs) async {
    final frequency = prefs.getString(_keyFrequency) ?? 'weekly';
    final day    = prefs.getInt(_keyDay) ?? DateTime.monday;
    final hour   = prefs.getInt(_keyHour) ?? 9;
    final minute = prefs.getInt(_keyMinute) ?? 0;
    final isKo   = (prefs.getString('locale') ?? 'ko') == 'ko';

    await _cancelRebalance();

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
        payload: payloadRebalance,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } else if (day == lastDayOfMonth) {
      // 말일은 달마다 날짜가 달라 「매월 n일」 반복으로 못 잡는다.
      // 열두 달치를 하나씩 놓는다.
      var at = nextDayOfMonth(now, day, hour, minute);
      for (final id in _monthEndIds) {
        await _plugin.zonedSchedule(
          id, title, body, at, details,
          payload: payloadRebalance,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        at = nextDayOfMonth(at, day, hour, minute);
      }
    } else {
      await _plugin.zonedSchedule(
        _notifId, title, body,
        nextDayOfMonth(now, day, hour, minute),
        details,
        payload: payloadRebalance,
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

  /// 예전 판에서 13시가 아닌 시각을 골라 둔 사람의 알림을 다시 잡는다.
  ///
  /// 시각을 고정해도 **이미 예약된 알림은 예전 시각 그대로 뜬다.** 앱을
  /// 켤 때 한 번 훑어서 옮긴다. 옮기고 나면 예전 키를 지워 다시 안 돈다.
  static Future<void> rescheduleSettlementsAtFixedHour() async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getInt(_keySettlementHourLegacy);
    if (old == null) return;
    for (final t in settlementTypes) {
      if (prefs.getBool(_settlementKey(t)) == true) {
        await _scheduleSettlement(t, prefs);
      }
    }
    await prefs.remove(_keySettlementHourLegacy);
    await prefs.remove('settlement_notif_minute');
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
    const h = settlementHour;
    const m = settlementMinute;

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
        final title = isKo ? '주간 결산이 나왔어요 📊' : 'Your week is in 📊';
        final body  = isKo ? '결산 탭에서 확인해 보세요.' : 'Open the Returns tab to see it.';
        await _plugin.cancel(_settlementWeeklyId);
        await _plugin.zonedSchedule(
          _settlementWeeklyId, title, body,
          // 달력으로는 일요일에 끝나지만, **숫자는 금요일 마감에 이미 굳는다.**
          // 주말에는 국내장도 미국장도 열리지 않아 토요일에 봐도 값이 같다.
          // 주말을 맞으며 지난 주를 돌아보는 자리가 더 맞다.
          //
          // 기본 13시면 어느 시간대에서 보든 미국 금요일 마감(20~21시 UTC)
          // 뒤다. 9시로 당기면 UTC+13 이상에서만 마감 전에 걸린다.
          nextWeekday(now, DateTime.saturday, h, m),
          details,
          payload: '$payloadSettlementPrefix$type',
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );

      case 'monthly':
        final title = isKo ? '지난달 결산이 나왔어요 📊' : 'Last month is in 📊';
        final body  = isKo ? '결산 탭에서 확인해 보세요.' : 'Open the Returns tab to see it.';
        await _plugin.cancel(_settlementMonthlyId);
        await _plugin.zonedSchedule(
          _settlementMonthlyId, title, body,
          nextDayOfMonth(now, 1, h, m),
          details,
          payload: '$payloadSettlementPrefix$type',
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );

      case 'quarterly':
        final title = isKo ? '지난 분기 결산이 나왔어요 📊' : 'Last quarter is in 📊';
        final body  = isKo ? '결산 탭에서 확인해 보세요.' : 'Open the Returns tab to see it.';
        for (var i = 0; i < _quarterlyIds.length; i++) {
          await _plugin.cancel(_quarterlyIds[i]);
          await _plugin.zonedSchedule(
            _quarterlyIds[i], title, body,
            nextSpecificDate(_quarterlyMonths[i], 1, h, m),
            details,
            payload: '$payloadSettlementPrefix$type',
            androidScheduleMode: AndroidScheduleMode.inexact,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dateAndTime,
          );
        }

      case 'yearly':
        final title = isKo ? '작년 결산이 나왔어요 📊' : 'Last year is in 📊';
        final body  = isKo ? '결산 탭에서 확인해 보세요.' : 'Open the Returns tab to see it.';
        await _plugin.cancel(_settlementYearlyId);
        await _plugin.zonedSchedule(
          _settlementYearlyId, title, body,
          nextSpecificDate(1, 1, h, m),
          details,
          payload: '$payloadSettlementPrefix$type',
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

  /// 그 달의 마지막 날짜 (28·29·30·31).
  ///
  /// 「다음 달 0일」은 이번 달 마지막 날이다 — 윤년까지 달력이 알아서 센다.
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// [from] 뒤의 가장 가까운 매월 [day]일 [hour]:[minute].
  ///
  /// [day]가 [lastDayOfMonth]면 그 달의 **마지막 날**로 잡는다.
  ///
  /// **없는 날짜를 넘기지 말 것.** 31일을 달라고 하면 Dart가 조용히 다음 달로
  /// 넘겨 버려서(2월 31일 → 3월 3일), 사용자가 고른 날과 다른 날에 울린다.
  /// 그래서 화면에서는 1~28일과 「말일」만 고르게 한다.
  static tz.TZDateTime nextDayOfMonth(
      tz.TZDateTime from, int day, int hour, int minute) {
    int dayIn(int year, int month) =>
        day == lastDayOfMonth ? daysInMonth(year, month) : day;
    try {
      var dt = tz.TZDateTime(tz.local, from.year, from.month,
          dayIn(from.year, from.month), hour, minute);
      if (!dt.isAfter(from)) {
        final y = from.month < 12 ? from.year : from.year + 1;
        final m = from.month < 12 ? from.month + 1 : 1;
        dt = tz.TZDateTime(tz.local, y, m, dayIn(y, m), hour, minute);
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
