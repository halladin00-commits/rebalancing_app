import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/widgets/settlement_capture_card.dart';
import 'package:rebalancing_app/widgets/settlement_header.dart';

/// 결산 캡처의 **머리글 손익색**을 실제로 그려서 잰다.
///
/// 무슨 일이 있었나
///   캡처 카드가 화면 머리글을 손으로 복사해 두고 있었다. 그 사이 조용히
///   갈라져서, 캡처만 **밝은 바탕용 진한 손익색**을 딥그린 위에 썼다 —
///   대비가 무너져 글자가 배경에 잠긴다. 금액 크기와 자간, 「수익률」
///   라벨 색까지 달라졌다.
///
///   **나란히 놓고 볼 일이 없어** 사용자가 폰에서 두 화면을 오가며 찾을
///   때까지 몰랐다. 이 앱에서 네 번째 같은 사고다.
///
/// 소스만 보는 시험으로는 부족하다 — 같은 위젯을 쓰면서도 색을 잘못
/// 넘기면 그대로 통과한다. **그려서 색을 집어 본다.**
void main() {
  const deepGreen = Color(0xFF0E4F49);

  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko'), Locale('en')],
        home: Scaffold(backgroundColor: deepGreen, body: child),
      );

  /// 그 글자의 색.
  Color colorOf(WidgetTester tester, String text) {
    final w = tester.widget<Text>(find.text(text));
    return w.style!.color!;
  }

  testWidgets('캡처 머리글이 딥그린용 손익색을 쓴다', (tester) async {
    final pnl = PnlColorNotifier();

    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: SettlementCaptureCard(
        title: '전체 결산',
        periodLabel: '37주',
        rangeLabel: '9.07 – 9.13',
        absoluteReturn: -4148970,
        returnRate: -1.06,
        rateAvailable: true,
        startValue: 390985545,
        endValue: 386836575,
        netCashFlow: 0,
        inProgress: false,
        currency: 'KRW',
        rowsTitle: '포트별 기여',
        rows: const [],
        isKo: true,
        positiveColor: pnl.positiveColor,
        negativeColor: pnl.negativeColor,
        pnlColors: pnl,
      ),
    )));
    await tester.pump();

    final amount = colorOf(tester, '−₩4,148,970');

    // **밝은 바탕용 색이면 안 된다.** 딥그린 위에서 대비가 무너진다.
    expect(amount, isNot(pnl.negativeColor),
        reason: '캡처가 밝은 바탕용 손익색을 딥그린 머리글에 쓴다');
    expect(amount, pnl.onBrandNegative,
        reason: '딥그린 위에서는 onBrandNegative 여야 한다');
  });

  testWidgets('캡처와 화면이 같은 색·같은 크기로 그린다', (tester) async {
    final pnl = PnlColorNotifier();

    // ── 화면 ──
    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: SettlementHeaderBody(
        periodLabel: '37주',
        rangeLabel: '9.07 – 9.13',
        absoluteReturn: -4148970,
        returnRate: -1.06,
        rateAvailable: true,
        startValue: 390985545,
        endValue: 386836575,
        netCashFlow: 0,
        partial: false,
        inProgress: false,
        currency: 'KRW',
        pnlColors: pnl,
      ),
    )));
    await tester.pump();
    final screenStyle =
        tester.widget<Text>(find.text('−₩4,148,970')).style!;

    // ── 캡처 ──
    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: SettlementCaptureCard(
        title: '전체 결산',
        periodLabel: '37주',
        rangeLabel: '9.07 – 9.13',
        absoluteReturn: -4148970,
        returnRate: -1.06,
        rateAvailable: true,
        startValue: 390985545,
        endValue: 386836575,
        netCashFlow: 0,
        inProgress: false,
        currency: 'KRW',
        rowsTitle: '포트별 기여',
        rows: const [],
        isKo: true,
        positiveColor: pnl.positiveColor,
        negativeColor: pnl.negativeColor,
        pnlColors: pnl,
      ),
    )));
    await tester.pump();
    final captureStyle =
        tester.widget<Text>(find.text('−₩4,148,970')).style!;

    expect(captureStyle.color, screenStyle.color, reason: '색이 다르다');
    expect(captureStyle.fontSize, screenStyle.fontSize, reason: '글자 크기가 다르다');
    expect(captureStyle.letterSpacing, screenStyle.letterSpacing,
        reason: '자간이 다르다');
    expect(captureStyle.fontWeight, screenStyle.fontWeight, reason: '굵기가 다르다');
  });

  testWidgets('「마감」 뱃지도 화면과 같다', (tester) async {
    final pnl = PnlColorNotifier();

    Future<TextStyle> badgeStyle(Widget child) async {
      await tester.pumpWidget(wrap(SingleChildScrollView(child: child)));
      await tester.pump();
      return tester.widget<Text>(find.text('마감')).style!;
    }

    final screen = await badgeStyle(SettlementHeaderBody(
      periodLabel: '37주',
      rangeLabel: '9.07 – 9.13',
      absoluteReturn: -4148970,
      returnRate: -1.06,
      rateAvailable: true,
      startValue: 1,
      endValue: 1,
      netCashFlow: 0,
      partial: false,
      inProgress: false,
      currency: 'KRW',
      pnlColors: pnl,
    ));

    final capture = await badgeStyle(SettlementCaptureCard(
      title: '전체 결산',
      periodLabel: '37주',
      rangeLabel: '9.07 – 9.13',
      absoluteReturn: -4148970,
      returnRate: -1.06,
      rateAvailable: true,
      startValue: 1,
      endValue: 1,
      netCashFlow: 0,
      inProgress: false,
      currency: 'KRW',
      rowsTitle: '포트별 기여',
      rows: const [],
      isKo: true,
      positiveColor: pnl.positiveColor,
      negativeColor: pnl.negativeColor,
      pnlColors: pnl,
    ));

    expect(capture.color, screen.color, reason: '뱃지 글자색이 다르다');
    expect(capture.fontSize, screen.fontSize, reason: '뱃지 글자 크기가 다르다');
  });
}
