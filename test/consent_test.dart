import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 유럽 광고 동의(UMP)가 **뚫리지 않는지** 소스에서 지킨다.
///
/// 왜 소스를 읽는 시험인가
///   동의를 안 받고 광고를 요청해도 **앱은 멀쩡하게 돌아간다.** 광고도
///   그냥 나온다. 잘못된 줄은 한국에서 앱을 켜 보는 것으로는 알 수 없고,
///   유럽 사용자에게 광고가 제한되거나 AdMob에서 경고가 와야 안다.
///
///   그래서 「광고를 붙이는 자리를 하나 더 만들면서 동의 확인을 빠뜨린다」가
///   실제로 일어날 수 있는 유일한 경로다. 그 자리를 여기서 막는다.
void main() {
  /// 광고를 **실제로 요청하는** 호출들. 자리를 새로 만들면 여기서 걸린다.
  const requests = [
    'AdService.createBanner(',
    'AppOpenAd.load(',
    'InterstitialAd.load(',
    'FullScreenAds.preload()',
    'MobileAds.instance.initialize()',
  ];

  /// 광고 단위를 정의만 해 두는 곳 — 요청하지 않으므로 동의와 무관하다.
  const factories = {
    'lib\\services\\ad_service.dart',
    'lib/services/ad_service.dart',
    'lib\\services\\full_screen_ads.dart',
    'lib/services/full_screen_ads.dart',
  };

  test('광고를 요청하는 곳은 모두 동의를 먼저 확인한다', () {
    final offenders = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (factories.contains(f.path)) continue;

      final s = f.readAsStringSync();
      final asks = requests.any(s.contains);
      if (!asks) continue;

      if (!s.contains('ConsentService')) offenders.add(f.path);
    }

    expect(offenders, isEmpty,
        reason: '이 파일들이 동의를 확인하지 않고 광고를 요청한다.\n'
            '  `await ConsentService.resolved` 뒤에 `canShowAds`를 보고 나서 요청할 것');
  });

  test('동의를 못 받았을 때의 기본값은 「광고 없음」이다', () {
    // 기본이 참이면, 동의를 물어보기 **전에** 광고가 한 번 나간다.
    // 망이 끊겨 물어보지 못한 경우도 마찬가지다.
    final s = File('lib/services/consent_service.dart').readAsStringSync();
    expect(s.contains('static bool _canShowAds = false;'), isTrue,
        reason: '기본값이 참이면 동의 전에 광고가 나간다');
  });

  test('지역을 앱이 직접 가르지 않는다', () {
    // 나라 목록을 앱에 적어 두면 **규정이 바뀔 때마다 앱을 새로 내야 한다.**
    // 어느 지역에 동의가 필요한지는 Google SDK가 판단한다.
    // 막으려는 것은 **앱이 기기 위치를 보고 스스로 판정하는 것**이다.
    // 주석에서는 대상 지역을 설명해야 하고, 시험용 플래그 이름
    // (`UMP_DEBUG_EEA`)과 SDK의 `DebugGeography.debugGeographyEea`는
    // 「유럽인 척하라」고 SDK에 **맡기는** 것이라 반대 방향이다.
    final code = File('lib/services/consent_service.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join(' ');
    for (final bad in const [
      'countryCode',
      'Locale(',
      'PlatformDispatcher',
      'timeZoneName',
      'SimCountryIso',
    ]) {
      expect(code.contains(bad), isFalse,
          reason: '동의가 필요한 지역을 앱이 직접 가르려 한다 ($bad)');
    }
  });

  test('「유럽인 척하기」가 스토어 빌드에 새어 나가지 않는다', () {
    // 확인하려고 켜 둔 채 출시하면 **한국 사용자에게도 동의 창이 뜨고**,
    // 매번 동의 기록을 지우므로 켤 때마다 다시 뜬다.
    final s = File('lib/services/consent_service.dart').readAsStringSync();
    expect(
        s.contains(
            "static const bool _debugEea = bool.fromEnvironment('UMP_DEBUG_EEA');"),
        isTrue,
        reason: '시험용 플래그가 컴파일 시점 값이 아니다 — 켠 채로 나갈 수 있다');
    for (final bad in const ['_debugEea = true', '_debugEea=true']) {
      expect(s.contains(bad), isFalse, reason: '시험용 플래그가 못으로 박혀 있다');
    }
  });

  test('유럽 사용자가 동의를 나중에 바꿀 수 있다', () {
    // 한 번 정한 동의를 되돌릴 통로가 없으면 그것만으로 정책 위반이다.
    final more = File('lib/screens/more_screen.dart').readAsStringSync();
    expect(more.contains('showPrivacyOptions'), isTrue,
        reason: '더보기에 광고 동의를 다시 고를 줄이 없다');
    expect(more.contains('isPrivacyOptionsRequired'), isTrue,
        reason: '그 줄을 **필요한 사용자에게만** 보여야 한다');
  });

  test('방침에 동의 절차가 적혀 있다', () {
    final policy = File('docs/privacy.html').readAsStringSync();
    expect(policy.contains('동의'), isTrue,
        reason: '유럽에서 동의를 받는다는 사실이 방침에 없다');
  });

  test('시험용 광고는 컴파일할 때만 켤 수 있다', () {
    // 예전에는 손으로 바꾸는 `= false` 상수였다. 그 자리는 양쪽으로 위험하다
    // — 켠 채로 내보내면 수익이 0이 되고, 끈 채로 시험하면 **실광고를 직접
    // 눌러** 무효 트래픽으로 계정이 정지될 수 있다.
    final s = File('lib/services/ad_service.dart').readAsStringSync();
    expect(
        s.contains(
            "static const bool _useTestAds = bool.fromEnvironment('USE_TEST_ADS');"),
        isTrue,
        reason: '시험용 광고 스위치가 컴파일 시점 값이 아니다');
    for (final bad in const ['_useTestAds = true', '_useTestAds=true']) {
      expect(s.contains(bad), isFalse, reason: '시험용 광고가 못으로 박혀 있다');
    }
  });
}
