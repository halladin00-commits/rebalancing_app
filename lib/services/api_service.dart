import 'dart:convert';
import 'package:http/http.dart' as http;

class StockPriceData {
  final double currentPrice;
  final double previousClose;
  StockPriceData({required this.currentPrice, required this.previousClose});
}

class ApiService {
  /// 환율 조회 (USD → KRW)
  static Future<ApiResult<double>> fetchExchangeRate() async {
    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return ApiResult.error('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final krw = data['rates']?['KRW'];
      if (krw == null) {
        return ApiResult.error('환율 데이터 없음');
      }

      return ApiResult.success(
        (krw as num).toDouble(),
      );
    } catch (e) {
      return ApiResult.error('환율 조회 실패: $e');
    }
  }

  /// 주가 조회 (Yahoo Finance)
  static Future<ApiResult<StockPriceData>> fetchStockPrice(
    String ticker,
    String market,
  ) async {
    if (ticker.isEmpty) {
      return ApiResult.error('티커 없음');
    }

    try {
      if (market == 'KR') {
        // 'A' 접두사만 제거 (신규 ETF는 0035T0 같이 영문 포함)
        String cleanTicker = ticker;
        if (cleanTicker.startsWith('A') && cleanTicker.length > 1) {
          final rest = cleanTicker.substring(1);
          if (rest.contains(RegExp(r'^[0-9]'))) {
            cleanTicker = rest;
          }
        }
        if (cleanTicker.isEmpty) {
          return ApiResult.error('$ticker: 유효하지 않은 종목코드');
        }

        // KOSPI(.KS) 시도 → 실패 시 KOSDAQ(.KQ) 시도
        final kospiResult = await _fetchYahoo('$cleanTicker.KS');
        if (kospiResult.ok) return kospiResult;

        final kosdaqResult = await _fetchYahoo('$cleanTicker.KQ');
        return kosdaqResult;
      } else {
        return await _fetchYahoo(ticker);
      }
    } catch (e) {
      return ApiResult.error('$ticker: $e');
    }
  }

  /// 기간 내 첫/마지막 거래일 종가 조회 (결산용)
  /// periodStart~periodEnd 범위의 일별 종가 중 첫 번째와 마지막 반환
  static Future<ApiResult<({double first, double last})>> fetchWeekPrices(
    String ticker,
    String market,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    if (ticker.isEmpty) return ApiResult.error('티커 없음');
    try {
      if (market == 'KR') {
        String cleanTicker = ticker;
        if (cleanTicker.startsWith('A') && cleanTicker.length > 1) {
          final rest = cleanTicker.substring(1);
          if (rest.contains(RegExp(r'^[0-9]'))) cleanTicker = rest;
        }
        if (cleanTicker.isEmpty) return ApiResult.error('유효하지 않은 종목코드');

        final r = await _fetchYahooPeriodPrices('$cleanTicker.KS', periodStart, periodEnd);
        if (r.ok) return r;
        return await _fetchYahooPeriodPrices('$cleanTicker.KQ', periodStart, periodEnd);
      } else {
        return await _fetchYahooPeriodPrices(ticker, periodStart, periodEnd);
      }
    } catch (e) {
      return ApiResult.error('$ticker: $e');
    }
  }

  /// 기간 안의 **날짜별 종가 전부**를 받는다.
  ///
  /// [fetchWeekPrices]는 양 끝 두 값만 쓰는데, 자산 추이를 메우려면 그 사이
  /// 날들이 다 필요하다. 야후 차트 API는 어차피 기간 전체를 한 번에 주므로
  /// **호출 횟수는 똑같다** — 버리던 값을 쓰는 것뿐이다.
  static Future<ApiResult<Map<DateTime, double>>> fetchDailyCloses(
    String ticker,
    String market,
    DateTime start,
    DateTime end,
  ) async {
    if (ticker.isEmpty) return ApiResult.error('티커 없음');
    try {
      if (market == 'KR') {
        var clean = ticker;
        if (clean.startsWith('A') && clean.length > 1) {
          final rest = clean.substring(1);
          if (rest.contains(RegExp(r'^[0-9]'))) clean = rest;
        }
        if (clean.isEmpty) return ApiResult.error('유효하지 않은 종목코드');
        final r = await _fetchYahooDailyCloses('$clean.KS', start, end);
        if (r.ok) return r;
        return await _fetchYahooDailyCloses('$clean.KQ', start, end);
      }
      return await _fetchYahooDailyCloses(ticker, start, end);
    } catch (e) {
      return ApiResult.error('$ticker: $e');
    }
  }

  static Future<ApiResult<Map<DateTime, double>>> _fetchYahooDailyCloses(
      String symbol, DateTime start, DateTime end) async {
    try {
      final p1 = start.millisecondsSinceEpoch ~/ 1000;
      final p2 = end.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
      final url =
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&period1=$p1&period2=$p2';
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return ApiResult.error('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final result = data['chart']?['result']?[0];
      final stamps = result?['timestamp'];
      final closes = result?['indicators']?['quote']?[0]?['close'];
      if (stamps == null || closes == null) return ApiResult.error('데이터 없음');

      // 거래소 시간대의 장 시작 시각이 찍혀 온다. 날짜만 쓰므로 현지 날짜로 자른다.
      final out = <DateTime, double>{};
      final ts = stamps as List;
      final cs = closes as List;
      for (var i = 0; i < ts.length && i < cs.length; i++) {
        final c = cs[i];
        if (c is! num) continue; // 휴장일은 null로 온다
        final d = DateTime.fromMillisecondsSinceEpoch((ts[i] as num).toInt() * 1000);
        out[DateTime(d.year, d.month, d.day)] = c.toDouble();
      }
      if (out.isEmpty) return ApiResult.error('유효한 종가 없음');
      return ApiResult.success(out);
    } catch (e) {
      return ApiResult.error('$symbol: $e');
    }
  }

  static Future<ApiResult<({double first, double last})>> _fetchYahooPeriodPrices(
      String symbol, DateTime start, DateTime end) async {
    try {
      // period2를 하루 더해서 end 당일 데이터 포함
      final p1 = start.millisecondsSinceEpoch ~/ 1000;
      final p2 = end.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
      final url =
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&period1=$p1&period2=$p2';
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return ApiResult.error('HTTP ${response.statusCode}');

      final data = json.decode(response.body);
      final closes = data['chart']?['result']?[0]?['indicators']?['quote']?[0]?['close'];
      if (closes == null || (closes as List).isEmpty) return ApiResult.error('데이터 없음');

      final validCloses = closes.whereType<num>().map((c) => c.toDouble()).toList();
      if (validCloses.isEmpty) return ApiResult.error('유효한 종가 없음');

      return ApiResult.success((first: validCloses.first, last: validCloses.last));
    } catch (e) {
      return ApiResult.error('$symbol: $e');
    }
  }

  static Future<ApiResult<StockPriceData>> _fetchYahoo(String symbol) async {
    try {
      final url =
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d';
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'Mozilla/5.0'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return ApiResult.error('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final meta = data['chart']?['result']?[0]?['meta'];
      final price = meta?['regularMarketPrice'];

      if (price == null) {
        return ApiResult.error('가격 데이터 없음');
      }

      final prevClose = meta?['regularMarketPreviousClose'] ?? meta?['chartPreviousClose'] ?? 0;

      return ApiResult.success(StockPriceData(
        currentPrice: (price as num).toDouble(),
        previousClose: (prevClose as num).toDouble(),
      ));
    } catch (e) {
      return ApiResult.error('$symbol: $e');
    }
  }
}

/// API 결과 래퍼
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool ok;

  ApiResult.success(this.data)
      : ok = true,
        error = null;
  ApiResult.error(this.error)
      : ok = false,
        data = null;
}
