import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/app_info.dart';

/// 앱에 보이는 판 번호가 실제 빌드와 같은지 확인한다.
///
/// `package_info_plus` 꾸러미를 더하지 않고 상수로 적어 두었다. 꾸러미
/// 하나가 하는 일이 문자열 하나뿐이면 값이 안 맞는다.
///
/// 대신 **손으로 적은 값은 반드시 어긋난다.** 판을 올리면서 `app_info.dart`를
/// 잊는다. 그러면 문의받을 때 사용자가 말한 판 번호가 틀린 값이 되어,
/// 없는 버그를 찾게 된다. 그 사고를 여기서 막는다.
void main() {
  test('앱 버전이 pubspec.yaml과 같다', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'),
        orElse: () => '');
    expect(line, isNotEmpty, reason: 'pubspec.yaml에 version: 이 없다');

    // `version: 1.0.0+13`
    final raw = line.split(':')[1].trim();
    final parts = raw.split('+');
    expect(parts.length, 2, reason: 'version 형식이 `1.0.0+13` 이 아니다');

    expect(appVersion, parts[0],
        reason: 'lib/app_info.dart의 appVersion을 pubspec에 맞춰 고쳐야 한다');
    expect(appBuild, parts[1],
        reason: 'lib/app_info.dart의 appBuild를 pubspec에 맞춰 고쳐야 한다');
    expect(appVersionLabel, '${parts[0]} (${parts[1]})');
  });

  test('더보기 탭에 라이선스 고지와 버전이 있다', () {
    // 플러터와 여러 꾸러미를 쓰므로 라이선스 고지 의무가 있다.
    // 앱 어디에도 없다가 이번에 넣었다.
    final more = File('lib/screens/more_screen.dart').readAsStringSync();
    expect(more.contains('showLicensePage'), isTrue,
        reason: '오픈소스 라이선스 고지가 없다');
    expect(more.contains('appVersionLabel'), isTrue,
        reason: '앱 버전이 안 보인다 — 문의받을 때 제일 먼저 묻는 값이다');
  });
}
