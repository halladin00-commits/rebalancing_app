import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/portfolio.dart';
import 'services/storage_service.dart';
import 'screens/portfolio_list_screen.dart';
import 'services/stock_search_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StockSearchService.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => PortfolioProvider(),
      child: const RebalancingApp(),
    ),
  );
}

class RebalancingApp extends StatelessWidget {
  const RebalancingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rebalancing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        fontFamily: 'Pretendard',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const PortfolioListScreen(),
    );
  }
}

/// 앱 전역 상태 관리
class PortfolioProvider extends ChangeNotifier {
  List<Portfolio> _portfolios = [];
  bool _loaded = false;

  List<Portfolio> get portfolios => _portfolios;
  bool get loaded => _loaded;

  PortfolioProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    _portfolios = await StorageService.loadPortfolios();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await StorageService.savePortfolios(_portfolios);
    notifyListeners();
  }

  // ── 포트폴리오 CRUD ──

  Future<void> addPortfolio(Portfolio pf) async {
    _portfolios.add(pf);
    await _save();
  }

  Future<void> updatePortfolio(String id, Portfolio updated) async {
    final idx = _portfolios.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _portfolios[idx] = updated;
      await _save();
    }
  }

  Future<void> deletePortfolio(String id) async {
    _portfolios.removeWhere((p) => p.id == id);
    await _save();
  }

  Future<void> reorderPortfolios(List<Portfolio> newOrder) async {
    _portfolios = newOrder;
    await _save();
  }

  Portfolio? getPortfolio(String id) {
    try {
      return _portfolios.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── 종목 CRUD ──

  Future<void> addItem(String pfId, PortfolioItem item) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.items.add(item);
      await _save();
    }
  }

  Future<void> updateItem(String pfId, PortfolioItem item) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      final idx = pf.items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        pf.items[idx] = item;
        await _save();
      }
    }
  }

  Future<void> deleteItem(String pfId, String itemId) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.items.removeWhere((i) => i.id == itemId);
      await _save();
    }
  }

  Future<void> reorderItems(String pfId, List<PortfolioItem> newOrder) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.items = newOrder;
      await _save();
    }
  }

  // ── 설정 변경 ──

  Future<void> updateSettings(
    String pfId, {
    String? currency,
    double? commissionRate,
    bool? commissionEnabled,
    double? exchangeRate,
    bool? exchangeAuto,
    bool? priceAuto,
  }) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      if (currency != null) pf.currency = currency;
      if (commissionRate != null) pf.commissionRate = commissionRate;
      if (commissionEnabled != null) pf.commissionEnabled = commissionEnabled;
      if (exchangeRate != null) pf.exchangeRate = exchangeRate;
      if (exchangeAuto != null) pf.exchangeAuto = exchangeAuto;
      if (priceAuto != null) pf.priceAuto = priceAuto;
      await _save();
    }
  }

  Future<void> setAdditionalInvestment(String pfId, double amount) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.additionalInvestment = amount;
      await _save();
    }
  }

  Future<void> applyRebalancing(
    String pfId,
    List<Map<String, dynamic>> results,
    double residualCash,  // 추가된 파라미터
  ) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      for (final r in results) {
        final item = pf.items.firstWhere((i) => i.id == r['id']);
        item.shares = (r['newShares'] as num).toDouble();
      }
      pf.additionalInvestment = residualCash; // 잔여현금 보존
      await _save();
    }
  }

  Future<void> updateLastRefreshed(String pfId) async {
    final pf = getPortfolio(pfId);
    if (pf != null) {
      pf.lastUpdated = DateTime.now().millisecondsSinceEpoch;
      await _save();
    }
  }

  /// 강제 UI 갱신
  void refresh() => notifyListeners();
}
