import 'dart:math';
import '../models/portfolio.dart';
import 'share_format.dart';

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

/// 편차를 못 내는 이유. 셋은 사용자가 할 일이 서로 다르다 —
/// 종목을 넣거나, 목표를 정하거나, 시세를 다시 받거나.
enum DriftBlocker { noItems, noTargets, noPrices }

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

  /// 사용자에게 **"조정 필요"라고 말해도 되는가.**
  ///
  /// 종목이 하나뿐이면 서로 옮길 데가 없어 조정이라는 말 자체가 성립하지
  /// 않는다. 그런데도 편차가 크다고 빨간 경고를 띄우면, 고칠 수 없는 경고를
  /// 첫날부터 보게 된다.
  ///
  /// 편차 계산(`driftExceeding`)은 그대로 둔다 — 그건 조정 계산에도 쓰이므로
  /// 건드리면 숫자가 바뀐다. 여기서는 **뭐라고 말할지만** 가른다.
  static List<ItemDrift> needsAdjusting(Portfolio portfolio) =>
      portfolio.items.length < 2 ? const [] : driftExceeding(portfolio);

  /// 편차를 **낼 수 있는가.** 시세가 하나라도 없으면 못 낸다.
  ///
  /// `needsAdjusting`이 비었다는 건 두 가지 뜻이다 — "괜찮다"와 "모르겠다".
  /// 구분하지 않으면 시세를 하나도 못 받은 앱이 `조정 필요 없음`이라고
  /// 단언한다. 사용자는 확인했다고 믿고 넘어간다.
  ///
  /// 보유 종목이 없으면 잴 것이 없는 것이지 못 재는 게 아니라 true다.
  static bool canComputeDrift(Portfolio portfolio) {
    final b = driftBlocker(portfolio);
    return b == null || b == DriftBlocker.noItems;
  }

  /// 편차를 못 내는 **이유**. 낼 수 있으면 null.
  ///
  /// 이유를 안 가리면 화면이 하나의 문구로 뭉뚱그린다 — 종목이 0개인
  /// 포트에 `시세를 받으면 편차를 계산합니다`라고 말하는 식이다. 사용자는
  /// 그 말을 믿고 **고칠 수 없는 것을 고치려 든다**(새로고침을 반복한다).
  ///
  /// 순서가 중요하다. 종목이 없으면 목표도 시세도 물을 필요가 없고,
  /// 목표가 없으면 시세가 있어도 편차라는 개념이 성립하지 않는다.
  static DriftBlocker? driftBlocker(Portfolio portfolio) {
    final holdings = portfolio.items.where((i) => !i.isCash);
    if (holdings.isEmpty) return DriftBlocker.noItems;

    final targetSum =
        portfolio.items.fold<double>(0, (s, i) => s + i.targetWeight);
    if (targetSum <= 0) return DriftBlocker.noTargets;

    if (allDrifts(portfolio).isEmpty) return DriftBlocker.noPrices;
    return null;
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

  /// [excludeIds]에 든 종목은 **건드리지 않는다** — 현재 수량을 그대로 두고
  /// 나머지만 목표에 맞춘다. 조정 제안에서 체크를 끈 종목이 여기로 온다
  /// ("저건 팔기 싫은데 나머지는 어떻게 하지"에 답하기 위한 것).
  ///
  /// [redistributeExcluded]는 **뺀 종목이 붙잡고 있는 돈을 뺀 나머지 예산**을
  /// 남은 종목의 목표 비중대로 나눈다 (시안 v20b의 `나머지 종목에`).
  ///
  /// **기본값이다.** 끄면 각 종목이 제 목표 비중을 그대로 향해서, 뺀 종목이
  /// 붙잡은 돈까지 다시 쓰려 든다 — 합이 총액을 넘는 **낼 수 없는 계획**이
  /// 나올 수 있다. 예전 기본값이었고 지금은 `예수금에 남김`으로만 남아 있다.
  static RebalanceResult? calculate(
    Portfolio portfolio, {
    Set<String>? excludeIds,
    bool redistributeExcluded = true,
  }) {
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
          newShares: item.isCash ? 0 : item.shares,
          newCashAmount: item.isCash ? item.shares : 0,
          isCash: item.isCash,
        )).toList(),
        cash: 0, commission: 0, total: 0,
      );
    }

    // ── 허용 편차 안에 있는 종목은 건드리지 않는다 ──
    //
    // 추가 투자금이 있으면 어차피 전 종목의 비중이 바뀌므로 잠그지 않는다.
    // 임계값이 0이면 기존 동작(전 종목 재배분) 그대로다.
    final lockedIds = <String>{...?excludeIds};
    if (portfolio.rebalancingThreshold > 0 && portfolio.additionalInvestment == 0) {
      final exceeding =
          Rebalancer.driftExceeding(portfolio).map((d) => d.item.id).toSet();
      for (final item in items) {
        if (!exceeding.contains(item.id)) lockedIds.add(item.id);
      }
    }

    // 소수점 거래는 목표 금액을 그대로 나눠 떨어뜨릴 수 있어 최대잉여법이
    // 필요 없다. 대신 수수료만큼 예산을 미리 빼 둬야 한다 —
    // 온주 거래는 내림에서 남는 돈이 수수료를 덮지만, 소수점 거래는
    // 남는 돈이 0이라 그냥 두면 잔여 현금이 음수가 된다.
    // 잠긴 종목이 붙잡고 있는 금액과, 아직 움직일 수 있는 종목의 목표 비중 합.
    //
    // **무엇 때문에 잠겼든** 나눈다. 종목을 뺀 경우든 허용 편차 안에 들어
    // 잠긴 경우든, 잠긴 종목은 지금 금액을 그대로 붙잡는다. 그런데 나머지를
    // 총액 기준으로 계산하면 그 돈이 두 번 세어져 예산을 넘는다 —
    // 잠긴 종목이 목표에서 벗어난 만큼이 그대로 초과액이 된다.
    //
    // 잠긴 것이 없으면 `lockedValue`가 0, `activeWeight`가 100이라
    // 원래 식과 똑같아진다.
    final spreading = redistributeExcluded && lockedIds.isNotEmpty;
    double lockedValue = 0, activeWeight = 0;
    if (spreading) {
      for (final item in items) {
        if (lockedIds.contains(item.id)) {
          lockedValue +=
              item.isCash ? item.shares : item.shares * priceInBase(item);
        } else {
          activeWeight += item.targetWeight;
        }
      }
    }

    final fractional = portfolio.fractionalEnabled;

    /// [base]를 목표 금액의 기준으로 삼아 각 종목의 목표 수량을 잡는다.
    /// 현재 비중(currentWeight)은 언제나 실제 총액 기준으로 둔다.
    List<_CalcItem> allocate(double base) {
      final out = <_CalcItem>[];
      for (final item in items) {
        final p = priceInBase(item);
        final cv = item.isCash ? item.shares : item.shares * p;
        final cw = (cv / total) * 100;
        final locked0 = lockedIds.contains(item.id);

        // 잠긴 종목이 있으면 목표 금액은 **두 상한 중 작은 쪽**이다.
        //
        //   제 목표 비중          — 이걸 넘으면 목표를 지나쳐 산다
        //   남은 예산의 제 몫      — 이걸 넘으면 없는 돈으로 산다
        //
        // 잠긴 종목이 목표보다 **많이** 갖고 있으면 예산 쪽이 작아져
        // 낼 수 없는 계획을 막는다. 목표보다 **적게** 갖고 있으면 목표 쪽이
        // 작아져 남는 돈이 현금으로 남는다 — 억지로 밀어 넣으면 다른 종목이
        // 목표를 넘어가므로 이게 맞다.
        final ownTarget = base * (item.targetWeight / 100);
        final tv = (spreading && !locked0 && activeWeight > 0)
            ? min(
                ownTarget,
                max(0.0, base - lockedValue) * (item.targetWeight / activeWeight))
            : ownTarget;
        final locked = lockedIds.contains(item.id);
        // 잠긴 종목은 "거래하지 않는다"는 뜻이므로 현재 수량을 그대로 둔다.
        if (item.isCash) {
          out.add(_CalcItem(
              item: item, price: p, currentValue: cv, currentWeight: cw,
              targetValue: tv,
              baseShares: locked ? item.shares : tv.roundToDouble(),
              remainder: 0, locked: locked));
        } else {
          if (p <= 0) continue; // 안전장치
          final ideal = tv / p;
          final assigned = locked
              ? item.shares
              : (fractional
                  ? (portfolio.fractionalRounding ==
                          FractionalRounding.minDeviation
                      ? roundShares(ideal)
                      : floorShares(ideal))
                  : ideal.floorToDouble());
          out.add(_CalcItem(
              item: item, price: p, currentValue: cv, currentWeight: cw,
              targetValue: tv, ideal: ideal, baseShares: assigned,
              remainder: (locked || fractional) ? 0 : ideal - assigned,
              locked: locked));
        }
      }
      return out;
    }

    double commissionOf(List<_CalcItem> d) => d.fold(
        0.0,
        (sum, x) => x.item.isCash
            ? sum
            : sum + (x.baseShares - x.item.shares).abs() * x.price * cr / 100);

    var data = allocate(total);

    if (fractional) {
      // 1차 배분으로 수수료를 어림한 뒤 그만큼 예산을 줄여 다시 배분한다.
      // 수수료율이 0.015% 수준이라 한 번이면 충분히 수렴한다.
      if (cr > 0) {
        final est = commissionOf(data);
        if (est > 0 && est < total) data = allocate(total - est);
      }
    } else {
      // 잠긴 종목은 잔여 예산 배분에서 빠진다
      final stocks = data.where((d) => !d.item.isCash && !d.locked).toList()
        ..sort((a, b) => b.remainder.compareTo(a.remainder));
      final allocated0 = data.fold(0.0, (sum, d) => d.item.isCash ? sum + d.baseShares : sum + d.baseShares * d.price);
      double budget = total - allocated0;
      // 최대잉여법: 소수점이 남은 종목에만 한 주씩 더 준다.
      // remainder가 0인 종목은 이미 목표에 정확히 맞아 있으므로 더하면 목표를 넘는다
      // (잠긴 종목의 편차 때문에 생긴 잔여 예산이 엉뚱한 종목을 밀어올리는 걸 막는다).
      for (final d in stocks) {
        if (d.item.targetWeight > 0 && d.remainder > 0 && budget >= d.price) {
          d.baseShares += 1;
          budget -= d.price;
        }
      }

      final allocated = data.fold(0.0, (sum, d) => d.item.isCash ? sum + d.baseShares : sum + d.baseShares * d.price);
      if (total - allocated < commissionOf(data) && stocks.isNotEmpty) {
        final removable = stocks
            .where((d) => d.remainder > 0 && d.baseShares > (d.ideal ?? 0).floorToDouble())
            .toList();
        if (removable.isNotEmpty) removable.last.baseShares -= 1;
      }
    }

    final commission = commissionOf(data);
    final ta = data.fold(0.0, (sum, d) => d.item.isCash ? sum + d.baseShares : sum + d.baseShares * d.price);
    final fc = max(0.0, total - ta - commission).roundToDouble();

    final results = data.map((d) {
      final ns = d.baseShares;
      var delta = ns - d.item.shares;
      if (delta.abs() < sharesEpsilon) delta = 0; // 부동소수 찌꺼기는 거래가 아니다
      final fv = d.item.isCash ? ns : ns * d.price;
      final fw = total > 0 ? (fv / total) * 100 : 0.0;
      return RebalanceItemResult(
        id: d.item.id, currentWeight: d.currentWeight, finalWeight: fw,
        newShares: d.item.isCash ? 0 : ns,
        newCashAmount: d.item.isCash ? ns : 0,
        delta: d.item.isCash ? 0 : delta,
        cashDelta: d.item.isCash ? ns - d.item.shares : 0,
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
  double baseShares;
  final double remainder;
  /// 허용 편차 안이라 거래하지 않는 종목
  final bool locked;
  _CalcItem({required this.item, required this.price, required this.currentValue, required this.currentWeight, required this.targetValue, this.ideal, required this.baseShares, required this.remainder, this.locked = false});
}
