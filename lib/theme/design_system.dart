import 'package:flutter/material.dart';
/// 개편 디자인의 치수 · 타입 스케일 확정값.
/// 매직 넘버 대신 이 상수를 쓴다. (기준 폭 390 논리 픽셀)
///
/// 색은 `main.dart`의 `extension AppColors on BuildContext`에 있다.
class DS {
  DS._();

  // ── 프레임 ──
  static const double screenPaddingH = 16;   // 화면 좌우 패딩
  static const double bottomNavHeight = 64;  // 하단 탭바
  static const double headerRadius = 28;     // 딥그린 헤더 하단 라운드
  static const double sheetRadius = 24;      // 바텀시트 상단 라운드

  // ── 카드 ──
  static const double cardRadius = 20;       // 결산 · 자산 주요 카드
  static const double listCardRadius = 18;   // 더보기 목록 카드
  static const double tileRadius = 16;       // 작은 타일
  static const double cardPaddingH = 18;     // 카드 좌우 패딩
  static const double cardGap = 9;           // 카드 사이 간격

  // ── 배지 · 칩 · 컨트롤 ──
  static const double badgeRadius = 6;
  static const double chipRadius = 20;
  static const double buttonRadius = 14;
  static const double buttonHeight = 48;
  static const double toggleW = 44;
  static const double toggleH = 26;
  static const double toggleThumb = 20;
  static const double minTouch = 44;

  // ── 진행 막대 ──
  static const double barTrackHeight = 5;
  static const double barTrackRadius = 3;

  // ── 타입 (Pretendard, 논리 px) ──
  static const double displayAmount = 35;  // 헤더 총액,  w800, ls -1.5
  static const double cardAmount = 32;     // 카드 총액,  w800, ls -1.4
  static const double totalAmount = 17;    // 합계 행,    w800, ls -0.4
  static const double rowName = 15;        // 행 이름,    w700, ls -0.2
  static const double rowAmount = 15;      // 행 금액,    w700, ls -0.3
  static const double returnPct = 12.5;    // 수익률,     w700
  static const double dayChange = 11;      // 전일대비,   w700
  static const double sectionTitle = 13;   // 섹션 제목,  w800, ls -0.2
  static const double groupLabel = 11.5;   // 그룹 라벨,  w800
  static const double body = 11.5;         // 부가 설명,  w500
  static const double caption = 10.5;      // 최소 크기 — 이보다 작게 쓰지 말 것
  static const double navLabel = 10.5;
  static const double navIcon = 23;
}

/// 차트 구간 색.
///
/// 의미를 담지 않는다 — 인접 구간을 **구분**하기 위한 것이다.
/// 비중 막대와 도넛 차트가 같은 색을 써야 두 화면이 한 앱으로 읽힌다.
const List<Color> chartPalette = [
  Color(0xFF0E4F49), // 브랜드 딥그린
  Color(0xFF8FE7B0), // 민트
  Color(0xFFF2C36B), // 골드
  Color(0xFFE88C6A), // 살구
  Color(0xFF7FB5E0), // 하늘
  Color(0xFFB4C88A), // 올리브
  Color(0xFF3D5C58), // 흐린 초록
  Color(0xFFC08A3E), // 청동
  Color(0xFF9C86B5), // 흐린 보라
  Color(0xFFA39B8C), // 따뜻한 회색
];
