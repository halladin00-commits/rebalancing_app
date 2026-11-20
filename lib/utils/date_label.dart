/// 화면에 쓰는 날짜 글자를 만드는 한 곳.
///
/// 한국어는 `2026.11.01`, `11.01 – 11.30`처럼 점으로 적는다. 영어 독자에게
/// `11.01`은 날짜로 잘 안 읽힌다(11월 1일인지 1월 11일인지 헷갈린다).
/// 그래서 영어는 `Nov 1, 2026`, `Nov 1 – 30`처럼 달 이름으로 적는다.
///
/// 열두 곳이 각자 점을 찍고 있었다. 규칙은 여기에만 둔다.
library;

import 'package:flutter/widgets.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _p2(int n) => n.toString().padLeft(2, '0');

/// 화면 언어. 한국어가 아니면 전부 영어식으로 적는다.
String dateLang(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ko' ? 'ko' : 'en';

/// `2026.11.01` / `Nov 1, 2026`
String fmtDate(DateTime d, String lang) => lang == 'ko'
    ? '${d.year}.${_p2(d.month)}.${_p2(d.day)}'
    : '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// `11.01` / `Nov 1`
String fmtMonthDay(DateTime d, String lang) => lang == 'ko'
    ? '${_p2(d.month)}.${_p2(d.day)}'
    : '${_months[d.month - 1]} ${d.day}';

/// `11.01 12:40` / `Nov 1 12:40`
String fmtMonthDayTime(DateTime d, String lang) =>
    '${fmtMonthDay(d, lang)} ${_p2(d.hour)}:${_p2(d.minute)}';

/// 기간. [withYear]면 연도를 한 번 붙인다.
///
/// - 한국어: `2026.11.01 – 11.30` / `11.01 – 11.30` (전과 같다)
/// - 영어:  `Nov 1 – 30, 2026` / `Nov 28 – Dec 4` / `Dec 29, 2025 – Jan 4`
///
/// 해를 넘는 주는 한국어처럼 시작 연도만 적는다 — 결산 머리 한 줄에
/// 들어가야 해서 연도 둘을 다 적으면 길어진다.
String fmtRange(DateTime a, DateTime b, String lang, {bool withYear = false}) {
  if (lang == 'ko') {
    final start = withYear ? fmtDate(a, lang) : fmtMonthDay(a, lang);
    return '$start – ${fmtMonthDay(b, lang)}';
  }
  final sameMonth = a.year == b.year && a.month == b.month;
  final end = sameMonth ? '${b.day}' : fmtMonthDay(b, lang);
  if (!withYear) return '${fmtMonthDay(a, lang)} – $end';
  if (a.year != b.year) return '${fmtDate(a, lang)} – $end';
  return '${fmtMonthDay(a, lang)} – $end, ${b.year}';
}
