import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 위젯을 **길이에 상관없이** 통째로 그림으로 찍는다.
///
/// `screenshot` 패키지의 `captureFromWidget`은 렌더 판을 **화면 크기**로 잡는다.
/// 그래서 내용이 화면보다 길면 거기서 잘린다 — 종목이 세 개인 포트에서 첫
/// 종목만 나오고 끝났다. 잘려도 예외가 안 나서 그림을 열어 보기 전에는 모른다.
///
/// 여기서는 화면 밖(왼쪽 −10000)에 잠깐 그려 두고 찍는다.
/// `Positioned`에 left·top만 주면 자식은 **가로세로 모두 제약이 없는** 상태가
/// 되고, 거기서 `SizedBox(width:)`가 가로만 못박는다. 세로는 열려 있으므로
/// `Column(mainAxisSize: min)`이 내용만큼 자란다 — 아무리 길어도 다 들어간다.
///
/// 세로를 열려고 `OverflowBox(maxHeight: double.infinity)`를 쓰면 **안 된다.**
/// 그건 "가능한 한 크게"라는 뜻인데 위쪽 제약이 없으니 크기가 무한이 되고,
/// 릴리즈 빌드에는 assert가 없어 예외 대신 잘못된 변환 행렬이 만들어진다.
/// 그 판을 `toImage`가 그리려다 **앱이 멈춘다** (실제로 ANR로 확인함).
///
/// 배경은 찍을 위젯이 직접 칠해야 한다. 안 칠하면 투명하게 나오고,
/// JPEG로 저장하면 검은 그림이 된다 (`CaptureFrame`이 칠한다).
Future<Uint8List?> captureWidget(
  BuildContext context,
  Widget child, {
  double pixelRatio = 3.0,
  double width = 380,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final key = GlobalKey();

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // 화면 밖에 둔다 — 레이아웃과 그리기는 되지만 사용자에겐 안 보인다.
      left: -10000,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: SizedBox(
            // 가로만 못박는다. 세로는 열어 둔다.
            width: width,
            child: RepaintBoundary(key: key, child: child),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  try {
    // **시간으로 기다리지 않는다.** 예전에는 80밀리초를 어림해서 기다렸는데,
    // 기기가 느리거나 목록이 길면 그 안에 프레임이 안 돌아 렌더 객체가 아직
    // 없다. 그러면 null을 돌려주고 화면은 **아무 말 없이** 저장을 포기했다
    // (조정 제안 10건에서 실제로 그랬다).
    //
    // 프레임이 실제로 끝날 때까지 센다. 판이 잡히면 그 다음 한 프레임을 더
    // 기다린다 — 크기만 잡히고 아직 안 그려진 상태에서 찍으면 빈 그림이 된다.
    RenderRepaintBoundary? board;
    for (var frame = 0; frame < 40; frame++) {
      final binding = WidgetsBinding.instance;
      binding.scheduleFrame();
      await binding.endOfFrame;
      final object = key.currentContext?.findRenderObject();
      if (object is RenderRepaintBoundary && object.hasSize) {
        board = object;
        binding.scheduleFrame();
        await binding.endOfFrame;
        break;
      }
    }
    if (board == null) return null;
    final image = await board.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
