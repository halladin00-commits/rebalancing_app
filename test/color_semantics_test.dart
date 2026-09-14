import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/main.dart';

/// 색 하나가 뜻을 여러 개 지지 않게 막는다.
///
/// `#B85127`이 한때 **다섯 가지**를 동시에 뜻했다 — 손실 · 편차 초과 ·
/// 매도 · 삭제 · 오류. 그런데 이 색은 사용자가 바꿀 수 있다. 손익 색을
/// 「+빨강 / −파랑」으로 고르면 같은 값이 **이익**이 되고, 그 순간 편차와
/// 삭제와 오류가 전부 「이익 색」으로 칠해졌다.
///
/// 눈으로는 안 보인다. 기본 설정에서는 멀쩡해 보이고, **설정을 바꾼 사람
/// 화면에서만** 어긋난다. 그래서 시험이 대신 본다.
void main() {
  /// 주석을 뺀 코드 줄만. 주석에서는 「쓰지 말 것」이라고 설명한다.
  String codeOf(String path) => LineSplitter.split(File(path).readAsStringSync())
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//');
      })
      .join('\n');

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('손익 색은 손익 말고 아무 데도 안 쓴다', () {
    // `context.danger`는 손익 하락색(기본 스킴)과 같은 값이다.
    // 화면에서 이 이름을 직접 부르면 그 자리는 손익이 아닌데 손익색이 된다.
    final offenders = <String>[];
    for (final f in dartFiles()) {
      if (f.uri.pathSegments.last == 'main.dart') continue; // 정의한 곳
      if (codeOf(f.path).contains('context.danger')) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: '손익색을 다른 뜻에 쓰고 있다 — 편차는 warningText, '
            '삭제·오류는 destructive, 매수·매도는 오름·내림색');
  });

  test('편차는 어디서나 같은 색이다', () {
    // 한때 막대는 앰버(#9C4A16), 숫자는 주황빨강(#B85127)이었다.
    // 같은 화면에 나란히 있는데 색이 달랐다.
    for (final path in const [
      'lib/widgets/weight_bar.dart',
      'lib/screens/portfolio_rebalance_screen.dart',
      'lib/screens/rebalance_tab_screen.dart',
      'lib/screens/rebalance_proposal_screen.dart',
    ]) {
      expect(codeOf(path).contains('warningText'), isTrue,
          reason: '$path 가 편차를 앰버로 안 칠한다');
    }
  });

  test('매수·매도는 사용자가 고른 오름·내림색을 따른다', () {
    // 국내 HTS에서 매수 호가는 빨강, 상승도 빨강이다 — 한 관습이다.
    // 예전에는 기본 스킴에서만 우연히 같았고, 설정을 바꾸면 손익만 뒤집혔다.
    for (final path in const [
      'lib/screens/transaction_history_screen.dart',
      'lib/screens/rebalance_proposal_screen.dart',
      'lib/screens/transaction_form_screen.dart',
      'lib/screens/item_detail_screen.dart',
    ]) {
      final code = codeOf(path);
      expect(code.contains('positiveColor') || code.contains('negativeColor'),
          isTrue,
          reason: '$path 의 매수·매도가 오름·내림색을 안 따른다');
    }
  });

  testWidgets('삭제색과 손익 하락색이 눈에 띄게 다르다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    double lum(Color c) =>
        0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

    final a = lum(PnlColorNotifier.negativeOf(PnlColorScheme.greenRed));
    final b = lum(ctx.destructive);
    final contrast = a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);

    // 나란히 놓여도 다른 색으로 읽혀야 한다. **명도로** 갈라 두면 색을 잘
    // 구분 못 하는 사람에게도 통한다.
    expect(contrast, greaterThan(1.4),
        reason: '삭제색이 손익 하락색과 너무 비슷하다 '
            '(${contrast.toStringAsFixed(2)}:1)');
  });

  test('설정 이름이 하는 일과 맞는다', () {
    // 이 설정은 손익뿐 아니라 매수·매도 배지까지 바꾼다.
    // 「손익 색상」이라고 적어 두면 매매 배지가 바뀔 때 놀란다.
    final more = codeOf('lib/screens/more_screen.dart');
    expect(more.contains('손익 색상'), isFalse);
    expect(more.contains('오름·내림 색상'), isTrue);
  });
}
