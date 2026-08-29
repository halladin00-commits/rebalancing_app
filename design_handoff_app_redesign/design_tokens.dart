// 개편 디자인 색 토큰 — main.dart의 `extension AppColors on BuildContext`에 병합할 값.
//
// 사용법
//  1) 기존 AppColors 확장의 게터 값을 아래 값으로 교체한다(이름은 유지 → 호출부 수정 불필요).
//  2) 새 게터는 그대로 추가한다.
//  3) ThemeData(scaffoldBackgroundColor / appBarTheme / cardTheme)도 같은 값으로 맞춘다.
//  4) 손익 색은 여기 값을 PnlColorNotifier에 넣고, 위젯은 항상 notifier를 통해 읽는다.
//
// 라이트 값은 시안(hifi)에서 그대로 가져온 값이다. 다크 값은 같은 색상 계열에서
// 명도만 뒤집어 만든 대응값이며, 시안에는 다크 화면이 없으므로 구현 후 확인이 필요하다.

import 'package:flutter/material.dart';

extension AppColorsRedesign on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── 배경 / 표면 ──
  /// 화면 배경 (크림)
  Color get scaffoldBg => isDark ? const Color(0xFF16130F) : const Color(0xFFFBF8F1);
  /// 카드 표면
  Color get cardBg => isDark ? const Color(0xFF221E19) : Colors.white;
  Color get panelBg => cardBg;
  /// 트랙 · 배너 · 세그먼트 배경
  Color get trackBg => isDark ? const Color(0xFF2C2721) : const Color(0xFFF2EDE1);
  /// 카드 안 옅은 채움 (비교 블록 등)
  Color get subtleFill => isDark ? const Color(0xFF2A251F) : const Color(0xFFF7F3EA);
  Color get fieldFill => subtleFill;
  /// 비활성 채움
  Color get disabledFill => isDark ? const Color(0xFF332E27) : const Color(0xFFEFEADC);

  // ── 텍스트 ──
  Color get textPrimary => isDark ? const Color(0xFFF7F3EA) : const Color(0xFF16130F);
  /// 표 라벨 등 강한 보조
  Color get textStrong => isDark ? const Color(0xFFD9D2C4) : const Color(0xFF4A443B);
  Color get textSecondary => isDark ? const Color(0xFFA9A296) : const Color(0xFF726B5F);
  /// 기여도 · 부가 수치
  Color get textTertiary => isDark ? const Color(0xFF8E8779) : const Color(0xFF8A8478);
  Color get textHint => isDark ? const Color(0xFF6E675B) : const Color(0xFFA39B8C);
  /// 비활성 · 미래 기간
  Color get textDisabled => isDark ? const Color(0xFF554F45) : const Color(0xFFC3BCAC);
  /// 그룹 라벨 (더보기 섹션 등)
  Color get sectionLabel => textTertiary;

  // ── 선 ──
  /// 카드 안 행 구분선
  Color get dividerColor => isDark ? const Color(0xFF302B24) : const Color(0xFFEFEADC);
  /// 카드 밖 경계 · 탭바 상단선
  Color get borderColor => isDark ? const Color(0xFF3A342C) : const Color(0xFFE4DECF);

  // ── 브랜드 (딥 그린) ──
  /// AppBar · 주요 버튼 · 선택 상태
  Color get brand => const Color(0xFF0E4F49);
  Color get appBarBg => isDark ? const Color(0xFF0B3D38) : const Color(0xFF0E4F49);
  /// 밝은 배경 위 브랜드 텍스트
  Color get brandOnLight => isDark ? const Color(0xFF7FC9B4) : const Color(0xFF3D5C58);
  /// 브랜드 옅은 배경 (칩 · 비교 블록)
  Color get brandTint => isDark ? const Color(0xFF17342F) : const Color(0xFFE6EEEC);
  /// 딥 그린 위 강조 숫자
  Color get onBrandAccent => const Color(0xFF8FE7B0);
  Color get onBrandSecondary => Colors.white.withValues(alpha: 0.72);

  // ── 손익 (PnlColorNotifier.greenRed에 넣을 값) ──
  Color get pnlUp => const Color(0xFF0E7A52);
  Color get pnlDown => const Color(0xFFB85127);
  /// 전일대비 배지 배경
  Color get pnlUpTint => isDark ? const Color(0xFF12332A) : const Color(0xFFE6EEEC);
  Color get pnlDownTint => isDark ? const Color(0xFF3A231A) : const Color(0xFFF7E4DA);

  // ── 주의 / 진행중 ──
  Color get warningBg => isDark ? const Color(0xFF3A2E17) : const Color(0xFFF5EEDF);
  Color get warningText => isDark ? const Color(0xFFE0B36A) : const Color(0xFF9C4A16);
  /// 진행 중 기간 점 · 테두리
  Color get progressAccent => const Color(0xFFC08A3E);
  /// 딥 그린 위 주의색
  Color get onBrandWarning => const Color(0xFFF2C36B);

  // ── 시장 칩 ──
  Color get chipKrText => isDark ? const Color(0xFF9EC4DA) : const Color(0xFF1E4E6B);
  Color get chipKrBg => isDark ? const Color(0xFF17303D) : const Color(0xFFDCE9F0);
  Color get chipUsText => isDark ? const Color(0xFFC4A9E0) : const Color(0xFF4C2A72);
  Color get chipUsBg => isDark ? const Color(0xFF2A1F3A) : const Color(0xFFEBE4F3);
  Color get chipCashText => isDark ? const Color(0xFFB4C88A) : const Color(0xFF3F5218);
  Color get chipCashBg => isDark ? const Color(0xFF262E17) : const Color(0xFFE9EFDC);

  // ── 결산 차트 ──
  /// 확정 기간 막대
  Color get barSettled => isDark ? const Color(0xFF2E6B52) : const Color(0xFFBFE3CF);
  /// 선택된 기간 막대
  Color get barSelected => const Color(0xFF0E4F49);
  /// 손실 기간 막대 (기준선 아래)
  Color get barNegative => isDark ? const Color(0xFF7A4230) : const Color(0xFFEED4C6);
  /// 진행 중 기간 막대 테두리 (점선)
  Color get barInProgress => isDark ? const Color(0xFF4A7A66) : const Color(0xFFA9CBBB);
  /// 차트 기준선
  Color get chartBaseline => borderColor;
}

/// 치수 · 타입 스케일 — 시안 확정값. 매직 넘버 대신 이 상수를 쓸 것.
class DS {
  DS._();

  // 프레임
  static const double screenPaddingH = 16;
  static const double bottomNavHeight = 64;
  static const double bannerHeight = 50;
  static const double headerRadius = 28;   // AppBar 하단 라운드
  static const double sheetRadius = 24;    // 바텀시트 상단

  // 카드
  static const double cardRadius = 20;     // 결산·자산 주요 카드
  static const double listCardRadius = 18; // 더보기 목록 카드
  static const double tileRadius = 16;     // 작은 타일
  static const double cardPaddingH = 18;
  static const double cardGap = 9;
  static const List<double> cardShadow = [0, 1, 2]; // rgba(22,19,15,.05)

  // 배지 · 칩 · 컨트롤
  static const double badgeRadius = 6;
  static const double chipRadius = 20;
  static const double buttonRadius = 14;
  static const double buttonHeight = 48;
  static const double toggleW = 44;
  static const double toggleH = 26;
  static const double toggleThumb = 20;
  static const double minTouch = 44;

  // 진행 막대
  static const double barTrackHeight = 5;
  static const double barTrackRadius = 3;

  // 타입 (Pretendard, 논리 px)
  static const double displayAmount = 35;  // 헤더 총액, w800, ls -1.5
  static const double cardAmount = 32;     // 카드 총액, w800, ls -1.4
  static const double totalAmount = 17;    // 합계 행, w800, ls -0.4
  static const double rowName = 15;        // 행 이름, w700, ls -0.2
  static const double rowAmount = 15;      // 행 금액, w700, ls -0.3
  static const double returnPct = 12.5;    // 수익률, w700
  static const double dayChange = 11;      // 전일대비, w700
  static const double sectionTitle = 13;   // 섹션 제목, w800, ls -0.2
  static const double groupLabel = 11.5;   // 그룹 라벨, w800
  static const double body = 11.5;         // 부가 설명, w500
  static const double caption = 10.5;      // 최소 크기 — 이보다 작게 쓰지 말 것
  static const double navLabel = 10.5;
  static const double navIcon = 23;
}
