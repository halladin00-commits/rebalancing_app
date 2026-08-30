import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/josa.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../services/api_service.dart';
import '../services/stock_search_service.dart';
import '../theme/design_system.dart';
import 'item_form_screen.dart';
import '../widgets/list_card.dart';

/// 종목 추가 · 검색 (시안 v13a).
///
/// 다이얼로그 안에 검색창을 넣으면 키보드가 올라올 자리가 없다.
/// 시안은 전체 화면이다 — 검색 → 시장 필터 → 결과에서 바로 담기.
/// 목록에 없으면 직접 등록으로 빠진다.
class ItemSearchScreen extends StatefulWidget {
  final Portfolio portfolio;
  const ItemSearchScreen({super.key, required this.portfolio});

  @override
  State<ItemSearchScreen> createState() => _ItemSearchScreenState();
}

enum _Filter { all, kr, us, cash }

class _ItemSearchScreenState extends State<ItemSearchScreen> {
  final _ctl = TextEditingController();
  _Filter _filter = _Filter.all;
  List<StockSearchResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    // 글자마다 API를 때리지 않는다
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final found = await StockSearchService.search(q);
    if (!mounted) return;
    setState(() {
      _results = found;
      _loading = false;
    });
  }

  List<StockSearchResult> get _filtered => switch (_filter) {
        _Filter.kr => _results.where((r) => r.market == 'KR').toList(),
        _Filter.us => _results.where((r) => r.market == 'US').toList(),
        _ => _results,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cashMode = _filter == _Filter.cash;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      resizeToAvoidBottomInset: true,
      body: Column(children: [
        _buildHeader(context),
        _buildSearchField(context),
        _buildFilters(context),
        Expanded(
          child: cashMode
              ? _buildCashPane(context)
              : _buildResults(context, l10n),
        ),
        _buildManualEntry(context),
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
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.addStock,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white)),
                    const SizedBox(height: 1),
                    // 어느 포트에 담는지 밝힌다
                    Text(widget.portfolio.name,
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

  // ── 검색창 ──

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: TextField(
        controller: _ctl,
        autofocus: true,
        onChanged: _onChanged,
        style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: context.textPrimary),
        decoration: InputDecoration(
          hintText: context.l10n.searchHint,
          hintStyle: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: context.textHint),
          prefixIcon: Icon(Icons.search, size: 20, color: context.textTertiary),
          suffixIcon: _ctl.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.cancel,
                      size: 18, color: context.textTertiary),
                  onPressed: () {
                    _ctl.clear();
                    _onChanged('');
                  },
                ),
          filled: true,
          fillColor: context.cardBg,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.tileRadius),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.tileRadius),
              borderSide: BorderSide(color: context.borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.tileRadius),
              borderSide: BorderSide(color: context.brand, width: 1.5)),
        ),
      ),
    );
  }

  // ── 시장 필터 ──

  Widget _buildFilters(BuildContext context) {
    final l10n = context.l10n;
    final items = <(_Filter, String)>[
      (_Filter.all, l10n.filterAll),
      (_Filter.kr, l10n.filterKr),
      (_Filter.us, l10n.filterUs),
      (_Filter.cash, l10n.cash),
    ];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 0),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (f, label) = items[i];
          final active = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? context.brand : context.cardBg,
                borderRadius: BorderRadius.circular(DS.chipRadius),
                border: Border.all(
                    color: active ? context.brand : context.borderColor),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : context.textSecondary)),
            ),
          );
        },
      ),
    );
  }

  // ── 결과 ──

  Widget _buildResults(BuildContext context, dynamic l10n) {
    if (_loading) {
      return Center(
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: context.brand)));
    }
    if (_ctl.text.trim().isEmpty) {
      return _hint(context, Icons.search, l10n.searchPrompt);
    }
    final list = _filtered;
    if (list.isEmpty) {
      return _hint(context, Icons.search_off, l10n.searchNoResult);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 16),
      children: [
        ListCard(rows: [for (final r in list) _buildResultRow(context, r)]),
      ],
    );
  }

  Widget _buildResultRow(BuildContext context, StockSearchResult r) {
    return ListRow(
      leading: MarketChip(market: r.market, label: r.market),
      title: r.name,
      titleSize: 14.5,
      subtitle: Text(r.ticker,
          style: TextStyle(
              fontSize: DS.body,
              fontWeight: FontWeight.w600,
              color: context.textSecondary)),
      amount: '',
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: () => _add(context, r),
      trailing: Icon(Icons.add_circle, size: 22, color: context.brand),
    );
  }

  Widget _hint(BuildContext context, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 30, color: context.textDisabled),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary)),
        ]),
      ),
    );
  }

  /// 현금(예수금)은 검색 대상이 아니라 바로 만드는 항목이다.
  Widget _buildCashPane(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.cashAddHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
          const SizedBox(height: 14),
          SizedBox(
            height: DS.buttonHeight,
            child: ElevatedButton(
              onPressed: () => _openForm(context, isCash: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.buttonRadius)),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              child: Text(l10n.cashAddButton,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── 직접 등록 ──

  Widget _buildManualEntry(BuildContext context) {
    if (_filter == _Filter.cash) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: InkWell(
        onTap: () => _openForm(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_note, size: 20, color: context.brand),
            const SizedBox(width: 7),
            Text(context.l10n.manualEntryHint,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.brand)),
          ]),
        ),
      ),
    );
  }

  // ── 담기 ──

  Future<void> _add(BuildContext context, StockSearchResult r) async {
    final pf = widget.portfolio;
    // 이미 있는 종목이면 그 종목으로 돌려보낸다 — 중복으로 담기지 않게
    final dup = pf.items.where((i) => i.ticker == r.ticker).firstOrNull;
    if (dup != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.alreadyInPortfolio(
            withJosa(r.name, Josa.eunNeun, korean: Localizations.localeOf(context).languageCode == 'ko'),
          )),
        ),
      );
      return;
    }

    // 현재가를 미리 받아 둔다 — 실패해도 0으로 두고 진행한다
    double price = 0;
    final res = await ApiService.fetchStockPrice(r.ticker, r.market);
    if (res.ok && res.data != null) price = res.data!.currentPrice;
    if (!mounted) return;

    _openForm(context,
        preset: PortfolioItem(
          id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
          name: r.name,
          ticker: r.ticker,
          market: r.market,
          currentPrice: price,
        ));
  }

  void _openForm(BuildContext context,
      {PortfolioItem? preset, bool isCash = false}) {
    final pf = widget.portfolio;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemFormScreen(
          preset: preset ??
              (isCash
                  ? PortfolioItem(
                      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
                      name: context.l10n.cash,
                      market: 'CASH',
                      isCash: true,
                    )
                  : null),
          priceAuto: pf.priceAuto,
          currency: pf.currency,
          onSave: (item) {
            context.read<PortfolioProvider>().addItem(pf.id, item);
            // 검색 화면은 **닫지 않는다.** 종목을 열 개 담으려면 열 번
            // 처음부터 들어와야 했다. 폼은 스스로 닫히므로 여기 남아
            // 바로 다음 종목을 담을 수 있다. 다 담았으면 사용자가 닫는다.
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(context.l10n.itemAdded(item.name)),
                duration: const Duration(seconds: 2),
              ));
          },
        ),
      ),
    );
  }
}
