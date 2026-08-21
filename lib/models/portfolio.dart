/// 매수/매도 거래 내역
class StockTransaction {
  final String id;
  final DateTime date;
  final double quantity; // 양수 = 매수, 음수 = 매도
  final double price;   // 종목 통화 기준 주당 단가

  StockTransaction({
    required this.id,
    required this.date,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.millisecondsSinceEpoch,
    'quantity': quantity,
    'price': price,
  };

  factory StockTransaction.fromJson(Map<String, dynamic> json) => StockTransaction(
    id: json['id'] ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(json['date'] ?? 0),
    quantity: (json['quantity'] ?? 0).toDouble(),
    price: (json['price'] ?? 0).toDouble(),
  );

  StockTransaction copyWith({DateTime? date, double? quantity, double? price}) =>
      StockTransaction(id: id, date: date ?? this.date,
          quantity: quantity ?? this.quantity, price: price ?? this.price);
}

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
  double avgPrice;
  double previousClose;
  String createdAt;               // 'yyyy-MM-dd'
  List<StockTransaction> transactions;

  PortfolioItem({
    required this.id,
    required this.name,
    this.ticker = '',
    this.market = 'KR',
    this.isCash = false,
    this.targetWeight = 0,
    this.shares = 0,
    this.currentPrice = 0,
    this.avgPrice = 0,
    this.previousClose = 0,
    String? createdAt,
    List<StockTransaction>? transactions,
  })  : createdAt = createdAt ?? _todayKey(),
        transactions = transactions ?? [];

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ticker': ticker,
    'market': market,
    'isCash': isCash,
    'targetWeight': targetWeight,
    'shares': shares,
    'currentPrice': currentPrice,
    'avgPrice': avgPrice,
    'previousClose': previousClose,
    'createdAt': createdAt,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    final shares = (json['shares'] ?? 0).toDouble();
    final avgPrice = (json['avgPrice'] ?? 0).toDouble();
    final today = _todayKey();

    final txList = (json['transactions'] as List<dynamic>?)
            ?.map((e) => StockTransaction.fromJson(e))
            .toList() ??
        [];

    // 마이그레이션: 거래 내역 없고 수량 있으면 합성 거래 생성
    if (txList.isEmpty && shares > 0 && !(json['isCash'] ?? false)) {
      final uid = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      txList.add(StockTransaction(
        id: 'migrated_$uid',
        date: DateTime.now(),
        quantity: shares,
        price: avgPrice,
      ));
    }

    return PortfolioItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ticker: json['ticker'] ?? '',
      market: json['market'] ?? 'KR',
      isCash: json['isCash'] ?? false,
      targetWeight: (json['targetWeight'] ?? 0).toDouble(),
      shares: shares,
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      avgPrice: avgPrice,
      previousClose: (json['previousClose'] ?? 0).toDouble(),
      createdAt: json['createdAt'] ?? today,
      transactions: txList,
    );
  }

  PortfolioItem copyWith({
    String? id,
    String? name,
    String? ticker,
    String? market,
    bool? isCash,
    double? targetWeight,
    double? shares,
    double? currentPrice,
    double? avgPrice,
    double? previousClose,
    String? createdAt,
    List<StockTransaction>? transactions,
  }) => PortfolioItem(
    id: id ?? this.id,
    name: name ?? this.name,
    ticker: ticker ?? this.ticker,
    market: market ?? this.market,
    isCash: isCash ?? this.isCash,
    targetWeight: targetWeight ?? this.targetWeight,
    shares: shares ?? this.shares,
    currentPrice: currentPrice ?? this.currentPrice,
    avgPrice: avgPrice ?? this.avgPrice,
    previousClose: previousClose ?? this.previousClose,
    createdAt: createdAt ?? this.createdAt,
    transactions: transactions ?? List.from(this.transactions),
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
  double rebalancingThreshold;

  /// 소수점 단위 매매 허용 여부. 기본은 온주(1주 단위) 거래다.
  /// 증권사·계좌에 따라 소수점 매매가 되는 곳만 켠다.
  bool fractionalEnabled;

  int? lastUpdated;
  List<PortfolioItem> items;

  // 그래프 커스터마이즈
  String graphTitle;                   // 도넛 중앙 텍스트
  Map<String, String> graphColors;    // itemId → hex color
  Map<String, String> graphNames;     // itemId → 표시 이름
  List<String> graphOrder;            // itemId 순서 (비어있으면 비중 내림차순)

  Portfolio({
    required this.id,
    required this.name,
    this.emoji = '📈',
    this.currency = 'KRW',
    this.commissionRate = 0.015,
    this.commissionEnabled = false,
    this.exchangeRate = 1370,
    this.exchangeAuto = true,
    this.priceAuto = true,
    this.additionalInvestment = 0,
    this.rebalancingThreshold = 0.0,
    this.fractionalEnabled = false,
    this.lastUpdated,
    List<PortfolioItem>? items,
    String? graphTitle,
    Map<String, String>? graphColors,
    Map<String, String>? graphNames,
    List<String>? graphOrder,
  })  : items = items ?? [],
        graphTitle = graphTitle ?? '',
        graphColors = graphColors ?? {},
        graphNames = graphNames ?? {},
        graphOrder = graphOrder ?? [];

  /// 총 자산 평가액
  double get totalValue {
    return items.fold(0.0, (sum, item) {
      if (item.isCash) return sum + item.shares;
      final price = _priceInBase(item);
      return sum + item.shares * price;
    });
  }

  /// 미실현 손익 (기준통화, avgPrice > 0인 종목만)
  double get unrealizedPnL {
    return items.fold(0.0, (sum, item) {
      if (item.isCash || item.avgPrice <= 0 || item.shares <= 0) return sum;
      return sum + (_priceInBase(item) - _avgInBase(item)) * item.shares;
    });
  }

  /// 전일대비 손익 (기준통화, previousClose > 0인 종목만)
  double get dayPnL {
    return items.fold(0.0, (sum, item) {
      if (item.isCash || item.previousClose <= 0 || item.shares <= 0) return sum;
      return sum + (_priceInBase(item) - _prevCloseInBase(item)) * item.shares;
    });
  }

  bool get hasPriceData => items.any((i) => !i.isCash && i.currentPrice > 0);
  bool get hasAvgData => items.any((i) => !i.isCash && i.avgPrice > 0);
  bool get hasDayData => items.any((i) => !i.isCash && i.previousClose > 0);

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

  double _avgInBase(PortfolioItem item) {
    if (item.market == 'US' && currency == 'KRW') {
      return item.avgPrice * exchangeRate;
    }
    if (item.market == 'KR' && currency == 'USD') {
      return item.avgPrice / exchangeRate;
    }
    return item.avgPrice;
  }

  double _prevCloseInBase(PortfolioItem item) {
    if (item.market == 'US' && currency == 'KRW') {
      return item.previousClose * exchangeRate;
    }
    if (item.market == 'KR' && currency == 'USD') {
      return item.previousClose / exchangeRate;
    }
    return item.previousClose;
  }

  /// 그래프 표시용 정렬된 종목 목록 (비중 내림차순, 또는 graphOrder 순)
  List<PortfolioItem> get graphSortedItems {
    final nonCash = items.where((i) => !i.isCash).toList();
    if (graphOrder.isNotEmpty) {
      final ordered = <PortfolioItem>[];
      for (final id in graphOrder) {
        final found = nonCash.where((i) => i.id == id).firstOrNull;
        if (found != null) ordered.add(found);
      }
      // graphOrder에 없는 항목 뒤에 추가
      for (final item in nonCash) {
        if (!graphOrder.contains(item.id)) ordered.add(item);
      }
      return ordered;
    }
    return nonCash..sort((a, b) => b.targetWeight.compareTo(a.targetWeight));
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
    'rebalancingThreshold': rebalancingThreshold,
    'fractionalEnabled': fractionalEnabled,
    'lastUpdated': lastUpdated,
    'items': items.map((e) => e.toJson()).toList(),
    'graphTitle': graphTitle,
    'graphColors': graphColors,
    'graphNames': graphNames,
    'graphOrder': graphOrder,
  };

  factory Portfolio.fromJson(Map<String, dynamic> json) => Portfolio(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    emoji: json['emoji'] ?? '📈',
    currency: json['currency'] ?? 'KRW',
    commissionRate: (json['commissionRate'] ?? 0.015).toDouble(),
    commissionEnabled: json['commissionEnabled'] ?? false,
    exchangeRate: (json['exchangeRate'] ?? 1370).toDouble(),
    exchangeAuto: json['exchangeAuto'] ?? true,
    priceAuto: json['priceAuto'] ?? true,
    additionalInvestment: (json['additionalInvestment'] ?? 0).toDouble(),
    rebalancingThreshold: (json['rebalancingThreshold'] ?? 0.0).toDouble(),
    fractionalEnabled: json['fractionalEnabled'] ?? false,
    lastUpdated: json['lastUpdated'],
    items: (json['items'] as List<dynamic>?)
            ?.map((e) => PortfolioItem.fromJson(e))
            .toList() ??
        [],
    graphTitle: json['graphTitle'] ?? '',
    graphColors: (json['graphColors'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        {},
    graphNames: (json['graphNames'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        {},
    graphOrder: (json['graphOrder'] as List<dynamic>?)
            ?.map((e) => e.toString())
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
    double? rebalancingThreshold,
    bool? fractionalEnabled,
    int? lastUpdated,
    List<PortfolioItem>? items,
    String? graphTitle,
    Map<String, String>? graphColors,
    Map<String, String>? graphNames,
    List<String>? graphOrder,
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
    rebalancingThreshold: rebalancingThreshold ?? this.rebalancingThreshold,
    fractionalEnabled: fractionalEnabled ?? this.fractionalEnabled,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    items: items ?? this.items.map((e) => e.copyWith()).toList(),
    graphTitle: graphTitle ?? this.graphTitle,
    graphColors: graphColors ?? Map.from(this.graphColors),
    graphNames: graphNames ?? Map.from(this.graphNames),
    graphOrder: graphOrder ?? List.from(this.graphOrder),
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
  /// 목표 수량. 소수점 거래가 꺼져 있으면 항상 정수값이다.
  final double newShares;
  final double newCashAmount;

  /// 목표 − 현재. 양수면 매수, 음수면 매도.
  final double delta;
  final double cashDelta;
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

