import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/portfolio.dart';
import '../utils/csv_parser.dart';
import 'import_analyzer.dart';
import 'import_plan.dart';

import 'undo_service.dart';

export 'import_plan.dart' show ImportResult, ImportPlan;

/// 거래내역 파일을 읽어 들이는 일 (시안 v17b·v17c).
///
/// **읽기와 저장을 갈라 두었다.** [analyze]는 파일을 읽어 계획만 만들고,
/// [commit]이 실제로 쓴다. 파일을 고르자마자 저장해 버리면 무엇이 들어갔는지
/// 모른 채 끝나고, 잘못 들어간 것을 되돌리기도 어렵다.
class ExcelImportService {
  static const _headersKo = ['날짜', '종목명', '티커', '시장', '유형', '수량', '단가'];
  static const _headersEn = [
    'Date', 'Name', 'Ticker', 'Market', 'Type', 'Qty', 'Price'
  ];

  /// 시안이 약속한 상한. 이보다 크면 읽지 않고 그렇다고 말한다.
  static const int maxFileBytes = 5 * 1024 * 1024;

  // ── 표준 양식 ──

  static Future<void> downloadTemplate(bool isKo) async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    final headers = isKo ? _headersKo : _headersEn;
    for (int i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    final sample = [
      '2026.01.15',
      'KODEX 200',
      '069500',
      'KR',
      isKo ? '매수' : 'Buy',
      '10',
      '35000',
    ];
    for (int i = 0; i < sample.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(sample[i]);
    }

    final encoded = excel.encode();
    if (encoded == null) return;
    final dir = await getTemporaryDirectory();
    final fname = isKo ? '거래내역_양식.xlsx' : 'transaction_template.xlsx';
    final file = File('${dir.path}/$fname');
    await file.writeAsBytes(encoded);
    await Share.shareXFiles([XFile(file.path)]);
  }

  // ── 1단계: 읽기만 한다 ──

  /// 파일을 고르게 하고 **저장 없이** 계획만 만든다.
  ///
  /// 사용자가 파일 고르기를 취소하면 null.
  static Future<ImportPlan?> analyze(Portfolio pf, bool isKo) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
    );
    if (picked == null || picked.files.isEmpty) return null;

    final path = picked.files.single.path;
    if (path == null) return null;
    final fileName = picked.files.single.name;

    final file = File(path);
    final len = await file.length();
    if (len > maxFileBytes) {
      return ImportPlan(
        fileName: fileName,
        ready: const [],
        unlinked: const [],
        duplicates: const [],
        skipped: [
          SkippedRow(
              0,
              isKo
                  ? '파일이 5MB를 넘습니다 (${(len / 1024 / 1024).toStringAsFixed(1)}MB)'
                  : 'File exceeds 5MB (${(len / 1024 / 1024).toStringAsFixed(1)}MB)')
        ],
      );
    }

    final bytes = await file.readAsBytes();
    final lower = fileName.toLowerCase();

    List<List<String>> rows;
    try {
      if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
        // 깨진 바이트가 있어도 죽지 않게 한다. 열 이름을 못 알아보면
        // buildPlan이 "열을 찾지 못했다"고 말해 준다.
        final text = utf8.decode(bytes, allowMalformed: true);
        rows = parseCsv(text, delimiter: guessDelimiter(text));
      } else {
        rows = _readExcel(bytes);
      }
    } catch (e) {
      return ImportPlan(
        fileName: fileName,
        ready: const [],
        unlinked: const [],
        duplicates: const [],
        skipped: [
          SkippedRow(0, isKo ? '파일을 열 수 없습니다' : 'Could not open the file')
        ],
      );
    }

    return ImportAnalyzer.buildPlan(rows, fileName, pf, isKo: isKo);
  }

  static List<List<String>> _readExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.sheets.isEmpty) return const [];
    final sheet = excel.sheets[excel.sheets.keys.first];
    if (sheet == null) return const [];
    return [
      for (final row in sheet.rows) [for (final cell in row) _cellStr(cell)]
    ];
  }

  static String _cellStr(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.roundToDouble() ? d.round().toString() : d.toString();
    }
    if (v is DateTimeCellValue) {
      return '${v.year}.${v.month.toString().padLeft(2, '0')}'
          '.${v.day.toString().padLeft(2, '0')}';
    }
    return v.toString().trim();
  }

  // ── 2단계: 확정해서 쓴다 ──

  /// [plan]의 `ready`를 실제 거래로 넣는다.
  ///
  /// [links]는 못 찾은 종목을 어디에 붙일지다 — 값이 [createNewItemMarker]면
  /// 새 종목을 만들어 붙인다. 연결하지 않은 줄은 들어가지 않는다.
  static Future<ImportResult> commit(
    ImportPlan plan,
    Portfolio pf,
    PortfolioProvider provider, {
    Map<String, String> links = const {},
  }) async {
    final createdItems = <String>[];
    final createdIds = <String>[];       // 되돌릴 때 지울 종목
    final undoTx = <({String itemId, String txId})>[];
    final resolved = <String, String>{};

    // 새로 만들어 달라는 것부터 만든다
    for (final u in plan.unmatchedItems) {
      final target = links[u.label];
      if (target == null) continue;
      if (target == createNewItemMarker) {
        final row = plan.unlinked.firstWhere((r) => r.key == u.label);
        final id = _uid();
        await provider.addItem(pf.id, newItemFrom(row, id));
        createdIds.add(id);
        resolved[u.label] = id;
        createdItems.add(u.name.isNotEmpty ? u.name : u.ticker);
      } else {
        resolved[u.label] = target;
      }
    }

    final finalPlan = plan.withLinks(resolved);

    var added = 0;
    for (final r in finalPlan.ready) {
      final itemId = r.matchedItemId;
      if (itemId == null) continue;
      final tx = StockTransaction(
        id: _uid(),
        date: r.date,
        quantity: r.isBuy ? r.qty : -r.qty,
        price: r.price,
      );
      await provider.upsertTransaction(pf.id, itemId, tx);
      undoTx.add((itemId: itemId, txId: tx.id));
      added++;
    }

    // 한 번에 수십 건이 들어간다. 파일을 잘못 골랐거나 열이 어긋났으면
    // 하나씩 지우게 두지 않는다. 이 업로드가 **만든 종목까지** 기억한다.
    if (undoTx.isNotEmpty || createdIds.isNotEmpty) {
      await UndoService.save(UndoBatch(
        portfolioId: pf.id,
        kind: UndoBatch.kindImport,
        at: DateTime.now().millisecondsSinceEpoch,
        transactions: undoTx,
        createdItemIds: createdIds,
      ));
    }

    return ImportResult(
      addedCount: added,
      createdItems: createdItems,
      skippedRows: [
        for (final s in finalPlan.skipped) '${s.rowNumber}: ${s.reason}'
      ],
    );
  }

  static var _seq = 0;
  static String _uid() {
    _seq++;
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '_${_seq.toRadixString(36)}';
  }
}
