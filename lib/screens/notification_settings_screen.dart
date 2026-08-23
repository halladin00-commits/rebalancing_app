import 'package:flutter/material.dart';

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
  final _settlement = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await NotificationService.isEnabled();
    final freq = await NotificationService.getFrequency();
    for (final t in _settlementTypes) {
      _settlement[t] = await NotificationService.isSettlementEnabled(t);
    }
    if (!mounted) return;
    setState(() {
      _rebalanceOn = on;
      _freq = freq;
      _loaded = true;
    });
  }

  /// 알림을 처음 켤 때만 권한을 묻는다 — 앱 첫 실행에 미리 묻지 않는다.
  Future<bool> _ensurePermission() async {
    final granted = await NotificationService.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notifPermissionDenied)),
      );
    }
    return granted;
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
                        _radioRow(context, l10n.notifWeekly,
                            _freq == 'weekly', () => _setFreq('weekly')),
                        _radioRow(context, l10n.notifMonthly,
                            _freq == 'monthly', () => _setFreq('monthly')),
                      ],
                    ]),
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

  Future<void> _setFreq(String f) async {
    await NotificationService.enable(f);
    if (mounted) setState(() => _freq = f);
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

  Widget _radioRow(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? context.brand : context.textDisabled,
          ),
          const SizedBox(width: 11),
          Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
        ]),
      ),
    );
  }
}
