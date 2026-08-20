import 'package:flutter/material.dart';
import '../main.dart';
import '../services/notification_service.dart';

class NotificationSettingsDialog extends StatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  State<NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<NotificationSettingsDialog> {
  bool _enabled = false;
  String _frequency = 'weekly';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await NotificationService.isEnabled();
    final freq = await NotificationService.getFrequency();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _frequency = freq;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_enabled) {
      await NotificationService.requestPermission();
      await NotificationService.enable(_frequency);
    } else {
      await NotificationService.disable();
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_enabled ? l10n.notifSavedOn : l10n.notifSavedOff),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) return const SizedBox.shrink();

    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(l10n.notifReminder,
          style: TextStyle(color: context.textPrimary)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, l10n.notifEnableLabel),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.notifEnableDesc,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.textPrimary)),
                        const SizedBox(height: 2),
                        Text(l10n.notifEnableHint,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
            ),
            if (_enabled) ...[
              _sectionHeader(context, l10n.notifFrequency),
              _freqTile(context, 'weekly', l10n.notifWeekly),
              _freqTile(context, 'monthly', l10n.notifMonthly),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        TextButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      color: context.brand
          .withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.brand,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _freqTile(BuildContext context, String value, String label) {
    final selected = _frequency == value;
    return InkWell(
      onTap: () => setState(() => _frequency = value),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? context.brand
                  : context.textHint,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected
                    ? context.textPrimary
                    : context.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
