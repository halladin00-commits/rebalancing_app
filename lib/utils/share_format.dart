/// 보유 수량 표기.
///
/// 온주 거래에서는 `12000`처럼 정수로, 소수점 거래에서는 `3.4521`처럼
/// 필요한 자리까지만 보여준다. 브로커 앱에 그대로 옮겨 적을 수 있도록
/// 계산에 쓴 값과 화면에 찍히는 값이 같아야 하므로,
/// 반올림 자릿수([sharesDecimals])와 표기 자릿수를 하나로 묶어 둔다.
library;

/// 소수점 거래에서 쓰는 수량 자릿수.
///
/// 국내외 증권사 소수점 매매가 대체로 소수점 6자리까지 받지만,
/// 4자리면 남는 금액이 `주가 × 0.0001` 수준이라 사실상 0이고
/// 화면에서 읽기도 훨씬 낫다.
const int sharesDecimals = 4;

/// 예산을 넘지 않도록 [sharesDecimals] 자리에서 **버림**한다.
/// 반올림하면 배분 합계가 총액을 넘어 잔여 현금이 음수가 될 수 있다.
double floorShares(double n) {
  const f = 10000.0; // 10^sharesDecimals
  return (n * f).floorToDouble() / f;
}

/// 목표에 가장 가까운 수량 — [sharesDecimals] 자리에서 반올림한다.
/// 편차는 최소가 되지만 합계가 예산을 아주 조금 넘을 수 있다.
double roundShares(double n) {
  const f = 10000.0;
  return (n * f).roundToDouble() / f;
}

/// 자잘한 부동소수 오차를 0으로 본다. 이 값보다 작은 차이는 거래가 아니다.
const double sharesEpsilon = 0.00005;

/// 수량을 화면에 찍을 문자열로. 정수면 소수점을 붙이지 않는다.
String formatShares(double n) {
  if ((n - n.roundToDouble()).abs() < sharesEpsilon) {
    return n.round().toString();
  }
  var s = n.toStringAsFixed(sharesDecimals);
  // 끝자리 0과 남은 소수점을 털어낸다: 3.4500 → 3.45
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
