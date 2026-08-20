import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rebalancing_app/services/asset_history_service.dart';

/// 자산 추이 그래프는 이틀치 기록이 쌓여야 화면에 나오므로 UI로는 바로 확인할 수 없다.
/// 기록·조회·보관 규칙을 여기서 검증한다.
void main() {
  const key = 'asset_history_v1';

  String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('오늘 총자산을 기록하고 다시 읽는다', () async {
    await AssetHistoryService.record(1000000);

    final points = await AssetHistoryService.load();
    expect(points, hasLength(1));
    expect(points.first.totalKrw, 1000000);
    expect(dayKey(points.first.date), dayKey(DateTime.now()));
  });

  test('같은 날 다시 기록하면 덮어쓴다 — 하루 한 점', () async {
    await AssetHistoryService.record(1000000);
    await AssetHistoryService.record(1200000);
    await AssetHistoryService.record(1150000);

    final points = await AssetHistoryService.load();
    expect(points, hasLength(1));
    expect(points.first.totalKrw, 1150000);
  });

  test('0 이하는 기록하지 않는다 — 시세를 못 받은 상태', () async {
    await AssetHistoryService.record(0);
    await AssetHistoryService.record(-500);

    expect(await AssetHistoryService.load(), isEmpty);
  });

  test('날짜 오름차순으로 정렬해 돌려준다', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      key: json.encode({
        dayKey(now.subtract(const Duration(days: 1))): 1100.0,
        dayKey(now.subtract(const Duration(days: 3))): 900.0,
        dayKey(now.subtract(const Duration(days: 2))): 1000.0,
      }),
    });

    final points = await AssetHistoryService.load();
    expect(points.map((p) => p.totalKrw).toList(), [900.0, 1000.0, 1100.0]);
  });

  test('보관 기간(400일)을 넘긴 점은 기록할 때 버린다', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      key: json.encode({
        dayKey(now.subtract(const Duration(days: 500))): 500.0, // 버려져야 함
        dayKey(now.subtract(const Duration(days: 399))): 700.0, // 남아야 함
      }),
    });

    await AssetHistoryService.record(800);

    final points = await AssetHistoryService.load();
    expect(points.map((p) => p.totalKrw).toList(), [700.0, 800.0]);
  });

  test('loadRecent는 요청한 기간 밖의 점을 제외한다', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      key: json.encode({
        dayKey(now.subtract(const Duration(days: 40))): 100.0,
        dayKey(now.subtract(const Duration(days: 5))): 200.0,
        dayKey(now): 300.0,
      }),
    });

    final recent = await AssetHistoryService.loadRecent(days: 30);
    expect(recent.map((p) => p.totalKrw).toList(), [200.0, 300.0]);
  });

  test('저장값이 깨져 있으면 빈 목록으로 시작한다', () async {
    SharedPreferences.setMockInitialValues({key: 'not json at all'});

    expect(await AssetHistoryService.load(), isEmpty);

    // 그 상태에서도 새 기록은 정상 저장된다
    await AssetHistoryService.record(1234);
    final points = await AssetHistoryService.load();
    expect(points, hasLength(1));
    expect(points.first.totalKrw, 1234);
  });

  test('clear는 기록을 모두 지운다', () async {
    await AssetHistoryService.record(1000);
    await AssetHistoryService.clear();

    expect(await AssetHistoryService.load(), isEmpty);
  });

  test('그래프는 두 점부터 그린다', () {
    expect(AssetHistoryService.minPointsForChart, 2);
  });
}
