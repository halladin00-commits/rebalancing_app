#!/bin/sh
# 에뮬레이터 화면을 **글자로** 다룬다. 캡처 없이 확인하고 누른다.
#
# 왜 필요한가
#   Flutter는 캔버스에 직접 그린다. 접근성 트리가 없으면 `uiautomator`가
#   빈 껍데기만 뱉어서, 지금 무슨 화면인지 알려면 매번 캡처해서 눈으로 봐야
#   했다. 느리고, 비싸고(캡처 한 장이 컨텍스트에 계속 남는다), 화면 전환
#   중에 찍히면 엉뚱한 걸 보게 된다. 좌표도 매번 손으로 환산해야 했다.
#
#   검토용 빌드는 `--dart-define=A11Y_ALWAYS=true`로 트리를 항상 켜 둔다
#   (tools/build_review.sh가 넣는다). 그러면 화면의 글자와 위치를 그대로
#   읽을 수 있다. Flutter는 글자를 `text`가 아니라 **`content-desc`**에 넣는다.
#
# 쓰는 법
#   sh tools/ui.sh text                  화면의 글자를 모두 출력
#   sh tools/ui.sh has  "조정 제안"       있으면 0, 없으면 1로 끝난다
#   sh tools/ui.sh wait "조정 제안" 30    나타날 때까지 최대 30초 기다린다
#   sh tools/ui.sh tap  "조정 제안 보기"   그 글자를 가진 **가장 작은** 칸을 누른다
#
# 캡처는 **보기 좋은지 눈으로 봐야 할 때만** 쓴다.
# 어느 화면인지·눌렸는지·값이 맞는지는 전부 여기서 확인한다.

set -e
DEV="${DEVICE:-emulator-5554}"
CMD="${1:-text}"
ARG="$2"

# 노드 하나가 한 줄이 되도록 쪼갠다
nodes() {
  adb -s "$DEV" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || return 1
  adb -s "$DEV" shell cat /sdcard/ui.xml 2>/dev/null | tr '<' '\n<'
}

# 그 노드가 들고 있는 글자 (content-desc 우선, 없으면 text)
labels() {
  nodes | sed -n 's/.*content-desc="\([^"]*\)".*/\1/p;s/.*[^-]text="\([^"]*\)".*/\1/p' |
    grep -v '^$' | sed 's/&#10;/ | /g'
}

case "$CMD" in
  text)
    labels
    ;;

  has)
    if labels | grep -qF "$ARG"; then echo "있음: $ARG"; else echo "없음: $ARG"; exit 1; fi
    ;;

  wait)
    LIMIT="${3:-30}"
    i=0
    while [ "$i" -lt "$LIMIT" ]; do
      if labels | grep -qF "$ARG"; then echo "떴다: $ARG (${i}초)"; exit 0; fi
      i=$((i + 1))
      adb -s "$DEV" shell sleep 1
    done
    echo "안 뜸: $ARG (${LIMIT}초)" >&2
    labels | head -15 >&2
    exit 1
    ;;

  tap)
    # **딱 맞는 것을 먼저 찾는다.**
    #   `추가`로 찾으면 `종목 추가`·`포트폴리오 추가`·`직접 입력해서 추가`가
    #   전부 걸려서, 누르려던 버튼 대신 화면 제목을 누른 적이 있다.
    #   글자가 정확히 같은 노드가 있으면 그걸 쓰고, 없을 때만 부분 일치로 간다.
    HITS=$(nodes | grep -F "content-desc=\"$ARG\"" || true)
    [ -z "$HITS" ] && HITS=$(nodes | grep -F "text=\"$ARG\"" || true)
    [ -z "$HITS" ] && HITS=$(nodes | grep -F "$ARG" || true)

    # 그 글자를 품은 노드 중 **가장 작은 것**을 고른다.
    # 부모 컨테이너도 자식의 글자를 물려받으므로, 큰 것을 누르면 엉뚱한
    # 자리를 누르게 된다.
    # 좌표는 sed로 **순서대로** 뽑는다.
    # awk의 `for (i in a)`는 순서를 보장하지 않아서, 그걸로 꺼내면 x와 y가
    # 뒤섞인 채 엉뚱한 자리를 누른다 (실제로 겪었다).
    LINE=$(printf '%s\n' "$HITS" |
           sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p' |
           awk '{ print ($3 - $1) * ($4 - $2), $1, $2, $3, $4 }' |
           sort -n | head -1)
    if [ -z "$LINE" ]; then
      echo "못 찾음: $ARG" >&2
      exit 1
    fi
    set -- $LINE
    X=$(( ($2 + $4) / 2 ))
    Y=$(( ($3 + $5) / 2 ))
    echo "누름: $ARG @ $X,$Y"
    adb -s "$DEV" shell input tap "$X" "$Y"
    ;;

  *) echo "모르는 명령: $CMD" >&2; exit 1 ;;
esac
