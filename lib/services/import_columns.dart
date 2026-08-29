/// 파일의 열 이름을 보고 어떤 칸이 무엇인지 찾아낸다 (시안 v17b).
///
/// 시안의 약속: *"증권사에서 받은 파일을 그대로 올려도 됩니다 — 거래일 · 종목 ·
/// 구분 · 수량 · 단가 같은 열 이름을 자동으로 찾습니다."*
///
/// 증권사마다 열 이름이 다르므로 아는 이름을 모아 두고 맞춰 본다.
/// 못 찾으면 표준 양식의 순서(날짜·종목명·티커·시장·유형·수량·단가)로 본다.
library;

enum ImportField { date, name, ticker, market, type, qty, price, fee }

/// 열 이름 후보. 소문자·공백 제거 후 비교한다.
const Map<ImportField, List<String>> _aliases = {
  ImportField.date: [
    '날짜', '거래일', '거래일자', '일자', '체결일', '체결일자', '매매일자',
    'date', 'tradedate', 'transactiondate', 'settlementdate', 'tradingday',
  ],
  ImportField.name: [
    '종목명', '종목', '상품명', '종목이름', '주식명',
    'name', 'itemname', 'stockname', 'security', 'description', 'product',
  ],
  ImportField.ticker: [
    '티커', '종목코드', '코드', '단축코드', '심볼',
    'ticker', 'symbol', 'code', 'stockcode', 'isin',
  ],
  ImportField.market: [
    '시장', '거래소', '국가',
    'market', 'exchange', 'country',
  ],
  ImportField.type: [
    '유형', '구분', '매매구분', '거래구분', '매도매수', '매수매도', '주문구분',
    'type', 'side', 'action', 'buysell', 'transactiontype', 'orderside',
  ],
  ImportField.qty: [
    '수량', '주수', '체결수량', '거래수량', '주식수',
    'qty', 'quantity', 'shares', 'volume', 'amount',
  ],
  ImportField.price: [
    '단가', '가격', '체결단가', '체결가격', '거래단가', '주당가격',
    'price', 'unitprice', 'tradeprice', 'executionprice',
  ],
  ImportField.fee: [
    '수수료', '거래수수료',
    'fee', 'commission',
  ],
};

/// 표준 양식의 열 순서. 열 이름을 못 알아봤을 때 쓴다.
const List<ImportField> templateOrder = [
  ImportField.date,
  ImportField.name,
  ImportField.ticker,
  ImportField.market,
  ImportField.type,
  ImportField.qty,
  ImportField.price,
];

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s_\-()\[\]./]'), '');

/// 어느 칸이 무엇인지.
class ColumnMap {
  final Map<ImportField, int> _index;

  /// 데이터가 시작하는 줄 번호 (0부터).
  final int dataStartRow;

  /// 열 이름을 알아봐서 만든 것인지. false면 순서로 짐작한 것이다.
  final bool fromHeader;

  const ColumnMap(this._index, this.dataStartRow, this.fromHeader);

  int? operator [](ImportField f) => _index[f];
  bool has(ImportField f) => _index.containsKey(f);

  /// 최소한 날짜·수량이 있어야 거래로 읽을 수 있다.
  bool get usable => has(ImportField.date) && has(ImportField.qty);

  /// [row]에서 [f] 칸을 꺼낸다. 없으면 빈 문자열.
  String get(List<String> row, ImportField f) {
    final i = _index[f];
    if (i == null || i < 0 || i >= row.length) return '';
    return row[i];
  }

  /// [rows]의 앞부분을 훑어 열 이름 줄을 찾는다.
  ///
  /// 표준 양식은 첫 줄이 헤더고 둘째 줄이 예시다. 증권사 파일은 안내 문구가
  /// 몇 줄 앞에 붙기도 해서 위에서부터 몇 줄을 살펴본다.
  static ColumnMap detect(List<List<String>> rows) {
    final limit = rows.length < 10 ? rows.length : 10;
    for (var r = 0; r < limit; r++) {
      final found = <ImportField, int>{};
      for (var c = 0; c < rows[r].length; c++) {
        final cell = _norm(rows[r][c]);
        if (cell.isEmpty) continue;
        for (final e in _aliases.entries) {
          if (found.containsKey(e.key)) continue;
          if (e.value.any((a) => cell == a || cell.contains(a))) {
            found[e.key] = c;
            break;
          }
        }
      }
      // 세 칸 이상 알아봤고 날짜·수량이 있으면 이 줄이 헤더다
      if (found.length >= 3 &&
          found.containsKey(ImportField.date) &&
          found.containsKey(ImportField.qty)) {
        return ColumnMap(found, r + 1, true);
      }
    }

    // 못 알아봤다 — 표준 양식 순서로 본다.
    final byOrder = <ImportField, int>{
      for (var i = 0; i < templateOrder.length; i++) templateOrder[i]: i
    };
    return ColumnMap(byOrder, 0, false);
  }
}
