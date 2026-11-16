import 'dart:math' as math;

import 'holdings_parse.dart';

/// 영어로 된 증권사 앱(미국)의 잔고 화면을 읽는다.
///
/// 한국 앱과 다른 점이 셋이다.
///
/// - 종목을 **티커**로 적는다(「AAPL」). 이름은 잘려 있거나 아예 없다.
/// - 금액이 달러다 — 점은 늘 소수점이고 쉼표는 늘 천 단위다.
/// - 소수점 수량이 흔하다(「0.040578 shares」).
///
/// 화면 모양은 둘이다. 증권사 이름으로 가르지 않는다.
///
/// 1. **표** — 머리글에 칸 이름이 있다. 한 칸에 값이 하나거나
///    (E*TRADE·Schwab·IBKR·Merrill·Fidelity 표), 「Mkt Value/Qty」처럼 두 값을
///    위아래로 겹쳐 적는다(Webull·moomoo).
/// 2. **목록** — 머리글 없이 「AAPL / 10 shares / $189.50」 (Robinhood·Fidelity).
///
/// 2026-11 미국 앱 10곳의 실제 캡처 68장으로 맞췄다 (D:/ocr_samples/web_us).
HoldingsShot? parseHoldingsEn(List<OcrWord> words) {
  final clean = [
    for (final w in words)
      if (w.text.trim().isNotEmpty) w
  ];
  if (clean.isEmpty) return null;
  final h = _median(clean.map((w) => w.height));
  final lines = _lines(clean, h * 0.6);
  return _parseTable(lines, h) ?? _parseSharesList(lines, h);
}

/// 표의 칸 자리 — 머리글에서 읽은 것. 머리글이 화면 밖으로 밀린 다음 장을
/// 읽을 때 빌려 쓴다.
class EnTableLayout {
  final _Header _header;
  const EnTableLayout._(this._header);
}

/// 이 캡처가 수량 칸이 있는 표면 그 칸 자리를 돌려준다.
EnTableLayout? enTableLayoutOf(List<OcrWord> words) {
  final clean = [
    for (final w in words)
      if (w.text.trim().isNotEmpty) w
  ];
  if (clean.isEmpty) return null;
  final h = _median(clean.map((w) => w.height));
  final hd = _findHeader(_lines(clean, h * 0.6), h);
  return hd == null || !hd.has(_C.qty) ? null : EnTableLayout._(hd);
}

/// 머리글이 없는 캡처를 **다른 장의 칸 자리로** 읽는다.
///
/// 종목이 많으면 화면을 내려 가며 여러 장 찍는다. 둘째 장부터는 머리글이
/// 화면 밖이다 — 같은 폰의 같은 화면이니 칸 자리는 첫 장과 같다.
/// 머리글이 없으니 무엇이든 표로 읽힐 수 있다. 그래서 까다롭게 본다 —
/// 티커가 있는 종목만 받고, 숫자를 맞춰 볼 수 있는 표면 맞는 줄이 있어야 한다.
HoldingsShot? parseHoldingsEnWith(List<OcrWord> words, EnTableLayout layout) {
  final clean = [
    for (final w in words)
      if (w.text.trim().isNotEmpty) w
  ];
  if (clean.isEmpty) return null;
  final h = _median(clean.map((w) => w.height));
  final shot = _parseTable(_lines(clean, h * 0.6), h, borrowed: layout._header);
  if (shot == null) return null;
  final hs = shot.holdings;
  if (hs.length < 2) return null;
  final checked = hs.where((x) => x.check != NumberCheck.none).length;
  final ok = hs.where((x) => x.check == NumberCheck.ok).length;
  if (checked > 0 && ok * 2 < checked) return null;
  return shot;
}

// ── 낱말 ──

double _median(Iterable<double> xs) {
  final s = xs.toList()..sort();
  return s.isEmpty ? 0 : s[s.length ~/ 2];
}

List<List<OcrWord>> _lines(Iterable<OcrWord> words, double tol) {
  final sorted = [...words]..sort((a, b) => a.cy.compareTo(b.cy));
  final lines = <List<OcrWord>>[];
  var sum = 0.0;
  for (final w in sorted) {
    if (lines.isNotEmpty && (w.cy - sum / lines.last.length).abs() < tol) {
      lines.last.add(w);
      sum += w.cy;
    } else {
      lines.add([w]);
      sum = w.cy;
    }
  }
  for (final l in lines) {
    l.sort((a, b) => a.left.compareTo(b.left));
  }
  return lines;
}

double _cy(List<OcrWord> l) =>
    l.map((w) => w.cy).reduce((a, b) => a + b) / l.length;

class _N {
  final double v;

  /// 「+」「-」가 붙었다 — 손익이다. 가격·수량·평가금액은 부호가 없다.
  final bool signed;
  final bool pct;
  final bool dollar;

  /// 「6.08M」처럼 줄여 적은 값 — 검산에 못 쓴다.
  final bool approx;
  const _N(this.v,
      {this.signed = false,
      this.pct = false,
      this.dollar = false,
      this.approx = false});
}

final _numShape = RegExp(r'^(\d{1,3}(,\d{3})+|\d+)?(\.\d+)?$');

/// 숫자 낱말을 값으로. 숫자가 아니면 null.
///
/// 글자 읽기는 0을 O로 자주 읽는다(「$344.8O」). 숫자 사이에 낀 O만 고친다.
_N? _num(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return null;
  final neg = RegExp(r'^[(\[]?[-−–↓▼]').hasMatch(t);
  final signed = neg || RegExp(r'^[(\[]?[+↑▲]').hasMatch(t);
  t = t.replaceAll(RegExp(r'[()\[\]+\-−–↑↓▲▼\s]'), '');
  final dollar = t.contains(r'$');
  t = t.replaceAll(r'$', '');
  var pct = false;
  if (t.endsWith('%')) {
    pct = true;
    t = t.substring(0, t.length - 1);
  }
  var mult = 1.0;
  var approx = false;
  final m = RegExp(r'^(.*\d)([KMB])$').firstMatch(t);
  if (m != null) {
    mult = const {'K': 1e3, 'M': 1e6, 'B': 1e9}[m[2]]!;
    approx = true;
    t = m[1]!;
  }
  if (!RegExp(r'\d').hasMatch(t)) return null;
  if (RegExp(r'^[\dOo,.]+$').hasMatch(t)) t = t.replaceAll(RegExp('[Oo]'), '0');
  t = t.replaceAll('..', '.');
  // 오른쪽 끝에서 잘린 값 (「$60.」)
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  if (t.isEmpty || !_numShape.hasMatch(t)) return null;
  final v = double.tryParse(t.replaceAll(',', ''));
  if (v == null) return null;
  return _N((neg ? -v : v) * mult,
      signed: signed, pct: pct, dollar: dollar, approx: approx);
}

/// 티커로 보이는 낱말인가. 「BRK.B」「SPAXX**」「GO0G」(O를 0으로 읽음)도 받는다.
final _tickerShape = RegExp(r'^[A-Z0-9]{1,6}([.\-][A-Z])?\*{0,2}$');
bool _tickerLike(String t) =>
    _tickerShape.hasMatch(t) && RegExp('[A-Z]').hasMatch(t);

String _cleanTicker(String t) => t.replaceAll('*', '').toUpperCase();

/// 종목이 아닌 줄의 낱말 — 예수금·합계·옵션.
const _notHolding = {
  'cash', 'total', 'put', 'call', 'calls', 'puts', 'balances', 'pending', //
};

/// 옵션 줄에 적히는 만기 — 「240419」「Jun18'26」「AUG」.
final _expiry = RegExp(
    r"^(\d{6}|(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\d{0,2}('\d\d)?)$",
    caseSensitive: false);

bool _isOptionOrCash(Iterable<String> nameTokens) => nameTokens.any(
    (t) => _notHolding.contains(t.toLowerCase()) || _expiry.hasMatch(t));

bool _near(double a, double b, {double rel = 0.006, double abs = 0.02}) =>
    (a - b).abs() <= math.max(abs, b.abs() * rel);

// ── 표 ──

enum _C { qty, value, last, avg, pnl, etc }

/// 머리글 이름 → 그 칸에 적히는 값(위, 아래). 한 줄짜리 칸은 하나뿐이다.
const _labels = <String, List<_C>>{
  // 두 값을 겹쳐 적는 칸 (Webull·moomoo)
  'mktvalue/qty': [_C.value, _C.qty],
  'marketvalue/qty': [_C.value, _C.qty],
  'mv/qty': [_C.value, _C.qty],
  'qty/mktvalue': [_C.qty, _C.value],
  'qty/mv': [_C.qty, _C.value],
  'last/avgprice': [_C.last, _C.avg],
  'price/cost': [_C.last, _C.avg],
  'price/avgcost': [_C.last, _C.avg],
  'last/cost': [_C.last, _C.avg],
  'openp&l': [_C.pnl, _C.etc],
  'openp/l': [_C.pnl, _C.etc],
  'p&l': [_C.pnl, _C.etc],
  'p/l': [_C.pnl, _C.etc],
  'unrealizedp&l': [_C.pnl, _C.etc],
  'todaysp/l': [_C.etc, _C.etc],
  'todaysp&l': [_C.etc, _C.etc],
  '%chg': [_C.etc, _C.etc],
  'profit/lossratio': [_C.etc, _C.etc],
  // 한 값짜리 칸
  'qty': [_C.qty],
  'quantity': [_C.qty],
  'position': [_C.qty],
  'shares': [_C.qty],
  'last': [_C.last],
  'lastprice': [_C.last],
  'price': [_C.last],
  'mark': [_C.last],
  'pricepaid': [_C.avg],
  'avgcost': [_C.avg],
  'averagecost': [_C.avg],
  'avgprice': [_C.avg],
  'cost/share': [_C.avg],
  'marketvalue': [_C.value],
  'mktvalue': [_C.value],
  'mktval': [_C.value],
  'value': [_C.value],
  'currentvalue': [_C.value],
  'totalgain': [_C.pnl],
  'totalgain\$': [_C.pnl],
  '\$totalg/l': [_C.pnl],
  'totalg/l': [_C.pnl],
  'gain\$': [_C.pnl],
  'gain': [_C.pnl],
  'gain/loss': [_C.pnl],
  'change': [_C.etc],
  'chng': [_C.etc],
  'pricechng': [_C.etc],
  'pricechng\$': [_C.etc],
  'daysgain': [_C.etc],
  'daysgain\$': [_C.etc],
  'daysgain%': [_C.etc],
  'daychng': [_C.etc],
  'daychng\$': [_C.etc],
  '%ofacct': [_C.etc],
  '%totalg/l': [_C.etc],
  'totalgain%': [_C.etc],
  'bid': [_C.etc],
  'ask': [_C.etc],
};

const _nameHeaders = {'symbol', 'instrument', 'security', 'description'};

String _labelNorm(String t) =>
    t.toLowerCase().replaceAll(RegExp(r"[^a-z0-9/&%$]"), '');

class _Col {
  final List<_C> fields;
  final double left, right;

  /// 아는 칸 이름이었나. 모르는 낱말도 칸 자리는 차지한다.
  final bool known;
  const _Col(this.fields, this.left, this.right, {this.known = true});
  double get cx => (left + right) / 2;
}

class _Header {
  final List<_Col> cols;
  final bool hasName;
  final double top, bottom;
  const _Header(this.cols, this.hasName, this.top, this.bottom);

  bool has(_C c) => cols.any((x) => x.fields.contains(c));

  /// 한 종목이 숫자 몇 줄인가. 「Mkt Value/Qty」처럼 **쓰는 값 둘을** 겹쳐
  /// 적는 칸이 있을 때만 두 줄이다 — 「P&L」 한 칸만 금액·%로 겹친 표
  /// (IBKR)는 한 줄짜리다.
  int get depth => cols.any((c) =>
          c.fields.length == 2 &&
          c.fields[0] != _C.etc &&
          c.fields[1] != _C.etc)
      ? 2
      : 1;
}

/// [center] 줄을 가운데 두고 머리글을 읽어 본다. 머리글이 두 줄에 걸치기도
/// 한다(「Price / Paid」) — 위아래 [h]×1.6 안의, 숫자가 없는 줄을 함께 본다.
_Header? _headerAt(List<List<OcrWord>> lines, int center, double h) {
  final cy = _cy(lines[center]);
  final toks = <OcrWord>[];
  for (final l in lines) {
    if ((_cy(l) - cy).abs() > h * 1.6) continue;
    if (l.any((w) => _num(w.text) != null && !w.text.contains('/'))) continue;
    toks.addAll(l);
  }
  // 글자가 아닌 것(정렬 화살표를 한글로 읽은 것, 홀로 선 $)은 뺀다
  toks.removeWhere((w) => _labelNorm(w.text).isEmpty || w.text == r'$');
  if (toks.length < 2) return null;

  // 왼쪽부터, 위아래로 겹친 낱말은 위에서 아래로
  toks.sort((a, b) => a.left.compareTo(b.left));
  final seq = <OcrWord>[];
  final used = List.filled(toks.length, false);
  for (var i = 0; i < toks.length; i++) {
    if (used[i]) continue;
    final stack = [toks[i]];
    used[i] = true;
    for (var j = i + 1; j < toks.length; j++) {
      if (used[j]) continue;
      final a = toks[i], b = toks[j];
      final overlap = math.min(a.right, b.right) - math.max(a.left, b.left);
      if (overlap > 0 && (a.cy - b.cy).abs() > h * 0.6) {
        stack.add(b);
        used[j] = true;
      }
    }
    stack.sort((a, b) => a.cy.compareTo(b.cy));
    seq.addAll(stack);
  }

  var hasName = false;
  final cols = <_Col>[];
  for (var i = 0; i < seq.length;) {
    final first = _labelNorm(seq[i].text);
    if (_nameHeaders.any(first.startsWith)) {
      hasName = true;
      i++;
      continue;
    }
    var matched = 0;
    for (var n = math.min(4, seq.length - i); n >= 1; n--) {
      final part = seq.sublist(i, i + n);
      final fields = _labels[part.map((w) => _labelNorm(w.text)).join()];
      if (fields != null) {
        cols.add(_Col(fields, part.map((w) => w.left).reduce(math.min),
            part.map((w) => w.right).reduce(math.max)));
        matched = n;
        break;
      }
    }
    if (matched == 0) {
      // 모르는 칸도 자리는 차지한다 — 그 밑의 숫자를 옆 칸이 가져가면 안 된다
      cols.add(
          _Col(const [_C.etc], seq[i].left, seq[i].right, known: false));
      matched = 1;
    }
    i += matched;
  }
  final known = cols.where((c) => c.known);
  if (known.isEmpty) return null;
  if (!hasName && known.length < 2) return null;
  return _Header(cols, hasName, toks.map((w) => w.top).reduce(math.min),
      toks.map((w) => w.bottom).reduce(math.max));
}

_Header? _findHeader(List<List<OcrWord>> lines, double h) {
  _Header? best;
  var bestScore = 0;
  for (var i = 0; i < lines.length; i++) {
    final hd = _headerAt(lines, i, h);
    if (hd == null) continue;
    final known = hd.cols.where((c) => c.known).length;
    final score = (hd.hasName ? 10 : 0) + known;
    if (score > bestScore) {
      best = hd;
      bestScore = score;
    }
  }
  return best;
}

HoldingsShot? _parseTable(List<List<OcrWord>> lines, double h,
    {_Header? borrowed}) {
  final hd = borrowed ?? _findHeader(lines, h);
  if (hd == null) return null;
  // 머리글은 있는데 수량 칸이 없다 — 옆으로 밀어 둔 화면이다
  if (!hd.has(_C.qty)) {
    return hd.hasName || hd.has(_C.last) || hd.has(_C.value)
        ? const HoldingsShot(noQuantity: true)
        : null;
  }

  final firstLeft = hd.cols.map((c) => c.left).reduce(math.min);
  // 이름 칸과 숫자 칸의 경계. 숫자는 칸 머리글보다 왼쪽으로 조금 삐져나온다.
  final zone = hd.hasName ? firstLeft - h * 4 : double.negativeInfinity;
  bool isNumTok(OcrWord w) => w.cx > zone && _num(w.text) != null;

  final body = [
    for (final l in lines)
      if (borrowed != null || _cy(l) > hd.bottom + h * 0.2) l
  ];
  final numIdx = [
    for (var i = 0; i < body.length; i++)
      if (body[i].any(isNumTok)) i
  ];
  if (numIdx.isEmpty) return null;
  // 줄 간격이 갑자기 크게 벌어지면 표가 끝난 것이다 — 그 아래의 「As of
  // 07:08 AM」 같은 줄을 종목으로 읽지 않는다.
  if (numIdx.length >= 3) {
    final ys = [for (final i in numIdx) _cy(body[i])];
    final gaps = [for (var k = 1; k < ys.length; k++) ys[k] - ys[k - 1]];
    final typical = _median(gaps);
    for (var k = 0; k < gaps.length; k++) {
      // 벌어진 틈 아래에 한두 줄만 남았을 때만 — 표 가운데에 단추 줄이
      // 끼어 벌어진 것(moomoo 묶음 줄)을 표 끝으로 보면 안 된다
      if (gaps[k] > typical * 2.5 &&
          gaps[k] > h * 6 &&
          numIdx.length - (k + 1) <= 2) {
        numIdx.removeRange(k + 1, numIdx.length);
        break;
      }
    }
  }

  // 숫자 줄을 종목 단위로 묶는다. 값을 겹쳐 적는 표는 두 줄이 한 종목이다 —
  // 종목 안의 줄 간격이 종목 사이보다 좁다.
  final groups = <List<int>>[];
  if (hd.depth == 1) {
    for (final i in numIdx) {
      groups.add([i]);
    }
  } else {
    final gaps = [
      for (var k = 1; k < numIdx.length; k++)
        _cy(body[numIdx[k]]) - _cy(body[numIdx[k - 1]])
    ];
    // 종목 안의 두 줄은 늘 같은 간격으로 붙어 있다 — 가장 좁은 간격이 그것이다.
    // 종목 사이는 그보다 1.6배 넘게 뜬다(실측). 사이에 묶음 줄이나 단추 줄이
    // 끼면 훨씬 더 뜨므로, 가장 넓은 간격을 기준 삼으면 안 된다.
    var cut = h * 2.1;
    if (gaps.isNotEmpty) {
      final lo = gaps.reduce(math.min);
      if (lo < cut) cut = lo * 1.35;
    }
    for (var k = 0; k < numIdx.length; k++) {
      if (k > 0 && gaps[k - 1] < cut && groups.last.length < 2) {
        groups.last.add(numIdx[k]);
      } else {
        groups.add([numIdx[k]]);
      }
    }
  }

  bool isText(OcrWord w) => !isNumTok(w) && w.text != r'$';
  // 이름은 그 줄의 **첫 숫자 왼쪽**까지다. 오른쪽 끝에서 잘린 값(「$1,1」)이나
  // 숫자 칸에 낀 아이콘 글자를 이름으로 읽지 않는다.
  List<OcrWord> leading(List<OcrWord> l) {
    final firstNum = l
        .where(isNumTok)
        .map((w) => w.left)
        .fold<double>(double.infinity, math.min);
    return [for (final w in l) if (isText(w) && w.right <= firstNum) w];
  }

  // 두 줄짜리 표: 티커가 윗줄인가 아랫줄인가. 앱마다 다르다(Webull 위,
  // moomoo 아래). 줄마다 따로 정하면 「NVIDIA / NVDA」에서 헷갈린다 —
  // 표 전체에서 티커 꼴이 더 자주 나오는 쪽으로 정한다.
  var tickerRow = 0;
  if (hd.depth == 2) {
    final votes = [0, 0];
    for (final g in groups) {
      if (g.length != 2) continue;
      for (var r = 0; r < 2; r++) {
        final lead = leading(body[g[r]]);
        if (lead.length == 1 && _tickerLike(lead.first.text)) votes[r]++;
      }
    }
    if (votes[1] > votes[0]) tickerRow = 1;
  }

  final holdings = <ScannedHolding>[];
  final unreadable = <String>[];
  var prevEnd = -1;
  for (final g in groups) {
    final numLines = [for (final i in g) body[i]];
    final own = [for (final l in numLines) leading(l)]
      ..removeWhere((l) => l.isEmpty);
    // 숫자 줄에 글자가 없으면 이름이 그 위에 따로 적힌 표다(Fidelity).
    // 있으면 위의 줄은 **앞 종목의** 꺾인 이름이다(Merrill) — 가져오지 않는다.
    final above = own.isNotEmpty
        ? const <List<OcrWord>>[]
        : [
            for (var i = prevEnd + 1; i < g.first; i++)
              [for (final w in body[i]) if (isText(w)) w],
          ].where((l) => l.isNotEmpty).toList();
    final nameLines = [...above, ...own];
    prevEnd = g.last;

    // 두 줄짜리 표에서 티커 줄 — 한 줄만 읽힌 종목이면 모른다
    final tickerLine = hd.depth == 2 && numLines.length == 2
        ? leading(numLines[tickerRow])
        : null;
    final built = _buildFromTable(hd, numLines, nameLines, isNumTok,
        symbolAbove: own.isEmpty, tickerLine: tickerLine);
    if (built == null) continue;
    if (built.holding != null) {
      holdings.add(built.holding!);
    } else {
      unreadable.add(built.label);
    }
  }
  // 이름 머리글이 없는 표는 딴 화면의 이름표 줄(「Shares / Market Value」)과
  // 가리기 어렵다. 티커가 붙은 종목이 둘은 나와야 표로 친다.
  if (borrowed != null) {
    holdings.removeWhere((x) => x.symbol == null);
    unreadable.clear();
  }
  if (!hd.hasName) {
    if (holdings.where((x) => x.symbol != null).length < 2) return null;
    unreadable.clear();
  }
  if (holdings.isEmpty && unreadable.isEmpty) return null;
  return HoldingsShot(holdings: holdings, unreadable: unreadable);
}

({ScannedHolding? holding, String label})? _buildFromTable(
    _Header hd,
    List<List<OcrWord>> numLines,
    List<List<OcrWord>> nameLines,
    bool Function(OcrWord) isNumTok,
    {required bool symbolAbove, List<OcrWord>? tickerLine}) {
  final words = [for (final l in nameLines) ...l.map((w) => w.text)];
  if (words.isEmpty) return null;
  if (_isOptionOrCash(words)) return null;
  // 「Apple(4)」 — 주식과 옵션을 접어 둔 묶음 줄
  if (words.any((t) => RegExp(r'\(\d+\)').hasMatch(t))) return null;

  String? symbol;
  final nameParts = <String>[];
  if (symbolAbove) {
    // 티커가 숫자 줄 위에 따로 있다. 옆에 붙은 아이콘 한 글자(「O FSKAX」)는
    // 무시하고, 그러고도 낱말이 하나인 줄만 티커로 본다 — 「12:58:41 EDT」
    // 같은 줄을 티커로 읽지 않으려고.
    for (final l in nameLines) {
      final toks = [
        for (final w in l)
          if (w.text.replaceAll('*', '').length >= 2) w.text
      ];
      if (symbol == null && toks.length == 1 && _tickerLike(toks.first)) {
        symbol = _cleanTicker(toks.first);
      } else {
        nameParts.add(l.map((w) => w.text).join(' '));
      }
    }
    // 티커가 없으면 종목 줄이 아니다 — 표 밑의 안내문(「As of 07:08 AM」)이나
    // 딴 화면의 숫자다
    if (symbol == null) return null;
  } else if (hd.depth == 1) {
    // 한 줄짜리 표 — 줄의 첫 낱말이 티커다 (「TDIV AEB 44.440 …」)
    final first = nameLines.first.first.text;
    final rest = nameLines.first.skip(1).map((w) => w.text).join(' ');
    if (_tickerLike(first)) {
      symbol = _cleanTicker(first);
      if (rest.isNotEmpty) nameParts.add(rest);
    } else {
      // 티커 자리의 글자를 못 읽었다(「||AXX」). 낱말이 여럿이면 종목 줄이
      // 아니라 표 밑의 안내문이다(「As of 07:08 AM …」) — 그건 버린다.
      return nameLines.first.length == 1
          ? (holding: null, label: first)
          : null;
    }
  } else {
    // 두 줄짜리 표 — 한 줄은 티커, 한 줄은 이름
    for (final l in nameLines) {
      final toks = l.map((w) => w.text).toList();
      final isTickerLine = tickerLine != null
          ? identical(l.first, tickerLine.isEmpty ? null : tickerLine.first)
          : toks.length == 1 && _tickerLike(toks.first);
      if (symbol == null &&
          isTickerLine &&
          toks.length == 1 &&
          _tickerLike(toks.first)) {
        symbol = _cleanTicker(toks.first);
      } else {
        nameParts.add(toks.join(' '));
      }
    }
  }
  final name = nameParts.join(' ').trim();
  final label = symbol ?? name;
  if (label.isEmpty) return null;

  // 숫자를 칸에 놓는다 — 가장 가까운 칸으로
  final vals = <_C, _N>{};
  for (var row = 0; row < numLines.length; row++) {
    for (final w in numLines[row]) {
      if (!isNumTok(w)) continue;
      final n = _num(w.text)!;
      _Col? best;
      for (final c in hd.cols) {
        if (best == null || (c.cx - w.cx).abs() < (best.cx - w.cx).abs()) {
          best = c;
        }
      }
      if (best == null || row >= best.fields.length) continue;
      final f = best.fields[row];
      if (f == _C.etc) continue;
      vals.putIfAbsent(f, () => n);
    }
  }

  final qty = vals[_C.qty];
  if (qty == null) {
    // 한 줄짜리 표에서 낱말이 여럿인데 수량이 없으면 종목 줄이 아니라 그
    // 밑의 꺾인 이름 줄이다(「VANECK DEV MKT … -0.13%」).
    if (hd.depth == 1 && !symbolAbove && nameLines.first.length > 2) {
      return null;
    }
    return (holding: null, label: label);
  }
  // 0주·음수(공매도·닫힌 옵션)는 넣을 것이 없다
  if (qty.v <= 0 || qty.signed || qty.pct) return null;
  // 「$52」 — 수량은 못 읽고 옆 칸의 금액이 수량 칸으로 온 것이다
  if (qty.dollar) return (holding: null, label: label);

  return (
    holding: _holding(
      symbol: symbol,
      name: name.isEmpty ? (symbol ?? '') : name,
      qty: qty.v,
      last: vals[_C.last],
      value: vals[_C.value],
      avg: vals[_C.avg],
      pnl: vals[_C.pnl],
    ),
    label: label
  );
}

/// 읽은 숫자로 종목 한 줄을 만든다. 화면 안의 숫자끼리 맞춰 본다.
ScannedHolding _holding({
  required String? symbol,
  required String name,
  required double qty,
  _N? last,
  _N? value,
  _N? avg,
  _N? pnl,
  bool priceMaybeValue = false,
}) {
  var cur = last?.v ?? 0;
  var derived = false;
  final exactValue = value != null && !value.approx ? value.v : null;
  if (cur <= 0 && exactValue != null && exactValue > 0) {
    cur = exactValue / qty;
    derived = true;
  }
  NumberCheck check;
  if (last != null && exactValue != null) {
    check = _near(qty * last.v, exactValue)
        ? NumberCheck.ok
        : NumberCheck.failed;
  } else {
    check = NumberCheck.none;
  }

  // 평단가는 그대로 매수 단가가 된다 — 손익과 어긋나면 못 읽은 것으로 친다
  var avgPrice = avg != null && avg.v > 0 ? avg.v : 0.0;
  if (avgPrice > 0 && pnl != null && !pnl.approx && cur > 0 && !derived) {
    final expect = (cur - avgPrice) * qty;
    if (!_near(expect.abs(), pnl.v.abs(), rel: 0.02, abs: 0.05)) avgPrice = 0;
  }

  return ScannedHolding(
    name: name,
    symbol: symbol,
    currency: 'USD',
    qty: qty,
    avgPrice: avgPrice,
    currentPrice: cur,
    value: exactValue ?? (cur > 0 ? qty * cur : 0),
    priceDerived: derived,
    priceMaybeValue: priceMaybeValue,
    check: check,
  );
}

// ── 목록 ──

final _sharesWord = RegExp(r'^shares?$', caseSensitive: false);

/// 머리글 없는 목록 — 「AAPL / 10 shares」에 오른쪽 값 하나 (Robinhood·Fidelity).
///
/// ```
/// AAPL                      $171.70
/// 0.134181 shares
/// ```
///
/// 「N shares」가 종목마다 하나씩 있다 — 그것을 닻으로 삼는다. 티커는 그 위에
/// 같은 왼쪽 자리에서 시작하는 낱말이다.
///
/// 오른쪽 값이 무엇인지는 화면만으로는 모른다. Robinhood는 현재가를,
/// Fidelity는 평가금액을 적는다(설정에 따라 손익이나 등락률이기도 하다).
/// 부호 없는 달러 값만 받아 두고 [ScannedHolding.priceMaybeValue]로 표시한다 —
/// 시세를 받은 뒤에 어느 쪽인지 가린다.
HoldingsShot? _parseSharesList(List<List<OcrWord>> lines, double h) {
  final holdings = <ScannedHolding>[];
  final unreadable = <String>[];

  for (var li = 0; li < lines.length; li++) {
    final line = lines[li];
    for (var k = 0; k < line.length; k++) {
      if (!_sharesWord.hasMatch(line[k].text)) continue;
      final sw = line[k];

      // 수량: 바로 왼쪽의 숫자. 줄이 꺾였으면 바로 위의 숫자.
      OcrWord? qtyTok;
      if (k > 0 && sw.left - line[k - 1].right < h * 1.5) {
        qtyTok = line[k - 1];
      } else if (k == 0) {
        for (var up = li - 1; up >= 0 && up >= li - 2; up--) {
          final c = lines[up].first;
          if ((c.left - sw.left).abs() < h * 1.5 &&
              sw.top - c.bottom < h * 2.5 &&
              _num(c.text) != null) {
            qtyTok = c;
            break;
          }
        }
      }
      if (qtyTok == null) continue;
      final qty = _num(qtyTok.text);
      if (qty == null || qty.signed || qty.pct || qty.dollar) continue;
      // 「Owned 0.0079 shares」처럼 문장 가운데 놓인 것은 이 모양이 아니다
      if (k > 1) continue;

      // 티커: 수량 위, 같은 왼쪽 자리
      OcrWord? sym;
      for (var up = li - 1; up >= 0; up--) {
        final cand = lines[up];
        if (qtyTok.top - _cy(cand) > h * 4.5) break;
        if (identical(cand.first, qtyTok)) continue;
        OcrWord? best;
        for (final w in cand) {
          if ((w.left - qtyTok.left).abs() > h * 1.6) continue;
          if (best == null ||
              (w.left - qtyTok.left).abs() < (best.left - qtyTok.left).abs()) {
            best = w;
          }
        }
        if (best == null) continue;
        // 바로 위 낱말이 또 다른 「shares」 줄이면 이 종목의 티커가 없는 것이다
        if (_sharesWord.hasMatch(best.text) || _num(best.text) != null) break;
        sym = best;
        break;
      }
      if (sym == null) continue;
      final symText = sym.text.toUpperCase();
      if (!_tickerLike(symText)) {
        unreadable.add(sym.text);
        continue;
      }
      if (qty.v <= 0) continue;

      // 오른쪽 값: 티커 줄부터 수량 줄까지, 「shares」보다 오른쪽의 부호 없는 달러 값
      _N? right;
      for (final l in lines) {
        final y = _cy(l);
        if (y < sym.top - h * 0.3 || y > sw.bottom + h * 0.3) continue;
        for (final w in l) {
          if (w.left < sw.right) continue;
          final n = _num(w.text);
          if (n == null || n.signed || n.pct || !n.dollar) continue;
          right ??= n;
        }
      }

      holdings.add(ScannedHolding(
        name: _cleanTicker(symText),
        symbol: _cleanTicker(symText),
        currency: 'USD',
        qty: qty.v,
        avgPrice: 0,
        currentPrice: right?.v ?? 0,
        value: right == null ? 0 : right.v,
        priceMaybeValue: right != null,
        check: NumberCheck.none,
      ));
    }
  }
  if (holdings.isEmpty && unreadable.isEmpty) return null;
  return HoldingsShot(holdings: holdings, unreadable: unreadable);
}
