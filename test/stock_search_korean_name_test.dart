import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rebalancing_app/services/stock_search_service.dart';

/// 미국 종목은 영문 이름뿐이라 「애플」로 찾을 수 없었다. 서버 목록이 일부
/// 종목에 한글 이름(`k`)을 붙여 준다 — 그걸로 찾는지 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kosearch');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => dir.path);
    // 받아 둔 목록이 있는 폰
    File('${dir.path}/stocks_cache.json').writeAsStringSync(json.encode([
      {'t': 'AAPL', 'n': 'Apple Inc.', 'm': 'US', 'k': '애플|애플 컴퓨터'},
      {'t': 'APLE', 'n': 'Apple Hospitality REIT Inc.', 'm': 'US'},
      {
        't': 'BRK-B',
        'n': 'Berkshire Hathaway Inc.',
        'm': 'US',
        'k': '버크셔 해서웨이'
      },
      {'t': '900100', 'n': '애플망고', 'm': 'KQ'},
      {'t': '900200', 'n': '파인애플', 'm': 'KQ'},
      {'t': 'XYZ', 'n': 'No Korean Name Corp', 'm': 'US', 'k': ''},
    ]));
    StockSearchService.resetForTest();
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<List<StockSearchResult>> search(String q) => http.runWithClient(
      () => StockSearchService.search(q),
      () => MockClient((_) async => http.Response('', 503)));

  test('「애플」로 AAPL을 찾는다 — 이름은 영문 그대로', () async {
    final found = await search('애플');
    final aapl = found.firstWhere((s) => s.ticker == 'AAPL');
    expect(aapl.name, 'Apple Inc.');
    expect(aapl.koName, '애플');
    // 딱 맞는 이름이 맨 위, 이름에 들어 있기만 한 것은 뒤
    expect(found.first.ticker, 'AAPL');
    expect(found.map((s) => s.ticker), containsAll(['900100', '900200']));
    expect(found.indexWhere((s) => s.ticker == '900100'),
        lessThan(found.indexWhere((s) => s.ticker == '900200')));
  });

  test('다른 이름·띄어쓰기 없이도 찾는다', () async {
    expect((await search('애플 컴퓨터')).first.ticker, 'AAPL');
    expect((await search('버크셔해서웨이')).first.ticker, 'BRK-B');
    expect((await search('버크셔')).first.ticker, 'BRK-B');
  });

  test('한글 이름이 없는 종목은 예전 그대로다', () async {
    final found = await search('Korean');
    expect(found.single.ticker, 'XYZ');
    expect(found.single.koName, isNull);
    expect(await search('없는이름'), isEmpty);
  });

  test('국내 종목 목록에는 미국 종목이 섞이지 않는다', () async {
    final kr = await http.runWithClient(() => StockSearchService.krStocks(),
        () => MockClient((_) async => http.Response('', 503)));
    expect(kr.map((s) => s.ticker).toSet(), {'900100', '900200'});
  });
}
