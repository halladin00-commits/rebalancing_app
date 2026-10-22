import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
  static Future<List<String>> pickScreenshots() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (picked == null) return const [];
    return [for (final f in picked.files) if (f.path != null) f.path!];
  }

  /// [paths]를 한 장씩 읽는다. [onProgress]는 끝낸 장 수를 받는다.
  static Future<List<HoldingsShot>> read(List<String> paths,
      {void Function(int done)? onProgress}) async {
    final rec = TextRecognizer(script: TextRecognitionScript.korean);
    final shots = <HoldingsShot>[];
    try {
      for (final path in paths) {
        final r = await rec.processImage(InputImage.fromFilePath(path));
        shots.add(parseNamuHoldings([
          for (final b in r.blocks)
            for (final l in b.lines)
              for (final e in l.elements)
                OcrWord(e.text, e.boundingBox.left, e.boundingBox.top,
                    e.boundingBox.right, e.boundingBox.bottom),
        ]));
        onProgress?.call(shots.length);
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
    return shots;
  }
}
