import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 총자산 기록의 한 점.
class AssetPoint {
  final DateTime date;
  final double totalKrw;
  const AssetPoint(this.date, this.totalKrw);
}

/// 총자산 추이 기록.
///
/// 시세를 새로고침할 때마다 그날의 총자산(원화 환산)을 **하루 한 점** 남긴다.
/// 같은 날 여러 번 갱신하면 마지막 값으로 덮어쓴다 — 하루의 종가에 해당한다.
///
/// 과거 주가 API로 소급 계산하지 않는다. 기록이 쌓이는 만큼만 그린다.
class AssetHistoryService {
  AssetHistoryService._();

  static const _key = 'asset_history_v1';

  /// 보관 기간. 이보다 오래된 점은 저장 시 버린다.
  static const _retentionDays = 400;

  /// 그래프를 그리기 위한 최소 점 개수. 한 점짜리 선은 의미가 없다.
  static const minPointsForChart = 2;

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 오늘의 총자산을 기록한다. 같은 날 값이 있으면 덮어쓴다.
  static Future<void> record(double totalKrw) async {
    if (totalKrw <= 0) return; // 시세를 아직 못 받은 상태는 남기지 않는다
    final prefs = await SharedPreferences.getInstance();
    final map = _decode(prefs.getString(_key));

    map[_dayKey(DateTime.now())] = totalKrw;

    // 보관 기간을 넘긴 점 제거
    final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays));
    map.removeWhere((k, _) {
      final d = DateTime.tryParse(k);
      return d == null || d.isBefore(cutoff);
    });

    await prefs.setString(_key, json.encode(map));
  }

  /// 기록을 날짜 오름차순으로 반환한다.
  static Future<List<AssetPoint>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decode(prefs.getString(_key));

    final points = <AssetPoint>[];
    for (final e in map.entries) {
      final d = DateTime.tryParse(e.key);
      if (d != null) points.add(AssetPoint(d, e.value));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  /// 최근 [days]일치만 반환한다.
  static Future<List<AssetPoint>> loadRecent({int days = 365}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final all = await load();
    return all.where((p) => !p.date.isBefore(cutoff)).toList();
  }

  /// 기록 전체 삭제 (백업 복원 등으로 자산이 완전히 바뀔 때).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, double> _decode(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }
}
