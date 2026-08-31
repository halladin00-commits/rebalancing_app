import 'package:flutter_test/flutter_test.dart';

/// 수수료율 표기.
///
/// 허용 편차용 포맷터(`toStringAsFixed(1)`)를 그대로 쓰다가 `0.015`가
/// `0.0`이 됐다. 화면이 **「수수료 0.0%는 빼고 계산했습니다」**라고
/// 말하게 된다 — 반영했다면서 0을 적으면 안 한 것과 구분이 안 된다.
String rate(double v) =>
    v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

void main() {
  test('국내 위탁 수수료 0.015%가 그대로 나온다', () {
    expect(rate(0.015), '0.015');
  });

  test('한 자리에서 자르면 0이 되던 값들', () {
    expect(rate(0.005), '0.005');
    expect(rate(0.01), '0.01');
  });

  test('끝의 0은 턴다', () {
    expect(rate(0.5), '0.5');
    expect(rate(0.100), '0.1');
    expect(rate(3.0), '3');
  });

  test('0은 0이다', () {
    expect(rate(0), '0');
  });
}
