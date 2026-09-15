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
        return ApiResult.error('HTTP ${response.statusCode}', ApiErrorKind.network);
      }

      final data = json.decode(response.body);
      final krw = data['rates']?['KRW'];
      if (krw == null) {
        return ApiResult.error('환율 데이터 없음', ApiErrorKind.noData);
      }

      return ApiResult.success(
        (krw as num).toDouble(),
      );
    } catch (e) {
      return ApiResult.error('환율 조회 실패: $e', ApiErrorKind.network);
    }
  }

  /// 주가 조회 (Yahoo Finance)
  static Future<ApiResult<StockPriceData>> fetchStockPrice(
    String ticker,
    String market,
  ) async {
    if (ticker.isEmpty) {
      return ApiResult.error('티커 없음', ApiErrorKind.badTicker);
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
          return ApiResult.error('$ticker: 유효하지 않은 종목코드', ApiErrorKind.badTicker);
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
      return ApiResult.error('$ticker: $e', ApiErrorKind.network);
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
    if (ticker.isEmpty) return ApiResult.error('티커 없음', ApiErrorKind.badTicker);
    try {
      if (market == 'KR') {
        String cleanTicker = ticker;
        if (cleanTicker.startsWith('A') && cleanTicker.length > 1) {
          final rest = cleanTicker.substring(1);
          if (rest.contains(RegExp(r'^[0-9]'))) cleanTicker = rest;
        }
        if (cleanTicker.isEmpty) return ApiResult.error('유효하지 않은 종목코드', ApiErrorKind.badTicker);

        final r = await _fetchYahooPeriodPrices('$cleanTicker.KS', periodStart, periodEnd);
        if (r.ok) return r;
        return await _fetchYahooPeriodPrices('$cleanTicker.KQ', periodStart, periodEnd);
      } else {
        return await _fetchYahooPeriodPrices(ticker, periodStart, periodEnd);
      }
    } catch (e) {
      return ApiResult.error('$ticker: $e', ApiErrorKind.network);
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
    if (ticker.isEmpty) return ApiResult.error('티커 없음', ApiErrorKind.badTicker);
    try {
      if (market == 'KR') {
        var clean = ticker;
        if (clean.startsWith('A') && clean.length > 1) {
          final rest = clean.substring(1);
          if (rest.contains(RegExp(r'^[0-9]'))) clean = rest;
        }
        if (clean.isEmpty) return ApiResult.error('유효하지 않은 종목코드', ApiErrorKind.badTicker);
        final r = await _fetchYahooDailyCloses('$clean.KS', start, end);
        if (r.ok) return r;
        return await _fetchYahooDailyCloses('$clean.KQ', start, end);
      }
      return await _fetchYahooDailyCloses(ticker, start, end);
    } catch (e) {
      return ApiResult.error('$ticker: $e', ApiErrorKind.network);
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
        return ApiResult.error('HTTP ${response.statusCode}', ApiErrorKind.network);
      }

      final data = json.decode(response.body);
      final result = data['chart']?['result']?[0];
      final stamps = result?['timestamp'];
      final closes = result?['indicators']?['quote']?[0]?['close'];
      if (stamps == null || closes == null) return ApiResult.error('데이터 없음', ApiErrorKind.noData);

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
      if (out.isEmpty) return ApiResult.error('유효한 종가 없음', ApiErrorKind.noData);
      return ApiResult.success(out);
    } catch (e) {
      return ApiResult.error('$symbol: $e', ApiErrorKind.network);
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

      if (response.statusCode != 200) return ApiResult.error('HTTP ${response.statusCode}', ApiErrorKind.network);

      final data = json.decode(response.body);
      final closes = data['chart']?['result']?[0]?['indicators']?['quote']?[0]?['close'];
      if (closes == null || (closes as List).isEmpty) return ApiResult.error('데이터 없음', ApiErrorKind.noData);

      final validCloses = closes.whereType<num>().map((c) => c.toDouble()).toList();
      if (validCloses.isEmpty) return ApiResult.error('유효한 종가 없음', ApiErrorKind.noData);

      return ApiResult.success((first: validCloses.first, last: validCloses.last));
    } catch (e) {
      return ApiResult.error('$symbol: $e', ApiErrorKind.network);
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
        return ApiResult.error('HTTP ${response.statusCode}', ApiErrorKind.network);
      }

      final data = json.decode(response.body);
      final meta = data['chart']?['result']?[0]?['meta'];
      final price = meta?['regularMarketPrice'];

      if (price == null) {
        return ApiResult.error('가격 데이터 없음', ApiErrorKind.noData);
      }

      final prevClose = meta?['regularMarketPreviousClose'] ?? meta?['chartPreviousClose'] ?? 0;

      return ApiResult.success(StockPriceData(
        currentPrice: (price as num).toDouble(),
        previousClose: (prevClose as num).toDouble(),
      ));
    } catch (e) {
      return ApiResult.error('$symbol: $e', ApiErrorKind.network);
    }
  }
}

/// 왜 실패했는가 — **화면에 보일 말은 화면이 정한다.**
///
/// 예전에는 여기서 한국어 문장을 만들어 돌려줬고, 그게 영어 화면의 스낵바
/// 안에 그대로 박혀 나갔다. 서비스는 **무슨 일이 있었는지**만 말하고,
/// 어느 말로 적을지는 화면이 정한다.
enum ApiErrorKind {
  /// 망이 없거나 서버가 응답하지 않는다.
  network,

  /// 응답은 왔는데 쓸 값이 없다.
  noData,

  /// 종목코드가 비었거나 형식이 아니다.
  badTicker,

  unknown,
}

/// API 결과 래퍼
class ApiResult<T> {
  final T? data;

  /// 개발자용 자세한 내용. **화면에 그대로 내지 말 것** — 번역이 안 된다.
  final String? error;

  final ApiErrorKind kind;
  final bool ok;

  ApiResult.success(this.data)
      : ok = true,
        error = null,
        kind = ApiErrorKind.unknown;
  ApiResult.error(this.error, [this.kind = ApiErrorKind.unknown])
      : ok = false,
        data = null;
}
