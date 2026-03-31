import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class StockSearchResult {
  final String ticker;
  final String name;
  final String market; // 'KR' or 'US'

  StockSearchResult({
    required this.ticker,
    required this.name,
    required this.market,
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

  /// 종목 검색
  static Future<List<StockSearchResult>> search(String query) async {
    if (!_initialized) await initialize();
    if (query.trim().isEmpty || _stocks == null) return [];

    final q = query.trim().toLowerCase();
    return _stocks!
        .where((s) {
          final ticker = (s['t'] as String).toLowerCase();
          final name = (s['n'] as String).toLowerCase();
          return name.contains(q) || ticker.contains(q);
        })
        .take(10)
        .map((s) {
          final marketCode = s['m'] as String;
          final market =
              (marketCode == 'KS' || marketCode == 'KQ') ? 'KR' : 'US';
          return StockSearchResult(
            ticker: s['t'] as String,
            name: s['n'] as String,
            market: market,
          );
        })
        .toList();
  }

  /// 데이터 로드 우선순위: 캐시 → 번들
  static Future<void> _loadStocks() async {
    // 1. 캐시된 파일 시도
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

    // 2. 번들 파일 폴백
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

      if (await metaFile.exists()) {
        final metaStr = await metaFile.readAsString();
        final meta = json.decode(metaStr);
        final lastUpdate = DateTime.tryParse(meta['updated_at'] ?? '');
        if (lastUpdate != null) {
          final diff = DateTime.now().toUtc().difference(lastUpdate);
          if (diff.inHours < 24) {
            print('종목 데이터 최신 (${diff.inHours}시간 전)');
            return;
          }
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

      final metaResp = await http
          .get(Uri.parse(_metaUrl))
          .timeout(const Duration(seconds: 10));
      if (metaResp.statusCode == 200) {
        await metaFile.writeAsString(metaResp.body);
      }

      _stocks = list.cast<Map<String, dynamic>>();
      print('종목 데이터 업데이트 완료: ${_stocks!.length}건');
    } catch (e) {
      print('업데이트 실패 (기존 데이터 유지): $e');
    }
  }
}