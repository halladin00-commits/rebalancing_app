#!/bin/sh
# 캡처 묶음을 에뮬레이터의 글자 읽기(ML Kit)로 읽혀 낱말 자리를 뽑는다.
#
# 잔고 캡처 불러오기는 「읽힌 낱말 → 표」를 기기 없이 시험한다
# (test/holdings_scan_samples_test.dart). 그 시험의 입력을 만드는 도구다.
# 새 증권사 화면이 생기면 캡처를 폴더에 넣고 이걸 돌린다.
#
# 쓰는 법:
#   sh tools/ocr_probe.sh build              # 탐침 앱을 만들어 에뮬레이터에 깐다 (한 번)
#   sh tools/ocr_probe.sh run <폴더> <결과.json>   # 폴더의 그림을 읽힌다
#   sh tools/ocr_probe.sh clean              # 탐침 앱과 그림을 지운다
#
# **캡처와 결과는 저장소 밖에 둔다** (D:/ocr_samples). 남의 잔고가 찍혀 있다.

set -e
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1
PKG=com.xaxavoo.rebalancing
DIR=/sdcard/Android/data/$PKG/files

case "$1" in
  build)
    cp tools/ocr_probe_main.dart lib/_ocr_probe_main.dart
    trap 'rm -f lib/_ocr_probe_main.dart' EXIT
    export GRADLE_USER_HOME="${GRADLE_USER_HOME:-D:/gradle_fresh}"
    flutter build apk --debug --target-platform android-x64 -t lib/_ocr_probe_main.dart
    adb install -r build/app/outputs/flutter-apk/app-debug.apk
    ;;
  run)
    SRC="$2"; OUT="$3"
    [ -d "$SRC" ] && [ -n "$OUT" ] || { echo "쓰는 법: run <폴더> <결과.json>" >&2; exit 1; }
    adb shell am force-stop $PKG
    adb shell rm -rf $DIR
    adb shell mkdir -p $DIR
    for f in "$SRC"/*; do
      case "$f" in *.jpg|*.jpeg|*.png|*.webp|*.JPG|*.PNG) adb push "$f" "$DIR/" >/dev/null ;; esac
    done
    adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    i=0
    until adb shell ls $DIR/result.json >/dev/null 2>&1; do
      i=$((i + 1)); [ $i -gt 200 ] && { echo "시간 초과" >&2; exit 1; }
      sleep 3
    done
    adb pull $DIR/result.json "$OUT" | tail -1
    adb shell am force-stop $PKG
    ;;
  clean)
    adb shell rm -rf $DIR
    adb uninstall $PKG || true
    ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
