import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/portfolio.dart';

class StorageService {
  static const String _key = 'portfolios_v1';
  static const String _lastBackupKey = 'last_backup_at_v1';

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

  /// 마지막으로 백업을 **실제로 내보낸** 시각. 한 번도 안 했으면 null.
  static Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastBackupKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 백업 파일 생성 후 공유 시트 열기. 실제로 어딘가로 보냈으면 true.
  ///
  /// 공유 시트를 그냥 닫으면 파일은 아무 데도 가지 않는다. 그때도 시각을
  /// 남기면 **백업한 적 없는 사람에게 백업했다고 말하게 된다** — 기기를
  /// 잃고 나서야 알게 되는 종류의 거짓말이라 보낸 경우에만 기록한다.
  static Future<bool> exportPortfolios(List<Portfolio> portfolios) async {
    final jsonStr = json.encode(portfolios.map((e) => e.toJson()).toList());
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fname =
        'rebalancing_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$fname');
    await file.writeAsString(jsonStr);
    final res = await Share.shareXFiles([XFile(file.path)]);
    if (res.status != ShareResultStatus.success) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
    return true;
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
