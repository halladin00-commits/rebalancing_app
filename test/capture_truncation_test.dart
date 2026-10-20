import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **목록을 자르면 잘랐다고 말해야 한다.**
///
/// 캡처는 긴 목록을 잘라 담는다 — 그림이 한없이 길어지면 안 되기 때문이다.
/// 그런데 잘랐다는 말이 없으면 **그림이 전부인 줄 안다.**
///
/// 실제 자료에서 바로 터졌다.
///   · 10종목짜리 ISA 결산 → 여덟 줄만 나오고 2종목이 사라짐
///   · 거래 20건짜리 종목 → 다섯 줄만 나오고 15건이 사라짐
///
/// 둘 다 예외도 로그도 안 남는다. 그림만 보면 멀쩡해 보인다.
void main() {
  /// `.take(n)`으로 자르는 자리마다 잘림을 알리는 장치가 같이 있어야 한다.
  test('캡처가 목록을 자르면 「잘림」을 함께 낸다', () {
    final offenders = <String>[];

    for (final path in [
      'lib/screens/all_settlement_screen.dart',
      'lib/screens/portfolio_settlement_screen.dart',
      'lib/screens/item_detail_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      final cuts = RegExp(r'\.take\(').allMatches(src).length;
      if (cuts == 0) continue;
      final tells = 'hiddenRows'.allMatches(src).length +
          'CaptureTruncated'.allMatches(src).length;
      if (tells == 0) {
        offenders.add('${path.split('/').last}: 자르기 $cuts곳, 알림 없음');
      }
    }

    expect(offenders, isEmpty,
        reason: '목록을 말없이 자르고 있다 — 그림을 보는 사람은 그게 전부인 줄 안다: '
            '${offenders.join(' / ')}');
  });

  _excludedBannerReachesCapture();

  /// **차트 기간 글씨는 화면과 캡처가 같은 함수를 써야 한다.**
  ///
  /// 두 결산 화면이 **서로 다른 규칙**을 쓴다 — 포트 결산은 오늘까지로
  /// 끊고(「N일 경과」를 같이 적으므로), 전체 결산은 기간 끝까지를 쓴다.
  /// 캡처만 한쪽 규칙으로 바꿨다가 화면 10.31 / 그림 10.20이 됐다.
  ///
  /// 각 화면 안에서 **한 함수**를 둘이 같이 쓰면 갈라질 수가 없다.
  test('차트 기간 글씨를 화면과 캡처가 같은 함수로 낸다', () {
    for (final f in [
      'lib/screens/all_settlement_screen.dart',
      'lib/screens/portfolio_settlement_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      final calls = RegExp(r'_chartRangeLabel\(').allMatches(src).length;
      // 정의 1 + 화면 1 + 캡처 1 = 3
      expect(calls, greaterThanOrEqualTo(3),
          reason: '${f.split('/').last}: 화면과 캡처가 같은 함수를 안 쓴다');
      // 날짜를 직접 만드는 곳이 함수 밖에 또 있으면 갈라질 수 있다
      final direct = RegExp(r'_fullRangeLabel\(').allMatches(src).length;
      expect(direct, lessThanOrEqualTo(2),
          reason: '${f.split('/').last}: _fullRangeLabel 을 여러 곳에서 직접 부른다');
    }
  });

  test('「잘림」 문구가 두 언어에 다 있다', () {
    for (final f in ['lib/l10n/app_ko.arb', 'lib/l10n/app_en.arb']) {
      expect(File(f).readAsStringSync(), contains('captureTruncated'),
          reason: '$f 에 잘림 문구가 없다 — 한쪽 언어에서만 말해 준다');
    }
  });
}

/// **화면이 「이 숫자는 일부만 센 값」이라고 말하면, 그림도 말해야 한다.**
///
/// 결산 화면에는 「N종목 결산 제외 · ₩X」 띠가 있다. 그 띠의 주석이
/// 존재 이유를 이렇게 적어 뒀다 —
///
///   결산 숫자가 일부 종목을 빼고 계산된 값인데 그 사실이 화면 어디에도
///   없으면, 사용자는 틀린 숫자를 맞는 줄 알고 본다.
///
/// 그런데 **그림에만 그 띠가 없었다.** 그림은 남에게 보내는 것이라 더
/// 위험하다 — 받은 사람은 물어볼 화면도 없다.
void _excludedBannerReachesCapture() {
  test('결산 캡처가 「결산 제외」 띠를 싣는다', () {
    final card =
        File('lib/widgets/settlement_capture_card.dart').readAsStringSync();
    expect(card, contains('ExcludedBanner('),
        reason: '캡처 판이 결산 제외 띠를 안 그린다 — 일부만 센 값인 줄 모르고 본다');

    for (final f in [
      'lib/screens/all_settlement_screen.dart',
      'lib/screens/portfolio_settlement_screen.dart',
    ]) {
      expect(File(f).readAsStringSync(), contains('excludedItems:'),
          reason: '${f.split('/').last} 가 제외 종목을 캡처로 안 넘긴다');
    }
  });
}
