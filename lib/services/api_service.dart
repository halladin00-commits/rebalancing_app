import 'dart:convert';
import 'package:http/http.dart' as http;

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
  static Future<ApiResult<double>> fetchStockPrice(
    String ticker,
    String market,
  ) async {
    if (ticker.isEmpty) {
      return ApiResult.error('티커 없음');
    }

    try {
      if (market == 'KR') {
        // KOSPI(.KS) 시도 → 실패 시 KOSDAQ(.KQ) 시도
        final cleanTicker = ticker.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
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

  static Future<ApiResult<double>> _fetchYahoo(String symbol) async {
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
      final price =
          data['chart']?['result']?[0]?['meta']?['regularMarketPrice'];

      if (price == null) {
        return ApiResult.error('가격 데이터 없음');
      }

      return ApiResult.success((price as num).toDouble());
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
