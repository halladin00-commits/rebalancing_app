import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../screens/item_search_screen.dart';
import '../screens/portfolio_form_screen.dart';

/// 포트폴리오 자체를 다루는 동작 — 이름 변경 · 복제 · 삭제.
///
/// 예전에는 자산 탭의 편집 모드 카드에만 붙어 있었다. 순서 변경이 별도 화면이
/// 되면서(시안 v16c) 그 카드가 사라졌고, 시안은 이 셋을 **포트 상세의 ⋮
/// 메뉴**에 둔다(v13d). 두 곳에서 같은 다이얼로그를 쓰게 여기로 뺐다.

String _uid() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    DateTime.now().microsecond.toRadixString(36);

/// 이름과 아이콘을 고친다.
void editPortfolio(BuildContext context, Portfolio pf) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PortfolioFormScreen(
        initialName: pf.name,
        initialEmoji: pf.emoji,
        isEdit: true,
        onSave: (name, emoji) {
          context
              .read<PortfolioProvider>()
              .updatePortfolio(pf.id, pf.copyWith(name: name, emoji: emoji));
        },
      ),
    ),
  );
}

/// 종목까지 통째로 복제한다. 새 id를 주지 않으면 원본과 얽힌다.
void duplicatePortfolio(BuildContext context, Portfolio pf, String suffix) {
  final copy = pf.copyWith(
    id: _uid(),
    name: '${pf.name} $suffix',
    items: pf.items.map((i) => i.copyWith(id: _uid())).toList(),
  );
  context.read<PortfolioProvider>().addPortfolio(copy);
}

/// 삭제 전에 **무엇이 함께 사라지는지** 보여준다 (시안 v16b).
/// 이름만으로는 되돌릴 수 없다는 말의 무게가 전해지지 않는다.
///
/// 지웠으면 true를 돌려준다 — 포트 상세에서 부르면 그 화면도 닫아야 한다.
Future<bool> confirmDeletePortfolio(BuildContext context, Portfolio pf) async {
  final l10n = context.l10n;
  final done = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.cardBg,
      title: Text(l10n.deleteConfirmTitle,
          style: TextStyle(color: ctx.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pf.name,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ctx.textPrimary)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ctx.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.deleteLosesItems(
                pf.items.where((i) => !i.isCash).length,
                pf.items.fold(0, (n, i) => n + i.transactions.length),
              ),
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: ctx.warningText),
            ),
          ),
          const SizedBox(height: 10),
          Text(l10n.deleteCannotUndo,
              style: TextStyle(fontSize: 12.5, color: ctx.textSecondary)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel)),
        TextButton(
          onPressed: () {
            ctx.read<PortfolioProvider>().deletePortfolio(pf.id);
            Navigator.pop(ctx, true);
          },
          style: TextButton.styleFrom(foregroundColor: ctx.danger),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return done ?? false;
}

/// 포트폴리오를 만들고 바로 종목 담기로 이어 준다.
///
/// 빈 화면(리밸런싱·결산 탭)에서도 쓴다 — 예전에는 "포트폴리오를 먼저
/// 만들어야 합니다"라는 회색 글자만 있고 누를 것이 없었다.
void createPortfolioThenAddItems(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PortfolioFormScreen(
        onSave: (name, emoji) {
          final pf = Portfolio(id: _uid(), name: name, emoji: emoji);
          context.read<PortfolioProvider>().addPortfolio(pf);
          // 폼이 pop 되기 전에 불리므로 프레임이 끝난 뒤에 민다
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ItemSearchScreen(portfolio: pf)),
            );
          });
        },
      ),
    ),
  );
}
