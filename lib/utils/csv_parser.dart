/// 아주 작은 CSV 파서.
///
/// 증권사에서 내려받은 거래내역은 CSV인 경우가 많다. 패키지를 하나 더 들이는
/// 대신 직접 읽는다 — 규칙이 단순하고, 여기서 틀리면 남의 돈 기록이 틀어지므로
/// 동작을 눈으로 확인할 수 있는 편이 낫다.
///
/// 다루는 것:
///   - 큰따옴표로 감싼 칸 (`"삼성전자, 우선주"` 처럼 쉼표가 들어간 경우)
///   - 큰따옴표 안의 큰따옴표 (`""` → `"`)
///   - 큰따옴표 안의 줄바꿈
///   - CRLF / LF 섞임
///   - 맨 앞의 BOM
///
/// 구분자는 [delimiter]로 바꿀 수 있다. 탭으로 내려주는 곳도 있다.
List<List<String>> parseCsv(String text, {String delimiter = ','}) {
  // 엑셀이 UTF-8로 저장하면 앞에 BOM이 붙는다. 그대로 두면 첫 열 이름이 안 맞는다.
  if (text.startsWith('﻿')) text = text.substring(1);
  if (text.isEmpty) return const [];

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;

  void endField() {
    row.add(field.toString().trim());
    field.clear();
  }

  void endRow() {
    endField();
    // 완전히 빈 줄은 버린다 — 파일 끝의 빈 줄까지 한 건으로 세면 안 된다.
    if (row.any((c) => c.isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final c = text[i];

    if (inQuotes) {
      if (c == '"') {
        // `""`는 따옴표 한 개를 뜻한다
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(c);
      i++;
      continue;
    }

    if (c == '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (c == delimiter) {
      endField();
      i++;
      continue;
    }
    if (c == '\r') {
      // CRLF는 한 번만 센다
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
      i++;
      continue;
    }
    if (c == '\n') {
      endRow();
      i++;
      continue;
    }
    field.write(c);
    i++;
  }

  // 마지막 줄이 줄바꿈 없이 끝나는 경우
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// 구분자를 짐작한다. 첫 줄에서 가장 많이 나온 것을 고른다.
///
/// 쉼표가 없는데 탭으로 갈라진 파일을 쉼표로 읽으면 한 줄이 통째로 한 칸이 된다.
String guessDelimiter(String text) {
  final firstLine = text.split(RegExp(r'\r?\n')).firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => '',
      );
  if (firstLine.isEmpty) return ',';
  var best = ',';
  var bestCount = 0;
  for (final d in [',', '\t', ';', '|']) {
    final n = firstLine.split(d).length - 1;
    if (n > bestCount) {
      bestCount = n;
      best = d;
    }
  }
  return best;
}
