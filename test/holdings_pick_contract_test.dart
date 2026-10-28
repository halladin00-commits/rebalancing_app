import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 캡처를 고를 때 **사본을 남기지 않는다.**
///
/// file_picker는 사진을 고르면 기본으로 JPEG 화질 30으로 다시 눌러 공용
/// 「사진」 폴더(`Pictures/JPEG_…jpg`)에 저장하고 지우지 않는다. 계좌 캡처의
/// 사본이 갤러리에 쌓이고(클라우드 백업에도 실린다), 뭉개진 글씨를 읽느라
/// 글자 읽기가 틀린다. 에뮬레이터에서 가져올 때마다 세 장씩 생기는 것을 봤다.
///
/// 기기 없이는 사본이 생기는지 볼 수 없으므로, 부르는 쪽에서 끄는지를 본다.
void main() {
  test('잔고 캡처를 고를 때 압축(=공용 폴더 사본)을 끈다', () {
    final src =
        File('lib/services/holdings_ocr_service.dart').readAsStringSync();
    expect(src.contains('FileType.image'), isTrue,
        reason: '캡처를 고르는 곳을 못 찾았다 — 검사가 헛돈다');
    expect(src.contains('allowCompression: false'), isTrue,
        reason: '압축을 켜 두면 공용 「사진」 폴더에 계좌 캡처 사본이 남는다');
  });

  test('사진을 고르는 다른 곳도 압축을 끈다', () {
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (!src.contains('FileType.image')) continue;
      expect(src.contains('allowCompression: false'), isTrue,
          reason: '${f.path} — 사진을 고르는데 압축을 안 껐다. 공용 폴더에 사본이 남는다');
    }
  });
}
