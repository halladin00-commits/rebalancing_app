import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 목표 비중·허용 편차를 **찾아갈 수 있는지** 지킨다.
///
/// 무슨 일이 있었나
///   둘은 같은 화면(`TargetWeightsScreen`)에서 고친다. 그런데 그리로 가는
///   길이 **⋮ 메뉴뿐**이었다.
///
///   리밸런싱 포트 화면은 처음부터 끝까지 목표 비중 이야기다 —
///   「허용 ±3%p」가 적혀 있고, 종목마다 「현재 → 목표」가 있고, 머리에
///   「현재 → 목표」라고 써 있다. **그런데 아무것도 안 눌렸다.** 읽을 수만
///   있고 손댈 수는 없는 화면이었다.
///
///   더 근본적으로는, 종목을 다 담고 나와도 **목표를 정하라고 아무도
///   알려주지 않았다.** 리밸런싱 탭에 들어가야 비로소 버튼이 바뀌는데,
///   거기 갈 이유를 모르는 사람은 영영 그 화면을 못 만난다.
///
/// 이 길들은 **눈으로 보면 있는 것 같고 없어도 티가 안 난다.** 아는 사람은
/// 메뉴로 가고, 모르는 사람은 앱을 지운다. 그래서 시험으로 세어 둔다.
void main() {
  late String reb;
  late String detail;

  setUpAll(() {
    reb = File('lib/screens/portfolio_rebalance_screen.dart').readAsStringSync();
    detail =
        File('lib/screens/portfolio_detail_screen.dart').readAsStringSync();
  });

  test('허용 편차 칩을 누르면 고치러 갈 수 있다', () {
    // 허용 편차가 앱에서 보이는 유일한 자리다.
    final i = reb.indexOf('허용 ±');
    // 캡처용이 먼저 나오므로 화면용(뒤쪽)을 본다.
    final j = reb.indexOf('허용 ±', i + 1);
    expect(j, isNot(-1), reason: '화면용 허용 칩을 못 찾았다');

    // 칩 언저리에 누르는 장치와 화살표가 있어야 한다.
    final around = reb.substring(j - 700, j + 400);
    expect(around.contains('_openTargets'), isTrue,
        reason: '허용 칩이 안 눌린다 — 고치러 갈 길이 ⋮ 메뉴뿐이 된다');
    expect(around.contains('chevron_right'), isTrue,
        reason: '눌리는 표시가 없다 — 칩은 보통 안 눌리므로 아무도 안 눌러본다');
  });

  test('종목 목록 끝에 「바꾸러 가기」 줄이 있다', () {
    expect(reb.contains('_targetsRow('), isTrue,
        reason: '목표들을 다 훑고 난 자리에 바꾸러 갈 길이 없다');
    expect(reb.contains('목표 비중 · 허용 편차 바꾸기'), isTrue);
  });

  test('목표가 없으면 포트 화면이 먼저 알려준다', () {
    // 종목을 다 담고 나온 사람이 다음에 무엇을 해야 하는지 알 유일한 길.
    expect(detail.contains('_buildTargetsPrompt('), isTrue,
        reason: '목표를 정하라는 안내가 없다');
    expect(detail.contains('목표 비중을 정해 주세요'), isTrue);
  });

  test('목표를 정하고 나면 그 안내는 사라진다', () {
    // 할 일이 끝난 안내가 계속 남아 있으면 그때부터는 잔소리다.
    final i = detail.indexOf('Widget _buildTargetsPrompt(');
    final body = detail.substring(i, i + 700);
    expect(body.contains('weightSum'), isTrue,
        reason: '목표가 찼는지 안 본다 — 다 정한 뒤에도 계속 뜬다');
    expect(body.contains('SizedBox.shrink()'), isTrue,
        reason: '조건이 맞으면 사라져야 한다');
    // 종목이 하나면 비중을 나눌 일이 없다.
    expect(body.contains('items.length < 2'), isTrue,
        reason: '종목 하나짜리 포트에도 목표를 정하라고 한다');
  });

  test('캡처에는 누르는 표시를 넣지 않는다', () {
    // 그림에서는 누를 데가 없다. 화살표가 찍히면 눌러 보려다 만다.
    //
    // 예전에는 `_buildCapture`부터 `_captureDriftRow`까지를 잘라 봤다.
    // 캡처가 화면 행을 쓰게 되면서 `_captureDriftRow`가 없어지자 자르기가
    // 깨졌다 — **다음 함수 이름을 끝으로 삼으면 안 된다.** 중괄호로 센다.
    final start = reb.indexOf('Widget _buildCapture');
    expect(start, isNot(-1), reason: '_buildCapture 를 못 찾았다');
    final open = reb.indexOf(') {', start) + 2;
    var depth = 0;
    var end = -1;
    for (var k = open; k < reb.length; k++) {
      if (reb[k] == '{') depth++;
      if (reb[k] == '}') {
        depth--;
        if (depth == 0) {
          end = k;
          break;
        }
      }
    }
    expect(end, isNot(-1), reason: '_buildCapture 본문을 못 잘랐다');
    final body = reb.substring(open, end);

    expect(body.contains('chevron_right'), isFalse,
        reason: '캡처 그림에 누르는 화살표가 들어갔다');
    expect(body.contains('_openTargets'), isFalse);
  });
}
