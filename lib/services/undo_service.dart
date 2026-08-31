import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 되돌릴 수 있는 **한 묶음**.
///
/// 조정 제안의 일괄 기록과 거래내역 업로드는 한 번에 수십 건을 넣는다.
/// 잘못 눌렀거나 실제로는 체결이 안 됐으면, 지금까지는 거래 내역에서
/// **하나씩 지워야 했다.**
///
/// 포트당 **가장 최근 묶음 하나**만 남긴다. 다음 묶음을 기록하면 앞의 것은
/// 사라진다 — 과거 묶음까지 골라 되돌리게 하면, 그 뒤에 쌓인 거래가
/// 있을 때 결과가 무엇이어야 하는지 애매해진다.
class UndoBatch {
  /// 무엇을 되돌리는지 화면에 적기 위한 구분.
  static const kindProposal = 'proposal';
  static const kindImport = 'import';

  final String portfolioId;
  final String kind;

  /// 기록한 시각 (epoch ms)
  final int at;

  /// 되돌릴 거래들. `(종목 id, 거래 id)`
  final List<({String itemId, String txId})> transactions;

  /// 업로드가 **새로 만든** 종목. 되돌릴 때 같이 지운다 —
  /// 단, 그 뒤에 다른 거래가 붙었으면 남긴다.
  final List<String> createdItemIds;

  /// 예수금 종목과 되돌릴 수량. 일괄 기록이 예수금을 건드렸을 때만 있다.
  final String? cashItemId;
  final double? cashBefore;

  /// 되돌릴 「마지막 조정 시각」. 기록 전 값이라 null일 수 있다.
  final int? lastRebalancedBefore;

  const UndoBatch({
    required this.portfolioId,
    required this.kind,
    required this.at,
    required this.transactions,
    this.createdItemIds = const [],
    this.cashItemId,
    this.cashBefore,
    this.lastRebalancedBefore,
  });

  int get count => transactions.length;

  Map<String, dynamic> toJson() => {
        'p': portfolioId,
        'k': kind,
        'at': at,
        'tx': [
          for (final t in transactions) {'i': t.itemId, 't': t.txId}
        ],
        'ci': createdItemIds,
        'cid': cashItemId,
        'cb': cashBefore,
        'lr': lastRebalancedBefore,
      };

  factory UndoBatch.fromJson(Map<String, dynamic> j) => UndoBatch(
        portfolioId: j['p'] as String,
        kind: j['k'] as String? ?? kindProposal,
        at: j['at'] as int,
        transactions: [
          for (final t in (j['tx'] as List? ?? []))
            (
              itemId: (t as Map)['i'] as String,
              txId: t['t'] as String,
            )
        ],
        createdItemIds: [
          for (final c in (j['ci'] as List? ?? [])) c as String
        ],
        cashItemId: j['cid'] as String?,
        cashBefore: (j['cb'] as num?)?.toDouble(),
        lastRebalancedBefore: j['lr'] as int?,
      );
}

/// 포트당 마지막 묶음 하나를 들고 있는다.
///
/// 포트폴리오 본체(`portfolios_v1`)와 **따로 둔다.** 되돌리기 기록은
/// 파생 정보라 백업·복원에 끼어들 이유가 없고, 형식이 바뀌어도
/// 사용자 자산 데이터가 위험해지지 않는다.
class UndoService {
  static const String _key = 'undo_batch_v1';

  static Future<Map<String, dynamic>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // 형식이 깨졌으면 되돌리기만 못 하고 끝난다 — 자산 데이터와 무관하다
      return {};
    }
  }

  static Future<void> save(UndoBatch batch) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _all();
    all[batch.portfolioId] = batch.toJson();
    await prefs.setString(_key, jsonEncode(all));
  }

  /// 이 포트의 마지막 묶음. 없으면 null.
  static Future<UndoBatch?> load(String portfolioId) async {
    final all = await _all();
    final j = all[portfolioId];
    if (j == null) return null;
    try {
      return UndoBatch.fromJson(j as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String portfolioId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _all();
    all.remove(portfolioId);
    await prefs.setString(_key, jsonEncode(all));
  }
}
