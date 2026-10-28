import 'dart:math' as math;

import '../models/portfolio.dart';
import 'stock_search_service.dart';

/// 잔고 캡처에서 읽은 낱말 하나와 그 자리(픽셀).
///
/// 글자 읽기(ML Kit)와 떼어 둔다 — 이 파일은 **읽힌 결과를 표로 되돌리는**
/// 일만 한다. 그래야 기기 없이 시험할 수 있다.
class OcrWord {
  final String text;
  final double left, top, right, bottom;
  const OcrWord(this.text, this.left, this.top, this.right, this.bottom);

  double get cx => (left + right) / 2;
  double get cy => (top + bottom) / 2;
  double get height => bottom - top;
}

/// 캡처의 종목 한 줄.
class ScannedHolding {
  /// 화면에 적힌 그대로의 이름. 길면 증권사가 잘라서 보여 준다.
  final String name;
  final double qty;
  final double avgPrice;
  final double currentPrice;
  final double value;

  /// 국가 칸이 해외다 — 외화로 적혀 있어 아직 못 다룬다.
  final bool foreign;

  const ScannedHolding({
    required this.name,
    required this.qty,
    required this.avgPrice,
    required this.currentPrice,
    required this.value,
    this.foreign = false,
  });

  /// **수량 × 현재가 = 평가금액** 인가.
  ///
  /// 증권사는 이 셋을 원 단위까지 맞춰서 보여 준다. 숫자 하나라도 잘못
  /// 읽었으면 여기서 어긋난다 — 글자 읽기를 믿을지 말지는 이것으로 정한다.
  bool get verified => (qty * currentPrice - value).abs() < 1;

  /// 숫자 네 개가 모두 같은가 — 두 캡처에 겹쳐 찍힌 같은 줄이다.
  bool sameNumbers(ScannedHolding o) =>
      qty == o.qty &&
      value == o.value &&
      currentPrice == o.currentPrice &&
      avgPrice == o.avgPrice;
}

/// 캡처 한 장을 읽은 결과.
class HoldingsShot {
  final List<ScannedHolding> holdings;

  /// 표 안에 있는데 다 읽지 못한 종목의 이름. 이름까지 못 읽었으면 빈 문자열.
  final List<String> unreadable;

  /// 잔고 표의 머리글(종목명·잔고수량·매입가)을 찾지 못했다.
  final bool notHoldingsScreen;

  const HoldingsShot({
    this.holdings = const [],
    this.unreadable = const [],
    this.notHoldingsScreen = false,
  });
}

/// 이름 밑 둘째 줄의 「국가」.
const _countries = {'국내', '해외', '미국', '중국', '일본', '홍콩', '베트남'};

/// 이름 밑 둘째 줄의 「구분」.
const _accountKinds = {'현금', '신용', '대출', '담보', '융자', '대주'};

/// 둘째 머리글 줄에 있는 말. 여기까지가 머리글이다.
const _subHeaders = ['국가', '구분', '수익률', '평가금액', '현재가'];

final _numberLike = RegExp(r'^-?[\d,.]+$');

/// 「국내 현금」 칸의 낱말인가.
///
/// 「국내수」처럼 군더더기를 한 글자 붙이거나, 「국내현금」처럼 붙여 읽기도
/// 한다. 그 말들을 지우고 한 글자 이하만 남으면 그 칸의 낱말로 본다.
bool _isEnder(String t) {
  var rest = t;
  for (final e in [..._countries, ..._accountKinds]) {
    rest = rest.replaceAll(e, '');
  }
  return rest.length < t.length && rest.length <= 1;
}

bool _isForeign(String t) =>
    _countries.any((c) => c != '국내' && t.startsWith(c));

/// NH 나무 「주식잔고」 화면을 읽는다.
///
/// 표는 종목마다 두 줄이다.
///
/// ```
/// 종목명        평가손익   잔고수량   매입가
/// 국가 구분     수익률     평가금액   현재가
/// ```
///
/// 이름이 길면 두 줄로 꺾이고, 그 밑에 「국내 현금」이 온다. 그래서 칸은
/// **「국내 현금」 줄에서 끝난다**고 본다. 숫자는 머리글의 가로 자리로 칸을
/// 가르고, 한 칸 안에서 위의 것이 첫 줄(수량·매입가), 아래 것이 둘째 줄
/// (평가금액·현재가)이다.
HoldingsShot parseNamuHoldings(List<OcrWord> words) {
  // 머리글은 「종목명」과 **같은 줄에 「잔고수량」·「매입가」가 있는 것**이다.
  // 화면 위쪽에 검색칸 같은 다른 「종목명」이 있어도 헷갈리지 않는다.
  for (final header in words.where((w) => w.text.contains('종목명'))) {
    bool sameRow(OcrWord w) => (w.cy - header.cy).abs() < header.height;
    OcrWord? headerWord(String s) =>
        words.where((w) => sameRow(w) && w.text.contains(s)).firstOrNull;

    final qtyH = headerWord('잔고수량') ?? headerWord('수량');
    final priceH = headerWord('매입가');
    if (qtyH == null || priceH == null) continue;
    return _parseTable(words, header, qtyH, priceH, headerWord('평가손익'));
  }
  return const HoldingsShot(notHoldingsScreen: true);
}

HoldingsShot _parseTable(List<OcrWord> words, OcrWord header, OcrWord qtyH,
    OcrWord priceH, OcrWord? plH) {
  final plLeft = plH?.left ?? (header.right + qtyH.left) / 2;

  // 둘째 머리글 줄까지가 머리글이다
  var dataTop = header.bottom;
  for (final w in words) {
    if (w.top > header.bottom &&
        w.top < header.bottom + header.height * 2.2 &&
        _subHeaders.any(w.text.contains)) {
      if (w.bottom > dataTop) dataTop = w.bottom;
    }
  }

  final body = words.where((w) => w.top > dataTop).toList();
  final left = body.where((w) => w.cx < plLeft).toList();
  final qtyCol = body
      .where((w) => w.cx >= qtyH.left && w.cx < priceH.left && _isNum(w))
      .toList();
  final priceCol =
      body.where((w) => w.cx >= priceH.left && _isNum(w)).toList();

  // 왼쪽 칸의 줄들. **낱말이 전부** 「국내 현금」인 줄에서 종목 한 칸이
  // 끝난다 — 이름 속 낱말 하나로 칸을 끊지 않는다.
  final leftRows = _rows(left);
  final enders =
      leftRows.where((r) => r.every((w) => _isEnder(w.text))).toList();

  final holdings = <ScannedHolding>[];
  final unreadable = <String>[];
  var from = dataTop;
  for (var i = 0; i < enders.length; i++) {
    final end = enders[i];
    final endTop = end.map((w) => w.top).reduce(math.min);
    final endBottom = end.map((w) => w.bottom).reduce(math.max);
    // 둘째 줄 숫자는 「국내 현금」과 같은 높이에 있다. 숫자 상자가 조금
    // 처져도 이 칸에 들게 반 줄 여유를 둔다.
    final to = endBottom + (endBottom - endTop) / 2;
    bool inBand(OcrWord w) => w.cy > from && w.cy <= to;

    final name = leftRows
        .where((r) => !enders.contains(r) && inBand(r.first))
        .map((r) => r.map((w) => w.text).join(' '))
        .join();
    final q = _rows(qtyCol.where(inBand).toList()).map(_joinNumber).toList();
    final p = _rows(priceCol.where(inBand).toList()).map(_joinNumber).toList();
    from = to;

    // 맨 위 칸은 머리글 밑으로 반쯤 말려 들어간 것일 수 있다 — 이름이나
    // 숫자 줄이 모자란다. 앞뒤 캡처에 온전히 있으니 **그것만** 조용히
    // 넘긴다. 나머지는 못 읽었다고 알린다 — 조용히 빠지면 사용자는 종목이
    // 빠진 줄 모른다.
    final parsed = !q.contains(null) && !p.contains(null);
    final short = q.length < 2 || p.length < 2;
    if (i == 0 && parsed && (short || name.isEmpty)) continue;
    if (name.isEmpty || !parsed || q.length != 2 || p.length != 2) {
      unreadable.add(name);
      continue;
    }
    holdings.add(ScannedHolding(
      name: name,
      qty: q[0]!,
      value: q[1]!,
      avgPrice: p[0]!,
      currentPrice: p[1]!,
      foreign: end.any((w) => _isForeign(w.text)),
    ));
  }
  return HoldingsShot(holdings: holdings, unreadable: unreadable);
}

bool _isNum(OcrWord w) => _numberLike.hasMatch(w.text);

/// 가로로 한 줄에 놓인 낱말끼리 묶는다. 위에서 아래로, 줄 안에서는 왼쪽부터.
List<List<OcrWord>> _rows(List<OcrWord> words) {
  final sorted = [...words]..sort((a, b) => a.cy.compareTo(b.cy));
  final rows = <List<OcrWord>>[];
  for (final w in sorted) {
    final last = rows.isEmpty ? null : rows.last;
    if (last != null && w.cy < last.first.bottom && w.cy > last.first.top) {
      last.add(w);
    } else {
      rows.add([w]);
    }
  }
  for (final r in rows) {
    r.sort((a, b) => a.left.compareTo(b.left));
  }
  return rows;
}

/// 한 줄의 숫자 조각을 하나로 — 「-1,724,3 72」처럼 사이가 떠서 둘로 읽히기도 한다.
double? _joinNumber(List<OcrWord> row) {
  final s = row.map((w) => w.text).join().replaceAll(',', '');
  return double.tryParse(s);
}

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
  final q = _norm(ocrName.replaceAll('…', '').replaceAll('...', ''));
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
    return StockLookup(NameMatch.prefix, stock: prefix.first);
  }
  if (prefix.length > 1) {
    return StockLookup(NameMatch.ambiguous,
        candidates: prefix.take(12).toList());
  }

  // 잘못 읽은 글자 — 길이가 비슷한 것만 본다
  final limit = q.length >= 10 ? 2 : 1;
  StockSearchResult? best;
  var bestD = limit + 1;
  var tie = false;
  for (var i = 0; i < list.length; i++) {
    final n = norms[i];
    if ((n.length - q.length).abs() > limit) continue;
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
    if (!scan.verified) out.add(HoldingIssue.numbersOff);
    final s = stock;
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
    for (final h in shot.holdings) {
      final lookup = _lookup(h.name, stocks, norms);
      final existing = findExisting(pf, lookup.stock, h.name);
      // 0주는 넣을 것이 없다. 앱에 있는 종목이면 「증권사 0주」라는 차이가
      // 보여야 하니 남긴다.
      if (existing == null && h.qty <= 0) continue;
      final row = HoldingRow(h, lookup, existing);
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

/// 시세로 대조할 종목 코드 — 새로 넣을 수 있는 줄의 종목과, 이름이 비슷해
/// 헷갈릴 수 있는 후보들.
Set<String> priceTickers(List<HoldingRow> rows) => {
      for (final r in rows)
        if (r.existing == null) ...[
          if (r.stock != null) r.stock!.ticker,
          for (final c in r.choices) c.ticker,
        ],
    };

/// 캡처의 한 줄로 새 종목을 만든다 — **오늘, 오늘 현재가로 매수 1건.**
///
/// 매입가로 넣지 않는다. 결산은 「산 돈」과 「지금 평가금액」의 차이를 그
/// 기간의 수익으로 본다. 매입가로 넣으면 몇 년 치 평가이익이 **이번 주
/// 결산에 한꺼번에** 잡힌다. 현재가로 넣으면 결산이 오늘부터 깨끗하게
/// 시작한다 — 대신 앱의 평균단가·평가손익은 0에서 시작한다(사용자가 정함).
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
          price: r.scan.currentPrice),
    ],
  )..syncFromTransactions();
}
