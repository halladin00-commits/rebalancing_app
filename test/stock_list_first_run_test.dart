import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rebalancing_app/services/stock_search_service.dart';

/// 앱에 넣어 둔 종목 목록은 출시한 날의 것이다. 처음 켠 폰이 그 목록으로
/// 종목을 찾으면 그 뒤 상장한 종목이 「없는 종목」이 된다 — 첫 실행에서만
/// 최신 목록을 잠깐 기다리고, 인터넷이 느리면 붙잡지 않는지 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  // 서버에만 있는 종목 — 넣어 둔 목록에는 없다
  const fresh = {'t': '999999', 'n': '어제상장한종목', 'm': 'KS'};
  final serverList = json.encode([
    fresh,
    for (var i = 0; i < 120; i++)
      {'t': '${800000 + i}', 'n': '채움$i', 'm': 'KQ'},
  ]);

  http.Client server({required Duration delay}) => MockClient((req) async {
        await Future<void>.delayed(delay);
        final utf8Headers = {'content-type': 'application/json; charset=utf-8'};
        if (req.url.path.endsWith('meta.json')) {
          return http.Response('{"updated_at":"2099-01-01"}', 200,
              headers: utf8Headers);
        }
        return http.Response(serverList, 200, headers: utf8Headers);
      });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('stocklist');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => dir.path);
    StockSearchService.resetForTest();
    StockSearchService.firstRunWait = const Duration(seconds: 5);
  });

  tearDown(() async {
    // 뒤에서 받던 것이 끝난 다음에 지운다
    await Future<void>.delayed(const Duration(milliseconds: 700));
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  bool has(List<StockSearchResult> l, String ticker) =>
      l.any((s) => s.ticker == ticker);

  test('첫 실행: 받고 있는 최신 목록을 기다렸다가 쓴다', () async {
    await http.runWithClient(() async {
      final kr = await StockSearchService.krStocks();
      expect(has(kr, '999999'), isTrue,
          reason: '넣어 둔 목록으로 먼저 답해 버렸다');
      final found = await StockSearchService.search('어제상장');
      expect(found.map((s) => s.ticker), contains('999999'));
    }, () => server(delay: const Duration(milliseconds: 150)));
  });

  test('첫 실행인데 인터넷이 느리다: 넣어 둔 목록으로 간다', () async {
    StockSearchService.firstRunWait = const Duration(milliseconds: 200);
    await http.runWithClient(() async {
      final sw = Stopwatch()..start();
      final kr = await StockSearchService.krStocks();
      expect(has(kr, '005930'), isTrue, reason: '넣어 둔 목록이 안 읽혔다');
      expect(has(kr, '999999'), isFalse);
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)),
          reason: '느린 서버를 끝까지 기다렸다');
    }, () => server(delay: const Duration(milliseconds: 500)));
  });

  test('서버가 죽었다: 넣어 둔 목록으로 간다', () async {
    await http.runWithClient(() async {
      final kr = await StockSearchService.krStocks();
      expect(has(kr, '005930'), isTrue);
    }, () => MockClient((_) async => http.Response('', 503)));
  });

  test('두 번째 실행부터는 기다리지 않는다', () async {
    // 지난번에 받아 둔 목록이 있다
    File('${dir.path}/stocks_cache.json').writeAsStringSync(json.encode([
      {'t': '111111', 'n': '지난번목록', 'm': 'KS'},
    ]));
    await http.runWithClient(() async {
      final sw = Stopwatch()..start();
      final kr = await StockSearchService.krStocks();
      expect(has(kr, '111111'), isTrue);
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 400)),
          reason: '받아 둔 목록이 있는데도 서버를 기다렸다');
    }, () => server(delay: const Duration(milliseconds: 500)));
  });
}
