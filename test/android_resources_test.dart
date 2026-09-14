import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dart에서 이름으로 부르는 안드로이드 자원이 **APK에서 지워지지 않게** 지킨다.
///
/// 무슨 일이 있었나
///   릴리즈 빌드는 `shrinkResources`로 안 쓰는 자원을 버린다. 그런데 훑는
///   대상이 **자바 코드와 XML뿐이다.** Dart 문자열 `'@drawable/ic_stat_notify'`
///   는 안 보이므로, 그 아이콘은 아무도 안 쓰는 것으로 판정되어 통째로 빠졌다.
///
///   빠져도 **빌드는 성공한다.** 앱도 켜진다. `flutter analyze`도 조용하다.
///   `NotificationService.initialize`가 예외로 죽어서 **알림이 하나도
///   예약되지 않는데**, 화면 어디에도 그 사실이 안 나온다. 알림 날짜가
///   될 때까지, 또는 logcat을 볼 때까지 모른다.
///
///   디버그 빌드에서는 줄이기를 안 해서 멀쩡히 동작한다 — 에뮬레이터로
///   아무리 눌러 봐도 안 잡히는 종류다.
void main() {
  test('Dart가 부르는 안드로이드 자원이 keep.xml에 있다', () {
    final keepFile = File('android/app/src/main/res/raw/keep.xml');
    expect(keepFile.existsSync(), isTrue,
        reason: 'keep.xml 이 없다 — Dart로만 부르는 자원이 릴리즈에서 지워진다');
    final keep = keepFile.readAsStringSync();

    // Dart 안의 `@drawable/...` · `@mipmap/...` 를 모두 걷는다.
    final referenced = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in RegExp(r'@(drawable|mipmap)/([a-z0-9_]+)')
          .allMatches(f.readAsStringSync())) {
        referenced.add('@${m.group(1)}/${m.group(2)}');
      }
    }
    expect(referenced, isNotEmpty,
        reason: '자원 참조를 하나도 못 찾았다 — 검사가 헛돌고 있다');

    final missing = referenced.where((r) => !keep.contains(r)).toList()..sort();
    expect(missing, isEmpty,
        reason: '이 자원들이 keep.xml 에 없다. 릴리즈 APK에서 빠져 '
            '쓰는 순간 예외가 난다 (알림 아이콘이 실제로 그랬다)');
  });

  test('알림 아이콘 파일이 밀도별로 다 있다', () {
    // keep.xml 은 「지우지 마라」일 뿐, 없는 파일을 만들어 주지는 않는다.
    for (final d in const [
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
    ]) {
      final f = File('android/app/src/main/res/drawable-$d/ic_stat_notify.png');
      expect(f.existsSync(), isTrue, reason: 'drawable-$d 에 알림 아이콘이 없다');
    }
  });
}
