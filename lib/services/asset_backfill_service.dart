import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/portfolio.dart';
import 'api_service.dart';
import 'asset_history_service.dart';
import 'settlement_service.dart';

/// 하루치 자산. 총액과 포트별 값을 같이 낸다.
class DailyAssets {
  final DateTime date;
  final double totalKrw;
  final Map<String, double> byPortfolio;

  const DailyAssets(this.date, this.totalKrw, this.byPortfolio);
}

/// 자산 추이의 **빈 날을 메운다.**
///
/// 기록은 앱을 켠 날에만 남았다. 그러면 선은 자산 추이가 아니라 **접속
/// 기록**이 된다 — 며칠 쉬었다 들어오면 그 사이가 통째로 비고, 앱 구조를
/// 모르는 사람에게는 데이터가 사라진 것으로 보인다.
///
/// 거래 내역이 있으면 그날 몇 주를 갖고 있었는지는 계산할 수 있다. 남은 건
/// 그날의 종가뿐이고, 야후 차트 API는 **기간 전체를 한 번에** 준다 —
/// 1년치를 메워도 종목당 1회다. 새로고침 한 번이 쓰는 호출 수와 같다.
///
/// 이미 기록된 날은 건드리지 않는다. 그날 실제로 재던 값이 더 정확하다.
class AssetBackfillService {
  AssetBackfillService._();

  /// 어디까지 메웠는지. `{'from':..,'until':..,'sig':..}`
  static const _markerKey = 'asset_backfill_v1';

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 종목 구성이 바뀌면 이미 메운 구간도 다시 메워야 한다.
  static String _signature(List<Portfolio> portfolios) {
    final ids = <String>[];
    for (final pf in portfolios) {
      for (final it in pf.items) {
        if (it.isCash || it.ticker.isEmpty) continue;
        ids.add('${pf.id}:${it.id}');
      }
    }
    ids.sort();
    return ids.join(',').hashCode.toRadixString(16);
  }

  /// 거래가 처음 생긴 날. 그 전은 자산이 0이라 그릴 게 없다.
  static DateTime? firstTransactionDay(List<Portfolio> portfolios) {
    DateTime? first;
    for (final pf in portfolios) {
      for (final it in pf.items) {
        for (final tx in it.transactions) {
          if (first == null || tx.date.isBefore(first)) first = tx.date;
        }
      }
    }
    return first == null ? null : _day(first);
  }

  /// 메워야 할 구간. 없으면 null.
  ///
  /// 네트워크를 쓰기 전에 값싸게 판단한다. 어제까지 메워 뒀고 종목도
  /// 그대로면 오늘 하루치만 받으면 된다.
  static Future<({DateTime from, DateTime to})?> pendingRange(
    List<Portfolio> portfolios, {
    int days = 365,
  }) async {
    if (portfolios.isEmpty) return null;
    final firstTx = firstTransactionDay(portfolios);
    if (firstTx == null) return null;

    final today = _day(DateTime.now());
    final windowStart = today.subtract(Duration(days: days));
    final from = firstTx.isAfter(windowStart) ? firstTx : windowStart;
    if (from.isAfter(today)) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_markerKey);
    if (raw == null) return (from: from, to: today);

    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      if (m['sig'] != _signature(portfolios)) return (from: from, to: today);
      final markFrom = DateTime.parse(m['from'] as String);
      final markUntil = DateTime.parse(m['until'] as String);
      // 앞쪽이 덜 메워졌으면(창이 넓어졌거나 옛 거래가 들어왔으면) 통째로 다시
      if (from.isBefore(markFrom)) return (from: from, to: today);
      if (!markUntil.isBefore(today)) return null;
      // 이어서 메운다. 마지막 메운 날 하루 전부터 받아야 종가가 이어진다.
      return (from: markUntil.subtract(const Duration(days: 3)), to: today);
    } catch (_) {
      return (from: from, to: today);
    }
  }

  /// 구간의 날짜별 자산을 계산해 **비어 있는 날만** 기록에 채운다.
  ///
  /// 채운 날 수를 돌려준다. 시세를 하나도 못 받으면 0이고, 기록은 그대로 둔다.
  static Future<int> run(
    List<Portfolio> portfolios, {
    int days = 365,
  }) async {
    final range = await pendingRange(portfolios, days: days);
    if (range == null) return 0;

    // 종목마다 한 번씩. 같은 티커가 여러 포트에 있어도 각자 받는다 —
    // 포트별 통화·환율이 달라 값이 갈리므로 종목 id로 들고 있는 게 안전하다.
    final closes = <String, Map<DateTime, double>>{};
    final targets = <({Portfolio pf, PortfolioItem item})>[];
    for (final pf in portfolios) {
      for (final it in pf.items) {
        if (it.isCash || it.ticker.isEmpty) continue;
        targets.add((pf: pf, item: it));
      }
    }
    if (targets.isEmpty) return 0;

    // 한 번에 다 던지지 않는다 — 새로고침과 같은 4개씩.
    const lanes = 4;
    for (var i = 0; i < targets.length; i += lanes) {
      final chunk = targets.skip(i).take(lanes);
      final got = await Future.wait(chunk.map((t) async => (
            id: t.item.id,
            r: await ApiService.fetchDailyCloses(
                t.item.ticker, t.item.market, range.from, range.to),
          )));
      for (final g in got) {
        if (g.r.ok && g.r.data != null) closes[g.id] = g.r.data!;
      }
    }
    if (closes.isEmpty) return 0;

    final daily = buildDailyAssets(
      portfolios: portfolios,
      closesByItemId: closes,
      from: range.from,
      to: range.to,
    );
    if (daily.isEmpty) return 0;

    final filled = await AssetHistoryService.fillMissing(daily);

    final prefs = await SharedPreferences.getInstance();
    final firstTx = firstTransactionDay(portfolios)!;
    final today = _day(DateTime.now());
    final windowStart = today.subtract(Duration(days: days));
    await prefs.setString(
        _markerKey,
        json.encode({
          'from': _dayKey(firstTx.isAfter(windowStart) ? firstTx : windowStart),
          'until': _dayKey(today),
          'sig': _signature(portfolios),
        }));
    return filled;
  }

  /// 기록이 통째로 무의미해졌을 때(복원 등) 표시를 지운다.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_markerKey);
  }
}

/// 날짜별 자산을 계산한다. **네트워크를 쓰지 않는다** — 테스트할 수 있게.
///
/// [closesByItemId]는 종목 id별 `날짜 → 종가(종목 원 통화)`.
///
/// 종가가 없는 날(휴장·상장 전)은 **마지막 종가를 끌고 온다.** 시장마다
/// 휴일이 달라 어떤 종목만 값이 있는 날이 생기는데, 거기서 그 종목을 빼면
/// 그날만 자산이 푹 꺼진 것처럼 보인다.
List<DailyAssets> buildDailyAssets({
  required List<Portfolio> portfolios,
  required Map<String, Map<DateTime, double>> closesByItemId,
  required DateTime from,
  required DateTime to,
}) {
  // 값이 있는 날만 후보로 둔다. 주말까지 그리면 없는 거래일을 지어내게 된다.
  final dates = <DateTime>{};
  for (final series in closesByItemId.values) {
    for (final d in series.keys) {
      if (d.isBefore(from) || d.isAfter(to)) continue;
      dates.add(DateTime(d.year, d.month, d.day));
    }
  }
  final sorted = dates.toList()..sort();
  if (sorted.isEmpty) return const [];

  // 종목별로 「그날까지의 마지막 종가」를 끌고 가기 위한 커서
  final lastClose = <String, double>{};

  final out = <DailyAssets>[];
  for (final d in sorted) {
    final endExclusive = d.add(const Duration(days: 1));

    // 이 날짜의 종가를 먼저 반영한다
    for (final e in closesByItemId.entries) {
      final c = e.value[d];
      if (c != null) lastClose[e.key] = c;
    }

    var total = 0.0;
    final byPf = <String, double>{};
    var anyHolding = false;

    for (final pf in portfolios) {
      var pfValue = 0.0;
      for (final it in pf.items) {
        if (it.isCash) {
          // 예수금은 거래 내역이 없어 과거 잔액을 알 수 없다. 지금 잔액을 쓴다 —
          // 모든 날에 같은 값이 더해지므로 선의 모양은 바뀌지 않는다.
          pfValue += it.shares;
          continue;
        }
        final shares = SettlementService.holdingsBefore(it, endExclusive);
        if (shares == 0) continue;
        final close = lastClose[it.id];
        if (close == null) continue; // 아직 그 종목의 첫 종가 전
        pfValue += shares * SettlementService.priceInBase(close, it.market, pf);
        anyHolding = true;
      }
      if (pfValue <= 0) continue;
      final krw = pf.currency == 'USD' ? pfValue * pf.exchangeRate : pfValue;
      byPf[pf.id] = krw;
      total += krw;
    }

    // 아직 아무것도 안 산 날은 남기지 않는다 — 0에서 솟는 선이 생긴다
    if (!anyHolding || total <= 0) continue;
    out.add(DailyAssets(d, total, byPf));
  }
  return out;
}
