import '../models/portfolio.dart';
import 'import_columns.dart';
import 'import_plan.dart';

/// 표(행 목록)를 읽어 **저장하기 전의 계획**을 만든다 (시안 v17c).
///
/// 파일을 고르는 일과 저장하는 일은 여기 없다. 순수 계산만 두어 실제 증권사
/// 파일 모양으로 시험할 수 있게 했다 — 여기서 틀리면 남의 돈 기록이 조용히
/// 틀어지므로, 눈으로 확인 못 하는 코드를 두면 안 된다.
class ImportAnalyzer {
  /// 숫자 칸을 읽는다. `1,200` `₩11,235` `$512.40` `(50)` 같은 것을 다룬다.
  ///
  /// 괄호는 회계에서 음수를 뜻하지만, 여기서는 매수/매도를 `구분` 칸으로
  /// 판단하므로 **부호를 버리고 크기만** 본다.
  static double? parseNumber(String raw) {
    if (raw.trim().isEmpty) return null;
    var s = raw.replaceAll(RegExp(r'[^\d.\-]'), '');
    if (s.isEmpty || s == '-' || s == '.') return null;
    // 소수점이 여러 개면 읽을 수 없다 (1.234.567 같은 유럽식)
    if ('.'.allMatches(s).length > 1) s = s.replaceAll('.', '');
    final v = double.tryParse(s);
    return v?.abs();
  }

  /// 날짜 문자열. `2026.08.12` `2026-08-12` `2026/8/12` `20260812`를 받는다.
  static DateTime? parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final sep = RegExp(r'^(\d{4})[.\-/\s]+(\d{1,2})[.\-/\s]+(\d{1,2})').firstMatch(s);
    if (sep != null) {
      final y = int.parse(sep.group(1)!);
      final m = int.parse(sep.group(2)!);
      final d = int.parse(sep.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return DateTime(y, m, d);
      return null;
    }

    // 구분자 없는 8자리
    final plain = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
    if (plain != null) {
      final y = int.parse(plain.group(1)!);
      final m = int.parse(plain.group(2)!);
      final d = int.parse(plain.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return DateTime(y, m, d);
      return null;
    }

    // 엑셀 날짜 시리얼 (1899-12-30 기준)
    final serial = int.tryParse(s);
    if (serial != null && serial > 20000 && serial < 80000) {
      final dt = DateTime(1899, 12, 30).add(Duration(days: serial));
      return DateTime(dt.year, dt.month, dt.day);
    }
    return null;
  }

  static String parseMarket(String s) {
    final t = s.toLowerCase().trim();
    if (t.startsWith('kr') ||
        t.contains('한국') ||
        t.contains('korea') ||
        t.contains('kospi') ||
        t.contains('kosdaq')) {
      return 'KR';
    }
    if (t.startsWith('us') ||
        t.contains('미국') ||
        t.contains('usa') ||
        t.contains('nasdaq') ||
        t.contains('nyse')) {
      return 'US';
    }
    return '';
  }

  /// 매수면 true, 매도면 false, 못 읽으면 null.
  static bool? parseSide(String s) {
    final t = s.toLowerCase().trim().replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return null;
    const buys = ['매수', '매입', '현금매수', '신규매수', 'buy', 'b', 'bought', 'purchase'];
    const sells = ['매도', '매각', '현금매도', 'sell', 's', 'sold', 'sale'];
    if (buys.any((k) => t == k || t.startsWith(k))) return true;
    if (sells.any((k) => t == k || t.startsWith(k))) return false;
    return null;
  }

  /// 티커에서 거래소 꼬리표를 뗀다 — `SCHD.US` → `SCHD`.
  static String normalizeTicker(String raw) {
    var t = raw.trim().toUpperCase();
    final dot = t.lastIndexOf('.');
    if (dot > 0 && t.length - dot <= 4) t = t.substring(0, dot);
    return t;
  }

  /// [rows]를 읽어 계획을 만든다. 저장하지 않는다.
  static ImportPlan buildPlan(
    List<List<String>> rows,
    String fileName,
    Portfolio pf, {
    bool isKo = true,
  }) {
    final cols = ColumnMap.detect(rows);

    final ready = <ParsedRow>[];
    final unlinked = <ParsedRow>[];
    final duplicates = <ParsedRow>[];
    final skipped = <SkippedRow>[];

    if (!cols.usable) {
      return ImportPlan(
        fileName: fileName,
        ready: const [],
        unlinked: const [],
        duplicates: const [],
        skipped: [
          SkippedRow(0, isKo ? '거래일·수량 열을 찾지 못했습니다' : 'Could not find date and quantity columns')
        ],
      );
    }

    // 티커·이름 → 종목 id
    final byTicker = <String, String>{};
    final byName = <String, String>{};
    for (final item in pf.items) {
      if (item.isCash) continue;
      if (item.ticker.isNotEmpty) {
        byTicker[normalizeTicker(item.ticker)] = item.id;
      }
      if (item.name.isNotEmpty) byName[item.name.trim()] = item.id;
    }

    // 이미 있는 거래 (같은 종목·같은 날·같은 수량·같은 단가)
    final existing = <String>{};
    for (final item in pf.items) {
      for (final t in item.transactions) {
        existing.add(_txKey(item.id, t.date, t.quantity, t.price));
      }
    }

    for (var r = cols.dataStartRow; r < rows.length; r++) {
      final row = rows[r];
      final lineNo = r + 1;
      if (row.every((c) => c.trim().isEmpty)) continue;

      final date = parseDate(cols.get(row, ImportField.date));
      if (date == null) {
        final raw = cols.get(row, ImportField.date);
        // 표준 양식의 예시 행은 조용히 건너뛴다
        if (raw.isEmpty && row.every((c) => c.trim().isEmpty)) continue;
        skipped.add(SkippedRow(
            lineNo, isKo ? '거래일을 읽을 수 없습니다 ($raw)' : 'Unreadable date ($raw)'));
        continue;
      }

      final qty = parseNumber(cols.get(row, ImportField.qty));
      if (qty == null || qty <= 0) {
        skipped.add(SkippedRow(
            lineNo,
            isKo
                ? '수량을 읽을 수 없습니다 (${cols.get(row, ImportField.qty)})'
                : 'Unreadable quantity'));
        continue;
      }

      final side = parseSide(cols.get(row, ImportField.type));
      if (side == null) {
        skipped.add(SkippedRow(
            lineNo,
            isKo
                ? '매수·매도를 알 수 없습니다 (${cols.get(row, ImportField.type)})'
                : 'Unknown buy/sell'));
        continue;
      }

      final price = parseNumber(cols.get(row, ImportField.price)) ?? 0;
      final name = cols.get(row, ImportField.name).trim();
      final ticker = normalizeTicker(cols.get(row, ImportField.ticker));
      if (name.isEmpty && ticker.isEmpty) {
        skipped.add(SkippedRow(
            lineNo, isKo ? '종목명과 티커가 모두 없습니다' : 'No name or ticker'));
        continue;
      }

      var market = parseMarket(cols.get(row, ImportField.market));
      if (market.isEmpty) {
        // 시장 칸이 없으면 티커 모양으로 짐작한다 — 한국은 숫자 6자리다
        market = RegExp(r'^\d{6}$').hasMatch(ticker) ? 'KR' : 'US';
      }

      final itemId =
          (ticker.isNotEmpty ? byTicker[ticker] : null) ?? byName[name];

      final parsed = ParsedRow(
        rowNumber: lineNo,
        date: date,
        name: name,
        ticker: ticker,
        market: market,
        isBuy: side,
        qty: qty,
        price: price,
        matchedItemId: itemId,
      );

      if (itemId == null) {
        unlinked.add(parsed);
      } else if (existing
          .contains(_txKey(itemId, date, side ? qty : -qty, price))) {
        duplicates.add(parsed);
      } else {
        ready.add(parsed);
      }
    }

    return ImportPlan(
      fileName: fileName,
      ready: ready,
      unlinked: unlinked,
      duplicates: duplicates,
      skipped: skipped,
    );
  }

  /// 같은 거래인지 가리는 열쇠. 날짜는 날짜까지만, 금액은 소수점 둘째까지 본다.
  static String _txKey(String itemId, DateTime d, double qty, double price) =>
      '$itemId|${d.year}-${d.month}-${d.day}'
      '|${qty.toStringAsFixed(4)}|${price.toStringAsFixed(2)}';
}
