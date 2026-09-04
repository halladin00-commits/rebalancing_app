import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../services/notification_service.dart';
import '../theme/design_system.dart';
import '../widgets/brand_header.dart';
import '../widgets/list_card.dart';

/// 알림 설정.
///
/// 개편 전에는 더보기의 `리밸런싱 알림`과 `결산 알림` 두 행이 **같은
/// 다이얼로그**를 열었고, 그 다이얼로그에는 결산 항목이 아예 없었다.
/// 즉 결산 알림은 값만 읽히고 켜고 끌 방법이 없었다. 한 화면으로 합친다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

/// 결산 알림 종류. 결산 탭의 기간 단위와 같다.
const _settlementTypes = ['weekly', 'monthly', 'quarterly', 'yearly'];

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loaded = false;
  bool _rebalanceOn = false;
  String _freq = 'weekly';
  int _day = DateTime.monday;
  int _monthDay = 1;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _settlementTime = const TimeOfDay(hour: 13, minute: 0);
  final _settlement = <String, bool>{};

  /// 시스템에서 이 앱의 알림이 켜져 있는가. 앱 안의 스위치와 별개다.
  bool _granted = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await NotificationService.isEnabled();
    final freq = await NotificationService.getFrequency();
    final day = await NotificationService.getDay();
    final hour = await NotificationService.getHour();
    final minute = await NotificationService.getMinute();
    final sh = await NotificationService.getSettlementHour();
    final sm = await NotificationService.getSettlementMinute();
    final granted = await NotificationService.isGranted();
    for (final t in _settlementTypes) {
      _settlement[t] = await NotificationService.isSettlementEnabled(t);
    }
    if (!mounted) return;
    setState(() {
      _rebalanceOn = on;
      _freq = freq;
      // 요일과 일자는 같은 칸(`notif_day`)을 나눠 쓴다. 주기를 바꿔도
      // 각자 마지막에 고른 값을 기억하도록 둘로 갈라 들고 있는다.
      if (freq == 'weekly') {
        _day = day.clamp(DateTime.monday, DateTime.sunday);
      } else {
        _monthDay = day.clamp(1, 28);
      }
      _time = TimeOfDay(hour: hour, minute: minute);
      _settlementTime = TimeOfDay(hour: sh, minute: sm);
      _granted = granted;
      _loaded = true;
    });
  }

  /// 스위치를 켤 때 권한을 확인한다.
  ///
  /// 안드로이드는 **두 번 거부하면 더 이상 창을 띄우지 않는다.** 그때는
  /// 스낵바로 "설정에서 허용하세요"라고만 하면 어디로 가야 하는지 모른다 —
  /// 설정 화면으로 보내주는 버튼을 같이 낸다.
  Future<bool> _ensurePermission() async {
    if (await NotificationService.isGranted()) return true;
    final granted = await NotificationService.requestPermission();
    if (granted) {
      if (mounted) setState(() => _granted = true);
      return true;
    }
    if (mounted) {
      setState(() => _granted = false);
      await _showPermissionDialog();
    }
    return false;
  }

  Future<void> _showPermissionDialog() async {
    final l10n = context.l10n;
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(l10n.notifPermissionTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(l10n.notifPermissionBody,
            style: const TextStyle(fontSize: 13.5, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.notifOpenSettings)),
        ],
      ),
    );
    if (open == true) await NotificationService.openSystemSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        BrandHeader(
          title: l10n.notifReminder,
          titleSize: 17,
          titleWeight: FontWeight.w700,
          leading: IconButton(
            tooltip: context.l10n.a11yBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (!_granted) ...[
                      _permissionBanner(context),
                      const SizedBox(height: 14),
                    ],
                    SectionTitle(title: l10n.notifRebalanceSection),
                    const SizedBox(height: DS.cardGap),
                    ListCard(rows: [
                      _toggleRow(
                        context,
                        title: l10n.notifEnableDesc,
                        sub: l10n.notifEnableHint,
                        value: _rebalanceOn,
                        onChanged: _setRebalance,
                      ),
                      if (_rebalanceOn) ...[
                        _pickerRow(
                          context,
                          label: l10n.notifFrequencyLabel,
                          value: _freq == 'weekly'
                              ? l10n.notifEveryWeek
                              : l10n.notifEveryMonth,
                          onTap: _pickFrequency,
                        ),
                        if (_freq == 'weekly')
                          _pickerRow(
                            context,
                            label: l10n.notifWeekdayLabel,
                            value: _weekdayName(context, _day),
                            onTap: _pickWeekday,
                          )
                        else
                          _pickerRow(
                            context,
                            label: l10n.notifDayLabel,
                            value: l10n.notifDayOfMonth(_monthDay),
                            onTap: _pickMonthDay,
                          ),
                        _pickerRow(
                          context,
                          label: l10n.notifTimeLabel,
                          value: MaterialLocalizations.of(context)
                              .formatTimeOfDay(_time),
                          onTap: _pickTime,
                        ),
                      ],
                    ]),
                    if (_rebalanceOn && _freq == 'monthly') ...[
                      const SizedBox(height: 8),
                      _hint(context, l10n.notifDayCapHint),
                    ],
                    const SizedBox(height: 18),

                    SectionTitle(title: l10n.settlementNotifHeader),
                    const SizedBox(height: DS.cardGap),
                    ListCard(rows: [
                      for (final t in _settlementTypes)
                        _toggleRow(
                          context,
                          title: _settlementLabel(context, t),
                          value: _settlement[t] ?? false,
                          onChanged: (v) => _setSettlement(t, v),
                        ),
                      _pickerRow(
                        context,
                        label: l10n.settlementNotifTime,
                        sub: l10n.settlementNotifTimeHint,
                        value: MaterialLocalizations.of(context)
                            .formatTimeOfDay(_settlementTime),
                        onTap: _pickSettlementTime,
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(l10n.settlementNotifNote,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.55,
                              color: context.textSecondary)),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }

  String _settlementLabel(BuildContext context, String type) {
    final l10n = context.l10n;
    return switch (type) {
      'monthly' => l10n.settlementMonthly,
      'quarterly' => l10n.settlementQuarterly,
      'yearly' => l10n.settlementYearly,
      _ => l10n.settlementWeekly,
    };
  }

  // ── 저장 (누를 때마다 바로 반영한다 — 저장 버튼이 없다) ──

  Future<void> _setRebalance(bool v) async {
    if (v && !await _ensurePermission()) return;
    if (v) {
      await NotificationService.enable(_freq);
    } else {
      await NotificationService.disable();
    }
    if (mounted) setState(() => _rebalanceOn = v);
  }

  Future<void> _applyRebalance() async {
    await NotificationService.enable(
      _freq,
      day: _freq == 'weekly' ? _day : _monthDay,
      hour: _time.hour,
      minute: _time.minute,
    );
  }

  Future<void> _pickFrequency() async {
    final l10n = context.l10n;
    final picked = await _choose<String>(
      title: l10n.notifFrequencyLabel,
      current: _freq,
      options: [
        (value: 'weekly', label: l10n.notifEveryWeek),
        (value: 'monthly', label: l10n.notifEveryMonth),
      ],
    );
    if (picked == null || picked == _freq || !mounted) return;
    setState(() => _freq = picked);
    await _applyRebalance();
  }

  Future<void> _pickWeekday() async {
    final picked = await _choose<int>(
      title: context.l10n.notifWeekdayLabel,
      current: _day,
      options: [
        for (var d = DateTime.monday; d <= DateTime.sunday; d++)
          (value: d, label: _weekdayName(context, d)),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _day = picked);
    await _applyRebalance();
  }

  Future<void> _pickMonthDay() async {
    final l10n = context.l10n;
    final picked = await _choose<int>(
      title: l10n.notifDayLabel,
      current: _monthDay,
      // 29~31일은 없는 달이 있다. 고르게 해 두면 그 달만 조용히 건너뛰거나
      // 엉뚱한 날로 밀린다 — 아예 28일까지만 준다.
      options: [
        for (var d = 1; d <= 28; d++) (value: d, label: l10n.notifDayOfMonth(d)),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _monthDay = picked);
    await _applyRebalance();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    await _applyRebalance();
  }

  Future<void> _pickSettlementTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _settlementTime);
    if (picked == null || !mounted) return;
    setState(() => _settlementTime = picked);
    await NotificationService.setSettlementTime(picked.hour, picked.minute);
  }

  /// 고르는 자리는 다 같은 시트를 쓴다 — 항목마다 다르게 생기면 무엇을
  /// 누르는 자리인지 매번 다시 익혀야 한다.
  Future<T?> _choose<T>({
    required String title,
    required T current,
    required List<({T value, String label})> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                children: [
                  for (final o in options)
                    ListTile(
                      dense: true,
                      title: Text(o.label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: o.value == current
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: o.value == current
                                  ? context.brand
                                  : context.textPrimary)),
                      trailing: o.value == current
                          ? Icon(Icons.check, size: 18, color: context.brand)
                          : null,
                      onTap: () => Navigator.pop(sheetCtx, o.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayName(BuildContext context, int weekday) {
    // 2026-01-05가 월요일 — 거기서 세어 그 나라 말로 된 요일 이름을 얻는다
    final d = DateTime(2026, 1, 4 + weekday);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.EEEE(locale).format(d);
  }

  Future<void> _setSettlement(String type, bool v) async {
    if (v && !await _ensurePermission()) return;
    if (v) {
      await NotificationService.enableSettlement(type);
    } else {
      await NotificationService.disableSettlement(type);
    }
    if (mounted) setState(() => _settlement[type] = v);
  }

  // ── 행 ──

  /// 시스템에서 알림이 꺼져 있을 때 맨 위에 뜨는 띠.
  ///
  /// 안 알려주면 앱 안 스위치는 켜져 있는데 알림은 안 오는 상태가 되고,
  /// 사용자는 앱이 고장 났다고 읽는다.
  Widget _permissionBanner(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(DS.cardRadius),
      ),
      child: Row(children: [
        Icon(Icons.notifications_off_outlined,
            size: 18, color: context.warningText),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.notifSystemOff,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.onWarningTitle)),
            const SizedBox(height: 2),
            Text(l10n.notifSystemOffHint,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: context.onWarningBody)),
          ]),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: NotificationService.openSystemSettings,
          child: Text(l10n.notifOpenSettings,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.warningText)),
        ),
      ]),
    );
  }

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.55,
                color: context.textSecondary)),
      );

  /// 눌러서 고르는 행. 지금 값을 오른쪽에 적는다.
  Widget _pickerRow(
    BuildContext context, {
    required String label,
    String? sub,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: context.textSecondary)),
                  ],
                ]),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.brandOnLight)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more, size: 18, color: context.textHint),
        ]),
      ),
    );
  }

  Widget _toggleRow(
    BuildContext context, {
    required String title,
    String? sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondary)),
            ],
          ]),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

}
