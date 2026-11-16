import '../models/portfolio.dart';
import 'holdings_parse.dart';
import 'stock_search_service.dart';

export 'holdings_parse.dart';

/// 예전 이름 — NH 나무만 읽던 때의 것. 지금은 [parseHoldings]가 화면 모양을
/// 보고 읽는다.
HoldingsShot parseNamuHoldings(List<OcrWord> words) => parseHoldings(words);

// ── 종목 찾기 ──

String _norm(String s) => s.replaceAll(RegExp(r'\s'), '').toUpperCase();

enum NameMatch {
  exact,
  prefix,
  fuzzy,
  ambiguous,
  none,

  /// 사용자가 후보 중에서 골랐다.
  chosen,
}

class StockLookup {
  final NameMatch kind;
  final StockSearchResult? stock;

  /// [NameMatch.ambiguous]일 때 고를 후보.
  final List<StockSearchResult> candidates;

  /// 이름이 똑같은 종목을 찾았는데, **그 이름으로 시작하는 더 긴 종목**도
  /// 있다. 증권사가 긴 이름을 잘라서 보여 주면 잘린 이름이 우연히 다른
  /// 종목의 온전한 이름일 수 있다(「KODEX 미국S&P500」 ← 「…액티브」).
  final List<StockSearchResult> alternatives;

  const StockLookup(this.kind,
      {this.stock, this.candidates = const [], this.alternatives = const []});
}

/// 캡처의 이름을 종목 목록에 대 본다.
///
/// - 똑같은 이름 → 그 종목 (더 긴 이름의 종목도 있으면 [StockLookup.alternatives])
/// - 증권사가 이름을 잘라서 보여 준다(「…TOP4」 ← 「…TOP4 Plus」). 그렇게
///   **시작하는 종목이 하나뿐이면** 그 종목
/// - 한두 글자 잘못 읽었으면(「AI」 → 「A」) 가장 가까운 것 — 사용자가 확인한다
StockLookup lookupStock(String ocrName, List<StockSearchResult> list) =>
    _lookup(ocrName, list, [for (final s in list) _norm(s.name)]);

/// [norms]는 [list] 이름을 미리 다듬어 둔 것. 종목이 만사천 개라 종목마다
/// 다시 다듬으면 캡처 한 번에 수십만 번이 된다.
StockLookup _lookup(
    String ocrName, List<StockSearchResult> list, List<String> norms) {
  // 잘린 이름 끝의 말줄임표와 닫히지 않은 괄호를 뗀다 (「…Nifty50(」)
  final q = _norm(ocrName.replaceAll('…', ''))
      .replaceFirst(RegExp(r'[.(]+$'), '');
  if (q.isEmpty) return const StockLookup(NameMatch.none);

  final exact = <StockSearchResult>[];
  final prefix = <StockSearchResult>[];
  for (var i = 0; i < list.length; i++) {
    if (norms[i] == q) exact.add(list[i]);
    if (norms[i].startsWith(q)) prefix.add(list[i]);
  }
  if (exact.length == 1) {
    final longer = prefix.where((s) => s.ticker != exact.first.ticker);
    return StockLookup(NameMatch.exact,
        stock: exact.first, alternatives: longer.take(10).toList());
  }
  if (prefix.length == 1) {
    // 짧은 이름은 잘린 것이 아니라 **다른 종목**이기 쉽다 — 해외 종목
    // 「인텔」이 「인텔리안테크」로 찾아진다. 고르게 한다.
    if (q.length < 4) {
      return StockLookup(NameMatch.ambiguous, candidates: prefix);
    }
    return StockLookup(NameMatch.prefix, stock: prefix.first);
  }
  if (prefix.length > 1) {
    return StockLookup(NameMatch.ambiguous,
        candidates: prefix.take(12).toList());
  }

  // 잘못 읽은 글자 — 길이가 비슷한 것만 본다. 짧은 이름은 한 글자만 달라도
  // 딴 종목이다(「쿠팡」 ← 「쿠콘」, 「SCHD」 ← 「SHD」) — 짐작하지 않는다.
  if (q.length < 5) return const StockLookup(NameMatch.none);
  final limit = q.length >= 10 ? 2 : 1;
  StockSearchResult? best;
  var bestD = limit + 1;
  var tie = false;
  // 우선주는 보통주와 **딴 종목**이다. 종목 목록에 우선주가 빠져 있으면
  // 「한국금융지주우」가 한 글자 차이인 「한국금융지주」로 짐작된다 — 막는다.
  final preferred = _preferred.hasMatch(q);
  for (var i = 0; i < list.length; i++) {
    final n = norms[i];
    if ((n.length - q.length).abs() > limit) continue;
    if (_preferred.hasMatch(n) != preferred) continue;
    final d = _distance(n, q, limit);
    if (d < bestD) {
      bestD = d;
      best = list[i];
      tie = false;
    } else if (d == bestD) {
      tie = true;
    }
  }
  if (best != null && bestD <= limit && !tie) {
    return StockLookup(NameMatch.fuzzy, stock: best);
  }
  return const StockLookup(NameMatch.none);
}

/// 우선주 이름의 끝 — 「삼성전자우」「현대차2우B」.
final _preferred = RegExp(r'우[A-C]?$');

/// 편집 거리. [limit]을 넘으면 더 세지 않는다.
int _distance(String a, String b, int limit) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin > limit) return limit + 1;
    prev = cur;
  }
  return prev[b.length];
}

// ── 앱과 맞대기 ──

enum HoldingIssue {
  /// 해외 종목 — 아직 못 다룬다
  foreign,

  /// 종목 목록에 없다
  notFound,

  /// 그렇게 시작하는 종목이 여럿이다 — 골라야 한다
  nameAmbiguous,

  /// 같은 종목이 **다른 수량으로** 두 번 나왔다 — 두 계좌의 캡처를 섞었거나
  /// 한 계좌 안에서 현금·신용으로 갈려 있다. 어느 쪽인지 앱은 모른다
  qtyConflict,

  /// 수량 × 현재가 ≠ 평가금액 — 숫자를 잘못 읽었을 수 있다
  numbersOff,

  /// 읽은 수량을 맞춰 볼 다른 숫자가 화면에 없었다 — 틀렸다는 것이 아니라
  /// **맞는지 모른다.** 사용자가 한 번 본다
  numbersUnchecked,

  /// 이름을 한두 글자 다르게 읽었다 — 고른 종목이 맞는지 봐야 한다
  nameGuessed,

  /// 찾은 종목의 지금 시세가 캡처의 현재가와 많이 다르다 — 다른 종목일 수 있다
  priceOff,

  /// 이름이 같은 종목을 찾았지만 더 긴 이름의 종목도 있고, 시세로도 어느
  /// 쪽인지 가리지 못했다
  similarNames,
}

/// 「다른 종목이다」로 보는 시세 차이. 캡처가 며칠 묵어도 걸리지 않을 만큼
/// 넉넉하게 잡았다 — 이름이 비슷한 종목끼리는 보통 값의 자릿수부터 다르다.
const priceTolerance = 0.10;

/// 확인 화면의 한 줄.
class HoldingRow {
  final ScannedHolding scan;
  final StockLookup lookup;

  /// 앱에 이미 있는 같은 종목.
  final PortfolioItem? existing;

  /// 같은 종목이 서로 다른 수량으로 나왔을 때의 그 수량들. 없으면 빈 목록.
  final List<double> conflictQtys;

  /// 종목 코드 → 지금 시세. 받은 것만 들어 있다.
  final Map<String, double> live;

  const HoldingRow(this.scan, this.lookup, this.existing,
      {this.conflictQtys = const [], this.live = const {}});

  StockSearchResult? get stock => lookup.stock;

  /// 앱 화면에 보일 이름 — 찾은 종목 이름이 잘리지 않은 온전한 이름이다.
  String get displayName => existing?.name ?? stock?.name ?? scan.name;

  /// 시세가 캡처의 현재가 근처인가.
  bool nearShot(double price) =>
      scan.currentPrice > 0 &&
      (price / scan.currentPrice - 1).abs() <= priceTolerance;

  /// 찾은 종목이 맞다는 걸 **시세가 뒷받침하는가** — 그 종목 시세는 캡처와
  /// 가깝고, 이름이 비슷한 다른 종목 중에는 가까운 것이 없다.
  bool get _confirmedByPrice {
    final s = stock;
    if (s == null) return false;
    final mine = live[s.ticker];
    if (mine == null || !nearShot(mine)) return false;
    return lookup.alternatives.every((a) {
      final p = live[a.ticker];
      return p == null || !nearShot(p);
    });
  }

  /// 걸리는 것들. 앞의 것일수록 무겁다.
  List<HoldingIssue> get issues {
    if (scan.foreign) return const [HoldingIssue.foreign];
    final out = <HoldingIssue>[];
    if (existing == null) {
      if (lookup.kind == NameMatch.none) return const [HoldingIssue.notFound];
      if (lookup.kind == NameMatch.ambiguous) {
        out.add(HoldingIssue.nameAmbiguous);
      }
    }
    if (conflictQtys.isNotEmpty) out.add(HoldingIssue.qtyConflict);
    final s = stock;
    if (scan.check == NumberCheck.failed) {
      out.add(HoldingIssue.numbersOff);
    } else if (scan.check == NumberCheck.none && existing == null) {
      // 현재가를 평가금액 ÷ 수량으로 셈한 화면이면, 그 값이 지금 시세와
      // 맞는 것이 곧 수량을 맞춰 본 것이다. 그것도 못 했으면 확인을 받는다.
      final p = s == null ? null : live[s.ticker];
      if (!(scan.priceDerived && p != null && nearShot(p))) {
        out.add(HoldingIssue.numbersUnchecked);
      }
    }
    if (existing == null && s != null) {
      if (lookup.kind == NameMatch.fuzzy) out.add(HoldingIssue.nameGuessed);
      final p = live[s.ticker];
      if (p != null && !nearShot(p)) {
        out.add(HoldingIssue.priceOff);
      } else if (lookup.alternatives.isNotEmpty && !_confirmedByPrice) {
        out.add(HoldingIssue.similarNames);
      }
    }
    return out;
  }

  /// 앱 수량과 같은가. 앱에 없으면 null.
  bool? get sameQty =>
      existing == null ? null : (existing!.shares - scan.qty).abs() < 1e-6;

  static const _blocking = {
    HoldingIssue.foreign,
    HoldingIssue.notFound,
    HoldingIssue.nameAmbiguous,
    HoldingIssue.qtyConflict,
  };

  /// 고르면 새 종목으로 넣을 수 있나.
  bool get addable =>
      existing == null &&
      stock != null &&
      !issues.any(_blocking.contains);

  /// 처음부터 골라 둘 것 — 걸리는 데가 하나도 없는 새 종목만.
  bool get preselected => addable && issues.isEmpty;

  /// 사용자가 다른 종목으로 바꿀 때 보여 줄 후보.
  List<StockSearchResult> get choices {
    if (lookup.kind == NameMatch.ambiguous) return lookup.candidates;
    final s = stock;
    if (s != null && lookup.alternatives.isNotEmpty) {
      return [s, ...lookup.alternatives];
    }
    return const [];
  }

  HoldingRow withStock(StockSearchResult s, PortfolioItem? existing) =>
      HoldingRow(scan, StockLookup(NameMatch.chosen, stock: s), existing,
          conflictQtys: conflictQtys, live: live);

  HoldingRow withLive(Map<String, double> prices) => HoldingRow(
      scan, lookup, existing,
      conflictQtys: conflictQtys, live: prices);

  String? get _key => existing?.id ?? stock?.ticker;

  /// 같은 보유 종목을 가리키는가 — 같은 종목이거나, 종목을 못 찾았어도
  /// 겹쳐 찍힌 줄의 이름이 잘린 것이면 같은 것이다. 그때는 숫자 네 개가
  /// 똑같고, 잘린 이름이 온전한 이름 안에 들어 있다. **숫자만으로는 합치지
  /// 않는다** — 다른 종목을 하나로 뭉개면 한 종목이 통째로 사라진다.
  bool isSameHolding(HoldingRow o) {
    final a = _key, b = o._key;
    if (a != null && b != null) return a == b;
    final na = _norm(scan.name), nb = _norm(o.scan.name);
    if (a == null && b == null && na == nb) return true;
    return scan.sameNumbers(o.scan) && (na.contains(nb) || nb.contains(na));
  }

  /// 같은 보유 종목의 두 줄을 하나로.
  HoldingRow merge(HoldingRow o) {
    // 숫자는 검산이 맞는 쪽, 이름은 더 확실히 찾은 쪽
    final numbers = (!scan.verified && o.scan.verified) ? o.scan : scan;
    final named = _rank(o.lookup.kind) > _rank(lookup.kind) ? o : this;
    // 둘 다 검산이 맞는데 수량이 다르면 겹쳐 찍힌 것이 아니다
    final qtys = <double>{
      ...conflictQtys,
      ...o.conflictQtys,
      if (scan.verified && o.scan.verified && scan.qty != o.scan.qty) ...[
        scan.qty,
        o.scan.qty
      ],
    }.toList()
      ..sort();
    return HoldingRow(numbers, named.lookup,
        named.existing ?? existing ?? o.existing,
        conflictQtys: qtys, live: live);
  }

  static int _rank(NameMatch k) => switch (k) {
        NameMatch.exact || NameMatch.chosen => 4,
        NameMatch.prefix => 3,
        NameMatch.fuzzy => 2,
        NameMatch.ambiguous => 1,
        NameMatch.none => 0,
      };
}

/// 같은 종목이 앱에 있나 — 종목 코드로, 코드가 없으면 이름으로.
PortfolioItem? findExisting(Portfolio pf, StockSearchResult? s, String name) {
  final items = pf.items.where((i) => !i.isCash);
  if (s != null) {
    final byTicker = items.where((i) => i.ticker == s.ticker).firstOrNull;
    if (byTicker != null) return byTicker;
  }
  final n = _norm(s?.name ?? name);
  return items.where((i) => _norm(i.name) == n).firstOrNull;
}

/// 여러 장의 캡처를 합쳐 확인 화면의 줄로 만든다.
///
/// 캡처를 이어 찍으면 경계의 종목이 두 장에 다 나온다. 같은 종목은 한 줄로
/// 합친다. 같은 종목인데 수량이 다르면 합치되 **어긋났다고 표시**한다 —
/// 한쪽을 조용히 버리면 그 수량이 사라진다.
List<HoldingRow> buildHoldingRows(
    List<HoldingsShot> shots, Portfolio pf, List<StockSearchResult> stocks) {
  final rows = <HoldingRow>[];
  final norms = [for (final s in stocks) _norm(s.name)];
  for (final shot in shots) {
    // **한 장 안에서** 같은 종목이 두 줄이면 한 계좌에 나뉘어 적힌 것이다
    // (「현금 1주」와 「소수점 0.8주」). 한 화면이 같은 줄을 두 번 보여 주지는
    // 않으니 겹쳐 찍힌 것일 수 없다 — 더한다.
    final mine = <HoldingRow>[];
    for (final h in shot.holdings) {
      final lookup = _lookup(h.name, stocks, norms);
      final existing = findExisting(pf, lookup.stock, h.name);
      // 0주는 넣을 것이 없다. 앱에 있는 종목이면 「증권사 0주」라는 차이가
      // 보여야 하니 남긴다.
      if (existing == null && h.qty <= 0) continue;
      final row = HoldingRow(h, lookup, existing);
      final k = row._key == null
          ? -1
          : mine.indexWhere((r) => r._key == row._key);
      if (k == -1) {
        mine.add(row);
      } else {
        mine[k] = HoldingRow(
            _sum(mine[k].scan, h), mine[k].lookup, mine[k].existing);
      }
    }
    for (final row in mine) {
      final j = rows.indexWhere((r) => r.isSameHolding(row));
      if (j == -1) {
        rows.add(row);
      } else {
        rows[j] = rows[j].merge(row);
      }
    }
  }
  return rows;
}

/// 한 화면에 두 줄로 나뉘어 적힌 같은 종목을 하나로 더한다.
ScannedHolding _sum(ScannedHolding a, ScannedHolding b) {
  final qty = a.qty + b.qty;
  // 한쪽이라도 평단가를 못 읽었으면 합친 평단가도 모르는 것이다 —
  // 0을 섞어 평균 내면 절반짜리 평단가가 나온다
  final cost = a.avgPrice > 0 && b.avgPrice > 0
      ? a.avgPrice * a.qty + b.avgPrice * b.qty
      : 0.0;
  final checks = {a.check, b.check};
  return ScannedHolding(
    name: a.name,
    qty: qty,
    avgPrice: qty > 0 ? cost / qty : 0,
    currentPrice: a.currentPrice,
    value: a.value + b.value,
    foreign: a.foreign || b.foreign,
    priceDerived: a.priceDerived || b.priceDerived,
    check: checks.contains(NumberCheck.failed)
        ? NumberCheck.failed
        : checks.contains(NumberCheck.none)
            ? NumberCheck.none
            : NumberCheck.ok,
  );
}

/// 시세로 대조할 종목 코드 — 새로 넣을 수 있는 줄의 종목과, 이름이 비슷해
/// 헷갈릴 수 있는 후보들.
Set<String> priceTickers(List<HoldingRow> rows) => {
      for (final r in rows)
        if (r.existing == null) ...[
          if (r.stock != null) r.stock!.ticker,
          for (final c in r.choices) c.ticker,
        ],
    };

/// 기록할 매수 단가 — 캡처의 평단가. 못 읽었으면 현재가.
double scanBuyPrice(ScannedHolding s) =>
    s.avgPrice > 0 ? s.avgPrice : s.currentPrice;

/// 캡처의 한 줄로 새 종목을 만든다 — **오늘, 평단가로 매수 1건.**
///
/// 처음에는 현재가로 넣었다(평단가로 넣으면 몇 년 치 평가이익이 이번 결산에
/// 한꺼번에 잡혀서). 그런데 그러면 「내가 얼마 벌었나」가 0에서 시작해
/// 증권사 화면과 달라진다. 2026-11-16 사용자가 뒤집었다 — 평단가로 넣고,
/// 결산 화면이 「이전 거래를 넣어야 과거 결산이 맞다」고 알린다
/// (`SettlementService.hasOneDayOfHistory`).
PortfolioItem newItemFromScan(HoldingRow r, String id, DateTime today) {
  final s = r.stock!;
  final date = DateTime(today.year, today.month, today.day);
  return PortfolioItem(
    id: id,
    name: s.name,
    ticker: s.ticker,
    market: s.market,
    currentPrice: r.scan.currentPrice,
    transactions: [
      StockTransaction(
          id: '${id}_0',
          date: date,
          quantity: r.scan.qty,
          price: scanBuyPrice(r.scan)),
    ],
  )..syncFromTransactions();
}
