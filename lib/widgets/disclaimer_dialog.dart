import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class DisclaimerDialog extends StatefulWidget {
  final bool isFirstRun;
  const DisclaimerDialog({super.key, this.isFirstRun = true});

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final skip = prefs.getBool('disclaimer_skip') ?? false;
    if (skip) return;
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const DisclaimerDialog(isFirstRun: true),
      );
    }
  }

  static Future<void> showAlways(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const DisclaimerDialog(isFirstRun: false),
    );
  }

  @override
  State<DisclaimerDialog> createState() => _DisclaimerDialogState();
}

class _DisclaimerDialogState extends State<DisclaimerDialog> {
  bool _checked = false;

  Future<void> _confirm() async {
    if (widget.isFirstRun && _checked) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('disclaimer_skip', true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canConfirm = !widget.isFirstRun || _checked;
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(l10n.disclaimerTitle,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section(context, l10n.disclaimerSectionPurpose),
                    _body(context, l10n.disclaimerTextPurpose),
                    _section(context, l10n.disclaimerSectionData),
                    _body(context, l10n.disclaimerTextData),
                    _section(context, l10n.disclaimerSectionRisk),
                    _body(context, l10n.disclaimerTextRisk),
                    _section(context, l10n.disclaimerSectionTax),
                    _body(context, l10n.disclaimerTextTax),
                    _section(context, l10n.disclaimerSectionService),
                    _body(context, l10n.disclaimerTextService),
                  ],
                ),
              ),
            ),
            if (widget.isFirstRun) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setState(() => _checked = !_checked),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _checked
                        ? const Color(0xFF1D4ED8).withValues(alpha: 0.15)
                        : context.rowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _checked ? const Color(0xFF3B82F6) : context.borderColor,
                    ),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _checked ? const Color(0xFF3B82F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _checked ? const Color(0xFF3B82F6) : context.borderColor,
                          width: 2,
                        ),
                      ),
                      child: _checked
                          ? const Icon(Icons.check, color: Colors.white, size: 12)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '위 내용을 전부 확인하였으며 동의합니다.',
                        style: TextStyle(
                            fontSize: 13,
                            color: _checked
                                ? const Color(0xFF93C5FD)
                                : context.textSecondary),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm ? const Color(0xFF3B82F6) : context.disabledFill,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              widget.isFirstRun ? '시작하기' : l10n.disclaimerConfirmBtn,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: canConfirm ? Colors.white : context.textHint,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6))),
      );

  Widget _body(BuildContext context, String text) => Text(
        text,
        style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.5),
      );
}
