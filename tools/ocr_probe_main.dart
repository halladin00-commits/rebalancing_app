// 캡처를 **기기의 글자 읽기(ML Kit)로** 읽혀 낱말과 자리를 뽑는다.
//
// 앱에 들어가지 않는다 — tools/ocr_probe.sh 가 이 파일을 lib/ 에 잠깐
// 복사해 진입점으로 삼아 빌드하고, 끝나면 지운다.
//
// 앱 전용 외부 폴더의 그림을 모두 읽어 result.json 으로 남긴다.
//   { "파일이름": { "ms": 걸린 시간, "w": 가로, "h": 세로,
//                   "lines": [ { "t": 낱말, "b": [왼, 위, 오른, 아래] } ] } }
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('probe')))));
  final dir = (await getExternalStorageDirectory())!;
  final rec = TextRecognizer(script: TextRecognitionScript.korean);
  final out = <String, dynamic>{};
  final files = dir.listSync().whereType<File>().where((f) {
    final p = f.path.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp');
  }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    final sw = Stopwatch()..start();
    // 갓 깔면 모델을 내려받는 중이다 — 될 때까지 기다린다
    for (var attempt = 0; attempt < 30; attempt++) {
      try {
        final r = await rec.processImage(InputImage.fromFilePath(f.path));
        final codec = await ui.instantiateImageCodec(await f.readAsBytes());
        final img = (await codec.getNextFrame()).image;
        out[name] = {
          'ms': sw.elapsedMilliseconds,
          'w': img.width,
          'h': img.height,
          'lines': [
            for (final b in r.blocks)
              for (final l in b.lines)
                for (final e in l.elements)
                  {
                    't': e.text,
                    'b': [
                      e.boundingBox.left.round(),
                      e.boundingBox.top.round(),
                      e.boundingBox.right.round(),
                      e.boundingBox.bottom.round()
                    ],
                  },
          ],
        };
        break;
      } catch (e) {
        out[name] = {'error': '$e'};
        if (!'$e'.contains('download')) break;
        await Future<void>.delayed(const Duration(seconds: 10));
        sw.reset();
      }
    }
  }
  await File('${dir.path}/result.json').writeAsString(jsonEncode(out));
  // ignore: avoid_print
  print('OCR_PROBE_DONE');
}
