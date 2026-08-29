import '../models/portfolio.dart';

/// 파일에서 읽어낸 거래 한 줄. **아직 저장하지 않았다.**
class ParsedRow {
  /// 파일에서의 줄 번호 (1부터). 무엇이 잘못됐는지 사람에게 말할 때 쓴다.
  final int rowNumber;
  final DateTime date;
  final String name;
  final String ticker;
  final String market;
  final bool isBuy;
  final double qty;
  final double price;

  /// 포트폴리오에서 찾은 종목. 못 찾았으면 null이다.
  final String? matchedItemId;

  const ParsedRow({
    required this.rowNumber,
    required this.date,
    required this.name,
    required this.ticker,
    required this.market,
    required this.isBuy,
    required this.qty,
    required this.price,
    this.matchedItemId,
  });

  /// 종목을 못 찾은 줄을 [itemId]에 붙인 새 줄.
  ParsedRow linkedTo(String itemId) => ParsedRow(
        rowNumber: rowNumber,
        date: date,
        name: name,
        ticker: ticker,
        market: market,
        isBuy: isBuy,
        qty: qty,
        price: price,
        matchedItemId: itemId,
      );

  /// 종목을 가리키는 이름. 티커가 있으면 티커를 쓴다.
  String get key => ticker.isNotEmpty ? ticker : name;
}

/// 읽지 못한 줄과 그 이유.
class SkippedRow {
  final int rowNumber;
  final String reason;
  const SkippedRow(this.rowNumber, this.reason);
}

/// 포트폴리오에 없는 종목. 사용자가 연결하거나 새로 만들어야 한다.
class UnmatchedItem {
  final String ticker;
  final String name;
  final String market;
  final int rowCount;
  const UnmatchedItem({
    required this.ticker,
    required this.name,
    required this.market,
    required this.rowCount,
  });

  String get label => ticker.isNotEmpty ? ticker : name;
}

/// 가져오기 전에 사용자에게 보여줄 전부 (시안 v17c).
///
/// 파일을 읽자마자 저장해 버리면 **조용히 잘못 들어간다.** 그래서 읽기와 저장을
/// 갈라, 몇 건이 들어가고 몇 건이 왜 빠지는지 먼저 보여준다.
class ImportPlan {
  final String fileName;

  /// 그대로 가져올 줄.
  final List<ParsedRow> ready;

  /// 종목을 못 찾은 줄. 연결하기 전에는 안 들어간다.
  final List<ParsedRow> unlinked;

  /// 이미 같은 거래가 있는 줄. 건너뛴다.
  final List<ParsedRow> duplicates;

  /// 읽지 못한 줄.
  final List<SkippedRow> skipped;

  const ImportPlan({
    required this.fileName,
    required this.ready,
    required this.unlinked,
    required this.duplicates,
    required this.skipped,
  });

  /// 파일에서 읽으려 한 전체 줄 수.
  int get totalRows =>
      ready.length + unlinked.length + duplicates.length + skipped.length;

  /// 지금 상태로 가져갈 건수.
  int get importCount => ready.length;

  bool get isEmpty => totalRows == 0;

  /// 못 찾은 종목을 티커별로 묶은 것.
  List<UnmatchedItem> get unmatchedItems {
    final byKey = <String, List<ParsedRow>>{};
    for (final r in unlinked) {
      byKey.putIfAbsent(r.key, () => []).add(r);
    }
    return [
      for (final e in byKey.entries)
        UnmatchedItem(
          ticker: e.value.first.ticker,
          name: e.value.first.name,
          market: e.value.first.market,
          rowCount: e.value.length,
        )
    ];
  }

  /// 가져올 줄들의 기간. 비어 있으면 null.
  ({DateTime from, DateTime to})? get dateRange {
    if (ready.isEmpty) return null;
    var from = ready.first.date, to = ready.first.date;
    for (final r in ready) {
      if (r.date.isBefore(from)) from = r.date;
      if (r.date.isAfter(to)) to = r.date;
    }
    return (from: from, to: to);
  }

  int get buyCount => ready.where((r) => r.isBuy).length;
  int get sellCount => ready.where((r) => !r.isBuy).length;

  /// 가져올 줄에 등장하는 종목 수.
  int get itemCount => ready.map((r) => r.matchedItemId).toSet().length;

  /// 최근 거래부터 정렬한 미리보기용 목록.
  List<ParsedRow> get previewNewestFirst {
    final list = [...ready]..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 못 찾은 종목을 [links](종목키 → itemId)로 붙인 새 계획.
  ImportPlan withLinks(Map<String, String> links) {
    if (links.isEmpty) return this;
    final nowReady = [...ready];
    final stillUnlinked = <ParsedRow>[];
    for (final r in unlinked) {
      final id = links[r.key];
      if (id != null) {
        nowReady.add(r.linkedTo(id));
      } else {
        stillUnlinked.add(r);
      }
    }
    return ImportPlan(
      fileName: fileName,
      ready: nowReady,
      unlinked: stillUnlinked,
      duplicates: duplicates,
      skipped: skipped,
    );
  }
}

/// 저장까지 끝난 결과.
class ImportResult {
  final int addedCount;
  final List<String> createdItems;
  final List<String> skippedRows;

  const ImportResult({
    required this.addedCount,
    required this.createdItems,
    required this.skippedRows,
  });
}

/// 연결할 때 "새 종목으로 만들기"를 고른 경우 쓰는 표시.
///
/// `links` 맵의 값이 이것으로 시작하면 새 종목을 만들어 붙인다.
const String createNewItemMarker = '__new__';

/// 새 종목을 만들 때 쓸 뼈대. 실제 생성은 저장 단계에서 한다.
PortfolioItem newItemFrom(ParsedRow r, String id) => PortfolioItem(
      id: id,
      name: r.name.isNotEmpty ? r.name : r.ticker,
      ticker: r.ticker,
      market: r.market,
    );
