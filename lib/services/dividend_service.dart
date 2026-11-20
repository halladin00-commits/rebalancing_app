import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/portfolio.dart';
import 'settlement_service.dart';

/// 배당 **추정**.
///
/// 앱은 배당을 기록하지 않는다(거래에는 매수·매도만 있다). 대신 야후가 주는
/// 종목별 「배당락일 · 1주당 배당금」과, 거래 내역으로 구한 「그날 갖고 있던
/// 수량」을 곱해 그 기간에 받았을 배당을 어림한다.
///
/// **수익률에는 넣지 않는다** (2026-11-21 사용자 결정, A안). 결산 화면에
/// 따로 한 장으로 보여 준다. 그래서 돈 계산의 정의도, 저장 형식도 그대로다.
///
/// 어림인 이유 — 화면이 같이 밝힌다:
/// - **세전**이다. 실제 입금은 원천징수 뒤 금액이고, ISA·연금은 세금이 다르다.
/// - **배당락일 기준**이다. 입금은 1~4주 뒤라 다른 달 결산에 들어갈 수 있다.
/// - 야후 기록이 빠지거나 늦을 수 있다.
/// - 환산은 포트의 **지금** 환율로 한다.
class DividendService {
  // ── 배당 기록 받기 ──

  /// 이만큼 지난 기록은 다시 받는다. 배당은 한 달에 한두 번 바뀐다.
  static const Duration maxAge = Duration(hours: 12);

  static const String _prefsKey = 'dividend_history_v1';

  static final Map<String, _Cached> _mem = {};
  static final Map<String, Future<List<DividendEvent>?>> _inflight = {};
  static bool _diskLoaded = false;

  /// 테스트에서 디스크 캐시와 메모리를 비운다.
  static void resetForTest() {
    _mem.clear();
    _inflight.clear();
    _diskLoaded = true; // 테스트는 디스크를 읽지 않는다
  }

  /// 종목의 배당 기록 (최근 10년, 오래된 것부터). 받지 못하면 null.
  ///
  /// 같은 종목을 여러 화면이 동시에 물어도 **한 번만** 받는다.
  static Future<List<DividendEvent>?> history(
      String ticker, String market) async {
    if (ticker.isEmpty || market == 'CASH') return const [];
    final key = '$market:$ticker';
    await _loadDisk();
    final hit = _mem[key];
    if (hit != null &&
        DateTime.now().difference(hit.at) < maxAge) {
      return hit.events;
    }
    final running = _inflight[key];
    if (running != null) return running;

    final f = () async {
      final got = await _fetch(ticker, market);
      if (got != null) {
        _mem[key] = _Cached(DateTime.now(), got);
        _saveDisk();
        return got;
      }
      // 못 받았으면 낡은 기록이라도 쓴다 — 없는 것보다 낫다
      return hit?.events;
    }();
    _inflight[key] = f;
    try {
      return await f;
    } finally {
      _inflight.remove(key);
    }
  }

  static Future<List<DividendEvent>?> _fetch(String ticker, String market) async {
    if (market == 'KR') {
      var clean = ticker;
      if (clean.startsWith('A') && clean.length > 1) {
        final rest = clean.substring(1);
        if (rest.contains(RegExp(r'^[0-9]'))) clean = rest;
      }
      if (clean.isEmpty) return null;
      return await _fetchSymbol('$clean.KS') ?? await _fetchSymbol('$clean.KQ');
    }
    return _fetchSymbol(ticker);
  }

  static Future<List<DividendEvent>?> _fetchSymbol(String symbol) async {
    try {
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/'
          '$symbol?range=10y&interval=1mo&events=div';
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return parseChart(json.decode(res.body));
    } catch (_) {
      return null;
    }
  }

  /// 야후 차트 응답에서 배당만 뽑는다. 종목이 없으면 null.
  ///
  /// 날짜는 **거래소의 날짜**로 자른다. 국내 종목은 UTC 0시로 찍혀 오는데,
  /// 폰의 시간대로 바꾸면 미국에 있는 폰에서는 전날이 된다. 응답의
  /// `gmtoffset`(거래소 시차)을 더한 뒤 날짜만 쓴다.
  static List<DividendEvent>? parseChart(dynamic data) {
    if (data is! Map) return null;
    final chart = data['chart'];
    final result = chart is Map ? chart['result'] : null;
    if (result is! List || result.isEmpty) return null;
    final r = result.first;
    final offset = (r['meta']?['gmtoffset'] as num?)?.toInt() ?? 0;
    final divs = r['events']?['dividends'];
    final out = <DividendEvent>[];
    if (divs is Map) {
      for (final v in divs.values) {
        if (v is! Map) continue;
        final ts = v['date'];
        final amt = v['amount'];
        if (ts is! num || amt is! num || amt <= 0) continue;
        final d = DateTime.fromMillisecondsSinceEpoch(
            (ts.toInt() + offset) * 1000,
            isUtc: true);
        out.add(DividendEvent(DateTime(d.year, d.month, d.day), amt.toDouble()));
      }
    }
    out.sort((a, b) => a.exDate.compareTo(b.exDate));
    return out;
  }

  static Future<void> _loadDisk() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final m = json.decode(raw) as Map<String, dynamic>;
      m.forEach((k, v) {
        final at = DateTime.fromMillisecondsSinceEpoch((v['at'] as num).toInt());
        final ev = [
          for (final e in (v['ev'] as List))
            DividendEvent(
              DateTime((e[0] as num).toInt() ~/ 10000,
                  (e[0] as num).toInt() ~/ 100 % 100, (e[0] as num).toInt() % 100),
              (e[1] as num).toDouble(),
            ),
        ];
        _mem.putIfAbsent(k, () => _Cached(at, ev));
      });
    } catch (_) {
      // 읽지 못하면 새로 받으면 된다
    }
  }

  static void _saveDisk() {
    final m = {
      for (final e in _mem.entries)
        e.key: {
          'at': e.value.at.millisecondsSinceEpoch,
          'ev': [
            for (final d in e.value.events)
              [
                d.exDate.year * 10000 + d.exDate.month * 100 + d.exDate.day,
                d.perShare,
              ],
          ],
        },
    };
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefsKey, json.encode(m)))
        .catchError((_) => false);
  }

  // ── 계산 ──

  /// 기간 [start] ~ [end](그날 포함)에 배당락일이 든 배당.
  ///
  /// 진행 중인 기간은 [end]를 오늘로 넘긴다 — 아직 안 온 배당락일은 세지 않는다.
  ///
  /// 수량은 **배당락일 전까지** 갖고 있던 것이다. 배당락일에 산 주식은 배당을
  /// 못 받고, 그날 판 주식은 받는다. 결산이 쓰는 [SettlementService.holdingsBefore]
  /// 를 그대로 쓴다 — 결산과 같은 거래 경계다.
  static List<DividendLine> linesFor(
    Portfolio pf,
    PortfolioItem item,
    List<DividendEvent> events,
    DateTime start,
    DateTime end,
  ) {
    final from = DateTime(start.year, start.month, start.day);
    final until = SettlementService.endExclusive(end);
    final out = <DividendLine>[];
    for (final e in events) {
      if (e.exDate.isBefore(from) || !e.exDate.isBefore(until)) continue;
      final shares = SettlementService.holdingsBefore(item, e.exDate);
      if (shares <= 0) continue;
      final perShareBase =
          SettlementService.priceInBase(e.perShare, item.market, pf);
      out.add(DividendLine(
        itemId: item.id,
        name: item.name,
        market: item.market,
        exDate: e.exDate,
        perShare: e.perShare,
        shares: shares,
        amount: shares * perShareBase,
      ));
    }
    return out;
  }

  /// 포트 하나의 기간 배당 추정 (포트 통화).
  static Future<DividendEstimate> estimate(
      Portfolio pf, DateTime start, DateTime end) async {
    final lines = <DividendLine>[];
    var failed = 0;
    await Future.wait(pf.items.map((item) async {
      if (item.isCash || item.ticker.isEmpty) return;
      // 기간이 끝나기 전에 거래가 하나도 없으면 그때 갖고 있던 적이 없다.
      // (기간 중에 다 판 종목은 판 날까지의 배당이 있으니 물어본다)
      final until = SettlementService.endExclusive(end);
      if (!item.transactions.any((t) => t.date.isBefore(until))) return;
      final ev = await history(item.ticker, item.market);
      if (ev == null) {
        failed++;
        return;
      }
      lines.addAll(linesFor(pf, item, ev, start, end));
    }));
    lines.sort((a, b) {
      final c = a.exDate.compareTo(b.exDate);
      return c != 0 ? c : b.amount.compareTo(a.amount);
    });
    return DividendEstimate(
      total: lines.fold(0.0, (s, l) => s + l.amount),
      lines: lines,
      failed: failed,
      currency: pf.currency,
    );
  }

  /// 여러 포트를 [currency] 하나로 합친 배당 추정.
  ///
  /// 환산은 결산 합계와 같은 [SettlementService.combineFx]를 쓴다.
  static Future<DividendEstimate> estimateCombined(List<Portfolio> all,
      String currency, DateTime start, DateTime end) async {
    final each = await Future.wait(all.map((pf) => estimate(pf, start, end)));
    final lines = <DividendLine>[];
    var failed = 0;
    final byPortfolio = <({String id, String name, double amount})>[];
    for (var i = 0; i < all.length; i++) {
      final pf = all[i];
      final fx = SettlementService.combineFx(pf, all, currency);
      failed += each[i].failed;
      double sum = 0;
      for (final l in each[i].lines) {
        final a = l.amount * fx;
        sum += a;
        lines.add(l.withAmount(a));
      }
      if (sum > 0) byPortfolio.add((id: pf.id, name: pf.name, amount: sum));
    }
    lines.sort((a, b) {
      final c = a.exDate.compareTo(b.exDate);
      return c != 0 ? c : b.amount.compareTo(a.amount);
    });
    byPortfolio.sort((a, b) => b.amount.compareTo(a.amount));
    return DividendEstimate(
      total: lines.fold(0.0, (s, l) => s + l.amount),
      lines: lines,
      failed: failed,
      currency: currency,
      byPortfolio: byPortfolio,
    );
  }
}

class _Cached {
  final DateTime at;
  final List<DividendEvent> events;
  _Cached(this.at, this.events);
}

/// 배당락일과 1주당 배당금 (종목 통화).
class DividendEvent {
  final DateTime exDate;
  final double perShare;
  const DividendEvent(this.exDate, this.perShare);
}

/// 한 종목의 한 번의 배당.
class DividendLine {
  final String itemId;
  final String name;
  final String market;
  final DateTime exDate;

  /// 1주당 배당 (종목 통화 — 국내 원, 미국 달러)
  final double perShare;

  /// 배당락일 전까지 갖고 있던 수량
  final double shares;

  /// 받았을 금액 (추정을 낸 통화 — [DividendEstimate.currency])
  final double amount;

  const DividendLine({
    required this.itemId,
    required this.name,
    required this.market,
    required this.exDate,
    required this.perShare,
    required this.shares,
    required this.amount,
  });

  DividendLine withAmount(double a) => DividendLine(
        itemId: itemId,
        name: name,
        market: market,
        exDate: exDate,
        perShare: perShare,
        shares: shares,
        amount: a,
      );
}

class DividendEstimate {
  final double total;
  final List<DividendLine> lines;

  /// 배당 기록을 받지 못한 종목 수. 0이 아니면 합계가 모자랄 수 있다.
  final int failed;

  final String currency;

  /// 합친 추정에서 포트별 합계 (큰 것부터). 포트 하나짜리면 비어 있다.
  final List<({String id, String name, double amount})> byPortfolio;

  const DividendEstimate({
    required this.total,
    required this.lines,
    required this.failed,
    required this.currency,
    this.byPortfolio = const [],
  });

  bool get isEmpty => lines.isEmpty;
}
