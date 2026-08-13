import '../models/portfolio.dart';
import '../services/api_service.dart';

enum SettlementPeriod { weekly, monthly, quarterly, yearly }

class PeriodKey {
  final int year;
  final int sub; // 주간: 주차, 월간: 월(1~12), 분기: 분기(1~4), 연간: 0

  const PeriodKey(this.year, this.sub);

  @override
  bool operator ==(Object other) =>
      other is PeriodKey && year == other.year && sub == other.sub;

  @override
  int get hashCode => year * 100 + sub;
}

class SettlementItemContribution {
  final String itemId;
  final String name;
  final double startValue;
  final double endValue;
  final double contribution;       // 포트폴리오 총자산 대비 기여도 (%)
  final double itemReturnPct;      // 종목 자체 수익률 (%)
  final double itemAbsoluteReturn; // 종목 기간 손익 (금액)

  SettlementItemContribution({
    required this.itemId,
    required this.name,
    required this.startValue,
    required this.endValue,
    required this.contribution,
    required this.itemReturnPct,
    required this.itemAbsoluteReturn,
  });
}

class SettlementResult {
  final SettlementPeriod period;
  final PeriodKey key;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double startValue;
  final double endValue;
  final double absoluteReturn;
  final double returnRate;
  final double netCashFlow; // 기간 중 순 투자금 (매수 양수, 매도 음수)
  final bool isCurrentPeriod;
  final List<SettlementItemContribution> contributions;

  SettlementResult({
    required this.period,
    required this.key,
    required this.periodStart,
    required this.periodEnd,
    required this.startValue,
    required this.endValue,
    required this.absoluteReturn,
    required this.returnRate,
    required this.netCashFlow,
    required this.isCurrentPeriod,
    required this.contributions,
  });
}

class SettlementService {
  // ── ISO 주차 헬퍼 ──

  /// ISO 주차의 월요일 날짜
  static DateTime isoWeekMonday(int year, int week) {
    // Jan 4 is always in ISO week 1
    final jan4 = DateTime(year, 1, 4);
    final weekday = jan4.weekday; // 1=Mon
    final week1Monday = jan4.subtract(Duration(days: weekday - 1));
    return week1Monday.add(Duration(days: (week - 1) * 7));
  }

  /// 날짜의 ISO 주차 번호
  static int isoWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekday = date.weekday;
    return ((dayOfYear - weekday + 10) / 7).floor();
  }

  /// 해당 연도의 ISO 주 수 (52 또는 53)
  static int isoWeeksInYear(int year) {
    // Dec 28 is always in the last ISO week of the year
    return isoWeekNumber(DateTime(year, 12, 28));
  }

  // ── 기간 범위 계산 ──

  static ({DateTime start, DateTime end}) periodRange(
      SettlementPeriod p, PeriodKey key) {
    switch (p) {
      case SettlementPeriod.weekly:
        final start = isoWeekMonday(key.year, key.sub);
        return (start: start, end: start.add(const Duration(days: 6)));
      case SettlementPeriod.monthly:
        final start = DateTime(key.year, key.sub, 1);
        final end = DateTime(key.year, key.sub + 1, 0); // 말일
        return (start: start, end: end);
      case SettlementPeriod.quarterly:
        final startMonth = (key.sub - 1) * 3 + 1;
        final endMonth = startMonth + 2;
        final start = DateTime(key.year, startMonth, 1);
        final end = DateTime(key.year, endMonth + 1, 0);
        return (start: start, end: end);
      case SettlementPeriod.yearly:
        return (
          start: DateTime(key.year, 1, 1),
          end: DateTime(key.year, 12, 31),
        );
    }
  }

  // ── 거래 기반 보유 수량 ──

  /// date 시점(포함)까지의 거래 합산 수량
  static double holdingsAt(PortfolioItem item, DateTime date) {
    return item.transactions
        .where((t) => !t.date.isAfter(date))
        .fold(0.0, (sum, t) => sum + t.quantity);
  }

  // ── 메인 결산 계산 ──

  static Future<SettlementResult?> calculate(
      Portfolio pf, SettlementPeriod period, PeriodKey key) async {
    final range = periodRange(period, key);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 현재 기간 여부 판단
    final isCurrentPeriod = !range.end.isBefore(today);
    final effectiveEnd = isCurrentPeriod ? today : range.end;

    final cache = <String, ({double first, double last})>{};

    // 비현금 종목 API 조회
    for (final item in pf.items) {
      if (item.isCash || item.ticker.isEmpty) continue;
      final startShares = holdingsAt(item, range.start.subtract(const Duration(days: 1)));
      final endShares = holdingsAt(item, effectiveEnd);
      if (startShares == 0 && endShares == 0) continue;

      if (isCurrentPeriod) {
        // 현재 기간: start 가격만 API 조회, end 가격은 현재가 사용
        final r = await ApiService.fetchWeekPrices(
            item.ticker, item.market, range.start, range.start.add(const Duration(days: 5)));
        if (r.ok && r.data != null) {
          cache[item.id] = (first: r.data!.first, last: item.currentPrice);
        } else if (item.currentPrice > 0) {
          // API 실패 시 현재가를 start/end 모두 사용 (수익률 0)
          cache[item.id] = (first: item.currentPrice, last: item.currentPrice);
        }
      } else {
        final r = await ApiService.fetchWeekPrices(
            item.ticker, item.market, range.start, effectiveEnd);
        if (r.ok && r.data != null) cache[item.id] = r.data!;
      }
    }

    // 현금 가치
    double cashValue = 0;
    for (final item in pf.items) {
      if (!item.isCash) continue;
      cashValue += item.shares;
    }

    // 종목별 계산
    double totalStart = cashValue;
    double totalEnd = cashValue;
    final rawItems = <({PortfolioItem item, double startVal, double endVal})>[];

    for (final item in pf.items) {
      if (item.isCash) continue;
      final prices = cache[item.id];
      if (prices == null) continue;

      final startShares = holdingsAt(item, range.start.subtract(const Duration(days: 1)));
      final endShares = holdingsAt(item, effectiveEnd);

      final startPrice = _priceInBase(prices.first, item.market, pf);
      final endPrice = _priceInBase(prices.last, item.market, pf);

      final startVal = startShares * startPrice;
      final endVal = endShares * endPrice;

      totalStart += startVal;
      totalEnd += endVal;
      rawItems.add((item: item, startVal: startVal, endVal: endVal));
    }

    if (rawItems.isEmpty) return null;

    // Modified Dietz: 기간 중 발생한 매수/매도 현금흐름 계산
    double totalNetCashFlow = 0;
    double totalWeightedCashFlow = 0;
    final periodDays = effectiveEnd.difference(range.start).inDays;

    for (final raw in rawItems) {
      for (final tx in raw.item.transactions) {
        if (!tx.date.isAfter(range.start) || tx.date.isAfter(effectiveEnd)) continue;
        final txValueBase = tx.quantity * _priceInBase(tx.price, raw.item.market, pf);
        totalNetCashFlow += txValueBase;
        final daysFromEnd = effectiveEnd.difference(tx.date).inDays;
        final weight = periodDays > 0 ? daysFromEnd / periodDays : 0.0;
        totalWeightedCashFlow += txValueBase * weight;
      }
    }

    final absoluteReturn = (totalEnd - totalStart) - totalNetCashFlow;
    final denominator = totalStart + totalWeightedCashFlow;
    final returnRate = denominator > 0 ? absoluteReturn / denominator * 100 : 0.0;

    final contributions = rawItems.map((e) {
      double itemNetCF = 0;
      double itemWeightedCF = 0;
      for (final tx in e.item.transactions) {
        if (!tx.date.isAfter(range.start) || tx.date.isAfter(effectiveEnd)) continue;
        final txVal = tx.quantity * _priceInBase(tx.price, e.item.market, pf);
        itemNetCF += txVal;
        final daysFromEnd = effectiveEnd.difference(tx.date).inDays;
        final weight = periodDays > 0 ? daysFromEnd / periodDays : 0.0;
        itemWeightedCF += txVal * weight;
      }
      final itemAbsReturn = (e.endVal - e.startVal) - itemNetCF;
      final contrib = denominator > 0 ? itemAbsReturn / denominator * 100 : 0.0;
      final itemDenom = e.startVal + itemWeightedCF;
      final itemReturn = itemDenom > 0 ? itemAbsReturn / itemDenom * 100 : 0.0;
      return SettlementItemContribution(
        itemId: e.item.id,
        name: e.item.name,
        startValue: e.startVal,
        endValue: e.endVal,
        contribution: contrib,
        itemReturnPct: itemReturn,
        itemAbsoluteReturn: itemAbsReturn,
      );
    }).toList()
      ..sort((a, b) => b.contribution.compareTo(a.contribution));

    return SettlementResult(
      period: period,
      key: key,
      periodStart: range.start,
      periodEnd: effectiveEnd,
      startValue: totalStart,
      endValue: totalEnd,
      absoluteReturn: absoluteReturn,
      returnRate: returnRate,
      netCashFlow: totalNetCashFlow,
      isCurrentPeriod: isCurrentPeriod,
      contributions: contributions,
    );
  }

  // ── 헬퍼 ──

  static double _priceInBase(double price, String market, Portfolio pf) {
    if (market == 'US' && pf.currency == 'KRW') return price * pf.exchangeRate;
    if (market == 'KR' && pf.currency == 'USD') return price / pf.exchangeRate;
    return price;
  }

  // ── 드롭다운용 유틸 ──

  /// 포트폴리오 전체 거래 중 가장 이른 연도
  static int earliestYear(Portfolio pf) {
    int earliest = DateTime.now().year;
    for (final item in pf.items) {
      for (final tx in item.transactions) {
        if (tx.date.year < earliest) earliest = tx.date.year;
      }
    }
    return earliest;
  }

  /// 현재 기간의 sub 값 (주차/월/분기)
  static int currentSub(SettlementPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case SettlementPeriod.weekly:
        return isoWeekNumber(now);
      case SettlementPeriod.monthly:
        return now.month;
      case SettlementPeriod.quarterly:
        return ((now.month - 1) ~/ 3) + 1;
      case SettlementPeriod.yearly:
        return 0;
    }
  }

  /// 특정 연도에서 선택 가능한 최대 sub 값
  static int maxSub(SettlementPeriod period, int year) {
    final now = DateTime.now();
    final isCurrent = year == now.year;
    switch (period) {
      case SettlementPeriod.weekly:
        return isCurrent ? isoWeekNumber(now) : isoWeeksInYear(year);
      case SettlementPeriod.monthly:
        return isCurrent ? now.month : 12;
      case SettlementPeriod.quarterly:
        return isCurrent ? ((now.month - 1) ~/ 3) + 1 : 4;
      case SettlementPeriod.yearly:
        return 0;
    }
  }
}
