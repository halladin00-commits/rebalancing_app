# -*- coding: utf-8 -*-
"""에뮬레이터를 **글자로** 조작한다.

왜 만들었나
  좌표를 눈으로 짐작해 누르다 계속 헛돌았다. 화면이 조금만 밀려도 딴 것이
  눌리고, 눌렸는지 아닌지도 모른 채 다음 단계로 갔다.

  여기서는 **누른 뒤 기대한 화면이 떴는지 확인하고**, 안 떴으면 다시 누른다.

주의 — IndexedStack
  탭 네 개가 한 트리에 다 살아 있어서, 접근성 정보에는 **안 보이는 탭의
  글자도 같이 나온다.** 그래서 탭 이름처럼 흔한 말로 찾으면 엉뚱한 것이
  잡힌다. 화면마다 **그 화면에만 있는 말**로 찾을 것.

쓰는 법: 다른 스크립트에서 불러 쓴다.
"""
import re
import subprocess
import time

DEV = 'emulator-5554'
PKG = 'com.xaxavoo.rebalancing.review'


def sh(*args, timeout=60):
    return subprocess.run(['adb', '-s', DEV] + list(args),
                          capture_output=True, timeout=timeout).stdout


def dump(tries=4):
    """화면의 접근성 정보. 가끔 빈 값이 와서 몇 번 다시 본다."""
    for _ in range(tries):
        out = sh('shell',
                 'uiautomator dump /sdcard/u.xml >/dev/null 2>&1; cat /sdcard/u.xml')
        if out and b'<node' in out:
            return out.decode('utf-8', 'ignore')
        time.sleep(2)
    return ''


BOUNDS = re.compile(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
ATTR = re.compile(r'(?:text|content-desc)="([^"]*)"')


def find(pattern, xml=None, within=None, avoid=None):
    """[pattern]을 품은 글자의 가운데 좌표. 없으면 None.

    **마디를 하나씩 본다.** 한 마디에 `text=""`와 `content-desc="더보기"`가
    같이 있는 일이 흔한데, 통째로 정규식을 걸면 **앞의 빈 text가 먼저
    잡혀** 아무것도 못 찾는다. 실제로 그래서 한참 헛돌았다.

    within: (top, bottom) — 그 세로 범위 안의 것만 본다. 안 보이는 탭의
    같은 글자를 걸러낼 때 쓴다.
    """
    xml = xml if xml is not None else dump()
    for node in xml.split('<node')[1:]:
        node = node.split('>')[0]
        vals = ATTR.findall(node)
        if not any(pattern in v for v in vals):
            continue
        # 같은 이름을 품은 **딴 것**을 걸러낸다. 파일 선택창의
        # 「…파일 미리보기」 단추가 파일 이름보다 먼저 잡혀, 파일을 고르는
        # 대신 미리보기만 열린 적이 있다.
        if avoid and any(avoid in v for v in vals):
            continue
        b = BOUNDS.search(node)
        if not b:
            continue
        x1, y1, x2, y2 = map(int, b.groups())
        if x2 <= x1 or y2 <= y1:
            continue
        if within and not (within[0] <= (y1 + y2) // 2 <= within[1]):
            continue
        return (x1 + x2) // 2, (y1 + y2) // 2


def tap(x, y):
    sh('shell', 'input', 'tap', str(x), str(y))


def tap_text(pattern, expect=None, tries=4, wait=3.0, within=None,
             avoid=None):
    """글자를 찾아 누르고, [expect]가 뜰 때까지 확인한다."""
    for i in range(tries):
        pos = find(pattern, within=within, avoid=avoid)
        if pos:
            tap(*pos)
            time.sleep(wait)
            if expect is None or find(expect):
                return True
        else:
            time.sleep(wait)
    return False


def wait_for(pattern, tries=10, wait=2.0):
    for _ in range(tries):
        if find(pattern):
            return True
        time.sleep(wait)
    return False


def shot(path):
    out = subprocess.run(['adb', '-s', DEV, 'exec-out', 'screencap', '-p'],
                         capture_output=True, timeout=120).stdout
    with open(path, 'wb') as f:
        f.write(out)
    return len(out)


def relaunch(clear=False):
    sh('shell', 'am', 'force-stop', PKG)
    if clear:
        sh('shell', 'pm', 'clear', PKG)
    time.sleep(2)
    sh('shell', 'monkey', '-p', PKG, '-c',
       'android.intent.category.LAUNCHER', '1')
    time.sleep(18)
