#!/bin/sh
# 에뮬레이터 화면을 찍어 폭 480px로 줄여 저장한다.
#
# 원본은 1080x2400이고, 그대로 읽으면 축소본의 3~4배쯤 토큰을 먹는다.
# 480px에서도 글자·색·정렬이 다 읽히므로 레이아웃 확인에는 충분하다.
# 픽셀 단위로 따져야 할 때만 원본(raw.png)을 본다.
#
# 쓰는 법:  sh tools/shot.sh <이름>   →  <이름>.png
# 좌표 환산: 480px 화면에서 잰 좌표 x2.25 = adb input tap 에 넣을 좌표
#
# 참고: Flutter는 캔버스에 그리므로 `uiautomator dump`로는 위젯이 안 잡힌다.
#       (접근성 서비스가 켜져야 semantics 트리가 생긴다.) 화면 확인은 캡처로 한다.

set -e
DEV="${DEVICE:-emulator-5554}"
OUT_DIR="${OUT_DIR:-.}"
NAME="${1:-shot}"
WIDTH="${WIDTH:-480}"

adb -s "$DEV" exec-out screencap -p > "$OUT_DIR/raw.png"

python - "$OUT_DIR/raw.png" "$OUT_DIR/$NAME.png" "$WIDTH" <<'PY'
import sys
from PIL import Image

src, dst, width = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert('RGB')
w, h = im.size
nh = int(h * width / w)
im.resize((width, nh), Image.LANCZOS).save(dst, optimize=True)
print(f"{w}x{h} -> {width}x{nh}  {dst}")
PY
