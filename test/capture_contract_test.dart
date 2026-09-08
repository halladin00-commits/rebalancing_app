import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 캡처 그림이 **조용히** 망가지는 두 가지를 소스에서 잡는다.
///
/// 왜 소스를 읽는 시험인가
///   이 두 가지는 예외도 로그도 안 남는다. 앱을 켜서 그림을 열어 봐야만
///   안다. 그래서 화면 하나를 고치고 「나머지도 같은 구성이니 됐겠지」로
///   넘어가게 되고, 실제로 넘어간 쪽이 매번 틀렸다.
///
///   캡처 화면이 일곱 개다. 새 화면이 하나 붙을 때 여기서 걸리게 해 둔다.
///
///   1. 뿌리가 배경을 안 칠하면 투명하게 찍히고, JPEG로 저장되며 **검은 그림**
///   2. 스크롤 위젯을 쓰면 화면 밖 내용이 **잘려서** 안 들어간다
void main() {
  /// 캡처용 그림을 만드는 함수들. 새 화면을 만들면 여기에 더한다.
  const builders = <String, String>{
    'lib/screens/portfolio_detail_screen.dart': '_buildAssetCapture',
    'lib/screens/portfolio_list_screen.dart': '_buildMainCapture',
    'lib/screens/rebalance_tab_screen.dart': '_buildCapture',
    'lib/screens/rebalance_proposal_screen.dart': '_buildCapture',
    'lib/screens/portfolio_rebalance_screen.dart': '_buildCapture',
    'lib/screens/portfolio_settlement_screen.dart': '_buildCapture',
    'lib/screens/all_settlement_screen.dart': '_buildCapture',
  };

  /// 함수 본문을 중괄호 짝으로 잘라 낸다.
  String bodyOf(String source, String name) {
    final start = source.indexOf('Widget $name(');
    expect(start, isNot(-1), reason: '$name 을 못 찾았다 — 이름이 바뀌었나');
    var i = source.indexOf('{', start);
    var depth = 0;
    for (var k = i; k < source.length; k++) {
      if (source[k] == '{') depth++;
      if (source[k] == '}') {
        depth--;
        if (depth == 0) return source.substring(i, k);
      }
    }
    fail('$name 의 본문 끝을 못 찾았다');
  }

  builders.forEach((path, name) {
    final label = path.split('/').last;

    test('$label — 캡처가 배경을 칠한다', () {
      final body = bodyOf(File(path).readAsStringSync(), name);
      // 뿌리가 스스로 칠하거나, 칠하는 틀(CaptureFrame·SettlementCaptureCard)을 쓴다.
      final paints = body.contains('color: context.scaffoldBg') ||
          body.contains('CaptureFrame(') ||
          body.contains('SettlementCaptureCard(');
      expect(paints, isTrue,
          reason: '$name 이 배경을 안 칠한다 — 저장하면 검은 그림이 된다');
    });

    test('$label — 캡처에 스크롤 위젯을 쓰지 않는다', () {
      final body = bodyOf(File(path).readAsStringSync(), name);
      for (final w in const [
        'ListView',
        'SingleChildScrollView',
        'CustomScrollView',
        'GridView',
        'PageView',
      ]) {
        expect(body.contains('$w('), isFalse,
            reason: '$name 이 $w 을 쓴다 — 화면 밖 내용이 그림에서 잘린다');
      }
    });
  });

  test('캡처에 높이를 못으로 박지 않는다', () {
    // 종목 세 개짜리 포트에서 첫 줄만 나오고 끝난 적이 있다.
    // 원인은 `targetSize: Size(380, 120 + 종목수 * 90)` 이라는 **어림짐작**이었다.
    // 실제 줄 높이가 어림보다 크면 그만큼 잘리는데, 예외가 안 난다.
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      expect(s.contains('targetSize:'), isFalse,
          reason: '${f.path} 가 캡처 높이를 미리 정한다 — 내용이 길면 잘린다');
    }
  });
  test('캡처 실패를 말없이 삼키지 않는다', () {
    // 사용자가 [이미지 저장]을 눌렀고 시트는 닫혔다. 그런데 아무 일도 안
    // 일어나고 아무 말도 없으면, 저장된 줄 알고 앨범을 찾게 된다.
    // 실제로 조정 제안 10건에서 그랬다.
    for (final path in builders.keys) {
      final source = File(path).readAsStringSync();
      expect(source.contains('if (bytes == null) return;'), isFalse,
          reason: '$path 가 캡처 실패를 말없이 삼킨다');
    }
  });

  test('캡처가 시간을 어림해서 기다리지 않는다', () {
    // `Future.delayed(80ms)` 는 프레임이 그 안에 돈다는 **보장이 아니다.**
    // 기기가 느리거나 목록이 길면 렌더 객체가 아직 없어 null이 나왔다.
    final source = File('lib/utils/widget_capture.dart').readAsStringSync();
    // 주석에서는 「쓰면 안 된다」고 설명하므로 코드 줄만 본다.
    final code = LineSplitter.split(source)
        .where((l) => !l.trimLeft().startsWith('//'))
        .join(' ');
    expect(code.contains('Future<void>.delayed'), isFalse,
        reason: '시간으로 기다리면 느린 기기에서 캡처가 빈다');
    expect(code.contains('endOfFrame'), isTrue,
        reason: '프레임이 실제로 끝나는 것을 기다려야 한다');
  });
}
