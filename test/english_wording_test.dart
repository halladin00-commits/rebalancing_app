import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/main.dart';

/// 영어 사용자에게 먼저 보이던 흠.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ko = lookupAppLocalizations(const Locale('ko'));

  group('수량 + 단위', () {
    test('영어는 띄어 쓰고 단수·복수를 가린다 — 예전엔 「4shares」', () {
      expect(en.sharesCount(4, '4'), '4 shares');
      expect(en.sharesCount(1, '1'), '1 share');
      expect(en.sharesCount(1.5, '1.5'), '1.5 shares');
    });

    test('한국어는 그대로 붙여 쓴다', () {
      expect(ko.sharesCount(4, '4'), '4주');
      expect(ko.sharesCount(1, '1'), '1주');
    });
  });

  test('캡처 장수의 복수형 — 예전엔 「1 screenshots」', () {
    expect(en.holdingsStep2(1), '2 / 2 · 1 screenshot');
    expect(en.holdingsStep2(3), '2 / 2 · 3 screenshots');
    expect(ko.holdingsStep2(1), '2 / 2 · 캡처 1장');
  });

  test('앱 안의 이름과 맞춘 낱말', () {
    expect(en.evaluationAmount, 'Market value');
    expect(en.settlementNotifHeader, 'Returns reminders');
  });

  test('합계 표시 통화의 기본값 — 한국어 기기만 원화', () {
    expect(MainCurrencyNotifier.defaultFor('ko'), 'KRW');
    expect(MainCurrencyNotifier.defaultFor('en'), 'USD');
    expect(MainCurrencyNotifier.defaultFor('ja'), 'USD');
  });
}
