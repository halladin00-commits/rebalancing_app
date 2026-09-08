#!/bin/sh
# 앱의 **모든 캡처 이미지**를 한 번에 만들어 꺼낸다.
#
# 왜 필요한가
#   캡처는 눈으로만 보이는 종류로 망가진다 — 배경이 검게 나오거나, 목록이
#   잘리거나, 화면과 배치가 달라지거나. 예외도 로그도 안 남는다.
#   그런데 한 화면씩 확인하려면 앱을 옮겨 다니며 탭을 여러 번 눌러야 해서,
#   「하나만 보고 나머지는 같은 구성이니 되겠지」로 넘어가게 된다.
#   **그 추측이 지금까지 틀린 것들의 원인이었다.**
#
#   한 번에 다 만들어 놓고 나란히 보면 그럴 이유가 없어진다.
#
# 쓰는 법:  sh tools/captures.sh [출력폴더]
#
# 앞선 조건: 검토용 빌드가 깔려 있어야 한다 (tools/build_review.sh).
#            `tools/ui.sh`로 화면을 글자로 찾으므로 접근성 트리가 필요하다.

set -e
DEV="${DEVICE:-emulator-5554}"
OUT="${1:-captures}"
PKG=com.xaxavoo.rebalancing.review
mkdir -p "$OUT"

say() { echo "── $* ──"; }

# 우상단 [캡처] 버튼의 실제 좌표를 찾아 누른다.
# 버튼 개수가 화면마다 달라 좌표를 박아 두면 엉뚱한 걸 누른다.
tap_capture() {
  adb -s "$DEV" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || return 1
  B=$(adb -s "$DEV" shell cat /sdcard/ui.xml | tr '<' '\n<' |
      grep -F 'content-desc="캡처"' |
      sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p' |
      head -1)
  [ -z "$B" ] && { echo "  캡처 버튼 없음"; return 1; }
  set -- $B
  adb -s "$DEV" shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
  adb -s "$DEV" shell sleep 3
  # 「이미지 저장」은 **좌표로 누른다.**
  #
  # 여기서 `uiautomator dump`를 뜨면 **시트가 닫힌다.** 덤프로 버튼을 찾으려다
  # 정작 시트를 닫아 놓고, 다음 탭이 하단 탭바를 눌러 다른 화면으로 갔다.
  # 시트 모양은 화면마다 같으므로 아래에서 잰 자리면 된다.
  SZ=$(adb -s "$DEV" shell wm size | sed 's/.*: //' | tr -d '')
  W=$(echo "$SZ" | cut -dx -f1)
  H=$(echo "$SZ" | cut -dx -f2)
  adb -s "$DEV" shell input tap $(( W * 267 / 1000 )) $(( H - 245 ))
  adb -s "$DEV" shell sleep 8
}

pull_latest() {
  F=$(adb -s "$DEV" shell "content query --uri content://media/external/images/media --projection _display_name --sort '_id DESC'" 2>/dev/null |
      head -1 | sed 's/.*_display_name=//' | tr -d '\r')
  [ -z "$F" ] && { echo "  저장된 파일 없음"; return 1; }
  adb -s "$DEV" pull "/storage/emulated/0/Pictures/$F" "$OUT/$1.jpg" >/dev/null 2>&1 &&
    echo "  → $OUT/$1.jpg  ($F)"
}

adb -s "$DEV" shell input keyevent KEYCODE_HOME >/dev/null
adb -s "$DEV" shell am force-stop "$PKG"
adb -s "$DEV" shell monkey -p "$PKG" 1 >/dev/null 2>&1
sh tools/ui.sh wait "자산" 45 >/dev/null || true
adb -s "$DEV" shell sleep 20   # 첫 시세 갱신이 끝나길 기다린다

say "자산 탭"
sh tools/ui.sh tap "자산" >/dev/null 2>&1 || true
adb -s "$DEV" shell sleep 5
tap_capture && pull_latest asset || true

say "리밸런싱 탭"
sh tools/ui.sh tap "리밸런싱" >/dev/null 2>&1 || true
adb -s "$DEV" shell sleep 6
tap_capture && pull_latest rebalance_tab || true

say "결산 탭"
sh tools/ui.sh tap "결산" >/dev/null 2>&1 || true
adb -s "$DEV" shell sleep 8
tap_capture && pull_latest settlement || true

echo
echo "포트 상세·포트 리밸런싱·포트별 결산·조정 제안은 포트를 골라야 해서"
echo "손으로 들어간 뒤 다시 부르면 된다:  sh tools/captures.sh <폴더>"
