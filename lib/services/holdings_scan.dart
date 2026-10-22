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

  /// 국가 칸이 「국내」가 아니다 — 외화로 적혀 있어 아직 못 다룬다.
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
}

/// 캡처 한 장을 읽은 결과.
class HoldingsShot {
  final List<ScannedHolding> holdings;

  /// 이름은 보이는데 숫자를 다 읽지 못한 종목.
  final List<String> unreadable;

  /// 잔고 표의 머리글(종목명·잔고수량·매입가)을 찾지 못했다.
  final bool notHoldingsScreen;

  const HoldingsShot({
    this.holdings = const [],
    this.unreadable = const [],
    this.notHoldingsScreen = false,
  });
}

/// 표의 한 칸을 끝내는 말 — 이름 밑 둘째 줄의 「국가 · 구분」.
const _rowEnders = {'국내', '해외', '미국', '현금', '신용', '대출', '담보', '융자'};

/// 둘째 머리글 줄에 있는 말. 여기까지가 머리글이다.
const _subHeaders = ['국가', '구분', '수익률', '평가금액', '현재가'];

final _numberLike = RegExp(r'^-?[\d,.]+$');

/// 「국내」를 「국내수」처럼 군더더기를 붙여 읽기도 한다 — 한 글자까지 봐준다.
bool _isEnder(String t) =>
    _rowEnders.contains(t) ||
    (t.length == 3 && _rowEnders.contains(t.substring(0, 2)));

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
  final header = words.where((w) => w.text.contains('종목명')).firstOrNull;
  if (header == null) return const HoldingsShot(notHoldingsScreen: true);

  bool sameRow(OcrWord w) => (w.cy - header.cy).abs() < header.height;
  OcrWord? headerWord(String s) =>
      words.where((w) => sameRow(w) && w.text.contains(s)).firstOrNull;

  final qtyH = headerWord('잔고수량') ?? headerWord('수량');
  final priceH = headerWord('매입가');
  if (qtyH == null || priceH == null) {
    return const HoldingsShot(notHoldingsScreen: true);
  }
  final plLeft = headerWord('평가손익')?.left ?? (header.right + qtyH.left) / 2;

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

  // 「국내 현금」 줄들 — 칸이 끝나는 자리
  final enders = _rows(left.where((w) => _isEnder(w.text)).toList());

  final holdings = <ScannedHolding>[];
  final unreadable = <String>[];
  var from = dataTop;
  for (var i = 0; i < enders.length; i++) {
    final end = enders[i];
    final to = end.last.bottom;
    bool inBand(OcrWord w) => w.cy > from && w.cy <= to;

    final nameWords = left
        .where((w) => inBand(w) && !_isEnder(w.text))
        .toList();
    final name = _rows(nameWords).map((r) => r.map((w) => w.text).join(' ')).join();
    final q = _rows(qtyCol.where(inBand).toList()).map(_joinNumber).toList();
    final p = _rows(priceCol.where(inBand).toList()).map(_joinNumber).toList();
    from = to;

    if (name.isEmpty) continue;
    if (q.length != 2 || p.length != 2 || q.contains(null) || p.contains(null)) {
      // 맨 위 칸은 머리글 밑으로 반쯤 말려 들어간 것일 수 있다 — 다음 캡처에 온전히 있다
      if (i > 0) unreadable.add(name);
      continue;
    }
    holdings.add(ScannedHolding(
      name: name,
      qty: q[0]!,
      value: q[1]!,
      avgPrice: p[0]!,
      currentPrice: p[1]!,
      foreign: !end.any((w) => w.text.startsWith('국내')),
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

enum NameMatch { exact, prefix, fuzzy, ambiguous, none }

class StockLookup {
  final NameMatch kind;
  final StockSearchResult? stock;

  /// [NameMatch.ambiguous]일 때 고를 후보.
  final List<StockSearchResult> candidates;

  const StockLookup(this.kind, {this.stock, this.candidates = const []});
}

/// 캡처의 이름을 종목 목록에 대 본다.
///
/// - 똑같은 이름 → 그 종목
/// - 증권사가 이름을 잘라서 보여 준다(「…TOP4」 ← 「…TOP4 Plus」). 그렇게
///   **시작하는 종목이 하나뿐이면** 그 종목
/// - 한두 글자 잘못 읽었으면(「AI」 → 「A」) 가장 가까운 것 — 사용자가 확인한다
StockLookup lookupStock(String ocrName, List<StockSearchResult> list) {
  final q = _norm(ocrName.replaceAll('…', '').replaceAll('...', ''));
  if (q.isEmpty) return const StockLookup(NameMatch.none);

  final exact = list.where((s) => _norm(s.name) == q).toList();
  if (exact.length == 1) return StockLookup(NameMatch.exact, stock: exact.first);

  final prefix = list.where((s) => _norm(s.name).startsWith(q)).toList();
  if (prefix.length == 1) {
    return StockLookup(NameMatch.prefix, stock: prefix.first);
  }
  if (prefix.length > 1) {
    return StockLookup(NameMatch.ambiguous, candidates: prefix.take(8).toList());
  }

  // 잘못 읽은 글자 — 길이가 비슷한 것만 본다
  final limit = q.length >= 10 ? 2 : 1;
  StockSearchResult? best;
  var bestD = limit + 1;
  var tie = false;
  for (final s in list) {
    final n = _norm(s.name);
    if ((n.length - q.length).abs() > limit) continue;
    final d = _distance(n, q, limit);
    if (d < bestD) {
      bestD = d;
      best = s;
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
  /// 수량 × 현재가 ≠ 평가금액 — 숫자를 잘못 읽었을 수 있다
  numbersOff,

  /// 이름을 한두 글자 다르게 읽었다 — 고른 종목이 맞는지 봐야 한다
  nameGuessed,

  /// 그렇게 시작하는 종목이 여럿이다 — 골라야 한다
  nameAmbiguous,

  /// 종목 목록에 없다
  notFound,

  /// 해외 종목 — 아직 못 다룬다
  foreign,
}

/// 확인 화면의 한 줄.
class HoldingRow {
  final ScannedHolding scan;
  final StockLookup lookup;

  /// 앱에 이미 있는 같은 종목.
  final PortfolioItem? existing;

  const HoldingRow(this.scan, this.lookup, this.existing);

  StockSearchResult? get stock => lookup.stock;

  /// 앱 화면에 보일 이름 — 찾은 종목 이름이 잘리지 않은 온전한 이름이다.
  String get displayName => existing?.name ?? stock?.name ?? scan.name;

  HoldingIssue? get issue {
    if (scan.foreign) return HoldingIssue.foreign;
    if (existing == null) {
      switch (lookup.kind) {
        case NameMatch.none:
          return HoldingIssue.notFound;
        case NameMatch.ambiguous:
          return HoldingIssue.nameAmbiguous;
        case NameMatch.fuzzy:
          return HoldingIssue.nameGuessed;
        case NameMatch.exact:
        case NameMatch.prefix:
          break;
      }
    }
    if (!scan.verified) return HoldingIssue.numbersOff;
    return null;
  }

  /// 앱 수량과 같은가. 앱에 없으면 null.
  bool? get sameQty =>
      existing == null ? null : (existing!.shares - scan.qty).abs() < 1e-6;

  /// 고르면 새 종목으로 넣을 수 있나.
  bool get addable =>
      existing == null &&
      stock != null &&
      issue != HoldingIssue.foreign &&
      issue != HoldingIssue.notFound;

  /// 처음부터 골라 둘 것 — 걸리는 데가 하나도 없는 새 종목만.
  bool get preselected => addable && issue == null;

  HoldingRow withStock(StockSearchResult s, PortfolioItem? existing) =>
      HoldingRow(scan, StockLookup(NameMatch.exact, stock: s), existing);
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
/// 합친다 — 검산이 맞는 쪽을 남긴다.
List<HoldingRow> buildHoldingRows(
    List<HoldingsShot> shots, Portfolio pf, List<StockSearchResult> stocks) {
  final byKey = <String, HoldingRow>{};
  for (final shot in shots) {
    for (final h in shot.holdings) {
      final lookup = lookupStock(h.name, stocks);
      final existing = findExisting(pf, lookup.stock, h.name);
      final row = HoldingRow(h, lookup, existing);
      final key = existing?.id ?? lookup.stock?.ticker ?? _norm(h.name);
      final prev = byKey[key];
      if (prev == null || (!prev.scan.verified && h.verified)) {
        byKey[key] = row;
      }
    }
  }
  return byKey.values.toList();
}

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
