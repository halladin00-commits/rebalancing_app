import 'package:flutter/material.dart';
import '../main.dart';

const _emojis = [
  '📈','📉','💰','💵','💴','💶','💷','🪙','💎','🏦',
  '📊','🔖','🎯','⭐','🚀','🌟','💹','🏠','🛢️','⚡',
];

class PortfolioFormDialog extends StatefulWidget {
  final String? initialName;
  final String? initialEmoji;
  final bool isEdit;
  final Function(String name, String emoji) onSave;

  const PortfolioFormDialog({
    super.key,
    this.initialName,
    this.initialEmoji,
    this.isEdit = false,
    required this.onSave,
  });

  @override
  State<PortfolioFormDialog> createState() => _PortfolioFormDialogState();
}

class _PortfolioFormDialogState extends State<PortfolioFormDialog> {
  late TextEditingController _nameController;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _emoji = widget.initialEmoji ?? '📈';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.cardBg,
      title: Text(
          widget.isEdit ? '포트폴리오 수정' : '포트폴리오 생성',
          style: TextStyle(color: context.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름
            Text('포트폴리오 이름',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: '예: 연금저축, 미국주식',
                hintStyle: TextStyle(color: context.textHint),
                filled: true,
                fillColor: context.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 아이콘
            Text('아이콘',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _emojis.map((e) {
                final selected = _emoji == e;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF3B82F6)
                            : context.borderColor,
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                          : context.fieldFill,
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  widget.onSave(_nameController.text.trim(), _emoji);
                  Navigator.pop(context);
                },
          child: Text(widget.isEdit ? '수정 완료' : '생성'),
        ),
      ],
    );
  }
}
