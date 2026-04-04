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

class SpeedDialFab extends StatefulWidget {
  final List<SpeedDialItem> items;
  const SpeedDialFab({super.key, required this.items});

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
    if (_open) _ctrl.forward(); else _ctrl.reverse();
  }

  void _close() {
    setState(() => _open = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 메뉴 아이템들
        FadeTransition(
          opacity: _fade,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Icon(item.icon,
                            size: 20,
                            color: item.iconColor ?? context.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
        // 메인 FAB (··· 버튼)
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: const Color(0xFF3B82F6),
          elevation: 4,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              _open ? Icons.close : Icons.more_vert,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
