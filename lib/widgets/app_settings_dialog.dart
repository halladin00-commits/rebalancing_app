import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/notification_service.dart';

class AppSettingsDialog extends StatefulWidget {
  final VoidCallback? onBackup;
  final VoidCallback? onRestore;

  const AppSettingsDialog({super.key, this.onBackup, this.onRestore});

  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> {
  bool _notifEnabled = false;
  String _frequency = 'weekly';
  int _day = DateTime.monday;   // weekly: 1-7, monthly: 1-31
  int _hour = 13;
  int _minute = 0;
  bool _notifLoading = true;

  bool _settlementWeekly    = false;
  bool _settlementMonthly   = false;
  bool _settlementQuarterly = false;
  bool _settlementYearly    = false;

  @override
  void initState() {
    super.initState();
    _loadNotif();
  }

  Future<void> _loadNotif() async {
    final enabled  = await NotificationService.isEnabled();
    final freq     = await NotificationService.getFrequency();
    final day      = await NotificationService.getDay();
    final hour     = await NotificationService.getHour();
    final minute   = await NotificationService.getMinute();
    final sWeekly  = await NotificationService.isSettlementEnabled('weekly');
    final sMonthly = await NotificationService.isSettlementEnabled('monthly');
    final sQuart   = await NotificationService.isSettlementEnabled('quarterly');
    final sYearly  = await NotificationService.isSettlementEnabled('yearly');
    if (mounted) {
      setState(() {
        _notifEnabled        = enabled;
        _frequency           = freq;
        _day                 = day;
        _hour                = hour;
        _minute              = minute;
        _settlementWeekly    = sWeekly;
        _settlementMonthly   = sMonthly;
        _settlementQuarterly = sQuart;
        _settlementYearly    = sYearly;
        _notifLoading        = false;
      });
    }
  }

  Future<void> _saveSettlementNotif(String type, bool enabled) async {
    if (enabled) {
      await NotificationService.requestPermission();
      await NotificationService.enableSettlement(type);
    } else {
      await NotificationService.disableSettlement(type);
    }
  }

  Future<void> _saveNotif({bool showSnackBar = false}) async {
    if (_notifEnabled) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) setState(() => _notifEnabled = false);
        if (mounted && showSnackBar) {
          final l10n = context.l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.notifPermissionDenied)),
          );
        }
        return;
      }
      await NotificationService.enable(
        _frequency,
        day: _day,
        hour: _hour,
        minute: _minute,
      );
    } else {
      await NotificationService.disable();
    }
    if (!mounted) return;
    if (showSnackBar) {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_notifEnabled ? l10n.notifSavedOn : l10n.notifSavedOff)),
      );
    }
  }

  String _weekdayLabel(int weekday, bool isKo) {
    if (isKo) {
      const labels = ['', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
      return labels[weekday];
    } else {
      const labels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return labels[weekday];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeNotifier = context.watch<ThemeNotifier>();
    final localeProvider = context.watch<LocaleProvider>();
    final pnlNotifier = context.watch<PnlColorNotifier>();
    final mainCurrency = context.watch<MainCurrencyNotifier>();
    final isKo = localeProvider.locale.languageCode == 'ko';

    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(l10n.settings, style: TextStyle(color: context.textPrimary)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 테마 ──
              _sectionHeader(context, isKo ? '테마' : 'Theme'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Builder(builder: (ctx) {
                    final effectiveDark = themeNotifier.mode == ThemeMode.dark ||
                        (themeNotifier.mode == ThemeMode.system && ctx.isDark);
                    return Row(children: [
                      _segBtn(
                        context,
                        isKo ? '라이트' : 'Light',
                        !effectiveDark,
                        () => themeNotifier.setMode(ThemeMode.light),
                      ),
                      _segBtn(
                        context,
                        isKo ? '다크' : 'Dark',
                        effectiveDark,
                        () => themeNotifier.setMode(ThemeMode.dark),
                      ),
                    ]);
                  }),
                ),
              ),

              // ── 언어 ──
              _sectionHeader(context, l10n.language),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    _segBtn(
                      context,
                      isKo ? '한국어' : 'Korean',
                      isKo,
                      () => localeProvider.setLocale(const Locale('ko')),
                    ),
                    _segBtn(
                      context,
                      'English',
                      !isKo,
                      () => localeProvider.setLocale(const Locale('en')),
                    ),
                  ]),
                ),
              ),

              // ── 손익 색상 ──
              _sectionHeader(context, isKo ? '손익 색상' : 'P&L Color'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    _pnlSegBtn(
                      context, pnlNotifier, PnlColorScheme.greenRed,
                      posColor: const Color(0xFF16A34A),
                      negColor: const Color(0xFFDC2626),
                      isKo: isKo,
                    ),
                    _pnlSegBtn(
                      context, pnlNotifier, PnlColorScheme.redBlue,
                      posColor: const Color(0xFFDC2626),
                      negColor: const Color(0xFF2563EB),
                      isKo: isKo,
                    ),
                  ]),
                ),
              ),

              // ── 기준 통화 ──
              _sectionHeader(context, isKo ? '기준 통화' : 'Base Currency'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    _segBtn(context, l10n.currencyKRW, mainCurrency.currency == 'KRW',
                        () => mainCurrency.setCurrency('KRW')),
                    _segBtn(context, l10n.currencyUSD, mainCurrency.currency == 'USD',
                        () => mainCurrency.setCurrency('USD')),
                  ]),
                ),
              ),

              // ── 알림 설정 ──
              _sectionHeader(context, l10n.notifReminder),
              if (_notifLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _settingRow(
                  context,
                  label: l10n.notifEnableDesc,
                  trailing: Switch(
                    value: _notifEnabled,
                    onChanged: (v) {
                      setState(() => _notifEnabled = v);
                      _saveNotif(showSnackBar: true);
                    },
                  ),
                ),
                if (_notifEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: 주기 + 요일/일자
                        Row(children: [
                          Expanded(child: _notifDropdown<String>(
                            context: context,
                            value: _frequency,
                            items: [
                              DropdownMenuItem(value: 'weekly',  child: Text(isKo ? '매주' : 'Weekly')),
                              DropdownMenuItem(value: 'monthly', child: Text(isKo ? '매월' : 'Monthly')),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _frequency = v!;
                                _day = v == 'weekly' ? DateTime.monday : 1;
                              });
                              _saveNotif();
                            },
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _notifDropdown<int>(
                            context: context,
                            value: _day,
                            items: _frequency == 'weekly'
                                ? List.generate(7, (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(_weekdayLabel(i + 1, isKo)),
                                  ))
                                : List.generate(31, (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(isKo ? '${i + 1}일' : '${i + 1}'),
                                  )),
                            onChanged: (v) {
                              setState(() => _day = v!);
                              _saveNotif();
                            },
                          )),
                        ]),
                        const SizedBox(height: 6),
                        // Row 2: 시 + 분
                        Row(children: [
                          Expanded(child: _notifDropdown<int>(
                            context: context,
                            value: _hour,
                            items: List.generate(24, (i) => DropdownMenuItem(
                              value: i,
                              child: Text(isKo
                                  ? '${i.toString().padLeft(2, '0')}시'
                                  : '${i.toString().padLeft(2, '0')}h'),
                            )),
                            onChanged: (v) {
                              setState(() => _hour = v!);
                              _saveNotif();
                            },
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _notifDropdown<int>(
                            context: context,
                            value: _minute,
                            items: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
                                .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(isKo
                                      ? '${m.toString().padLeft(2, '0')}분'
                                      : '${m.toString().padLeft(2, '0')}m'),
                                ))
                                .toList(),
                            onChanged: (v) {
                              setState(() => _minute = v!);
                              _saveNotif();
                            },
                          )),
                        ]),
                        if (_day >= 29 && _frequency == 'monthly') ...[
                          const SizedBox(height: 5),
                          Text(
                            isKo
                                ? '※ 해당 일이 없는 달은 건너뜁니다'
                                : '※ Skipped in months without this date',
                            style: TextStyle(fontSize: 11, color: context.textHint),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],

              // ── 결산 알림 ──
              _sectionHeader(context, l10n.settlementNotifHeader),
              if (!_notifLoading) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.rowBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(children: [
                      _compactToggleRow(context, l10n.settlementNotifWeekly, _settlementWeekly, (v) {
                        setState(() => _settlementWeekly = v);
                        _saveSettlementNotif('weekly', v);
                      }),
                      Divider(height: 1, color: context.borderColor),
                      _compactToggleRow(context, l10n.settlementNotifMonthly, _settlementMonthly, (v) {
                        setState(() => _settlementMonthly = v);
                        _saveSettlementNotif('monthly', v);
                      }),
                      Divider(height: 1, color: context.borderColor),
                      _compactToggleRow(context, l10n.settlementNotifQuarterly, _settlementQuarterly, (v) {
                        setState(() => _settlementQuarterly = v);
                        _saveSettlementNotif('quarterly', v);
                      }),
                      Divider(height: 1, color: context.borderColor),
                      _compactToggleRow(context, l10n.settlementNotifYearly, _settlementYearly, (v) {
                        setState(() => _settlementYearly = v);
                        _saveSettlementNotif('yearly', v);
                      }),
                    ]),
                  ),
                ),
              ],

              // ── 데이터 ──
              _sectionHeader(context, isKo ? '데이터' : 'Data'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onBackup?.call();
                      },
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: Text(l10n.backupData),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        side: BorderSide(color: context.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onRestore?.call();
                      },
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text(l10n.restoreData),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        side: BorderSide(color: context.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  // ── 섹션 헤더 ──
  Widget _sectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3B82F6).withValues(alpha: context.isDark ? 0.15 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3B82F6),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── 일반 설정 행 ──
  Widget _settingRow(BuildContext context,
      {required String label, String? subtitle, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 14, color: context.textPrimary)),
            if (subtitle != null)
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ]),
        ),
        trailing,
      ]),
    );
  }

  // ── 결산 알림 컴팩트 토글 행 ──
  Widget _compactToggleRow(
      BuildContext context, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: context.textPrimary)),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

  // ── 세그먼트 버튼 (언어용) ──
  Widget _segBtn(BuildContext context, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1D4ED8) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active
                      ? const Color(0xFF93C5FD)
                      : context.textSecondary)),
        ),
      ),
    );
  }

  // ── 세그먼트 버튼 (손익 색상용) ──
  Widget _pnlSegBtn(
    BuildContext context,
    PnlColorNotifier notifier,
    PnlColorScheme scheme, {
    required Color posColor,
    required Color negColor,
    required bool isKo,
  }) {
    final selected = notifier.scheme == scheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => notifier.setScheme(scheme),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1D4ED8).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              isKo ? '+수익' : '+Profit',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: posColor),
            ),
            Text(' / ',
                style: TextStyle(fontSize: 12, color: context.textHint)),
            Text(
              isKo ? '-손실' : '-Loss',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: negColor),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 알림 드롭다운 ──
  Widget _notifDropdown<T>({
    required BuildContext context,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
