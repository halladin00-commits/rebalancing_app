import 'dart:math' as math;

/// 잔고 캡처에서 읽은 낱말 하나와 그 자리(픽셀).
///
/// 글자 읽기(ML Kit)와 떼어 둔다 — 이 파일은 **읽힌 결과를 종목 목록으로
/// 되돌리는** 일만 한다. 그래야 기기 없이 시험할 수 있다.
class OcrWord {
  final String text;
  final double left, top, right, bottom;
  const OcrWord(this.text, this.left, this.top, this.right, this.bottom);

  double get cx => (left + right) / 2;
  double get cy => (top + bottom) / 2;
  double get height => bottom - top;
}

/// 읽은 숫자를 **화면 안의 다른 숫자로** 맞춰 봤는가.
enum NumberCheck {
  /// 맞춰 봤고 맞는다 (수량 × 현재가 = 평가금액 등)
  ok,

  /// 맞춰 봤는데 어긋난다 — 숫자 하나를 잘못 읽었을 수 있다
  failed,

  /// 맞춰 볼 숫자가 화면에 없다 (수량과 평가금액만 있는 화면 등)
  none,
}

/// 캡처의 종목 한 줄.
class ScannedHolding {
  /// 화면에 적힌 그대로의 이름. 길면 증권사가 잘라서 보여 준다.
  final String name;
  final double qty;
  final double avgPrice;

  /// 현재가. 화면에 없으면 평가금액 ÷ 수량 ([priceDerived]).
  final double currentPrice;
  final double value;

  /// 해외 종목이다 — 외화로 적혀 있어 아직 못 다룬다.
  final bool foreign;

  /// 현재가가 화면에 없어서 다른 숫자로 셈한 것이다.
  final bool priceDerived;

  final NumberCheck? _check;

  const ScannedHolding({
    required this.name,
    required this.qty,
    required this.avgPrice,
    required this.currentPrice,
    required this.value,
    this.foreign = false,
    this.priceDerived = false,
    NumberCheck? check,
  }) : _check = check;

  /// 화면 안에서 숫자를 맞춰 본 결과. 따로 주지 않았으면
  /// **수량 × 현재가 = 평가금액**으로 본다.
  NumberCheck get check =>
      _check ??
      (valueMatches(qty * currentPrice, value)
          ? NumberCheck.ok
          : NumberCheck.failed);

  /// 숫자를 맞춰 봤고 맞는다. 글자 읽기를 믿을지 말지는 이것으로 정한다.
  bool get verified => check == NumberCheck.ok;

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

  /// 화면 안에 있는데 다 읽지 못한 종목의 이름. 이름까지 못 읽었으면 빈 문자열.
  final List<String> unreadable;

  /// 잔고 화면으로 보이지 않는다 — 종목 목록을 찾지 못했다.
  final bool notHoldingsScreen;

  /// 잔고 표는 찾았는데 **수량 칸이 없는 화면**이다. 평가금액만으로는
  /// 몇 주인지 알 수 없다.
  final bool noQuantity;

  const HoldingsShot({
    this.holdings = const [],
    this.unreadable = const [],
    this.notHoldingsScreen = false,
    this.noQuantity = false,
  });
}

/// 두 금액이 같은가 — 0.5%까지 봐준다. 평균단가는 반올림해 보여 줘서
/// 수량 × 평균단가가 매입금액과 원 단위까지는 안 맞는다.
bool closeAmounts(double a, double b) =>
    (a - b).abs() <= math.max(1.0, b.abs() * 0.005);

/// 수량 × 현재가([expected])가 화면의 평가금액([shown])과 맞는가.
///
/// 원 단위까지 맞는 것이 보통이다. 다만 평가금액에서 **팔 때 들 수수료·세금을
/// 미리 빼서** 보여 주는 증권사가 있다(실제 캡처에서 0.4%까지 봤다). 그래서
/// 평가금액이 **모자란 쪽으로만** 0.5%까지 봐준다. 넘치는 쪽은 숫자를 잘못
/// 읽은 것이다 — 양쪽으로 다 봐주면 한 자리 잘못 읽은 것을 절반은 놓친다.
bool valueMatches(double expected, double shown) {
  final d = expected - shown;
  return d.abs() < 1 || (d > 0 && d <= expected.abs() * 0.005);
}

// ── 낱말 다루기 ──

final _lead = RegExp(r'^[(\[+\-−–▲▼△▽$₩￦]+');
final _trail = RegExp(r'[^\d]+$');
final _numBody = RegExp(r'^[\d.,/]+$');
final _digit = RegExp(r'\d');

/// 기호와 단위를 뗀 숫자 몸통. 「+1,234원」 → 「1,234」.
String _core(String t) => t.replaceFirst(_lead, '').replaceFirst(_trail, '');

/// 숫자로 보이는 낱말인가. 「(6.61%)」「13,984원」「25/」도 숫자다.
/// 끝에 군더더기가 한두 글자 붙기도 한다(「121,680A」).
bool _isNum(String t) {
  final s = _core(t);
  return s.isNotEmpty &&
      _numBody.hasMatch(s) &&
      _digit.hasMatch(s) &&
      t.length - s.length <= 3;
}

class _Num {
  final double v;

  /// 소수점 아래가 세 자리 이상이다 — 외화 값이다.
  final bool fx;
  const _Num(this.v, this.fx);
}

final _wonAsDigit = RegExp(r'^\d{1,3}(,\d{3})*,\d{4}$');
final _thousands = RegExp(r'^\d{1,3}([.,]\d{3})+$');
final _commaThousands = RegExp(r'^\d{1,3}(,\d{3})+$');
final _plain = RegExp(r'^\d+$');
final _decimal = RegExp(r'^(\d{1,3}(?:,\d{3})+|\d+)[.,](\d+)$');

/// 숫자 낱말을 값으로. [isQty]면 점은 늘 소수점이다(「0.809196」「2.407」).
/// 값·단가에서는 「445.000」처럼 쉼표를 점으로 읽은 것을 천 단위로 본다.
_Num? _parse(String? text, {bool isQty = false}) {
  if (text == null) return null;
  var s = _core(text);
  if (s.isEmpty) return null;
  final neg = RegExp(r'^[(\[]*[\-−–▼▽]').hasMatch(text);
  // 「232,813원」의 「원」을 숫자로 읽어 「232,8132」가 된다
  if (_wonAsDigit.hasMatch(s)) s = s.substring(0, s.length - 1);
  double? v;
  var fx = false;
  if (_plain.hasMatch(s)) {
    v = double.parse(s);
  } else if ((isQty ? _commaThousands : _thousands).hasMatch(s)) {
    v = double.parse(s.replaceAll(RegExp('[.,]'), ''));
  } else {
    final m = _decimal.firstMatch(s);
    if (m != null) {
      v = double.parse('${m[1]!.replaceAll(',', '')}.${m[2]}');
      fx = m[2]!.length >= 3;
    }
  }
  if (v == null) return null;
  return _Num(neg ? -v : v, fx);
}

/// 표 머리글·카드 이름표가 가리키는 칸.
enum _F {
  qty,

  /// 주문가능·매도가능 — 보통 보유수량과 같다. 같으면 수량을 두 번 읽은 셈이다
  avail,
  avg,
  cur,
  value,
  cost,
  pnl,
  rate,

  /// 숫자 칸이지만 쓰지 않는다 (비중·대비)
  etc,
}

final _labelNoise = RegExp(r'[\s()%.:|·,]');

_F? _field(String raw) {
  final t = raw.replaceAll(_labelNoise, '');
  if (t.isEmpty || t.length > 12 || _digit.hasMatch(t)) return null;
  if (RegExp('수익률|손익률|등락률').hasMatch(t)) return _F.rate;
  if (RegExp('매도가능|주문가능|가능수량|결제잔고|매도가').hasMatch(t) ||
      t == '가능') {
    return _F.avail;
  }
  if (RegExp('수량|보유잔고|보유량').hasMatch(t) || t == '잔고' || t == '보유') {
    return _F.qty;
  }
  if (RegExp('매입가|매입단가|평균단가|평균가|평단가|매수단가|평균매입가|매입평균가'
          '|매수평균가|손익단가|매수가')
      .hasMatch(t)) {
    return _F.avg;
  }
  if (t.contains('현재가')) return _F.cur;
  if (RegExp('매입금|매수금|투자원금').hasMatch(t)) return _F.cost;
  if (t.contains('평가금')) return _F.value;
  if (RegExp(r'평가손|^손익$').hasMatch(t)) return _F.pnl;
  if (RegExp('비중|대비|약정').hasMatch(t)) return _F.etc;
  return null;
}

/// 이름 칸에 이름 말고 함께 적히는 말 — 「국내 현금」「외화증권」「소수점」.
const _countries = {'국내', '해외', '미국', '중국', '일본', '홍콩', '베트남'};
const _accountKinds = {
  '외화증권',
  '소수점',
  '현금',
  '신용',
  '대출',
  '담보',
  '융자',
  '대주',
};

/// 「국내 현금」 칸의 낱말인가.
///
/// 「국내수」처럼 군더더기를 한 글자 붙이거나, 「국내현금」처럼 붙여 읽기도
/// 한다. 그 말들을 지우고 한 글자 이하만 남으면 그 칸의 낱말로 본다.
bool _isEnder(String t) {
  var rest = t;
  for (final e in [..._countries, ..._accountKinds]) {
    rest = rest.replaceAll(e, '');
  }
  rest = rest.replaceAll('|', '');
  return rest.length < t.length && rest.length <= 1;
}

bool _isForeign(String t) =>
    t.startsWith('외화') || _countries.any((c) => c != '국내' && t.startsWith(c));

double _median(Iterable<double> xs) {
  final s = xs.toList()..sort();
  return s.isEmpty ? 0 : s[s.length ~/ 2];
}

/// 가로로 한 줄에 놓인 낱말끼리 묶는다. 위에서 아래로, 줄 안에서는 왼쪽부터.
///
/// 같은 줄이라도 낱말마다 상자 높이가 조금씩 달라 반 줄쯤 어긋난다.
/// [tol]은 그만큼 — 보통 글자 높이의 0.6배.
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

double _lineCy(List<OcrWord> l) =>
    l.map((w) => w.cy).reduce((a, b) => a + b) / l.length;
double _lineTop(List<OcrWord> l) => l.map((w) => w.top).reduce(math.min);
double _lineBottom(List<OcrWord> l) => l.map((w) => w.bottom).reduce(math.max);

/// 이름 낱말들을 한 이름으로. 줄 안은 띄우고 줄끼리는 붙인다 — 증권사는
/// 긴 이름을 낱말 중간에서 꺾는다(「삼성에피스홀/딩스」).
/// 「국내 현금」처럼 이름이 아닌 줄은 뺀다. 그 줄이 해외를 가리켰으면
/// [foreign]이 참이 된다.
({String name, bool foreign}) _composeName(List<OcrWord> toks, double tol) {
  var foreign = false;
  final parts = <String>[];
  for (final line in _lines(toks, tol)) {
    final kept = line.where((w) => w.text != '|').toList();
    if (kept.isEmpty) continue;
    if (kept.every((w) => _isEnder(w.text))) {
      if (kept.any((w) => _isForeign(w.text))) foreign = true;
      continue;
    }
    // 이름 줄 끝에 붙은 「현금」도 뗀다 (「10호스팩 현금」)
    // (「미국나」처럼 꺾인 이름 조각을 나라 이름으로 보고 떼면 안 된다)
    while (kept.length > 1 && _accountKinds.contains(kept.last.text)) {
      kept.removeLast();
    }
    parts.add(kept.map((w) => w.text).join(' '));
  }
  return (name: parts.join(), foreign: foreign);
}

// ── 한 종목의 숫자 맞추기 ──

/// 칸별로 읽힌 글자에서 종목 한 줄을 만든다. 수량이나 값을 못 읽었으면 null.
ScannedHolding? _build(String name, Map<_F, String> cells,
    {bool foreign = false}) {
  var qtyText = cells[_F.qty];
  var availText = cells[_F.avail];
  // 「25/25」 — 주문가능/보유수량을 한 칸에 적는 화면
  if (qtyText != null && qtyText.contains('/')) {
    final p = qtyText.split('/').where((s) => s.trim().isNotEmpty).toList();
    if (p.length == 2) {
      availText ??= p[0];
      qtyText = p[1];
    } else if (p.length == 1) {
      qtyText = p[0];
    }
  }
  final qtyRead = _parse(qtyText, isQty: true);
  final avail = _parse(availText, isQty: true);
  // 수량 칸이 없고 매도가능만 있는 화면(접힌 카드)은 그것을 수량으로 쓴다
  final curRead = _parse(cells[_F.cur]);
  final valueRead = _parse(cells[_F.value]);
  var qty = (qtyRead ?? avail)?.v;
  var qtyGuessed = false;
  if (qty == null && curRead != null && valueRead != null && curRead.v > 0) {
    // 수량 「1」처럼 한 글자짜리는 글자 읽기가 통째로 놓치기도 한다.
    // 평가금액 ÷ 현재가가 정수로 떨어지면 그것이 수량이다 — 다만 맞춰 본
    // 것이 아니라 셈한 것이라 확인을 받는다.
    final q = valueRead.v / curRead.v;
    if (q >= 0.5 && (q - q.roundToDouble()).abs() < 0.02) {
      qty = q.roundToDouble();
      qtyGuessed = true;
    }
  }
  if (qty == null || qty <= 0) return null;
  final avg = _parse(cells[_F.avg]);
  final cost = _parse(cells[_F.cost]);
  final pnl = _parse(cells[_F.pnl]);
  final rate = _parse(cells[_F.rate]);

  var cur = curRead?.v;
  var derived = false;
  if (cur == null) {
    derived = true;
    if (valueRead != null) {
      cur = valueRead.v / qty;
    } else if (avg != null && pnl != null) {
      cur = avg.v + pnl.v / qty;
    } else if (avg != null && rate != null) {
      cur = avg.v * (1 + rate.v / 100);
    }
  }
  if (cur == null || cur <= 0) return null;
  final value = valueRead?.v ?? qty * cur;

  // 화면 안의 다른 숫자로 맞춰 본다. 수량 × 현재가 = 평가금액이 가장
  // 확실하다. 그 셋이 다 없으면 수량 × 평균단가 = 매입금액, 그것도 없으면
  // 보유수량 = 주문가능수량(같은 수를 두 번 읽은 것).
  NumberCheck check;
  if (qtyGuessed) {
    check = NumberCheck.none;
  } else if (curRead != null && valueRead != null) {
    check = valueMatches(qty * curRead.v, valueRead.v)
        ? NumberCheck.ok
        : NumberCheck.failed;
  } else if (avg != null && cost != null) {
    check = closeAmounts(qty * avg.v, cost.v)
        ? NumberCheck.ok
        : NumberCheck.failed;
  } else if (qtyRead != null && avail != null) {
    check = avail.v == qtyRead.v
        ? NumberCheck.ok
        : avail.v > qtyRead.v
            ? NumberCheck.failed
            : NumberCheck.none;
  } else {
    check = NumberCheck.none;
  }

  final fx = [curRead, valueRead, avg].any((n) => n != null && n.fx);
  return ScannedHolding(
    name: name,
    qty: qty,
    avgPrice: avg?.v ?? 0,
    currentPrice: cur,
    value: value,
    foreign: foreign || fx,
    priceDerived: derived,
    check: check,
  );
}

// ── 표 ──

class _Cell {
  final _F f;
  double left, right;
  _Cell(this.f, this.left, this.right);
  double get cx => (left + right) / 2;
}

class _Header {
  final OcrWord name;
  final List<List<_Cell>> rows;

  /// 「종목명」과 같은 줄(따로 적혔으면 가장 가까운 줄).
  final List<_Cell> nameRow;
  final double bottom;
  _Header(this.name, this.rows, this.nameRow, this.bottom);
}

bool _isNameHeader(String t, {required bool strict}) {
  final s = t.replaceAll(_labelNoise, '');
  if (s.contains('종목명')) return true;
  return !strict && (s == '종목' || s == '상품');
}

/// 「종목명」 머리글과 그 둘레의 숫자 칸 머리글을 찾는다.
///
/// 머리글은 한 줄이거나 두 줄이다. 「종목명」이 두 줄 사이 가운데에 따로
/// 적히기도 한다. 요약란의 「평가금액 1,234,567」 같은 줄은 숫자가 함께
/// 있어서 머리글이 아니다.
_Header? _findHeader(List<OcrWord> words) {
  for (final strict in [true, false]) {
    final cands = words
        .where((w) => _isNameHeader(w.text, strict: strict))
        .toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    for (final nameH in cands) {
      final h = nameH.height;
      final labels = words.where((w) =>
          !identical(w, nameH) &&
          _field(w.text) != null &&
          (w.cy - nameH.cy).abs() <= 3.2 * h);
      var rows = _lines(labels, 0.6 * h)
          .where((row) => !words.any((w) =>
              _isNum(w.text) &&
              _core(w.text).length >= 2 &&
              (w.cy - _lineCy(row)).abs() < 0.5 * h))
          .toList();
      if (rows.length > 2) {
        rows.sort((a, b) => (_lineCy(a) - nameH.cy)
            .abs()
            .compareTo((_lineCy(b) - nameH.cy).abs()));
        rows = rows.take(2).toList()
          ..sort((a, b) => _lineCy(a).compareTo(_lineCy(b)));
      }
      final cellRows = <List<_Cell>>[];
      for (final row in rows) {
        final cells = <_Cell>[];
        for (final w in row) {
          final f = _field(w.text)!;
          // 「보유 수량」처럼 두 낱말로 읽힌 한 칸
          if (cells.isNotEmpty && cells.last.f == f) {
            cells.last.right = w.right;
          } else {
            cells.add(_Cell(f, w.left, w.right));
          }
        }
        cellRows.add(cells);
      }
      final all = [for (final r in cellRows) ...r];
      if (all.length < 2) continue;
      if (!all.any((c) =>
          c.f == _F.qty ||
          c.f == _F.avail ||
          c.f == _F.value ||
          c.f == _F.cur)) {
        continue;
      }
      var bottom = nameH.bottom;
      var near = 0;
      for (var k = 0; k < rows.length; k++) {
        bottom = math.max(bottom, _lineBottom(rows[k]));
        if ((_lineCy(rows[k]) - nameH.cy).abs() <
            (_lineCy(rows[near]) - nameH.cy).abs()) {
          near = k;
        }
      }
      return _Header(nameH, cellRows, cellRows[near], bottom);
    }
  }
  return null;
}

/// 숫자 낱말 줄 하나와, 거기서 읽은 칸들.
class _NumLine {
  final List<OcrWord> core;

  /// 이름 칸 쪽에 있는 숫자 — 그 줄 머리글에 칸이 있으면 값이고
  /// (「주문가능 50 · 보유수량 50」), 없으면 이름의 일부다(「…나스닥 100」).
  final List<OcrWord> zone = [];
  _NumLine(this.core);
  double get cy => _lineCy(core);
  double get top => _lineTop(core);
  double get bottom => _lineBottom(core);
}

class _Record {
  final List<_NumLine> lines;

  /// 줄 수가 모자라다 — 캡처 위·아래에서 잘렸거나 한 줄을 못 읽었다.
  final bool orphan;
  final List<OcrWord> nameToks = [];
  _Record(this.lines, {this.orphan = false});
  double get top => lines.first.top;
  double get bottom => lines.last.bottom;
}

_Cell? _nearest(OcrWord t, List<_Cell> cells) {
  _Cell? best;
  var bestD = double.infinity;
  for (final c in cells) {
    final d = math.min((t.cx - c.cx).abs(), (t.right - c.right).abs());
    if (d < bestD) {
      bestD = d;
      best = c;
    }
  }
  return best;
}

final _rateLike = RegExp(r'^\d{1,4}\.\d{1,2}$');

/// 표 형태의 잔고 화면을 읽는다. 대부분의 증권사 앱이 이 모양이다.
///
/// ```
/// 종목명        평가손익   잔고수량   매입가      ← 머리글 첫 줄
/// (구분)        수익률     평가금액   현재가      ← 머리글 둘째 줄
/// 삼성전자      +12,000    10         71,000
/// 현금          +1.69%     722,000    72,200
/// ```
///
/// 머리글이 두 줄이면 종목도 숫자 두 줄이고, **머리글의 칸 자리가 곧 숫자의
/// 칸 자리**다. 어느 칸이 수량이고 현재가인지는 머리글 낱말로 안다 — 증권사
/// 마다 순서가 달라도 된다.
HoldingsShot? _parseTable(List<OcrWord> words) {
  final hdr = _findHeader(words);
  if (hdr == null) return null;
  final h = hdr.name.height;
  final allCells = [for (final r in hdr.rows) ...r];
  final hasQty = allCells.any((c) => c.f == _F.qty || c.f == _F.avail);

  // 「종목명」과 같은 줄(없으면 가장 가까운 줄)의 첫 숫자 칸부터가 숫자 자리다
  final rightOfName =
      hdr.nameRow.where((c) => c.left > hdr.name.left).map((c) => c.left);
  final allRight =
      allCells.where((c) => c.left > hdr.name.right).map((c) => c.left);
  final boundary = rightOfName.isNotEmpty
      ? rightOfName.reduce(math.min)
      : allRight.isNotEmpty
          ? allRight.reduce(math.min)
          : hdr.name.right + 4 * h;

  List<_Cell> coreCells(int r) =>
      hdr.rows[r].where((c) => c.cx >= boundary).toList();
  List<_Cell> zoneCells(int r) =>
      hdr.rows[r].where((c) => c.cx < boundary).toList();

  final body = words.where((w) => w.cy > hdr.bottom).toList();
  final coreNums =
      body.where((w) => _isNum(w.text) && w.cx >= boundary).toList();
  if (coreNums.isEmpty) {
    return HoldingsShot(noQuantity: !hasQty);
  }
  final tokH = _median(coreNums.map((w) => w.height));
  final tol = 0.6 * (tokH > 0 ? tokH : h);
  final lines = [for (final l in _lines(coreNums, tol)) _NumLine(l)];
  final leftover = <OcrWord>[];
  for (final w in body.where((w) => w.cx < boundary)) {
    if (!_isNum(w.text)) {
      leftover.add(w);
      continue;
    }
    final line =
        lines.where((l) => (l.cy - w.cy).abs() < tol).firstOrNull;
    if (line == null) {
      leftover.add(w);
    } else {
      line.zone.add(w);
    }
  }

  Map<_F, String> read(_NumLine line, int r) {
    final byCell = <_Cell, List<OcrWord>>{};
    final cc = coreCells(r);
    for (final t in line.core) {
      final c = _nearest(t, cc);
      if (c != null) (byCell[c] ??= []).add(t);
    }
    final zc = zoneCells(r);
    for (final t in line.zone) {
      final c = _nearest(t, zc);
      if (c != null) (byCell[c] ??= []).add(t);
    }
    return {
      for (final e in byCell.entries)
        e.key.f: (e.value..sort((a, b) => a.left.compareTo(b.left)))
            .map((w) => w.text)
            .join(),
    };
  }

  // 종목마다 숫자 줄이 머리글 줄 수만큼 있다
  final records = <_Record>[];
  final rowCount = hdr.rows.length;
  if (rowCount == 1) {
    records.addAll(lines.map((l) => _Record([l])));
  } else {
    final rateRow = hdr.rows.indexWhere((r) => r.any((c) => c.f == _F.rate));
    bool hasRate(_NumLine l) {
      final cc = coreCells(rateRow);
      return l.core.any((t) =>
          (t.text.contains('%') || _rateLike.hasMatch(_core(t.text))) &&
          _nearest(t, cc)?.f == _F.rate);
    }

    List<_Record> pairUp(bool Function(_NumLine a, _NumLine b) ok,
        {int start = 0}) {
      final out = <_Record>[
        for (var k = 0; k < start; k++) _Record([lines[k]], orphan: true)
      ];
      var i = start;
      while (i < lines.length) {
        if (i + 1 < lines.length && ok(lines[i], lines[i + 1])) {
          out.add(_Record([lines[i], lines[i + 1]]));
          i += 2;
        } else {
          out.add(_Record([lines[i]], orphan: true));
          i += 1;
        }
      }
      return out;
    }

    if (rateRow >= 0) {
      // 수익률은 %가 붙어 있어 **어느 줄인지 스스로 말해 준다.** 맨 위 종목이
      // 머리글 밑으로 반쯤 말려 들어가 둘째 줄만 보여도 짝이 밀리지 않는다.
      records.addAll(pairUp((a, b) => rateRow == 1
          ? !hasRate(a) && hasRate(b)
          : hasRate(a) && !hasRate(b)));
    } else {
      // 수익률 칸이 없는 화면 — 첫 줄부터 짝지은 것과 둘째 줄부터 짝지은 것
      // 중에 검산이 더 많이 맞는 쪽이 옳다
      int score(List<_Record> rs) => rs.where((r) {
            if (r.orphan) return false;
            final h = _build('x', {
              ...read(r.lines[0], 0),
              ...read(r.lines[1], 1),
            });
            return h != null && h.check == NumberCheck.ok;
          }).length;
      final a = pairUp((_, __) => true);
      final b = pairUp((_, __) => true, start: 1);
      records.addAll(score(b) > score(a) ? b : a);
    }
  }

  // 이름 낱말을 가장 가까운 종목에 붙인다. 이름은 숫자 줄 위에서 시작하기도
  // 하고(「VANGUARD S&P / 500」) 아래로 넘치기도 한다(「…액 / 티브」).
  final complete = records.where((r) => !r.orphan).toList();
  final intra = rowCount == 1
      ? 0.0
      : _median(complete.map((r) => r.lines.last.cy - r.lines.first.cy));
  final reach = intra > 0 ? intra : 1.2 * (tokH > 0 ? tokH : h);
  for (final r in records) {
    for (final l in r.lines) {
      // 그 줄 머리글에 이름 쪽 칸이 없으면 이름 쪽 숫자는 이름이다
      final ri = r.orphan ? -1 : r.lines.indexOf(l);
      if (ri < 0 || zoneCells(ri).isEmpty) {
        leftover.addAll(l.zone);
        l.zone.clear();
      }
    }
  }
  for (final w in leftover) {
    _Record? best;
    var bestD = double.infinity;
    for (final r in records) {
      final pad = 0.2 * h;
      final above = r.top - pad - w.cy;
      final below = w.cy - (r.bottom + pad);
      final d = above > 0
          ? (above <= 1.2 * reach ? above : double.infinity)
          : below > 0
              ? (below <= 0.8 * reach ? below : double.infinity)
              : 0.0;
      // 같은 거리면 아래 종목 — 이름은 숫자보다 먼저 시작한다
      if (d < bestD || (d == bestD && d.isFinite && above > 0)) {
        bestD = d;
        best = r;
      }
    }
    if (best != null && bestD.isFinite) best.nameToks.add(w);
  }

  final holdings = <ScannedHolding>[];
  final unreadable = <String>[];
  for (var i = 0; i < records.length; i++) {
    final r = records[i];
    final named = _composeName(r.nameToks, tol);
    final edge = i == 0 || i == records.length - 1;
    if (r.orphan) {
      // 맨 위·맨 아래의 반쪽은 캡처에서 잘린 것이다(맨 아래는 지수 띠 같은
      // 화면 장식이기도 하다). 앞뒤 캡처에 온전히 있으니 조용히 넘긴다.
      // 가운데서 줄이 모자라면 못 읽었다고 알린다 — 조용히 빠지면 사용자는
      // 종목이 빠진 줄 모른다.
      if (!edge) unreadable.add(named.name);
      continue;
    }
    if (!hasQty) continue;
    final cells = {
      for (var k = 0; k < r.lines.length; k++) ...read(r.lines[k], k),
    };
    final built = _build(named.name, cells, foreign: named.foreign);
    if (built == null || named.name.isEmpty) {
      // 맨 위 종목의 이름이 머리글 밑으로 가려진 것은 조용히 넘긴다
      if (i == 0 && built != null) continue;
      unreadable.add(named.name);
      continue;
    }
    holdings.add(built);
  }
  return HoldingsShot(
    holdings: holdings,
    unreadable: unreadable,
    noQuantity: !hasQty,
  );
}

// ── 카드 · 목록 ──

/// 한 줄에서 「이름표 → 값」 짝을 뽑는다. 「평균단가 41,763」.
Map<_F, String> _pairs(List<OcrWord> line) {
  final out = <_F, String>{};
  for (var i = 0; i < line.length; i++) {
    final label = line[i].text;
    final f = _field(label);
    if (f == null || f == _F.etc) continue;
    final vals = <String>[];
    var j = i + 1;
    while (j < line.length && _isNum(line[j].text)) {
      vals.add(line[j].text);
      j++;
    }
    if (vals.isEmpty) continue;
    final v = vals.join();
    // 「보유수량/매입단가  12/19,565」
    if (f == _F.qty && label.contains('/') && v.contains('/')) {
      final p = v.split('/');
      out[_F.qty] = p.first;
      out[_F.avg] = p.last;
    } else {
      out.putIfAbsent(f, () => v);
    }
    i = j - 1;
  }
  return out;
}

/// 카드 형태 — 종목 이름 밑에 「이름표 값」이 여러 줄 놓인다.
///
/// ```
/// NAVER                      현금
/// 평가손익   -53,903   매도가능        1
/// 손익률     -12.10%   평균단가  445,000
/// 평가금     393,000   현재가    393,000
/// ```
HoldingsShot? _parseCards(List<OcrWord> words) {
  if (words.isEmpty) return null;
  final h = _median(words.map((w) => w.height));
  final width = words.map((w) => w.right).reduce(math.max);
  final lines = _lines(words, 0.6 * h);
  final pairs = [for (final l in lines) _pairs(l)];

  final holdings = <ScannedHolding>[];
  final unreadable = <String>[];
  var i = 0;
  var prevEnd = -1;
  while (i < lines.length) {
    if (pairs[i].isEmpty) {
      i++;
      continue;
    }
    // 이름표가 되풀이되면 다음 종목이다
    final cells = <_F, String>{};
    final first = i;
    while (i < lines.length &&
        pairs[i].isNotEmpty &&
        !pairs[i].keys.any(cells.containsKey)) {
      cells.addAll(pairs[i]);
      i++;
    }
    final last = i - 1;
    if (!cells.containsKey(_F.qty) && !cells.containsKey(_F.avail)) {
      prevEnd = last;
      continue;
    }
    // 이름은 바로 위 줄의 왼쪽 글자
    final pitch = last > first
        ? (_lineCy(lines[last]) - _lineCy(lines[first])) / (last - first)
        : 1.8 * h;
    var name = '';
    var foreign = false;
    for (var k = first - 1; k > prevEnd && k >= 0; k--) {
      if (_lineCy(lines[first]) - _lineCy(lines[k]) > 2.6 * pitch) break;
      final toks = lines[k].where((w) => w.left < 0.55 * width).toList();
      if (toks.every((w) => _isNum(w.text))) continue;
      final named = _composeName(toks, 0.6 * h);
      if (named.name.isEmpty) continue;
      name = named.name;
      foreign = named.foreign;
      break;
    }
    prevEnd = last;
    final built = _build(name, cells, foreign: foreign);
    if (built == null || name.isEmpty) {
      unreadable.add(name);
    } else {
      holdings.add(built);
    }
  }
  if (holdings.isEmpty) return null;
  return HoldingsShot(holdings: holdings, unreadable: unreadable);
}

final _sharesToken = RegExp(r'^\d[\d,.]*주/?$');

/// 손익·수익률로 보이는 낱말 — 부호나 괄호로 시작하거나 「12.3%」 꼴이다.
/// 「14,309,353%」는 아니다(「원」을 %로 읽은 평가금).
final _signed = RegExp(r'^[+\-−(]|\d\.\d+%');

/// 목록 형태 — 머리글도 이름표도 없이 「이름 / 13주 / 평가금」만 있다
/// (토스증권·카카오페이증권 등).
///
/// ```
/// TIGER 미국S&P500            324,155
/// 13주               +10.90% (31,885원)
/// ```
///
/// 「13주」가 종목마다 하나씩 있다 — 그것을 닻으로 삼는다. 이름은 그 위에
/// 같은 왼쪽 자리에서 시작하는 줄이고, 평가금은 오른쪽의 부호 없는 숫자다.
/// 현재가가 화면에 없으니 평가금 ÷ 수량으로 셈한다.
HoldingsShot? _parseList(List<OcrWord> words) {
  final anchors = words.where((w) => _sharesToken.hasMatch(w.text)).toList()
    ..sort((a, b) => a.top.compareTo(b.top));
  if (anchors.isEmpty) return null;
  final h = _median(anchors.map((w) => w.height));
  final width = words.map((w) => w.right).reduce(math.max);
  final lines = _lines(words, 0.6 * h);
  int lineOf(OcrWord w) => lines.indexWhere((l) => l.contains(w));
  final anchorLines = {for (final a in anchors) lineOf(a)};

  final recs = <({OcrWord anchor, List<OcrWord> name, double top})>[];
  for (final a in anchors) {
    final la = lineOf(a);
    // 「현금 20주」 — 수량 앞에 구분이 붙으면 그 자리가 줄의 시작이다
    final before = lines[la].where((w) => w.left < a.left).toList();
    final alignX = before.isNotEmpty && _isEnder(before.last.text)
        ? before.last.left
        : a.left;
    final nameToks = <OcrWord>[];
    var lastCy = a.cy;
    var top = a.top;
    var taken = 0;
    for (var k = la - 1; k >= 0 && taken < 3; k--) {
      if (anchorLines.contains(k)) break;
      final line = lines[k];
      final text = line.map((w) => w.text).join();
      if (text.contains('평균') || text.contains('종목명')) break;
      if (!line.any((w) => (w.left - alignX).abs() <= 1.2 * h)) continue;
      if (lastCy - _lineCy(line) > 5 * h) break;
      // 이름 줄 가운데의 숫자(「+26.7%」)는 이름이 아니다. 줄 맨 앞의
      // 숫자는 이름이다(「TIGER / 200」)
      nameToks.addAll(line.where((w) =>
          w.left >= alignX - 1.2 * h &&
          w.left < 0.5 * width &&
          (!_isNum(w.text) || (w.left - alignX).abs() <= 1.2 * h)));
      lastCy = _lineCy(line);
      top = _lineTop(line);
      taken++;
    }
    recs.add((anchor: a, name: nameToks, top: top));
  }

  final holdings = <ScannedHolding>[];
  final unreadable = <String>[];
  for (var i = 0; i < recs.length; i++) {
    final r = recs[i];
    final from = r.top - 0.3 * h;
    final to = i + 1 < recs.length
        ? recs[i + 1].top - 0.3 * h
        : r.anchor.bottom + 5 * h;
    final inRange =
        lines.where((l) => _lineCy(l) >= from && _lineCy(l) < to).toList();
    final cells = <_F, String>{_F.qty: r.anchor.text};
    for (final l in inRange) {
      for (final e in _pairs(l).entries) {
        if (e.key != _F.qty && e.key != _F.avail) {
          cells.putIfAbsent(e.key, () => e.value);
        }
      }
    }
    // 오른쪽의 부호 없는 숫자 가운데 맨 위 것이 평가금이다. 손익은 부호나
    // %나 괄호가 붙어 있다.
    final labeled = cells.values.toSet();
    OcrWord? right;
    for (final l in inRange) {
      for (final w in l) {
        if (right != null) break;
        if (w.left > 0.45 * width &&
            _isNum(w.text) &&
            !_signed.hasMatch(w.text) &&
            !labeled.contains(w.text) &&
            _parse(w.text) != null) {
          right = w;
        }
      }
    }
    // 「현재가」와 그 값이 줄이 어긋나 짝을 못 지었으면 가장 가까운 숫자
    if (!cells.containsKey(_F.cur)) {
      final label = inRange
          .expand((l) => l)
          .where((w) => w.text.contains('현재가'))
          .firstOrNull;
      if (label != null) {
        OcrWord? best;
        for (final w in inRange.expand((l) => l)) {
          if (!_isNum(w.text) ||
              _signed.hasMatch(w.text) ||
              w.left <= 0.45 * width ||
              w.cy < label.cy - 0.5 * h ||
              (w.cy - label.cy).abs() > 3 * h) {
            continue;
          }
          if (best == null ||
              (w.cy - label.cy).abs() < (best.cy - label.cy).abs()) {
            best = w;
          }
        }
        if (best != null) cells[_F.cur] = best.text;
      }
    }
    final named = _composeName(r.name, 0.6 * h);
    var foreign = named.foreign;
    if (right != null && !cells.containsKey(_F.value)) {
      if (right.text.contains(r'$')) foreign = true;
      final cur = _parse(cells[_F.cur]);
      final qty = _parse(r.anchor.text, isQty: true);
      // 현재가가 따로 적힌 화면에서는 오른쪽 숫자가 평가금이 아닐 수 있다
      // (토스 「자세히 보기」는 그 자리에 1주 평균 금액이 온다). 수량 ×
      // 현재가와 맞을 때만 평가금으로 쓴다.
      if (cur == null ||
          (qty != null &&
              valueMatches(qty.v * cur.v, _parse(right.text)!.v))) {
        cells[_F.value] = right.text;
      }
    }
    final built = _build(named.name, cells, foreign: foreign);
    if (built == null || named.name.isEmpty) {
      unreadable.add(named.name);
    } else {
      holdings.add(built);
    }
  }
  if (holdings.isEmpty && unreadable.every((n) => n.isEmpty)) return null;
  return HoldingsShot(holdings: holdings, unreadable: unreadable);
}

/// 증권사 앱의 잔고 화면 캡처를 읽는다.
///
/// 증권사마다 화면이 다르지만 모양은 셋 중 하나다.
///
/// 1. **표** — 「종목명」 머리글이 있고 그 옆에 숫자 칸 머리글이 한두 줄
///    (NH·키움·미래에셋·한국투자·삼성·신한·KB·대신·하나·메리츠·유안타)
/// 2. **카드** — 종목 이름 밑에 「이름표 값」이 여러 줄 (KB 카드 보기 등)
/// 3. **목록** — 「이름 / 13주 / 평가금」 (토스·카카오페이·미니스탁)
///
/// 증권사 이름으로 가르지 않는다. 화면에 **무엇이 적혀 있는지**로 가른다 —
/// 앱이 개편돼 칸 순서가 바뀌어도, 처음 보는 증권사여도 머리글 낱말이
/// 같으면 읽는다.
HoldingsShot parseHoldings(List<OcrWord> words) {
  final table = _parseTable(words);
  if (table != null &&
      (table.holdings.isNotEmpty || table.unreadable.isNotEmpty)) {
    return table;
  }
  final found = _parseCards(words) ?? _parseList(words);
  if (found != null) return found;
  return table ?? const HoldingsShot(notHoldingsScreen: true);
}
