import 'dart:math';
import '../models/portfolio.dart';

/// 목표 비중에서 벗어난 정도.
class ItemDrift {
  final PortfolioItem item;
  final double currentWeight; // 현재 비중 (%)
  final double drift;         // 현재 − 목표 (%p). 양수면 과다 보유

  const ItemDrift({
    required this.item,
    required this.currentWeight,
    required this.drift,
  });
}

class Rebalancer {
  /// 허용 편차(`Portfolio.rebalancingThreshold`)를 넘어선 종목을 편차 큰 순으로 반환한다.
  ///
  /// 추가 투자금은 아직 집행 전 현금이므로 분모에서 제외한다 —
  /// 포함하면 모든 종목의 현재 비중이 희석돼 없는 편차가 생긴다.
  ///
  /// 임계값이 0이면 편차가 있는 종목이 모두 걸린다.
  static List<ItemDrift> driftExceeding(Portfolio portfolio) {
    final all = allDrifts(portfolio);
    final threshold = portfolio.rebalancingThreshold;
    return all.where((d) => d.drift.abs() >= threshold && d.drift.abs() > 0).toList();
  }

  /// 전 종목의 현재 비중과 편차. 편차 절댓값 내림차순.
  static List<ItemDrift> allDrifts(Portfolio portfolio) {
    final items = portfolio.items;
    if (items.isEmpty) return const [];
    if (items.any((i) => !i.isCash && i.currentPrice <= 0)) return const [];

    double priceInBase(PortfolioItem item) {
      if (item.isCash) return 1;
      if (item.market == 'US' && portfolio.currency == 'KRW') {
        return item.currentPrice * portfolio.exchangeRate;
      }
      if (item.market == 'KR' && portfolio.currency == 'USD') {
        return item.currentPrice / portfolio.exchangeRate;
      }
      return item.currentPrice;
    }

    final total = items.fold(0.0, (sum, item) {
      if (item.isCash) return sum + item.shares;
      return sum + item.shares * priceInBase(item);
    });
    if (total <= 0) return const [];

    final result = items.map((item) {
      final value = item.isCash ? item.shares : item.shares * priceInBase(item);
      final cw = value / total * 100;
      return ItemDrift(
        item: item,
        currentWeight: cw,
        drift: cw - item.targetWeight,
      );
    }).toList();

    result.sort((a, b) => b.drift.abs().compareTo(a.drift.abs()));
    return result;
  }

  static RebalanceResult? calculate(Portfolio portfolio) {
    final items = portfolio.items;
    if (items.isEmpty) return null;
    final weightSum = items.fold(0.0, (sum, item) => sum + item.targetWeight);
    if ((weightSum - 100).abs() > 0.01) return null;

    // 현금이 아닌 종목 중 현재가가 0인 것이 있으면 계산 불가
    final hasZeroPrice = items.any((i) => !i.isCash && i.currentPrice <= 0);
    if (hasZeroPrice) return null;

    final cr = portfolio.commissionEnabled ? portfolio.commissionRate : 0.0;

    double priceInBase(PortfolioItem item) {
      if (item.isCash) return 1;
      if (item.market == 'US' && portfolio.currency == 'KRW') return item.currentPrice * portfolio.exchangeRate;
      if (item.market == 'KR' && portfolio.currency == 'USD') return item.currentPrice / portfolio.exchangeRate;
      return item.currentPrice;
    }

    final total = items.fold(0.0, (sum, item) {
      if (item.isCash) return sum + item.shares;
      return sum + item.shares * priceInBase(item);
    }) + portfolio.additionalInvestment;

    if (total <= 0) {
      return RebalanceResult(
        results: items.map((item) => RebalanceItemResult(
          id: item.id, currentWeight: 0, finalWeight: 0,
          newShares: item.isCash ? 0 : item.shares.toInt(),
          newCashAmount: item.isCash ? item.shares : 0,
          isCash: item.isCash,
        )).toList(),
        cash: 0, commission: 0, total: 0,
      );
    }

    final data = <_CalcItem>[];
    for (final item in items) {
      final p = priceInBase(item);
      final cv = item.isCash ? item.shares : item.shares * p;
      final cw = (cv / total) * 100;
      final tv = total * (item.targetWeight / 100);
      if (item.isCash) {
        data.add(_CalcItem(item: item, price: p, currentValue: cv, currentWeight: cw, targetValue: tv, baseShares: tv.round(), remainder: 0));
      } else {
        if (p <= 0) continue; // 안전장치
        final ideal = tv / p;
        final base = ideal.floor();
        data.add(_CalcItem(item: item, price: p, currentValue: cv, currentWeight: cw, targetValue: tv, ideal: ideal, baseShares: base, remainder: ideal - base));
      }
    }

    final stocks = data.where((d) => !d.item.isCash).toList()..sort((a, b) => b.remainder.compareTo(a.remainder));
    double allocated = data.fold(0.0, (sum, d) => d.item.isCash ? sum + d.baseShares : sum + d.baseShares * d.price);
    double budget = total - allocated;
    for (final d in stocks) { if (d.item.targetWeight > 0 && budget >= d.price) { d.baseShares += 1; budget -= d.price; } }

    double commission = data.fold(0.0, (sum, d) => d.item.isCash ? sum : sum + (d.baseShares - d.item.shares).abs() * d.price * cr / 100);
    allocated = data.fold(0.0, (sum, d) => d.item.isCash ? sum + d.baseShares : sum + d.baseShares * d.price);
    double cash = total - allocated;

    if (cash < commission && stocks.isNotEmpty) {
      final removable = stocks.where((d) => d.remainder > 0 && d.baseShares > (d.ideal ?? 0).floor()).toList();
      if (removable.isNotEmpty) {
        removable.last.baseShares -= 1;
        commission = data.fold(0.0, (sum, d) => d.item.isCash ? sum : sum + (d.baseShares - d.item.shares).abs() * d.price * cr / 100);
      }
    }

    final ta = data.fold(0.0, (sum, d) => d.item.isCash ? sum + d.baseShares : sum + d.baseShares * d.price);
    final fc = max(0.0, total - ta - commission).roundToDouble();

    final results = data.map((d) {
      final ns = d.baseShares;
      final delta = ns - d.item.shares.toInt();
      final fv = d.item.isCash ? ns.toDouble() : ns * d.price;
      final fw = total > 0 ? (fv / total) * 100 : 0.0;
      return RebalanceItemResult(
        id: d.item.id, currentWeight: d.currentWeight, finalWeight: fw,
        newShares: d.item.isCash ? 0 : ns,
        newCashAmount: d.item.isCash ? ns.toDouble() : 0,
        delta: d.item.isCash ? 0 : delta,
        cashDelta: d.item.isCash ? ns.toDouble() - d.item.shares : 0,
        isCash: d.item.isCash,
      );
    }).toList();

    return RebalanceResult(results: results, cash: fc, commission: (commission * 100).round() / 100, total: total);
  }
}

class _CalcItem {
  final PortfolioItem item;
  final double price;
  final double currentValue;
  final double currentWeight;
  final double targetValue;
  final double? ideal;
  int baseShares;
  final double remainder;
  _CalcItem({required this.item, required this.price, required this.currentValue, required this.currentWeight, required this.targetValue, this.ideal, required this.baseShares, required this.remainder});
}
