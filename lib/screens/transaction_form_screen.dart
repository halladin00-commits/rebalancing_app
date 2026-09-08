import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../theme/design_system.dart';
import '../utils/share_format.dart';
import '../widgets/custom_date_picker.dart';
import '../widgets/list_card.dart';

/// 거래 추가·수정 (시안 v15a).
///
/// 개편 전에는 바텀시트 안에 작은 폼이 들어 있어 키보드가 올라오면 가려졌다.
/// 시안은 전체 화면이다 — 종목이 무엇인지 위에 못 박아 두고,
/// 매수/매도 → 수량 → 단가 → 날짜 순으로 내려오며 거래금액이 즉시 계산된다.
class TransactionFormScreen extends StatefulWidget {
  final Portfolio portfolio;
  final PortfolioItem item;

  /// 수정할 거래. 없으면 새 거래.
  final StockTransaction? transaction;

  const TransactionFormScreen({
    super.key,
    required this.portfolio,
    required this.item,
    this.transaction,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  late bool _isBuy;
  late DateTime _date;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _priceCtl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _isBuy = t == null || t.quantity >= 0;
    _date = t?.date ?? DateTime.now();
    _qtyCtl = TextEditingController(
        text: t == null ? '' : formatShares(t.quantity.abs()));
    _priceCtl = TextEditingController(
        text: t == null
            ? (widget.item.currentPrice > 0
                ? _priceStr(widget.item.currentPrice)
                : '')
            : _priceStr(t.price));
    _qtyCtl.addListener(_onChanged);
    _priceCtl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() => _error = null);

  String _priceStr(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  String get _sym => widget.item.market == 'US' ? '\$' : '₩';

  double get _qty => double.tryParse(_qtyCtl.text.trim()) ?? 0;
  double get _price => double.tryParse(_priceCtl.text.trim()) ?? 0;

  String _fmtMoney(double n) {
    if (widget.item.market == 'US') return '\$${n.toStringAsFixed(2)}';
    return '₩${n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
            children: [
              _buildItemCard(context),
              const SizedBox(height: 9),
              _buildSideSegment(context),
              const SizedBox(height: 9),
              ListCard(rows: [
                _fieldRow(context, l10n.transactionQty, _qtyCtl,
                    suffix: l10n.unitShares,
                    decimal: widget.portfolio.fractionalEnabled),
                _fieldRow(context, l10n.transactionPrice, _priceCtl,
                    prefix: _sym, decimal: true),
                _dateRow(context),
                if (widget.portfolio.commissionEnabled)
                  _feeRow(context),
                _amountRow(context),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.danger)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.info_outline, size: 15, color: context.textTertiary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(l10n.transactionAffectsAvg,
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
        _buildCta(context, item),
      ]),
    );
  }

  // ── 헤더 ──

  /// 지우기 전에 **무엇이 다시 계산되는지** 말한다.
  /// 거래 하나를 빼면 보유 수량과 평균 단가가 함께 바뀐다.
  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final tx = widget.transaction;
    if (tx == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.cardBg,
        title: Text(l10n.deleteTransactionTitle,
            style: TextStyle(color: ctx.textPrimary)),
        content: Text(l10n.deleteTransactionBody,
            style: TextStyle(fontSize: 13, color: ctx.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.danger),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context
        .read<PortfolioProvider>()
        .deleteTransaction(widget.portfolio.id, widget.item.id, tx.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.transactionDeleted),
      duration: const Duration(seconds: 2),
    ));
    Navigator.pop(context);
  }

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
          // 큰 글씨 설정(접근성)에서 제목+부제가 52px를 넘는다. 고정이면
          // `BOTTOM OVERFLOWED`가 뜬다 — 최소 높이만 정하고 늘어나게 둔다.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(children: [
              IconButton(
                tooltip: context.l10n.a11yClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.transaction == null
                      ? l10n.addTransaction
                      : l10n.editTransaction,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.white),
                ),
              ),
              // 어느 통화로 입력하는지 못 박아 둔다 — 해외 종목에서 헷갈린다
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(DS.chipRadius),
                ),
                child: Text(widget.item.market == 'US' ? 'USD' : 'KRW',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 종목 카드 ──

  Widget _buildItemCard(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final parts = <String>[
      if (item.ticker.isNotEmpty) item.ticker,
      if (item.currentPrice > 0)
        '${l10n.currentPrice} ${_fmtMoney(item.currentPrice)}',
      '${l10n.holdingQty} ${formatShares(item.shares)}${l10n.unitShares}',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(DS.tileRadius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16130F), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MarketChip(
              market: item.isCash ? 'CASH' : item.market,
              label: item.isCash ? l10n.cash : item.market),
          const SizedBox(width: 6),
          Expanded(
            child: Text(item.displayName(context),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 5),
        Text(parts.join(' · '),
            style: TextStyle(
                fontSize: DS.body,
                fontWeight: FontWeight.w600,
                color: context.textSecondary),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ── 매수 / 매도 ──

  Widget _buildSideSegment(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.trackBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        _side(context, l10n.buy, true),
        const SizedBox(width: 6),
        _side(context, l10n.sell, false),
      ]),
    );
  }

  Widget _side(BuildContext context, String label, bool buy) {
    final active = _isBuy == buy;
    // 매수는 초록, 매도는 주황 — 손익색과 같은 뜻으로 읽히게 둔다
    final activeBg = buy ? const Color(0xFF0E7A52) : context.danger;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isBuy = buy),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  color: active ? Colors.white : context.textSecondary)),
        ),
      ),
    );
  }

  // ── 입력 행 ──

  Widget _fieldRow(BuildContext context, String label,
      TextEditingController ctl,
      {String? prefix, String? suffix, bool decimal = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ),
        if (prefix != null)
          Text(prefix,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
        SizedBox(
          width: 130,
          child: TextField(
            controller: ctl,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimary),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              hintText: '0',
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 3),
          Text(suffix,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ],
      ]),
    );
  }

  Widget _dateRow(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () async {
        final picked = await showCustomDatePicker(context, initialDate: _date);
        if (picked != null) setState(() => _date = picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(
            child: Text(l10n.transactionDate,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
          ),
          Text(
            '${_date.year}.${_date.month.toString().padLeft(2, '0')}.${_date.day.toString().padLeft(2, '0')}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimary),
          ),
          const SizedBox(width: 8),
          Icon(Icons.calendar_month, size: 18, color: context.brand),
        ]),
      ),
    );
  }

  /// 수수료 (시안 v13b). 포트 설정으로 계산되므로 여기서 고칠 수 없다 —
  /// 시안의 `edit`은 거래마다 요율을 따로 두는 것인데, 그러려면 저장 형식이
  /// 바뀐다 (docs/DECISIONS.md에서 하지 않기로 정했다).
  /// 수수료를 끄고 쓰는 포트에는 아예 내지 않는다.
  Widget _feeRow(BuildContext context) {
    final pf = widget.portfolio;
    final l10n = context.l10n;
    final rate = pf.commissionRate;
    final fee = _qty * _price * rate / 100;
    final rateText =
        rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.feeLabel,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
            const SizedBox(height: 2),
            Text(l10n.commissionAutoRate(rateText),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary)),
          ]),
        ),
        Text(_fmtMoney(fee),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textSecondary)),
      ]),
    );
  }

  /// 거래금액은 입력이 아니라 결과다 — 수량 × 단가.
  Widget _amountRow(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(
          child: Text(l10n.transactionAmount,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
        ),
        Text(_fmtMoney(_qty * _price),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: context.textPrimary)),
      ]),
    );
  }

  // ── 저장 ──

  Widget _buildCta(BuildContext context, PortfolioItem item) {
    final l10n = context.l10n;
    return Container(
      color: context.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        // **글자를 붙인다.** 우상단 휴지통 아이콘으로 뒀더니 눈에 안 띄고
        // 무슨 버튼인지도 알기 어려웠다. 지우기는 되돌릴 수 없는 일이라
        // 「여기 있다」가 분명해야 하고, 실수로 눌리지 않게 저장과
        // 떨어져 있어야 한다.
        if (widget.transaction != null) ...[
          SizedBox(
            height: DS.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.delete,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.danger,
                side: BorderSide(color: context.danger.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.buttonRadius)),
              ),
            ),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: SizedBox(
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
              child: Text(l10n.saveTransaction,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_qty <= 0) {
      setState(() => _error = l10n.validationQtyPositive);
      return;
    }
    if (_price <= 0) {
      setState(() => _error = l10n.validationPricePositive);
      return;
    }
    // 매도는 보유 수량을 넘길 수 없다 — 수정 중이면 그 거래분은 되돌려 놓고 센다
    if (!_isBuy) {
      var owned = widget.item.shares;
      final t = widget.transaction;
      if (t != null) owned -= t.quantity;
      if (_qty > owned + sharesEpsilon) {
        setState(() => _error = l10n.validationSellExceeds(
            '${formatShares(owned)}${l10n.unitShares}'));
        return;
      }
    }

    final tx = StockTransaction(
      id: widget.transaction?.id ??
          DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      date: _date,
      quantity: _qty * (_isBuy ? 1.0 : -1.0),
      price: _price,
    );
    await context
        .read<PortfolioProvider>()
        .upsertTransaction(widget.portfolio.id, widget.item.id, tx);
    if (mounted) Navigator.pop(context, true);
  }
}
