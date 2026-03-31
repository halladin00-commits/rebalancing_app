import 'dart:convert';

/// 종목 항목
class PortfolioItem {
  String id;
  String name;
  String ticker;
  String market; // "KR", "US", "CASH"
  bool isCash;
  double targetWeight;
  double shares;
  double currentPrice;

  PortfolioItem({
    required this.id,
    required this.name,
    this.ticker = '',
    this.market = 'KR',
    this.isCash = false,
    this.targetWeight = 0,
    this.shares = 0,
    this.currentPrice = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ticker': ticker,
    'market': market,
    'isCash': isCash,
    'targetWeight': targetWeight,
    'shares': shares,
    'currentPrice': currentPrice,
  };

  factory PortfolioItem.fromJson(Map<String, dynamic> json) => PortfolioItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    ticker: json['ticker'] ?? '',
    market: json['market'] ?? 'KR',
    isCash: json['isCash'] ?? false,
    targetWeight: (json['targetWeight'] ?? 0).toDouble(),
    shares: (json['shares'] ?? 0).toDouble(),
    currentPrice: (json['currentPrice'] ?? 0).toDouble(),
  );

  PortfolioItem copyWith({
    String? id,
    String? name,
    String? ticker,
    String? market,
    bool? isCash,
    double? targetWeight,
    double? shares,
    double? currentPrice,
  }) => PortfolioItem(
    id: id ?? this.id,
    name: name ?? this.name,
    ticker: ticker ?? this.ticker,
    market: market ?? this.market,
    isCash: isCash ?? this.isCash,
    targetWeight: targetWeight ?? this.targetWeight,
    shares: shares ?? this.shares,
    currentPrice: currentPrice ?? this.currentPrice,
  );
}

/// 포트폴리오
class Portfolio {
  String id;
  String name;
  String emoji;
  String currency; // "KRW", "USD"
  double commissionRate;
  bool commissionEnabled;
  double exchangeRate;
  bool exchangeAuto;
  bool priceAuto;
  double additionalInvestment;
  int? lastUpdated; // timestamp
  List<PortfolioItem> items;

  Portfolio({
    required this.id,
    required this.name,
    this.emoji = '📈',
    this.currency = 'KRW',
    this.commissionRate = 0.015,
    this.commissionEnabled = true,
    this.exchangeRate = 1370,
    this.exchangeAuto = false,
    this.priceAuto = false,
    this.additionalInvestment = 0,
    this.lastUpdated,
    List<PortfolioItem>? items,
  }) : items = items ?? [];

  /// 총 자산 평가액
  double get totalValue {
    return items.fold(0.0, (sum, item) {
      if (item.isCash) return sum + item.shares;
      final price = _priceInBase(item);
      return sum + item.shares * price;
    });
  }

  /// 목표비중 합계
  double get weightSum =>
      items.fold(0.0, (sum, item) => sum + item.targetWeight);

  /// 종목의 기준통화 환산 가격
  double _priceInBase(PortfolioItem item) {
    if (item.isCash) return 1;
    if (item.market == 'US' && currency == 'KRW') {
      return item.currentPrice * exchangeRate;
    }
    if (item.market == 'KR' && currency == 'USD') {
      return item.currentPrice / exchangeRate;
    }
    return item.currentPrice;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'currency': currency,
    'commissionRate': commissionRate,
    'commissionEnabled': commissionEnabled,
    'exchangeRate': exchangeRate,
    'exchangeAuto': exchangeAuto,
    'priceAuto': priceAuto,
    'additionalInvestment': additionalInvestment,
    'lastUpdated': lastUpdated,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory Portfolio.fromJson(Map<String, dynamic> json) => Portfolio(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    emoji: json['emoji'] ?? '📈',
    currency: json['currency'] ?? 'KRW',
    commissionRate: (json['commissionRate'] ?? 0.015).toDouble(),
    commissionEnabled: json['commissionEnabled'] ?? true,
    exchangeRate: (json['exchangeRate'] ?? 1370).toDouble(),
    exchangeAuto: json['exchangeAuto'] ?? false,
    priceAuto: json['priceAuto'] ?? false,
    additionalInvestment: (json['additionalInvestment'] ?? 0).toDouble(),
    lastUpdated: json['lastUpdated'],
    items: (json['items'] as List<dynamic>?)
            ?.map((e) => PortfolioItem.fromJson(e))
            .toList() ??
        [],
  );

  Portfolio copyWith({
    String? id,
    String? name,
    String? emoji,
    String? currency,
    double? commissionRate,
    bool? commissionEnabled,
    double? exchangeRate,
    bool? exchangeAuto,
    bool? priceAuto,
    double? additionalInvestment,
    int? lastUpdated,
    List<PortfolioItem>? items,
  }) => Portfolio(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    currency: currency ?? this.currency,
    commissionRate: commissionRate ?? this.commissionRate,
    commissionEnabled: commissionEnabled ?? this.commissionEnabled,
    exchangeRate: exchangeRate ?? this.exchangeRate,
    exchangeAuto: exchangeAuto ?? this.exchangeAuto,
    priceAuto: priceAuto ?? this.priceAuto,
    additionalInvestment: additionalInvestment ?? this.additionalInvestment,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    items: items ?? this.items.map((e) => e.copyWith()).toList(),
  );
}

/// 리밸런싱 결과
class RebalanceResult {
  final List<RebalanceItemResult> results;
  final double cash;
  final double commission;
  final double total;

  RebalanceResult({
    required this.results,
    required this.cash,
    required this.commission,
    required this.total,
  });

  bool get hasChanges => results.any((r) => r.delta != 0);
}

class RebalanceItemResult {
  final String id;
  final double currentWeight;
  final double finalWeight;
  final int newShares; // 현금이 아닌 경우 주 단위
  final double newCashAmount; // 현금인 경우 금액
  final int delta; // 변화량 (현금 아닌 경우)
  final double cashDelta; // 현금 변화량
  final bool isCash;

  RebalanceItemResult({
    required this.id,
    required this.currentWeight,
    required this.finalWeight,
    this.newShares = 0,
    this.newCashAmount = 0,
    this.delta = 0,
    this.cashDelta = 0,
    this.isCash = false,
  });
}
