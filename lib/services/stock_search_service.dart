import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class StockSearchResult {
  final String ticker;
  final String name;
  final String market; // 'KR' or 'US'
  final bool isEtf;

  StockSearchResult({
    required this.ticker,
    required this.name,
    required this.market,
    this.isEtf = false,
  });
}

class StockSearchService {
  static const String _remoteUrl =
      'https://halladin00-commits.github.io/stock-data/stocks.json';
  static const String _metaUrl =
      'https://halladin00-commits.github.io/stock-data/meta.json';

  static const String _cacheFileName = 'stocks_cache.json';
  static const String _cacheMetaFileName = 'stocks_cache_meta.json';

  static List<Map<String, dynamic>>? _stocks;
  static bool _initialized = false;

  /// 초기화 — 앱 시작 시 호출
  static Future<void> initialize() async {
    if (_initialized) return;
    await _loadStocks();
    _initialized = true;
    _checkAndUpdate();
  }

  /// 종목 검색 (정확도순 정렬)
  static Future<List<StockSearchResult>> search(String query) async {
    if (!_initialized) await initialize();
    if (query.trim().isEmpty || _stocks == null) return [];

    final q = query.trim().toLowerCase();

    final matches = <_ScoredResult>[];
    for (final s in _stocks!) {
      final ticker = (s['t'] as String).toLowerCase();
      final name = (s['n'] as String).toLowerCase();

      if (!name.contains(q) && !ticker.contains(q)) continue;

      int score;
      if (ticker == q) {
        score = 0;
      } else if (name == q) {
        score = 1;
      } else if (ticker.startsWith(q)) {
        score = 2;
      } else if (name.startsWith(q)) {
        score = 3;
      } else if (ticker.contains(q)) {
        score = 4;
      } else {
        score = 5;
      }

      final marketCode = s['m'] as String;
      final market = (marketCode == 'KS' || marketCode == 'KQ') ? 'KR' : 'US';
      final isEtf = (s['ty'] as String?) == 'E';

      matches.add(_ScoredResult(
        result: StockSearchResult(
          ticker: s['t'] as String,
          name: s['n'] as String,
          market: market,
          isEtf: isEtf,
        ),
        score: score,
      ));
    }

    matches.sort((a, b) => a.score.compareTo(b.score));
    return matches.take(15).map((m) => m.result).toList();
  }

  /// 데이터 로드 우선순위: 캐시 → 번들
  static Future<void> _loadStocks() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/$_cacheFileName');
      if (await cacheFile.exists()) {
        final jsonStr = await cacheFile.readAsString();
        final list = json.decode(jsonStr) as List<dynamic>;
        _stocks = list.cast<Map<String, dynamic>>();
        print('종목 데이터 로드: 캐시 (${_stocks!.length}건)');
        return;
      }
    } catch (e) {
      print('캐시 로드 실패: $e');
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/kr_stocks.json');
      final list = json.decode(jsonStr) as List<dynamic>;
      _stocks = list.cast<Map<String, dynamic>>();
      print('종목 데이터 로드: 번들 (${_stocks!.length}건)');
    } catch (e) {
      print('번들 로드 실패: $e');
      _stocks = [];
    }
  }

  /// 백그라운드 업데이트 확인
  static Future<void> _checkAndUpdate() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final metaFile = File('${dir.path}/$_cacheMetaFileName');

      final metaResp = await http
          .get(Uri.parse(_metaUrl))
          .timeout(const Duration(seconds: 10));
      if (metaResp.statusCode != 200) {
        print('meta.json 조회 실패: ${metaResp.statusCode}');
        return;
      }
      final serverMeta = json.decode(metaResp.body);
      final serverUpdatedAt = serverMeta['updated_at'] ?? '';

      if (await metaFile.exists()) {
        final cachedMetaStr = await metaFile.readAsString();
        final cachedMeta = json.decode(cachedMetaStr);
        final cachedUpdatedAt = cachedMeta['updated_at'] ?? '';

        if (serverUpdatedAt == cachedUpdatedAt && serverUpdatedAt.isNotEmpty) {
          print('종목 데이터 최신 (서버와 동일)');
          return;
        }
      }

      print('종목 데이터 업데이트 중...');
      final dataResp = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 30));
      if (dataResp.statusCode != 200) return;

      final list = json.decode(dataResp.body) as List<dynamic>;
      if (list.length < 100) return;

      final cacheFile = File('${dir.path}/$_cacheFileName');
      await cacheFile.writeAsString(dataResp.body);
      await metaFile.writeAsString(metaResp.body);

      _stocks = list.cast<Map<String, dynamic>>();
      print('종목 데이터 업데이트 완료: ${_stocks!.length}건');
    } catch (e) {
      print('업데이트 실패 (기존 데이터 유지): $e');
    }
  }
}

class _ScoredResult {
  final StockSearchResult result;
  final int score;
  _ScoredResult({required this.result, required this.score});
}
