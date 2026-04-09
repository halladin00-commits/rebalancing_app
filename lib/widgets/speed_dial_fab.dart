import 'package:flutter/material.dart';
import '../main.dart';

class SpeedDialItem {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? bgColor;
  final VoidCallback onTap;

  const SpeedDialItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.bgColor,
  });
}

/// Stack 안에 Positioned.fill로 사용해야 함 (barrier가 전체 화면을 덮기 위해)
class SpeedDialFab extends StatefulWidget {
  final List<SpeedDialItem> items;
  /// 배너 광고 등으로 인해 FAB를 위로 올려야 할 때 사용 (기본값 0)
  final double bottomOffset;
  const SpeedDialFab({super.key, required this.items, this.bottomOffset = 0});

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) _ctrl.forward();
    else _ctrl.reverse();
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 투명 배리어: 열렸을 때 외부 탭 감지 → 닫기
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: Container(color: Colors.transparent),
            ),
          ),
        // FAB + 메뉴 아이템 (우하단 고정)
        Positioned(
          bottom: widget.bottomOffset,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FadeTransition(
                    opacity: _fade,
                    child: IgnorePointer(
                      ignoring: !_open,
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: widget.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 라벨
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Text(item.label,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: context.textPrimary)),
                            ),
                            const SizedBox(width: 8),
                            // 아이콘 버튼
                            Material(
                              color: item.bgColor ?? context.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 2,
                              shadowColor: Colors.black26,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  _close();
                                  item.onTap();
                                },
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: context.borderColor),
                                  ),
                                  child: Icon(item.icon,
                                      size: 20,
                                      color: item.iconColor ??
                                          context.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),   // IgnorePointer
                ),     // FadeTransition
                  // 메인 FAB
                  // 닫힘: ··· / 열림: ∨ (아래 꺽쇠)
                  FloatingActionButton(
                    heroTag: 'speed_dial_${widget.key}',
                    onPressed: _toggle,
                    backgroundColor: const Color(0xFF3B82F6),
                    elevation: 4,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _open
                            ? Icons.keyboard_arrow_down
                            : Icons.more_vert,
                        key: ValueKey(_open),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
