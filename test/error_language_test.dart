import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 서비스가 만든 **한국어 문장이 영어 화면으로 새지 않는지** 지킨다.
///
/// 무슨 일이 있었나
///   `ApiService`가 `'환율 조회 실패: ...'` 같은 한국어를 만들어 돌려줬고,
///   화면은 그걸 영어 스낵바 틀 안에 그대로 넣었다. 영어 사용자는 시세
///   갱신이 실패할 때마다 한국어를 봤다.
///
///   **오류가 날 때만 보이므로** 정상 경로만 훑어서는 절대 안 걸린다.
void main() {
  test('서비스는 화면에 보일 문구를 만들지 않는다', () {
    // 자세한 내용(`error`)은 개발자용으로 남기되, 화면은 `kind`를 보고
    // 제 말로 적는다.
    final api = File('lib/services/api_service.dart').readAsStringSync();
    expect(api.contains('enum ApiErrorKind'), isTrue,
        reason: '실패 종류가 없다 — 화면이 번역할 수가 없다');

    // 모든 실패에 종류가 붙어야 한다. 안 붙으면 전부 「알 수 없는 오류」다.
    final naked = RegExp(r"ApiResult\.error\((?:(?!ApiErrorKind)[^;])*\);")
        .allMatches(api)
        .map((m) => m.group(0)!)
        .where((m) => !m.contains('this.error'))
        .toList();
    expect(naked, isEmpty,
        reason: '종류 없이 돌려주는 실패가 있다:\n  ${naked.join('\n  ')}');
  });

  test('화면이 실패 종류를 제 말로 옮긴다', () {
    final s =
        File('lib/screens/portfolio_detail_screen.dart').readAsStringSync();
    expect(s.contains('_reasonText('), isTrue, reason: '번역하는 곳이 없다');
    // 서비스가 준 **문장을 그대로** 내보내면 안 된다. 번역을 한 번
    // 거쳐야 한다 — `_reasonText(...)` 없이 바로 넣으면 그게 옛 모습이다.
    expect(s.contains('updateFailed(errors.first'), isFalse,
        reason: '서비스 문구를 그대로 화면에 낸다');
    expect(s.contains('.error!'), isFalse,
        reason: '개발자용 자세한 내용을 화면으로 보낸다');
    // 네 종류를 다 덮어야 한다 — 빠지면 컴파일은 되고 말만 이상해진다.
    for (final k in const ['network', 'noData', 'badTicker', 'unknown']) {
      expect(s.contains('ApiErrorKind.$k'), isTrue, reason: '$k 를 안 옮긴다');
    }
  });
}
