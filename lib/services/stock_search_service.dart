import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  static Map<String, String> _krNameMap = {}; // 코드 → 한글 이름 빠른 조회
  static bool _initialized = false;

  /// 초기화 — 앱 시작 시 호출
  static Future<void> initialize() async {
    if (_initialized) return;
    await _loadStocks();
    _initialized = true;
    _checkAndUpdate();
  }

  /// 종목 검색 — Hybrid 방식
  /// 한글 포함: 로컬 JSON (Yahoo Finance가 한글 HTTP 400 반환)
  /// 영문/숫자: Yahoo + 로컬 병합 후 스코어 재정렬 (정확 일치 누락 방지)
  static Future<List<StockSearchResult>> search(String query) async {
    if (!_initialized) await initialize();
    final q = query.trim();
    if (q.isEmpty) return [];

    if (RegExp(r'[가-힣]').hasMatch(q)) {
      return _searchLocal(q);
    }

    List<StockSearchResult> yahoo = [];
    try {
      yahoo = await _searchYahoo(q);
    } catch (_) {}

    final local = _searchLocal(q);
    if (yahoo.isEmpty) return local;

    // 로컬(한글 이름 포함) + Yahoo 병합 → 스코어 재정렬
    final seen = <String>{};
    final combined = <StockSearchResult>[];
    for (final r in local) { if (seen.add(r.ticker)) combined.add(r); }
    for (final r in yahoo) { if (seen.add(r.ticker)) combined.add(r); }
    return _sortByScore(q.toLowerCase(), combined).take(15).toList();
  }

  /// 로컬 JSON 검색 (스코어 기반 정렬)
  static List<StockSearchResult> _searchLocal(String query) {
    if (_stocks == null) return [];
    final q = query.toLowerCase();
    final items = <StockSearchResult>[];

    for (final s in _stocks!) {
      final ticker = (s['t'] as String).toLowerCase();
      final name = (s['n'] as String).toLowerCase();
      if (!name.contains(q) && !ticker.contains(q)) continue;

      final marketCode = s['m'] as String;
      final market = (marketCode == 'KS' || marketCode == 'KQ') ? 'KR' : 'US';
      final isEtf = (s['ty'] as String?) == 'E';

      items.add(StockSearchResult(
        ticker: s['t'] as String,
        name: s['n'] as String,
        market: market,
        isEtf: isEtf,
      ));
    }

    return _sortByScore(q, items).take(15).toList();
  }

  /// 스코어 기반 정렬: 정확일치(0) → 이름일치(1) → 티커시작(2) → 이름시작(3) → 티커포함(4) → 이름포함(5)
  static List<StockSearchResult> _sortByScore(
      String q, List<StockSearchResult> items) {
    final scored = <_ScoredResult>[];
    for (final item in items) {
      final ticker = item.ticker.toLowerCase();
      final name = item.name.toLowerCase();
      int score;
      if (ticker == q)               { score = 0; }
      else if (name == q)            { score = 1; }
      else if (ticker.startsWith(q)) { score = 2; }
      else if (name.startsWith(q))   { score = 3; }
      else if (ticker.contains(q))   { score = 4; }
      else if (name.contains(q))     { score = 5; }
      else                           { continue; }
      scored.add(_ScoredResult(result: item, score: score));
    }
    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored.map((s) => s.result).toList();
  }

  /// Yahoo Finance 실시간 검색
  static Future<List<StockSearchResult>> _searchYahoo(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    final url = 'https://query1.finance.yahoo.com/v1/finance/search'
        '?q=$encoded&quotesCount=15&newsCount=0&listsCount=0';

    final resp = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) return [];

    final quotes = (json.decode(resp.body)['quotes'] as List?) ?? [];
    final results = <StockSearchResult>[];

    for (final q in quotes) {
      final quoteType = q['quoteType'] as String? ?? '';
      if (quoteType != 'EQUITY' && quoteType != 'ETF') continue;

      final symbol = q['symbol'] as String? ?? '';
      String ticker;
      String market;

      if (symbol.endsWith('.KS') || symbol.endsWith('.KQ')) {
        ticker = symbol.substring(0, symbol.length - 3);
        market = 'KR';
      } else if (!symbol.contains('.')) {
        ticker = symbol;
        market = 'US';
      } else {
        continue; // .T, .L 등 기타 거래소 스킵
      }

      if (ticker.isEmpty) continue;

      // 한국 주식: 로컬 한글 이름 우선, 없으면 Yahoo 영문 이름
      final name = (market == 'KR' && _krNameMap.containsKey(ticker))
          ? _krNameMap[ticker]!
          : ((q['shortname'] ?? q['longname'] ?? '') as String);

      if (name.isEmpty) continue;

      results.add(StockSearchResult(
        ticker: ticker,
        name: name,
        market: market,
        isEtf: quoteType == 'ETF',
      ));
    }
    return results;
  }

  /// 데이터 로드 우선순위: 캐시 → 번들
  static Future<void> _loadStocks() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/$_cacheFileName');
      if (await cacheFile.exists()) {
        final jsonStr = await cacheFile.readAsString();
        _stocks = await compute(_parseStocks, jsonStr);
        _buildKrNameMap();
        if (kDebugMode) print('종목 데이터 로드: 캐시 (${_stocks!.length}건)');
        return;
      }
    } catch (e) {
      if (kDebugMode) print('캐시 로드 실패: $e');
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/kr_stocks.json');
      _stocks = await compute(_parseStocks, jsonStr);
      _buildKrNameMap();
      if (kDebugMode) print('종목 데이터 로드: 번들 (${_stocks!.length}건)');
    } catch (e) {
      if (kDebugMode) print('번들 로드 실패: $e');
      _stocks = [];
    }
  }

  /// 14,000건짜리 JSON 파싱은 메인 스레드에서 하면 앱이 그동안 멈춘다.
  /// 스플래시가 몇 초씩 머무는 원인이었다. 별도 아이솔레이트로 넘긴다.
  ///
  /// `compute`에 넘기려면 최상위 또는 static 함수여야 한다.
  static List<Map<String, dynamic>> _parseStocks(String jsonStr) {
    final list = json.decode(jsonStr) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// 로컬 데이터에서 한글 이름 맵 빌드
  static void _buildKrNameMap() {
    if (_stocks == null) return;
    _krNameMap = {
      for (final s in _stocks!)
        if (s['m'] == 'KS' || s['m'] == 'KQ')
          (s['t'] as String): (s['n'] as String)
    };
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
        if (kDebugMode) print('meta.json 조회 실패: ${metaResp.statusCode}');
        return;
      }
      final serverMeta = json.decode(metaResp.body);
      final serverUpdatedAt = serverMeta['updated_at'] ?? '';

      if (await metaFile.exists()) {
        final cachedMetaStr = await metaFile.readAsString();
        final cachedMeta = json.decode(cachedMetaStr);
        final cachedUpdatedAt = cachedMeta['updated_at'] ?? '';

        if (serverUpdatedAt == cachedUpdatedAt && serverUpdatedAt.isNotEmpty) {
          if (kDebugMode) print('종목 데이터 최신 (서버와 동일)');
          return;
        }
      }

      if (kDebugMode) print('종목 데이터 업데이트 중...');
      final dataResp = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 30));
      if (dataResp.statusCode != 200) return;

      // 서버에서 받은 것도 같은 크기다 — 메인 스레드에서 파싱하지 않는다
      final list = await compute(_parseStocks, dataResp.body);
      if (list.length < 100) return;

      final cacheFile = File('${dir.path}/$_cacheFileName');
      await cacheFile.writeAsString(dataResp.body);
      await metaFile.writeAsString(metaResp.body);

      _stocks = list.cast<Map<String, dynamic>>();
      _buildKrNameMap(); // 한글 이름 맵도 갱신
      if (kDebugMode) print('종목 데이터 업데이트 완료: ${_stocks!.length}건');
    } catch (e) {
      if (kDebugMode) print('업데이트 실패 (기존 데이터 유지): $e');
    }
  }
}

class _ScoredResult {
  final StockSearchResult result;
  final int score;
  _ScoredResult({required this.result, required this.score});
}
