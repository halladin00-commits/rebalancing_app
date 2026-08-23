/// 금액 표기를 한곳에 모은다.
///
/// 화면마다 `_fmt` / `_fmtPrice`를 복사해 쓰고 있었다(8곳). 그러다 보니
/// 마이너스 기호가 `-`(ASCII)와 `−`(U+2212)로 갈렸고, 달러 금액에는
/// 천 단위 구분이 빠진 곳이 있었다(`$7230.00`).
library;

/// 천 단위 구분자를 넣는다. 정수부에만 넣는다.
String _group(String intPart) => intPart.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// 마이너스는 하이픈이 아니라 **빼기 기호**(U+2212)를 쓴다.
/// 숫자 옆에서 하이픈은 너무 짧아 눈에 안 걸린다.
const String minusSign = '−';

/// 기준통화 금액. 원화는 정수, 달러는 소수 둘째 자리.
///
/// `₩1,457,695,000` · `−$1,240.50`
String fmtMoney(double n, String currency) {
  final sign = n < 0 ? minusSign : '';
  final abs = n.abs();
  if (currency == 'USD') {
    final s = abs.toStringAsFixed(2);
    final dot = s.indexOf('.');
    return '$sign\$${_group(s.substring(0, dot))}${s.substring(dot)}';
  }
  return '$sign₩${_group(abs.round().toString())}';
}

/// 종목의 거래통화 기준 단가·금액. 시장으로 통화를 정한다.
///
/// `₩134,000` · `$215.63`
String fmtPrice(double n, String market) {
  final sign = n < 0 ? minusSign : '';
  final abs = n.abs();
  if (market == 'US') {
    final s = abs.toStringAsFixed(2);
    final dot = s.indexOf('.');
    return '$sign\$${_group(s.substring(0, dot))}${s.substring(dot)}';
  }
  return '$sign₩${_group(abs.round().toString())}';
}

/// 부호를 항상 붙인다 (손익 표기). `+₩12,000` · `−$3.40`
String fmtSigned(double n, String currency) =>
    '${n >= 0 ? '+' : ''}${fmtMoney(n, currency)}';
