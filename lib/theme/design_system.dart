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
