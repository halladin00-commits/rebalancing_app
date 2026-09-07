import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';


/// 예수금을 고치는 시트.
///
/// **앱은 예수금을 계산해 주지 않는다.** 세금·실제 수수료 등급·체결가·환전
/// 스프레드·CMA 이자·배당 입금·외부 입출금까지 알 수 없어서, 계산하면 매번
/// 조금씩 틀리고 그 오차가 조정할 때마다 쌓인다. 게다가 틀린 예수금은 다음
/// 조정의 매수 예산으로 들어가 수량을 틀리게 만든다.
///
/// 그래서 예수금은 **사용자가 선언하는 사실**로 다룬다 — 목표 비중과 같다.
/// 대신 언제 적은 값인지를 같이 보여 준다. 낡은 값은 티가 나야 고칠 수 있고,
/// 계산으로 틀린 값은 티가 안 난다.
class CashEditSheet extends StatefulWidget {
  final Portfolio pf;
  final PortfolioItem item;

  const CashEditSheet({super.key, required this.pf, required this.item});

  static Future<void> show(
      BuildContext context, Portfolio pf, PortfolioItem item) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x8016130F),
      builder: (_) => CashEditSheet(pf: pf, item: item),
    );
  }

  @override
  State<CashEditSheet> createState() => _CashEditSheetState();
}

class _CashEditSheetState extends State<CashEditSheet> {
  late final TextEditingController _amountCtl;
  late bool _inWeight;

  @override
  void initState() {
    super.initState();
    final v = widget.item.shares;
    _amountCtl = TextEditingController(
        text: v == 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2));
    _inWeight = widget.item.inWeight;
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  bool get _isKo => Localizations.localeOf(context).languageCode == 'ko';

  /// `3일 전에 적음` — 낡았는지 한눈에 보이게.
  String? _stamp() {
    final at = widget.item.cashUpdatedAt;
    if (at == null) return null;
    final days = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(at))
        .inDays;
    if (_isKo) {
      if (days <= 0) return '오늘 적은 값';
      return '$days일 전에 적은 값';
    }
    if (days <= 0) return 'Entered today';
    return 'Entered $days ${days == 1 ? "day" : "days"} ago';
  }

  Future<void> _save() async {
    final raw = _amountCtl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(raw);
    await context.read<PortfolioProvider>().updateCash(
          widget.pf.id,
          widget.item.id,
          amount: amount,
          inWeight: _inWeight,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.deleteConfirmTitle),
        content: Text(_isKo
            ? '예수금 항목을 지웁니다. 비중 계산에서도 빠집니다.'
            : 'This removes the cash entry. It will no longer count toward weights.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context
        .read<PortfolioProvider>()
        .deleteItem(widget.pf.id, widget.item.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sym = widget.pf.currency == 'USD' ? '\$' : '₩';
    final stamp = _stamp();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.scaffoldBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(DS.sheetRadius)),
        ),
        padding: EdgeInsets.fromLTRB(
            DS.screenPaddingH, 10, DS.screenPaddingH,
            MediaQuery.paddingOf(context).bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6CFBC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(children: [
            Text(l10n.cash,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            const SizedBox(width: 9),
            if (stamp != null)
              Text(stamp,
                  style: TextStyle(
                      fontSize: DS.caption,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.textSecondary),
              tooltip: l10n.delete,
              onPressed: _delete,
            ),
          ]),
          const SizedBox(height: 10),

          TextField(
            controller: _amountCtl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: context.textPrimary),
            decoration: InputDecoration(
              prefixText: '$sym ',
              prefixStyle: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary),
              hintText: '0',
              hintStyle: TextStyle(color: context.textHint),
              filled: true,
              fillColor: context.cardBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.tileRadius),
                  borderSide: BorderSide(color: context.borderColor)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.tileRadius),
                  borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.tileRadius),
                  borderSide: BorderSide(color: context.brand, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.cashCheckAtBroker,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: context.textSecondary)),
          ),
          const SizedBox(height: 14),

          // ── 비중에 포함할지 ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(DS.tileRadius),
              border: Border.all(color: context.cardBorder),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.cashInWeightTitle,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          _inWeight
                              ? l10n.cashInWeightOn
                              : l10n.cashInWeightOff,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                              color: context.textSecondary)),
                    ]),
              ),
              Switch(
                value: _inWeight,
                activeThumbColor: context.brand,
                onChanged: (v) => setState(() => _inWeight = v),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: DS.buttonHeight,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.buttonRadius)),
              ),
              child: Text(l10n.save,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
