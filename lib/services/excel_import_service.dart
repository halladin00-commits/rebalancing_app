import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/portfolio.dart';

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

class ExcelImportService {
  static const _headersKo = ['날짜', '종목명', '티커', '시장', '유형', '수량', '단가'];
  static const _headersEn = ['Date', 'Name', 'Ticker', 'Market', 'Type', 'Qty', 'Price'];

  static Future<void> downloadTemplate(bool isKo) async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    final headers = isKo ? _headersKo : _headersEn;

    // 헤더 행 (볼드)
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // 예시 행
    final sampleValues = [
      '2024.01.15',
      isKo ? 'KODEX 200' : 'KODEX 200',
      '069500',
      'KR',
      isKo ? '매수' : 'Buy',
      '10',
      '35000',
    ];
    for (int i = 0; i < sampleValues.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(sampleValues[i]);
    }

    final encoded = excel.encode();
    if (encoded == null) return;
    final dir = await getTemporaryDirectory();
    final fname = isKo ? '거래내역_양식.xlsx' : 'transaction_template.xlsx';
    final file = File('${dir.path}/$fname');
    await file.writeAsBytes(encoded);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<ImportResult?> importTransactions(
    Portfolio pf,
    PortfolioProvider provider,
    bool isKo,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (picked == null || picked.files.isEmpty) return null;

    final path = picked.files.single.path;
    if (path == null) return null;

    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final sheetName = excel.sheets.keys.first;
    final sheet = excel.sheets[sheetName];
    if (sheet == null) {
      return const ImportResult(addedCount: 0, createdItems: [], skippedRows: []);
    }

    int addedCount = 0;
    final List<String> createdItems = [];
    final List<String> skippedRows = [];

    // ticker → itemId 맵 (기존 종목 + 이번에 생성된 종목)
    final itemIdMap = <String, String>{};
    for (final item in pf.items) {
      if (!item.isCash && item.ticker.isNotEmpty) {
        itemIdMap[item.ticker] = item.id;
      }
    }

    // Row 0 = 헤더, Row 1 = 예시 → Row 2부터 처리
    // 단, Row 1이 예시행인지 확인 후 건너뜀
    int startRow = 1;
    if (sheet.rows.length > 1) {
      final firstDataStr = _cellStr(sheet.rows[1].isNotEmpty ? sheet.rows[1][0] : null);
      // 예시행 날짜가 2024.01.15이거나 숫자가 아니면 건너뜀
      if (_parseDate(sheet.rows[1].isNotEmpty ? sheet.rows[1][0] : null) == null &&
          firstDataStr.isNotEmpty) {
        startRow = 2;
      }
    }

    for (int rowIdx = startRow; rowIdx < sheet.rows.length; rowIdx++) {
      final row = sheet.rows[rowIdx];

      // 빈 행 스킵
      if (row.every((c) => c?.value == null)) continue;

      if (row.length < 6) {
        skippedRows.add(isKo ? '${rowIdx + 1}행: 컬럼 수 부족' : 'Row ${rowIdx + 1}: insufficient columns');
        continue;
      }

      final dateStr = _cellStr(row[0]);
      final name = _cellStr(row[1]);
      final ticker = _cellStr(row[2]).toUpperCase();
      final market = _parseMarket(_cellStr(row[3]));
      final typeStr = _cellStr(row[4]);
      final qtyStr = _cellStr(row[5]);
      final priceStr = row.length > 6 ? _cellStr(row[6]) : '';

      // 날짜 파싱
      final date = _parseDate(row[0]);
      if (date == null) {
        skippedRows.add(isKo ? '${rowIdx + 1}행: 날짜 오류 ($dateStr)' : 'Row ${rowIdx + 1}: invalid date ($dateStr)');
        continue;
      }

      // 유형 파싱
      final isBuy = _isBuy(typeStr);
      if (isBuy == null) {
        skippedRows.add(isKo ? '${rowIdx + 1}행: 유형 오류 ($typeStr)' : 'Row ${rowIdx + 1}: invalid type ($typeStr)');
        continue;
      }

      // 수량 파싱
      final qty = double.tryParse(qtyStr.replaceAll(',', ''));
      if (qty == null || qty <= 0) {
        skippedRows.add(isKo ? '${rowIdx + 1}행: 수량 오류 ($qtyStr)' : 'Row ${rowIdx + 1}: invalid qty ($qtyStr)');
        continue;
      }

      // 단가 파싱 (선택)
      final price = double.tryParse(priceStr.replaceAll(',', '')) ?? 0.0;

      // 종목 찾기 또는 생성
      String? itemId = itemIdMap[ticker];
      if (itemId == null && ticker.isEmpty) {
        itemId = pf.items.where((i) => !i.isCash && i.name == name).firstOrNull?.id;
      }

      if (itemId == null) {
        if (name.isEmpty && ticker.isEmpty) {
          skippedRows.add(isKo ? '${rowIdx + 1}행: 종목명/티커 없음' : 'Row ${rowIdx + 1}: missing name/ticker');
          continue;
        }
        // 신규 종목 생성
        final newId = _uid();
        final newItem = PortfolioItem(
          id: newId,
          name: name.isNotEmpty ? name : ticker,
          ticker: ticker,
          market: market,
        );
        await provider.addItem(pf.id, newItem);
        if (ticker.isNotEmpty) itemIdMap[ticker] = newId;
        itemId = newId;
        createdItems.add(name.isNotEmpty ? name : ticker);
      }

      // 거래 추가
      final tx = StockTransaction(
        id: _uid(),
        date: date,
        quantity: isBuy ? qty : -qty,
        price: price,
      );
      await provider.upsertTransaction(pf.id, itemId, tx);
      addedCount++;
    }

    return ImportResult(
      addedCount: addedCount,
      createdItems: createdItems,
      skippedRows: skippedRows,
    );
  }

  static String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      DateTime.now().microsecond.toRadixString(36);

  static String _cellStr(Data? cell) {
    if (cell?.value == null) return '';
    final v = cell!.value;
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      if (d == d.roundToDouble()) return d.round().toString();
      return d.toString();
    }
    if (v is DateTimeCellValue) {
      return '${v.year}.${v.month.toString().padLeft(2, '0')}.${v.day.toString().padLeft(2, '0')}';
    }
    return v.toString().trim();
  }

  static DateTime? _parseDate(Data? cell) {
    if (cell?.value == null) return null;
    final v = cell!.value;

    if (v is DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day);
    }

    // Excel 날짜 시리얼 (숫자)
    int? serial;
    if (v is IntCellValue) serial = v.value;
    if (v is DoubleCellValue) serial = v.value.round();
    if (serial != null && serial > 40000) {
      final dt = DateTime(1899, 12, 30).add(Duration(days: serial));
      return DateTime(dt.year, dt.month, dt.day);
    }

    // 문자열 파싱
    String s = '';
    if (v is TextCellValue) {
      s = v.value.toString().trim();
    } else {
      s = v.toString().trim();
    }

    final m = RegExp(r'^(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})$').firstMatch(s);
    if (m != null) {
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null) return DateTime(y, mo, d);
    }
    return null;
  }

  static String _parseMarket(String s) {
    final lower = s.toLowerCase().trim();
    if (lower.startsWith('kr') || lower.contains('한국') || lower.contains('korea')) return 'KR';
    if (lower.startsWith('us') || lower.contains('미국') || lower.contains('usa')) return 'US';
    return 'KR';
  }

  static bool? _isBuy(String s) {
    final lower = s.toLowerCase().trim();
    if (lower == '매수' || lower == 'buy' || lower == 'b') return true;
    if (lower == '매도' || lower == 'sell' || lower == 's') return false;
    return null;
  }
}
