import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'i': itemId,
        'n': name,
        's': startValue,
        'e': endValue,
        'c': contribution,
        'r': itemReturnPct,
        'a': itemAbsoluteReturn,
      };

  factory SettlementItemContribution.fromJson(Map<String, dynamic> j) =>
      SettlementItemContribution(
        itemId: j['i'] as String,
        name: j['n'] as String,
        startValue: (j['s'] as num).toDouble(),
        endValue: (j['e'] as num).toDouble(),
        contribution: (j['c'] as num).toDouble(),
        itemReturnPct: (j['r'] as num).toDouble(),
        itemAbsoluteReturn: (j['a'] as num).toDouble(),
      );
}

/// 기간 수익률과 **그걸 낼 수 있는지**.
///
/// 이 함수가 생기기 전에는 같은 화면에서 정의가 갈렸다 — 전체 결산 헤더는
/// `손익 ÷ 기초자산`, 바로 밑 포트별 행은 Modified Dietz였다. 기간 중 매매가
/// 없으면 두 식이 같아져 여태 안 드러났고, **하필 리밸런싱한 달에만** 어긋났다.
/// 실기기에서 헤더 `—`와 그 밑 `+4178.77%`가 같이 떴다. 이제 세 자리가 모두
/// 여기를 지난다.
///
/// 규칙은 셋이다.
///
/// 1. **기초자산이 있으면 Modified Dietz** — `손익 ÷ (기초자산 + 가중현금흐름)`.
///    기간 중 입금을 수익으로 치지 않으려고 있는 식이다.
/// 2. **기초자산이 0이고 기간 중에 넣었으면 넣은 돈 대비** — `손익 ÷ 순입금`.
///    기초가 0일 때 Modified Dietz를 쓰면 분모가 기간의 일부만 남아 수익률이
///    부풀려진다(8/23에 산 8월 결산이 `+2019.74%`로 나왔다). 처음부터 들고
///    있지 않았다면 "기초 대비"라는 말 자체가 성립하지 않는다. 사람이 아는
///    값은 **넣은 돈 대비 얼마**다.
/// 3. **그 외에는 못 낸다.** 0%로 적으면 "정말 0%"와 구분되지 않아 거짓말이 된다.
({double rate, bool available}) periodReturn({
  required double absoluteReturn,
  required double startValue,
  required double weightedCashFlow,
  required double netCashFlow,
}) {
  if (startValue > 0) {
    final denom = startValue + weightedCashFlow;
    if (denom > 0) {
      return (rate: absoluteReturn / denom * 100, available: true);
    }
    return (rate: 0.0, available: false);
  }
  if (netCashFlow > 0) {
    return (rate: absoluteReturn / netCashFlow * 100, available: true);
  }
  return (rate: 0.0, available: false);
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
  /// 수익률을 낼 수 있는가.
  ///
  /// Modified Dietz의 분모(기초 평가액 + 가중 현금흐름)가 0 이하이면
  /// 수익률은 **정의되지 않는다**. 예: 기간 안에서 처음 사서 그대로 들고 있는
  /// 경우 — 기초가 0이고 매수가 기간 끝에 몰려 가중치도 0이다.
  /// 이때 0%로 적으면 "정말 0%"와 구분되지 않아 거짓말이 된다.
  final bool rateAvailable;

  final double netCashFlow; // 기간 중 순 투자금 (매수 양수, 매도 음수)

  /// Modified Dietz의 가중 현금흐름. 합산 결산이 **포트별 분모를 더하려면**
  /// 이 값이 있어야 한다 — 수익률만 받아서는 합칠 수 없다.
  final double weightedCashFlow;

  final bool isCurrentPeriod;

  /// 시세를 못 받아 계산에서 빠진 종목 수.
  ///
  /// 0보다 크면 이 숫자는 **아직 다 받지 못한 값**이다. 남은 종목만으로 낸
  /// 것이므로 확정된 것처럼 크게 보여주면 안 된다 — 나중에 다 받으면
  /// 조용히 달라진다.
  final int missingPriceCount;
  bool get isPartial => missingPriceCount > 0;
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
    this.rateAvailable = true,
    required this.netCashFlow,
    this.weightedCashFlow = 0,
    required this.isCurrentPeriod,
    required this.contributions,
    this.missingPriceCount = 0,
  });

  /// 마감된 기간만 저장하므로 `isCurrentPeriod`는 늘 false로 되살린다.
  Map<String, dynamic> toJson() => {
        'p': period.index,
        'ky': key.year,
        'ks': key.sub,
        'ps': periodStart.millisecondsSinceEpoch,
        'pe': periodEnd.millisecondsSinceEpoch,
        'sv': startValue,
        'ev': endValue,
        'ar': absoluteReturn,
        'rr': returnRate,
        'ra': rateAvailable,
        'cf': netCashFlow,
        'wc': weightedCashFlow,
        'mp': missingPriceCount,
        'co': contributions.map((c) => c.toJson()).toList(),
      };

  factory SettlementResult.fromJson(Map<String, dynamic> j) => SettlementResult(
        period: SettlementPeriod.values[j['p'] as int],
        key: PeriodKey(j['ky'] as int, j['ks'] as int),
        periodStart: DateTime.fromMillisecondsSinceEpoch(j['ps'] as int),
        periodEnd: DateTime.fromMillisecondsSinceEpoch(j['pe'] as int),
        startValue: (j['sv'] as num).toDouble(),
        endValue: (j['ev'] as num).toDouble(),
        absoluteReturn: (j['ar'] as num).toDouble(),
        returnRate: (j['rr'] as num).toDouble(),
        rateAvailable: j['ra'] as bool? ?? true,
        netCashFlow: (j['cf'] as num).toDouble(),
        weightedCashFlow: (j['wc'] as num?)?.toDouble() ?? 0,
        missingPriceCount: j['mp'] as int? ?? 0,
        isCurrentPeriod: false,
        contributions: [
          for (final c in (j['co'] as List))
            SettlementItemContribution.fromJson(c as Map<String, dynamic>)
        ],
      );
}

/// 전체 결산에서 포트폴리오 하나가 차지하는 몫.
///
/// 기존 `SettlementItemContribution`은 **종목별**이다. 전체 결산 화면은
/// 포트폴리오 단위로 봐야 하므로 별도로 둔다.
class PortfolioContribution {
  final String portfolioId;
  final String name;
  final String emoji;
  final double startValue;
  final double endValue;
  final double absoluteReturn;

  /// 이 포트 자체의 수익률 (%)
  final double returnRate;

  /// 수익률을 낼 수 있는가. false면 `returnRate`는 의미가 없다 —
  /// `0.00%`로 적으면 "정말 0%"와 구분되지 않는다.
  final bool rateAvailable;

  /// 전체 수익률에 기여한 정도 (%p)
  final double contribution;

  const PortfolioContribution({
    required this.portfolioId,
    required this.name,
    required this.emoji,
    required this.startValue,
    required this.endValue,
    required this.absoluteReturn,
    required this.returnRate,
    this.rateAvailable = true,
    required this.contribution,
  });
}

/// 여러 포트폴리오를 원화 기준으로 합산한 결산.
class CombinedSettlement {
  final SettlementPeriod period;
  final PeriodKey key;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double startValue;
  final double endValue;
  final double absoluteReturn;
  final double returnRate;
  /// 수익률을 낼 수 있는가.
  ///
  /// Modified Dietz의 분모(기초 평가액 + 가중 현금흐름)가 0 이하이면
  /// 수익률은 **정의되지 않는다**. 예: 기간 안에서 처음 사서 그대로 들고 있는
  /// 경우 — 기초가 0이고 매수가 기간 끝에 몰려 가중치도 0이다.
  /// 이때 0%로 적으면 "정말 0%"와 구분되지 않아 거짓말이 된다.
  final bool rateAvailable;

  final double netCashFlow;
  final bool isCurrentPeriod;
  final List<PortfolioContribution> contributions;

  /// 시세를 못 받아 계산에서 빠진 종목 수 (모든 포트 합).
  /// 0보다 크면 아직 다 받지 못한 값이다.
  final int missingPriceCount;
  bool get isPartial => missingPriceCount > 0;

  const CombinedSettlement({
    required this.period,
    required this.key,
    required this.periodStart,
    required this.periodEnd,
    required this.startValue,
    required this.endValue,
    required this.absoluteReturn,
    required this.returnRate,
    this.rateAvailable = true,
    required this.netCashFlow,
    required this.isCurrentPeriod,
    required this.contributions,
    this.missingPriceCount = 0,
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

  /// [moment] **직전**까지의 보유 수량. 그 순간에 일어난 거래는 안 센다.
  ///
  /// 기간 경계는 자정이고 거래에는 시각이 붙어 있다. `holdingsAt(시작 − 1일)`로
  /// 세면 `시작 − 1일 00:00` 이후의 거래가 전부 빠져 **직전 하루치가 통째로
  /// 사라진다.** 8/23 12:20에 산 종목이 8/24 시작 주에 "원래 없던 것"이 되어,
  /// 산 금액 전부가 그 주의 손익으로 잡혔다.
  static double holdingsBefore(PortfolioItem item, DateTime moment) =>
      item.transactions
          .where((t) => t.date.isBefore(moment))
          .fold(0.0, (sum, t) => sum + t.quantity);

  /// 기간의 **열린 끝**. `range.end`는 마지막 날 자정이므로, 그날 장중에 한
  /// 거래를 포함하려면 하루를 더한 시점 앞까지를 봐야 한다.
  static DateTime endExclusive(DateTime end) =>
      DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

  /// 결산에서 빠지는 종목.
  ///
  /// `holdingsAt`은 거래 내역을 더해 그 시점 보유량을 구한다. 그래서 지금
  /// 보유 중이더라도 **그 기간까지의 거래 기록이 없으면 0으로 잡힌다** —
  /// 간편 입력으로 수량만 넣었거나, 옛 데이터가 오늘 날짜 거래 하나로
  /// 마이그레이션된 경우가 그렇다.
  ///
  /// 문제는 이게 조용히 일어난다는 것이다. 결산 숫자가 일부 종목을 뺀
  /// 값인데 사용자는 그 사실을 모른다. 화면에서 알려주려고 뽑아 둔다.
  static List<PortfolioItem> excludedItems(
      Portfolio pf, SettlementPeriod period, PeriodKey key) {
    final range = periodRange(period, key);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final effectiveEnd = range.end.isBefore(today) ? range.end : today;

    return pf.items
        .where((i) =>
            !i.isCash && i.shares > 0 && holdingsAt(i, effectiveEnd) <= 0)
        .toList();
  }

  /// 제외된 종목의 현재 평가액 합계 (포트 기준통화).
  static double excludedValue(Portfolio pf, List<PortfolioItem> items) {
    return items.fold(0.0, (sum, i) {
      var p = i.currentPrice;
      if (i.market == 'US' && pf.currency == 'KRW') {
        p *= pf.exchangeRate;
      } else if (i.market == 'KR' && pf.currency == 'USD') {
        p /= pf.exchangeRate;
      }
      return sum + i.shares * p;
    });
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

    // 비현금 종목 시세 조회.
    //
    // 결산 차트가 기간 6개를 한 번에 계산하므로 종목 수만큼 순차로 기다리면
    // 조회가 수십 번 직렬로 쌓인다. 종목 단위로는 동시에 받는다.
    await Future.wait(pf.items.map((item) async {
      if (item.isCash || item.ticker.isEmpty) return;
      final startShares =
          holdingsBefore(item, range.start);
      final endShares = holdingsBefore(item, endExclusive(effectiveEnd));
      if (startShares == 0 && endShares == 0) return;

      if (isCurrentPeriod) {
        // 현재 기간: start 가격만 조회하고 end는 현재가를 쓴다
        final r = await ApiService.fetchWeekPrices(item.ticker, item.market,
            range.start, range.start.add(const Duration(days: 5)));
        if (r.ok && r.data != null) {
          cache[item.id] = (first: r.data!.first, last: item.currentPrice);
        } else if (item.currentPrice > 0) {
          // 조회 실패 시 현재가를 양끝에 써서 수익률 0으로 둔다.
          // 숫자를 비우는 것보다 "변화 없음"이 정직하다.
          cache[item.id] = (first: item.currentPrice, last: item.currentPrice);
        }
      } else {
        final r = await ApiService.fetchWeekPrices(
            item.ticker, item.market, range.start, effectiveEnd);
        if (r.ok && r.data != null) cache[item.id] = r.data!;
      }
    }));

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

    // 시세를 못 받은 종목은 계산에서 빠진다. 그냥 빠뜨리면 **남은 종목만으로
    // 낸 수익률**이 포트 전체 수익률인 척하게 되므로 몇 개가 빠졌는지 센다.
    var missingPrices = 0;

    for (final item in pf.items) {
      if (item.isCash) continue;
      final prices = cache[item.id];
      if (prices == null) {
        if (item.shares > 0) missingPrices++;
        continue;
      }

      final startShares = holdingsBefore(item, range.start);
      final endShares = holdingsBefore(item, endExclusive(effectiveEnd));

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
        // 시작·끝 보유량과 **같은 경계**를 써야 한다. 어긋나면 어떤 거래가
        // 두 번 세어지거나 아무 기간에도 안 들어간다.
        if (tx.date.isBefore(range.start) ||
            !tx.date.isBefore(endExclusive(effectiveEnd))) continue;
        final txValueBase = tx.quantity * _priceInBase(tx.price, raw.item.market, pf);
        totalNetCashFlow += txValueBase;
        final daysFromEnd = effectiveEnd.difference(tx.date).inDays;
        final weight = periodDays > 0 ? daysFromEnd / periodDays : 0.0;
        totalWeightedCashFlow += txValueBase * weight;
      }
    }

    final absoluteReturn = (totalEnd - totalStart) - totalNetCashFlow;
    final pr = periodReturn(
      absoluteReturn: absoluteReturn,
      startValue: totalStart,
      weightedCashFlow: totalWeightedCashFlow,
      netCashFlow: totalNetCashFlow,
    );
    final rateAvailable = pr.available;
    final returnRate = pr.rate;

    // 종목별 기여도는 포트 전체를 100으로 보는 값이라 같은 분모를 쓴다
    final denominator = totalStart > 0
        ? totalStart + totalWeightedCashFlow
        : totalNetCashFlow;

    final contributions = rawItems.map((e) {
      double itemNetCF = 0;
      double itemWeightedCF = 0;
      for (final tx in e.item.transactions) {
        // 시작·끝 보유량과 **같은 경계**를 써야 한다. 어긋나면 어떤 거래가
        // 두 번 세어지거나 아무 기간에도 안 들어간다.
        if (tx.date.isBefore(range.start) ||
            !tx.date.isBefore(endExclusive(effectiveEnd))) continue;
        final txVal = tx.quantity * _priceInBase(tx.price, e.item.market, pf);
        itemNetCF += txVal;
        final daysFromEnd = effectiveEnd.difference(tx.date).inDays;
        final weight = periodDays > 0 ? daysFromEnd / periodDays : 0.0;
        itemWeightedCF += txVal * weight;
      }
      final itemAbsReturn = (e.endVal - e.startVal) - itemNetCF;
      final contrib = denominator > 0 ? itemAbsReturn / denominator * 100 : 0.0;
      // 종목 수익률도 포트·합산과 같은 규칙을 지난다
      final itemReturn = periodReturn(
        absoluteReturn: itemAbsReturn,
        startValue: e.startVal,
        weightedCashFlow: itemWeightedCF,
        netCashFlow: itemNetCF,
      ).rate;
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
      rateAvailable: rateAvailable,
      netCashFlow: totalNetCashFlow,
      weightedCashFlow: totalWeightedCashFlow,
      isCurrentPeriod: isCurrentPeriod,
      contributions: contributions,
      missingPriceCount: missingPrices,
    );
  }

  // ── 기간 이동 ──

  /// [key]에서 [offset]만큼 옮긴 기간 키. 음수면 과거.
  ///
  /// 결산 차트가 막대 6칸을 채우고 좌우로 넘길 때 쓴다.
  static PeriodKey shiftKey(SettlementPeriod p, PeriodKey key, int offset) {
    switch (p) {
      case SettlementPeriod.weekly:
        // 주차는 연도 경계에서 어긋나므로 날짜로 옮긴 뒤 다시 ISO 주차를 구한다.
        // 그 주의 목요일이 속한 해가 ISO 연도다.
        final monday =
            isoWeekMonday(key.year, key.sub).add(Duration(days: offset * 7));
        final thursday = monday.add(const Duration(days: 3));
        return PeriodKey(thursday.year, isoWeekNumber(thursday));
      case SettlementPeriod.monthly:
        final m = key.year * 12 + (key.sub - 1) + offset;
        return PeriodKey(m ~/ 12, m % 12 + 1);
      case SettlementPeriod.quarterly:
        final q = key.year * 4 + (key.sub - 1) + offset;
        return PeriodKey(q ~/ 4, q % 4 + 1);
      case SettlementPeriod.yearly:
        return PeriodKey(key.year + offset, 0);
    }
  }

  /// 지금 진행 중인 기간의 키
  static PeriodKey currentKey(SettlementPeriod p) =>
      PeriodKey(DateTime.now().year, currentSub(p));

  /// [key]가 미래(아직 시작하지 않은) 기간인가
  static bool isFuture(SettlementPeriod p, PeriodKey key) =>
      periodRange(p, key).start.isAfter(DateTime.now());

  // ── 과거 기간 계산 결과 캐시 ──
  //
  // 확정된 기간은 과거 시세로 계산하므로 값이 변하지 않는다.
  // 진행 중인 기간은 현재가에 따라 바뀌므로 캐시하지 않는다.
  // 거래 내역이 바뀌면 [clearCache]로 통째로 비운다.

  static final Map<String, SettlementResult?> _cache = {};
  static final Map<String, CombinedSettlement?> _combinedCache = {};

  // ── 디스크에도 남긴다 ──
  //
  // 예전에는 메모리 Map뿐이라 **앱을 껐다 켤 때마다** 지난 달·분기·연도를
  // 전부 다시 계산했다. 과거 시세를 API로 새로 받아야 해서 30초씩 걸렸고,
  // 서버가 안 주면 작년 성적을 아예 볼 수 없었다.
  //
  // 마감된 기간은 값이 변하지 않으므로 한 번 계산하면 그대로 쓸 수 있다.
  // 무효화는 `clearCache`가 맡는다 — 거래·시세가 바뀌면 `_save()`가 부른다.
  // 통째로 비우는 방식이라 거칠지만, 돈 계산에서는 정확한 편이 낫다.

  /// 저장 키. **수익률 계산식이 바뀌면 반드시 올린다.**
  ///
  /// 옛 식으로 낸 값이 캐시에 남아 있으면 새 식으로 다시 계산하지 않아
  /// 틀린 수익률이 그대로 굳는다. v3은 `periodReturn` 도입 때 올렸다.
  static const String _prefsKey = 'settlement_cache_v4';
  static const List<String> _staleKeys = [
    'settlement_cache_v2',
    'settlement_cache_v3',
  ];

  /// 너무 불어나지 않게 둔다. 주간 5년치를 담고도 남는다.
  static const int _maxEntries = 400;

  static bool _diskLoaded = false;
  static bool _writePending = false;

  static Future<void> _loadFromDisk() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // 옛 식으로 낸 값은 남겨두면 틀린 채로 굳는다 — 자리째 지운다
      for (final k in _staleKeys) {
        if (prefs.containsKey(k)) await prefs.remove(k);
      }
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in map.entries) {
        _cache[e.key] =
            SettlementResult.fromJson(e.value as Map<String, dynamic>);
      }
    } catch (_) {
      // 형식이 바뀌었거나 깨졌으면 그냥 다시 계산한다 — 지우고 넘어간다
      _cache.clear();
    }
  }

  /// 한 화면에서 6~12개가 연달아 쌓이므로 몰아서 한 번만 쓴다.
  static void _scheduleWrite() {
    if (_writePending) return;
    _writePending = true;
    Future.delayed(const Duration(seconds: 1), () async {
      _writePending = false;
      try {
        final entries = _cache.entries
            .where((e) => e.value != null)
            .toList();
        // 넘치면 오래 들어온 것부터 버린다 (Map은 삽입 순서를 지킨다)
        final keep = entries.length > _maxEntries
            ? entries.sublist(entries.length - _maxEntries)
            : entries;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _prefsKey,
            jsonEncode({for (final e in keep) e.key: e.value!.toJson()}));
      } catch (_) {
        // 저장에 실패해도 계산 자체는 멀쩡하다 — 다음에 다시 시도한다
      }
    });
  }

  static void clearCache() {
    _cache.clear();
    _combinedCache.clear();
    // 디스크도 같이 비운다. 안 그러면 다음 실행에 옛 값이 되살아난다.
    SharedPreferences.getInstance()
        .then((p) => p.remove(_prefsKey))
        .catchError((_) => false);
  }

  static String _ck(String scope, SettlementPeriod p, PeriodKey k) =>
      '$scope|${p.index}|${k.year}|${k.sub}';

  /// 캐시를 거치는 단일 포트 결산
  static Future<SettlementResult?> calculateCached(
      Portfolio pf, SettlementPeriod period, PeriodKey key) async {
    await _loadFromDisk();
    final ck = _ck(pf.id, period, key);
    if (_cache.containsKey(ck)) return _cache[ck];

    final r = await calculate(pf, period, key);
    // 진행 중인 기간은 현재가에 따라 바뀌므로 남기지 않는다.
    // **덜 받은 값도 남기지 않는다** — 남기면 틀린 수익률이 영영 굳는다.
    if (r != null && !r.isCurrentPeriod && !r.isPartial) {
      _cache[ck] = r;
      _scheduleWrite();
    }
    return r;
  }

  // ── 여러 기간 한 번에 ──

  /// [endKey]를 마지막으로 하는 최근 [count]개 기간을 오래된 순으로 계산한다.
  ///
  /// 결산 차트의 막대 6칸용. 미래 기간은 계산하지 않고 null로 둔다.
  static Future<List<SettlementResult?>> calculateSeries(
    Portfolio pf,
    SettlementPeriod period,
    PeriodKey endKey, {
    int count = 6,
  }) async {
    final keys = [
      for (var i = count - 1; i >= 0; i--) shiftKey(period, endKey, -i),
    ];
    return Future.wait(keys.map((k) async {
      if (isFuture(period, k)) return null;
      return calculateCached(pf, period, k);
    }));
  }

  // ── 전체 합산 ──

  /// 여러 포트폴리오를 원화 기준으로 합산한다.
  ///
  /// 포트마다 통화가 다를 수 있어 각자의 환율로 환산한 뒤 더한다.
  static Future<CombinedSettlement?> calculateCombined(
    List<Portfolio> portfolios,
    SettlementPeriod period,
    PeriodKey key, {
    bool useCache = true,
  }) async {
    if (portfolios.isEmpty) return null;

    final ck = _ck('__all__', period, key);
    if (useCache && _combinedCache.containsKey(ck)) return _combinedCache[ck];

    final results = await Future.wait(portfolios.map((pf) async =>
        (pf: pf, r: await calculateCached(pf, period, key))));

    double start = 0, end = 0, abs = 0, netCF = 0, weightedCF = 0;
    bool isCurrent = false;
    DateTime? periodStart, periodEnd;

    final rows = <({Portfolio pf, SettlementResult r, double fx})>[];
    for (final e in results) {
      final r = e.r;
      if (r == null) continue;
      final fx = e.pf.currency == 'USD' ? e.pf.exchangeRate : 1.0;
      start += r.startValue * fx;
      end += r.endValue * fx;
      abs += r.absoluteReturn * fx;
      netCF += r.netCashFlow * fx;
      weightedCF += r.weightedCashFlow * fx;
      if (r.isCurrentPeriod) isCurrent = true;
      periodStart ??= r.periodStart;
      periodEnd ??= r.periodEnd;
      rows.add((pf: e.pf, r: r, fx: fx));
    }

    if (rows.isEmpty) return null;

    final contributions = rows.map((e) {
      final pfStart = e.r.startValue * e.fx;
      final pfAbs = e.r.absoluteReturn * e.fx;
      return PortfolioContribution(
        portfolioId: e.pf.id,
        name: e.pf.name,
        emoji: e.pf.emoji,
        startValue: pfStart,
        endValue: e.r.endValue * e.fx,
        absoluteReturn: pfAbs,
        returnRate: e.r.returnRate,
        rateAvailable: e.r.rateAvailable,
        // 전체 분모로 나눠 %p로 만든다
        contribution: start > 0 ? pfAbs / start * 100 : 0.0,
      );
    }).toList()
      ..sort((a, b) => b.absoluteReturn.abs().compareTo(a.absoluteReturn.abs()));

    final range = periodRange(period, key);
    final combinedReturn = periodReturn(
      absoluteReturn: abs,
      startValue: start,
      weightedCashFlow: weightedCF,
      netCashFlow: netCF,
    );
    final combined = CombinedSettlement(
      period: period,
      key: key,
      periodStart: periodStart ?? range.start,
      periodEnd: periodEnd ?? range.end,
      startValue: start,
      endValue: end,
      absoluteReturn: abs,
      // 헤더만 `손익 ÷ 기초자산`을 쓰다가 바로 밑 포트별 행과 어긋났다.
      // 이제 세 자리가 모두 periodReturn을 지난다.
      returnRate: combinedReturn.rate,
      rateAvailable: combinedReturn.available,
      netCashFlow: netCF,
      isCurrentPeriod: isCurrent,
      contributions: contributions,
      // 포트 하나라도 덜 받았으면 합산도 덜 받은 값이다
      missingPriceCount: results.fold<int>(
          0, (n, e) => n + (e.r?.missingPriceCount ?? 0)),
    );

    // 덜 받은 값은 남기지 않는다 — 남기면 틀린 채로 굳는다
    if (!isCurrent && !combined.isPartial) _combinedCache[ck] = combined;
    return combined;
  }

  /// 전체 합산의 최근 [count]개 기간 (차트용)
  static Future<List<CombinedSettlement?>> calculateCombinedSeries(
    List<Portfolio> portfolios,
    SettlementPeriod period,
    PeriodKey endKey, {
    int count = 6,
    void Function(List<CombinedSettlement?> partial)? onProgress,
  }) async {
    final keys = [
      for (var i = count - 1; i >= 0; i--) shiftKey(period, endKey, -i),
    ];
    final out = List<CombinedSettlement?>.filled(keys.length, null);
    // **최신 칸부터** 채운다. 사람이 제일 먼저 보는 칸이고, 칸이 열두 개면
    // 다 끝나길 기다리는 동안 화면이 오래 빈다. 하나 끝날 때마다 알린다.
    for (var i = keys.length - 1; i >= 0; i--) {
      final k = keys[i];
      if (!isFuture(period, k)) {
        out[i] = await calculateCombined(portfolios, period, k);
      }
      onProgress?.call(List.of(out));
    }
    return out;
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
