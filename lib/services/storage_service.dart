import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/portfolio.dart';

class StorageService {
  static const String _key = 'portfolios_v1';

  /// 포트폴리오 목록 불러오기
  static Future<List<Portfolio>> loadPortfolios() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((e) => Portfolio.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 포트폴리오 목록 저장
  static Future<void> savePortfolios(List<Portfolio> portfolios) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(portfolios.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }
}
