import 'package:flutter/material.dart';

import '../main.dart';

/// 우상단 메뉴에 들어가는 것.
sealed class MenuEntry {
  const MenuEntry();
}

/// 누르면 무언가 하는 줄.
class MenuAction extends MenuEntry {
  final IconData icon;
  final String label;

  /// 눌러 보기 전에 알아야 할 것 (예: 무엇을 되돌리는지).
  final String? subtitle;

  final VoidCallback onTap;

  /// 되돌릴 수 없는 것 — 빨갛게 낸다.
  final bool danger;

  const MenuAction(
    this.icon,
    this.label,
    this.onTap, {
    this.subtitle,
    this.danger = false,
  });
}

/// 묶음 제목. 위에 구분선이 붙는다.
///
/// 열한 개를 구분 없이 쌓아 두면 목록이 아니라 더미가 된다 — 무엇이 무엇의
/// 짝인지 안 보여서 매번 처음부터 읽게 된다.
class MenuSection extends MenuEntry {
  final String title;
  const MenuSection(this.title);
}

/// 화면 우상단 메뉴.
///
/// **버튼 바로 아래에서 펼쳐진다.** 예전에는 화면 아래에서 시트가 올라왔는데,
/// 우상단을 누른 손과 시선이 화면 반대편 끝까지 갔다가 돌아와야 했다.
/// 누른 자리에서 열리는 게 짧다.
///
/// 그래서 **항목 수를 적게 유지해야 한다.** 팝업이 화면을 덮을 만큼 길어지면
/// 시트만도 못하다. [MenuSection]으로 묶고, 안 쓰는 것은 넣지 않는다.
class AppMenu extends StatelessWidget {
  final List<MenuEntry> entries;

  /// 딥그린 헤더 위에 놓이면 흰색, 밝은 배경이면 어두운 색.
  final bool onBrand;

  /// 목록 한 줄에 놓을 때는 작게. 헤더의 ⋮와 같은 크기면 줄이 뚱뚱해진다.
  final double iconSize;

  /// 버튼 그림. 안 주면 ⋮.
  final Widget? icon;

  /// 버튼을 길게 눌렀을 때 나오는 이름. 안 주면 「메뉴」.
  final String? tooltip;

  /// 끌 수 있다 — 무언가 만드는 중에는 다시 못 누르게 한다.
  final bool enabled;

  const AppMenu({
    super.key,
    required this.entries,
    this.onBrand = true,
    this.iconSize = 24,
    this.icon,
    this.tooltip,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      icon: icon ??
          Icon(Icons.more_vert,
              size: iconSize,
              color: onBrand ? Colors.white : context.textSecondary),
      tooltip: tooltip ?? context.l10n.a11yMenu,
      enabled: enabled,
      color: context.cardBg,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 208, maxWidth: 300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.cardBorder),
      ),
      onSelected: (i) {
        final e = entries[i];
        if (e is MenuAction) e.onTap();
      },
      itemBuilder: (_) => [
        for (var i = 0; i < entries.length; i++)
          ..._itemsFor(context, entries[i], i),
      ],
    );
  }

  List<PopupMenuEntry<int>> _itemsFor(
      BuildContext context, MenuEntry e, int i) {
    switch (e) {
      case MenuSection(:final title):
        return [
          // 첫 묶음 위에는 선을 긋지 않는다 — 메뉴 맨 위에 선이 뜨면
          // 무언가 잘린 것처럼 보인다.
          if (i != 0) const PopupMenuDivider(height: 9),
          PopupMenuItem<int>(
            enabled: false,
            height: 26,
            child: Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: context.textTertiary)),
          ),
        ];
      case MenuAction(
          :final icon,
          :final label,
          :final subtitle,
          :final danger
        ):
        final fg = danger ? context.danger : context.textPrimary;
        return [
          PopupMenuItem<int>(
            value: i,
            height: subtitle == null ? 42 : 54,
            child: Row(children: [
              Icon(icon,
                  size: 19, color: danger ? context.danger : context.textStrong),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: fg)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ];
    }
  }
}


/// 우상단 [캡처] 버튼과 그 아래에서 펼쳐지는 두 줄.
///
/// **바로 옆 ⋮ 메뉴와 같은 방식으로 연다.** 예전에는 화면 아래에서 시트가
/// 올라왔는데, 나란히 붙은 두 버튼이 서로 다르게 열리면 누를 때마다 어디를
/// 봐야 하는지 다시 생각하게 된다. 고를 것이 둘뿐이라 시트는 과하기도 했고,
/// 시트는 하단 네비바에 가려지는 함정이 따로 있다.
class CaptureMenu extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onShare;

  /// 딥그린 헤더 위면 흰색.
  final bool onBrand;

  /// 그림을 만드는 중 — 뱅글이를 보이고 다시 못 누르게 한다.
  final bool busy;

  const CaptureMenu({
    super.key,
    required this.onSave,
    required this.onShare,
    this.onBrand = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = onBrand ? Colors.white : context.textSecondary;
    return AppMenu(
      tooltip: l10n.capture,
      enabled: !busy,
      icon: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: color, strokeWidth: 2))
          : Icon(Icons.ios_share, color: color),
      onBrand: onBrand,
      entries: [
        MenuAction(Icons.save_alt_rounded, l10n.saveImage, onSave),
        MenuAction(Icons.share_rounded, l10n.shareImage, onShare),
      ],
    );
  }
}
