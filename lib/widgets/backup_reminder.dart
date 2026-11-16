import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../services/storage_service.dart';
import '../theme/design_system.dart';

/// 백업을 알릴 때인가.
///
/// 기록은 이 폰 한 곳에만 있다. 폰을 바꾸거나 앱을 지우면 몇 년 치 거래
/// 내역이 사라진다 — 이 앱에서 날 수 있는 가장 큰 사고다. 백업 기능은
/// 있지만 더보기 탭 안에 있어, 거기 가 보지 않은 사람은 있는 줄도 모른다.
///
/// - 지킬 기록이 있어야 한다: 거래가 있고, 가장 이른 거래가 [minDataAge]보다
///   오래됐다. 방금 깐 사람에게 첫날부터 조르지 않는다.
/// - 백업한 적이 없거나 [staleAfter]보다 오래됐다.
/// - 「나중에」를 눌렀으면 [snoozedUntil]까지는 조용히 있는다.
bool backupReminderDue({
  required DateTime now,
  required DateTime? firstTransaction,
  required DateTime? lastBackup,
  required DateTime? snoozedUntil,
  Duration minDataAge = const Duration(days: 7),
  Duration staleAfter = const Duration(days: 30),
}) {
  if (firstTransaction == null) return false;
  if (now.difference(firstTransaction) < minDataAge) return false;
  if (snoozedUntil != null && now.isBefore(snoozedUntil)) return false;
  return lastBackup == null || now.difference(lastBackup) >= staleAfter;
}

/// 가장 이른 거래의 날짜. 거래가 하나도 없으면 null.
DateTime? firstTransactionDate(List<Portfolio> portfolios) {
  DateTime? first;
  for (final pf in portfolios) {
    for (final item in pf.items) {
      for (final t in item.transactions) {
        if (first == null || t.date.isBefore(first)) first = t.date;
      }
    }
  }
  return first;
}

/// 첫 화면의 백업 알림. 알릴 때가 아니면 자리를 차지하지 않는다.
class BackupReminder extends StatefulWidget {
  final List<Portfolio> portfolios;

  /// 「나중에」를 누르면 조용히 있는 기간.
  static const snooze = Duration(days: 14);
  static const _snoozeKey = 'backup_reminder_snooze_until_v1';

  const BackupReminder({super.key, required this.portfolios});

  @override
  State<BackupReminder> createState() => _BackupReminderState();
}

class _BackupReminderState extends State<BackupReminder> {
  bool _loaded = false;
  DateTime? _lastBackup;
  DateTime? _snoozedUntil;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    StorageService.backupDone.addListener(_load);
  }

  @override
  void dispose() {
    StorageService.backupDone.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final at = await StorageService.lastBackupAt();
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(BackupReminder._snoozeKey);
    if (!mounted) return;
    setState(() {
      _lastBackup = at;
      _snoozedUntil =
          ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
      _loaded = true;
    });
  }

  Future<void> _later() async {
    final until = DateTime.now().add(BackupReminder.snooze);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        BackupReminder._snoozeKey, until.millisecondsSinceEpoch);
    if (mounted) setState(() => _snoozedUntil = until);
  }

  Future<void> _backup() async {
    if (_busy) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // 공유 창을 그냥 닫았으면 백업한 것이 아니다 — 알림을 그대로 둔다
      if (await StorageService.exportPortfolios(widget.portfolios)) {
        await _load();
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final now = DateTime.now();
    if (!backupReminderDue(
        now: now,
        firstTransaction: firstTransactionDate(widget.portfolios),
        lastBackup: _lastBackup,
        snoozedUntil: _snoozedUntil)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final last = _lastBackup;
    final title = last == null
        ? l10n.backupReminderNever
        : l10n.backupReminderDays(now.difference(last).inDays);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        decoration: BoxDecoration(
          color: context.warningBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.shield_outlined,
                  size: 17, color: context.warningText),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.warningText)),
                    const SizedBox(height: 3),
                    Text(l10n.backupReminderBody,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            color: context.warningText)),
                  ]),
            ),
            const SizedBox(width: 6),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: _later,
              style: TextButton.styleFrom(
                  foregroundColor: context.warningText,
                  minimumSize: const Size(48, 40)),
              child: Text(l10n.backupReminderLater,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: _busy ? null : _backup,
              style: TextButton.styleFrom(
                  foregroundColor: context.warningText,
                  minimumSize: const Size(48, 40)),
              child: Text(l10n.backupReminderNow,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline)),
            ),
          ]),
        ]),
      ),
    );
  }
}
