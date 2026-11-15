import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebalancing_app/l10n/app_localizations.dart';
import 'package:rebalancing_app/main.dart';
import 'package:rebalancing_app/widgets/contribution_row.dart';
import 'package:rebalancing_app/widgets/settlement_capture_card.dart';

/// 결산 그림의 줄 한도를 8에서 20으로 올렸다. 긴 그림은 예전에 **말없이
/// 잘린 적이 있다** — 스물다섯 종목짜리를 캡처와 같은 구조로 그려 찍어서, 스무 줄과
/// 「그 외」 줄이 그려지고 그림이 끝까지 나오는지 본다.
void main() {
  testWidgets('25종목 결산: 20줄 + 「그 외 5건 합계」, 그림이 끝까지 찍힌다',
      (tester) async {
    final pnl = PnlColorNotifier();
    // 번 종목 15, 잃은 종목 5, 자잘한 것 5(합계 −1,500)
    final pnls = <double>[
      for (var i = 15; i >= 1; i--) i * 100000.0,
      300, 200, -400, -600, -1000,
      for (var i = 1; i <= 5; i++) -i * 200000.0,
    ];
    final card = SettlementCaptureCard(
      title: 'ISA계좌',
      periodLabel: '46주',
      rangeLabel: '11.09 – 11.15',
      absoluteReturn: pnls.fold<double>(0, (s, v) => s + v),
      returnRate: 2.21,
      rateAvailable: true,
      startValue: 41257845,
      endValue: 42171655,
      netCashFlow: 0,
      inProgress: true,
      currency: 'KRW',
      rowsTitle: '종목별 기여',
      rows: [
        for (var i = 0; i < pnls.length; i++)
          CaptureRow(
            name: '종목 $i',
            absoluteReturn: pnls[i],
            returnRate: 1,
            rateAvailable: true,
            startValue: 1000000,
            endValue: 1000000 + pnls[i],
            share: 0.04,
            contribution: 0.1,
          ),
      ],
      isKo: true,
      positiveColor: pnl.positiveColor,
      negativeColor: pnl.negativeColor,
      pnlColors: pnl,
    );

    // captureWidget이 오버레이에 꽂는 것과 같은 구조 — 가로만 못박고 세로는 연다
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: 380, child: RepaintBoundary(key: key, child: card)),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(ContributionRow), findsNWidgets(20));
    expect(find.text('그 외 5건 합계 −₩1,500'), findsOneWidget);
    expect(find.text('종목 24'), findsOneWidget,
        reason: '가장 많이 잃은 종목이 그림에서 빠졌다');
    final laidOut = tester.getSize(find.byType(SettlementCaptureCard)).height;

    ui.Image? image;
    await tester.runAsync(() async {
      final board =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      image = await board.toImage(pixelRatio: 1.0);
    });

    expect(image!.width, 380);
    expect(image!.height, laidOut.ceil(),
        reason: '그림이 그려진 판보다 짧다 — 아래가 잘렸다');
    expect(image!.height, greaterThan(1500));
  });
}
