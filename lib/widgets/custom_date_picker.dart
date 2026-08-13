import 'package:flutter/material.dart';
import '../main.dart';

/// Year 드롭다운 + Month 드롭다운 + Day 캘린더 그리드 조합의 날짜 선택기.
/// [showDatePicker] 대체용 — 과거 날짜 선택 시 훨씬 빠름.
Future<DateTime?> showCustomDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = firstDate ?? DateTime(2000);
  final last = lastDate ?? DateTime.now();

  int year = initialDate.year.clamp(first.year, last.year);
  int month = initialDate.month;
  int day = initialDate.day;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      final l10n = ctx.l10n;
      final isKorean = Localizations.localeOf(ctx).languageCode == 'ko';
      final monthLabels = isKorean
          ? ['1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월']
          : ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final dowLabels = isKorean
          ? ['일','월','화','수','목','금','토']
          : ['Su','Mo','Tu','We','Th','Fr','Sa'];

      return StatefulBuilder(
        builder: (ctx, setS) {
          final minMonth = year == first.year ? first.month : 1;
          final maxMonth = year == last.year ? last.month : 12;
          if (month < minMonth) month = minMonth;
          if (month > maxMonth) month = maxMonth;

          final daysInMonth = DateTime(year, month + 1, 0).day;
          final maxDay = (year == last.year && month == last.month) ? last.day : daysInMonth;
          if (day > maxDay) day = maxDay;
          if (day < 1) day = 1;

          // 1일이 무슨 요일인지 (0=일, 1=월, ..., 6=토)
          final offset = DateTime(year, month, 1).weekday % 7;

          return AlertDialog(
            backgroundColor: ctx.cardBg,
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            title: Text(
              isKorean ? '날짜 선택' : 'Select Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ctx.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 연도 + 월 드롭다운
                Row(children: [
                  Expanded(
                    child: _dropdown<int>(
                      ctx,
                      value: year,
                      items: List.generate(
                        last.year - first.year + 1,
                        (i) => DropdownMenuItem(
                          value: last.year - i,
                          child: Text(
                            isKorean ? '${last.year - i}년' : '${last.year - i}',
                            style: TextStyle(fontSize: 14, color: ctx.textPrimary),
                          ),
                        ),
                      ),
                      onChanged: (y) => setS(() => year = y!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdown<int>(
                      ctx,
                      value: month.clamp(minMonth, maxMonth),
                      items: List.generate(
                        maxMonth - minMonth + 1,
                        (i) => DropdownMenuItem(
                          value: minMonth + i,
                          child: Text(
                            monthLabels[(minMonth + i) - 1],
                            style: TextStyle(fontSize: 14, color: ctx.textPrimary),
                          ),
                        ),
                      ),
                      onChanged: (m) => setS(() => month = m!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // 요일 헤더
                Row(
                  children: dowLabels.map((h) => Expanded(
                    child: Center(
                      child: Text(h,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ctx.textSecondary)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 2),

                // 날짜 그리드
                ..._dayGrid(ctx, offset, daysInMonth, maxDay, day,
                    (d) => setS(() => day = d)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, DateTime(year, month, day)),
                child: Text(l10n.confirm),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _dropdown<T>(BuildContext ctx, {
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: ctx.fieldFill,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ctx.borderColor),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: ctx.cardBg,
        style: TextStyle(fontSize: 14, color: ctx.textPrimary),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

List<Widget> _dayGrid(
  BuildContext ctx,
  int offset,
  int daysInMonth,
  int maxDay,
  int selectedDay,
  ValueChanged<int> onSelect,
) {
  final totalCells = offset + daysInMonth;
  final rows = (totalCells / 7).ceil();

  return List.generate(rows, (row) {
    return Row(
      children: List.generate(7, (col) {
        final cellIndex = row * 7 + col;
        final d = cellIndex - offset + 1;
        final valid = d >= 1 && d <= daysInMonth;
        final disabled = valid && d > maxDay;
        final selected = valid && d == selectedDay;

        return Expanded(
          child: valid
              ? GestureDetector(
                  onTap: disabled ? null : () => onSelect(d),
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$d',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                          color: disabled
                              ? ctx.textHint
                              : selected
                                  ? Colors.white
                                  : ctx.textPrimary,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      }),
    );
  });
}
