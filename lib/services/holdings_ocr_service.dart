import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'api_service.dart';
import 'holdings_scan.dart';

/// 글자 읽는 모델을 아직 내려받는 중이다.
///
/// 모델은 앱에 넣지 않고 Play 서비스가 받아 온다(앱이 0.26MB만 는다).
/// 설치할 때 미리 받게 해 두었지만, 갓 설치했거나 망이 없었으면 처음 한 번은
/// 여기에 걸린다. 1분쯤 지나면 된다.
class OcrModelNotReady implements Exception {}

/// 잔고 캡처를 **이 기기 안에서** 읽는다. 캡처는 어디로도 보내지 않는다.
class HoldingsOcrService {
  /// 갤러리에서 캡처를 여러 장 고른다. 안 골랐으면 빈 목록.
  ///
  /// **압축을 끈다.** file_picker는 사진을 고르면 기본으로 JPEG 화질 30으로
  /// 다시 눌러 **공용 「사진」 폴더에 사본을 남긴다**(지우지도 않는다).
  /// 계좌 캡처의 사본이 갤러리에 쌓이고, 뭉개진 글씨를 읽느라 「AI」를
  /// 「A」로 읽었다. 끄면 원본을 앱 전용 임시 폴더에만 복사한다.
  static Future<List<String>> pickScreenshots() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      allowCompression: false,
      compressionQuality: 0,
    );
    if (picked == null) return const [];
    return [for (final f in picked.files) if (f.path != null) f.path!];
  }

  /// 종목 코드들의 지금 시세. 받지 못한 것은 빠진다.
  ///
  /// 읽은 이름으로 찾은 종목이 맞는지 **시세로 한 번 더 대 보는** 데 쓴다.
  /// 종목 코드만 보낸다 — 수량·금액은 보내지 않는다(시세 갱신과 같다).
  ///
  /// 시세 갱신처럼 4개씩 나눠 받는다. 망이 나쁘면 한 종목에 20초까지 걸릴 수
  /// 있어서, [limit]이 지나면 그때까지 받은 것만 쓴다.
  static Future<Map<String, double>> livePrices(Map<String, String> tickers,
      {Duration limit = const Duration(seconds: 15)}) async {
    final out = <String, double>{};
    final queue = tickers.keys.toList();
    Future<void> lane() async {
      while (queue.isNotEmpty) {
        final t = queue.removeLast();
        // 하나가 터져도 나머지는 받는다 — 터진 채로 두면 화면이
        // 「시세 확인 중」에서 영영 안 넘어간다
        try {
          final r = await ApiService.fetchStockPrice(t, tickers[t] ?? 'KR');
          final p = r.data?.currentPrice ?? 0;
          if (r.ok && p > 0) out[t] = p;
        } catch (_) {}
      }
    }

    await Future.any([
      Future.wait([for (var i = 0; i < 4; i++) lane()]),
      Future.delayed(limit),
    ]);
    // 시간이 지나 돌아온 뒤에도 늦게 온 값이 섞이지 않게 떼어 낸다
    return Map.of(out);
  }

  /// [paths]를 한 장씩 읽는다. [onProgress]는 끝낸 장 수를 받는다.
  static Future<List<HoldingsShot>> read(List<String> paths,
      {void Function(int done)? onProgress}) async {
    final rec = TextRecognizer(script: TextRecognitionScript.korean);
    final read = <List<OcrWord>>[];
    try {
      for (final path in paths) {
        final r = await rec.processImage(InputImage.fromFilePath(path));
        read.add([
          for (final b in r.blocks)
            for (final l in b.lines)
              for (final e in l.elements)
                OcrWord(e.text, e.boundingBox.left, e.boundingBox.top,
                    e.boundingBox.right, e.boundingBox.bottom),
        ]);
        onProgress?.call(read.length);
      }
    } on PlatformException catch (e) {
      if ('${e.message}'.contains('download')) throw OcrModelNotReady();
      rethrow;
    } finally {
      await rec.close();
      // 고른 캡처는 앱 임시 폴더에 복사돼 있다 — 다 읽었으면 지운다
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (_) {}
    }
    // 다 읽은 뒤에 한꺼번에 푼다 — 머리글이 없는 장은 다른 장의 칸 자리를 빌린다
    return parseHoldingsShots(read);
  }
}
