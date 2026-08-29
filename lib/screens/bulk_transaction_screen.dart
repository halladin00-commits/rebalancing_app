import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../services/review_service.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';
import '../utils/share_format.dart';

/// 조정 제안을 거래 내역으로 한 번에 기록하는 화면 (시안 v20c).
///
/// 예전에는 다이얼로그였다. 3건을 기록하려고 거래 추가 화면을 세 번 여는 대신
/// **한 장에서 수량·단가만 고쳐** 한꺼번에 넣는다.
///
/// 제안은 주문을 내지 않는다 — 증권사에서 실제로 체결한 수량·단가로 고쳐 넣어야
/// 다음 조정이 정확해진다. 단가는 제안 시점 현재가를 채워 두기만 한다.
class BulkTransactionScreen extends StatefulWidget {
  final Portfolio pf;
  final RebalanceResult rb;

  const BulkTransactionScreen({super.key, required this.pf, required this.rb});

  @override
  State<BulkTransactionScreen> createState() => _BulkTransactionScreenState();
}

class _BulkTransactionScreenState extends State<BulkTransactionScreen> {
  late final List<RebalanceItemResult> _tradeable;
  late final Map<String, TextEditingController> _qtyCtrl;
  late final Map<String, TextEditingController> _priceCtrl;
  late final Map<String, bool> _isBuyMap;

  /// 거래일은 **한 번만** 고른다 — 같은 날 한 묶음으로 체결한 것이므로.
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tradeable =
        widget.rb.results.where((r) => !r.isCash && r.delta != 0).toList();
    _qtyCtrl = {
      for (final r in _tradeable)
        r.id: TextEditingController(text: formatShares(r.delta.abs()))
    };
    _priceCtrl = {
      for (final r in _tradeable)
        r.id: TextEditingController(
            text: _priceStr(
                widget.pf.items.firstWhere((i) => i.id == r.id).currentPrice))
    };
    _isBuyMap = {for (final r in _tradeable) r.id: r.delta > 0};
  }

  @override
  void dispose() {
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    for (final c in _priceCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _priceStr(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(3);

  double _qty(String id) => double.tryParse(_qtyCtrl[id]!.text) ?? 0;
  double _price(String id) => double.tryParse(_priceCtrl[id]!.text) ?? 0;

  /// 종목 통화 → 포트 통화 환산 배수.
  double _fx(PortfolioItem item) {
    if (item.market == 'US' && widget.pf.currency == 'KRW') {
      return widget.pf.exchangeRate;
    }
    if (item.market == 'KR' && widget.pf.currency == 'USD') {
      return 1.0 / widget.pf.exchangeRate;
    }
    return 1.0;
  }

  /// 포트 통화 기준 거래 금액.
  double _amount(RebalanceItemResult r) {
    final item = widget.pf.items.firstWhere((i) => i.id == r.id);
    return _qty(r.id) * _price(r.id) * _fx(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
            children: [
              _buildDateCard(context),
              const SizedBox(height: 9),
              for (final r in _tradeable) ...[
                _buildTradeCard(context, r),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 1),
              _buildSummary(context),
              const SizedBox(height: 9),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 15, color: context.textTertiary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(l10n.priceIsProposalNote,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                          color: context.textSecondary)),
                ),
              ]),
            ],
          ),
        ),
        _buildCta(context),
      ]),
    );
  }

  // ── 헤더 ──

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: context.appBarBg,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context, false),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.recordNTradesTitle(_tradeable.length),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white)),
                    const SizedBox(height: 1),
                    Text('${widget.pf.name} · ${l10n.fromProposal}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.onBrandSecondary),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 거래일 (한 번만 고른다) ──

  Widget _buildDateCard(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: _pickDate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 13),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(DS.listCardRadius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.transactionDate,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.textStrong)),
              const SizedBox(height: 3),
              Text(l10n.appliedToAllN(_tradeable.length),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary)),
            ]),
          ),
          Text(
              '${_date.year}.${_date.month.toString().padLeft(2, '0')}'
              '.${_date.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: context.textPrimary)),
          const SizedBox(width: 8),
          Icon(Icons.edit_calendar, size: 20, color: context.brand),
        ]),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ── 거래 한 건 ──

  Widget _buildTradeCard(BuildContext context, RebalanceItemResult r) {
    final l10n = context.l10n;
    final item = widget.pf.items.firstWhere((i) => i.id == r.id);
    final isBuy = _isBuyMap[r.id]!;
    final crossesFx = _fx(item) != 1.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _sideToggle(r.id, isBuy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.name,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(fmtMoney(_amount(r), widget.pf.currency),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: context.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _field(l10n.transactionQty, _qtyCtrl[r.id]!,
                  isInt: !widget.pf.fractionalEnabled)),
          const SizedBox(width: 8),
          Expanded(child: _field(l10n.transactionPrice, _priceCtrl[r.id]!)),
        ]),
        if (crossesFx) ...[
          const SizedBox(height: 8),
          Text(
              l10n.fxConverted(
                  fmtPrice(widget.pf.exchangeRate, widget.pf.currency),
                  fmtMoney(_amount(r), widget.pf.currency)),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary)),
        ],
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctl, {bool isInt = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textSecondary)),
      const SizedBox(height: 4),
      TextField(
        controller: ctl,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
        textAlign: TextAlign.right,
        // 금액이 바로 따라 움직여야 무엇을 고치는지 보인다
        onChanged: (_) => setState(() {}),
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: context.fieldFill,
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
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _sideToggle(String id, bool isBuy) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _sideBtn(id, true, isBuy, l10n.transactionBuy, context.brandOnLight,
            context.pnlUpTint),
        Container(width: 1, color: context.borderColor),
        _sideBtn(id, false, isBuy, l10n.transactionSell, context.danger,
            context.pnlDownTint),
      ]),
    );
  }

  Widget _sideBtn(String id, bool targetBuy, bool currentBuy, String label,
      Color fg, Color bg) {
    final selected = targetBuy == currentBuy;
    return GestureDetector(
      onTap: () => setState(() => _isBuyMap[id] = targetBuy),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        color: selected ? bg : Colors.transparent,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? fg : context.textTertiary)),
      ),
    );
  }

  // ── 합계 ──

  /// 수수료와 조정 후 예수금. 둘 다 **포트 설정을 따르므로** 여기서 고칠 수 없다.
  Widget _buildSummary(BuildContext context) {
    final l10n = context.l10n;
    final pf = widget.pf;

    double cashAfter = widget.rb.cash;
    for (final r in widget.rb.results) {
      if (r.isCash) cashAfter += r.newCashAmount;
    }

    double commission = 0;
    if (pf.commissionEnabled) {
      for (final r in _tradeable) {
        commission += _amount(r) * pf.commissionRate / 100;
      }
    }

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(DS.listCardRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (pf.commissionEnabled)
          line(
              l10n.commissionAutoSum(
                  _trimZero(pf.commissionRate), _tradeable.length),
              fmtMoney(commission, pf.currency)),
        // 조정 제안의 예수금 가계부와 **같은 숫자**여야 한다.
        // `rb.cash`는 어디에도 배분되지 않은 잔여금(추가 투자금으로 넘어간다)일
        // 뿐이고, 실제 예수금 잔액은 현금 항목의 `newCashAmount`다.
        // 둘을 더한 것이 조정 뒤 계좌에 실제로 남는 돈이다.
        line(l10n.cashAfterAdjust, fmtMoney(cashAfter, pf.currency)),
        const SizedBox(height: 9),
        Text(l10n.followsPortfolioSettings,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: context.textTertiary)),
      ]),
    );
  }

  // ── 기록 ──

  Widget _buildCta(BuildContext context) {
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.buttonRadius)),
          ),
          child: Text(context.l10n.recordNButton(_tradeable.length),
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final provider = context.read<PortfolioProvider>();
    final stamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < _tradeable.length; i++) {
      final r = _tradeable[i];
      final qty = _qty(r.id);
      final price = _price(r.id);
      if (qty <= 0 || price <= 0) continue;
      final tx = StockTransaction(
        id: '${stamp}_$i',
        date: _date,
        quantity: qty * (_isBuyMap[r.id]! ? 1.0 : -1.0),
        price: price,
      );
      await provider.upsertTransaction(widget.pf.id, r.id, tx);
    }

    final cashItems = widget.rb.results
        .where((r) => r.isCash)
        .map((r) => {'id': r.id, 'newShares': r.newCashAmount})
        .toList();
    await provider.updateCashAndResidual(
        widget.pf.id, cashItems, widget.rb.cash);

    if (!mounted) return;
    ReviewService.onRebalancingApplied();
    Navigator.pop(context, true);
  }
}
