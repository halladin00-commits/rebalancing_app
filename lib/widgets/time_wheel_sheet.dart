import 'package:flutter/material.dart';

import '../main.dart';

/// 시각을 고르는 시트. 갤럭시 알람처럼 **굴려서** 고른다.
///
/// 예전에는 머티리얼 기본 `showTimePicker`(시계 다이얼)를 썼다.
/// 하루 한 번 오는 알림 시각을 정하는 데 화면 절반을 시계판이 차지하고,
/// 시를 고르면 분 화면으로 넘어가는 두 단계였다. 분을 고치려다 시를 다시
/// 건드리는 일도 잦다.
///
/// 휠은 세 칸이 **한 화면에 같이 있어서** 지금 고른 값이 늘 보이고, 고치고
/// 싶은 칸만 굴리면 된다. 단계도 없다.
class TimeWheelSheet extends StatefulWidget {
  final TimeOfDay initial;

  const TimeWheelSheet({super.key, required this.initial});

  /// 고른 시각을 돌려준다. 취소하면 null.
  static Future<TimeOfDay?> show(BuildContext context, TimeOfDay initial) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // 하단 네비바에 버튼이 가리지 않게 한다.
      useSafeArea: true,
      builder: (_) => TimeWheelSheet(initial: initial),
    );
  }

  @override
  State<TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<TimeWheelSheet> {
  static const _itemHeight = 44.0;
  static const _visible = 3;

  late bool _pm;
  late int _hour12; // 1..12
  late int _minute;

  late final FixedExtentScrollController _apCtl;
  late final FixedExtentScrollController _hourCtl;
  late final FixedExtentScrollController _minCtl;

  @override
  void initState() {
    super.initState();
    final h = widget.initial.hour;
    _pm = h >= 12;
    _hour12 = h % 12 == 0 ? 12 : h % 12;
    _minute = widget.initial.minute;
    _apCtl = FixedExtentScrollController(initialItem: _pm ? 1 : 0);
    _hourCtl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minCtl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    for (final c in [_apCtl, _hourCtl, _minCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  TimeOfDay get _value {
    final h = _hour12 % 12 + (_pm ? 12 : 0);
    return TimeOfDay(hour: h, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    return SafeArea(
      top: false,
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
          Text(l10n.notifTimeLabel,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          const SizedBox(height: 10),
          SizedBox(
            height: _itemHeight * _visible,
            child: Stack(children: [
              // 가운데 고른 자리를 옅게 깔아 둔다 — 어디가 고른 값인지
              // 굴리는 동안에도 보여야 한다.
              Center(
                child: Container(
                  height: _itemHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: context.trackBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wheel(
                    controller: _apCtl,
                    width: 74,
                    count: 2,
                    label: (i) => i == 0
                        ? (isKo ? '오전' : 'AM')
                        : (isKo ? '오후' : 'PM'),
                    selected: _pm ? 1 : 0,
                    onChanged: (i) => setState(() => _pm = i == 1),
                  ),
                  _wheel(
                    controller: _hourCtl,
                    width: 62,
                    count: 12,
                    // 12 다음이 1로 이어진다 — 12시에서 1시로 가려고 열한 칸을
                    // 거슬러 올릴 이유가 없다. 갤럭시 알람도 이렇게 돈다.
                    looping: true,
                    label: (i) => '${i + 1}',
                    selected: _hour12 - 1,
                    onChanged: (i) => setState(() => _hour12 = i + 1),
                  ),
                  Text(':',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: context.textTertiary)),
                  _wheel(
                    controller: _minCtl,
                    width: 62,
                    count: 60,
                    // 00 위가 59로 이어진다. 안 이으면 00에 있을 때 위 칸이
                    // 비어서 줄이 한쪽만 허전하다.
                    looping: true,
                    label: (i) => i.toString().padLeft(2, '0'),
                    selected: _minute,
                    onChanged: (i) => setState(() => _minute = i),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textSecondary,
                      side: BorderSide(color: context.borderColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.cancel,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _value),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.confirm,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required double width,
    required int count,
    required String Function(int) label,
    required int selected,
    required ValueChanged<int> onChanged,
    bool looping = false,
  }) {
    Widget item(int i) {
      final on = i == selected;
      return Center(
        child: Text(
          label(i),
          style: TextStyle(
            fontSize: on ? 21 : 18,
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
            color: on ? context.textPrimary : context.textTertiary,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _itemHeight,
        // 굴린 뒤 칸 가운데에 멈춘다 — 반쯤 걸치면 무엇을 고른 건지 모른다.
        physics: const FixedExtentScrollPhysics(),
        // 굴릴 때 위아래가 살짝 눕는 정도. 기울기가 세면 글자가 안 읽힌다.
        diameterRatio: 1.6,
        // 순환하는 휠은 칸 번호가 음수나 count 이상으로도 온다.
        onSelectedItemChanged: (i) => onChanged(i % count),
        childDelegate: looping
            ? ListWheelChildLoopingListDelegate(
                children: [for (var i = 0; i < count; i++) item(i)])
            : ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (_, i) => item(i),
              ),
      ),
    );
  }
}
