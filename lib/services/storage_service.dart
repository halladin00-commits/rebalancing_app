import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  /// 백업 파일 생성 후 공유 시트 열기
  static Future<void> exportPortfolios(List<Portfolio> portfolios) async {
    final jsonStr = json.encode(portfolios.map((e) => e.toJson()).toList());
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fname =
        'rebalancing_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$fname');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)]);
  }

  /// 파일 선택 후 포트폴리오 목록 반환 (취소 시 null)
  static Future<List<Portfolio>?> importPortfolios() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;

    final content = await File(path).readAsString();
    final list = json.decode(content) as List<dynamic>;
    return list
        .map((e) => Portfolio.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
