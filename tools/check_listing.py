# -*- coding: utf-8 -*-
"""스토어 등록정보 원고를 올리기 전에 검사한다.

왜 만들었나 — 눈으로는 안 보이는 두 가지에 당했다.

  1. **Play는 줄바꿈을 적은 그대로 내보낸다.** 원고가 읽기 좋으라고
     70자에서 접어 놨더니, 스토어 페이지에 「…목표 비중을 정해 / 둡니다.」
     처럼 문장 한복판에서 끊겨 나갔다. 원고에서는 멀쩡해 보였다.

  2. **글자 수 제한.** 영어는 같은 내용이 한글의 두 배쯤 된다. 출시 노트를
     그대로 옮겼더니 683자로 500자 제한을 넘었다.

  3. **간단한 설명이 큰 글씨로 접히는 자리.** 글자 수로 어림잡았다가 두 번
     빗나갔다 — `ETF` 같은 로마자가 한글보다 좁아 한 줄에 더 들어간다.
     「…사고팔 수량 계산까지」로 뒀더니 **「계산까지」 넉 자만** 아랫줄에
     떨어졌다. 여기서는 **글꼴로 실제 폭을 잰다.**

Console의 「애셋 리뷰」 화면으로는 확인할 수 없다 — 그 화면은 저장된 글자를
그냥 텍스트로 꽂아 넣어서, 줄바꿈이 몇 개든 한 줄로 뭉쳐 보인다.

쓰는 법:  python tools/check_listing.py
"""
import io
import re
import sys

FILES = ['docs/store/listing.md']

LIMITS = [
    ('app name', 30), ('앱 이름', 30),
    ('release notes', 500), ('출시 노트', 500),
    ('short description', 80), ('간단한 설명', 80),
    ('full description', 4000), ('자세한 설명', 4000),
]

# 글머리표·구역 제목은 한 줄이 곧 한 덩어리라 접힌 게 아니다
MARKERS = ('•', '■', '✨', '🔧', '🔔', '·')

# 간단한 설명이 큰 글씨 한 줄에 들어가는 폭 (100pt 맑은 고딕 기준).
#
# 스토어 화면 캡처에서 **들어간 줄과 한 낱말 더해 넘친 줄**을 골라 역산했다.
#   들어감  「주식·ETF 비중 관리부터 사고팔 수량」      1617
#   넘침    「관리합니다. 몇 주를 사고팔지 계산해」      1662
# 그래서 한 줄 한도는 1617 이상 1662 미만이다. 안전하게 1617로 잡는다.
ONE_LINE = 1617.0
FONT = r'C:\Windows\Fonts\malgun.ttf'


def text_width(s):
    """글자 폭. 글꼴을 못 찾으면 재지 않는다 — 없는 자를 지어내지 않는다."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return None
    try:
        f = ImageFont.truetype(FONT, 100)
    except OSError:
        return None
    return ImageDraw.Draw(Image.new('RGB', (8, 8))).textlength(s, font=f)


def wrap_at(s, limit):
    lines, line = [], ''
    for word in s.split(' '):
        t = (line + ' ' + word).strip()
        if not line or text_width(t) <= limit:
            line = t
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def limit_for(head):
    low = head.lower()
    return next((v for k, v in LIMITS if k in low), None)


def blocks(text):
    """`## 제목` 구역마다 첫 코드 블록(붙여 넣을 원고)을 꺼낸다.

    구역별로 자른 뒤 찾는다 — 원고가 없는 구역(메모뿐인 곳)이 다음 구역의
    원고를 제 것으로 집어 가지 않게.
    """
    out = []
    for sec in re.split(r'^(?=#{1,2} )', text, flags=re.M):
        m = re.match(r'## (.+?)$', sec, re.M)
        if not m:
            continue
        code = re.search(r'^```\n(.*?)^```', sec, re.S | re.M)
        if code:
            out.append((m.group(1), code.group(1)))
    return out


def wrapped_prose(body):
    """문장 중간에 접힌 자리를 찾는다.

    줄글 두 줄이 **빈 줄 없이** 잇달아 있으면 접힌 것이다. Play는 그 줄바꿈을
    그대로 내보내므로 문장이 한복판에서 끊긴다.
    """
    lines = body.split('\n')
    bad = []
    for i, ln in enumerate(lines[:-1]):
        nxt = lines[i + 1]
        if not ln.strip() or not nxt.strip():
            continue
        if ln.lstrip().startswith(MARKERS) or nxt.lstrip().startswith(MARKERS):
            continue
        bad.append((i + 1, ln))
    return bad


def main():
    # 윈도 콘솔(cp949)은 —·「」를 못 찍고 죽는다
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    fails = 0
    for path in FILES:
        print('== %s' % path)
        text = io.open(path, encoding='utf-8').read()
        for head, body in blocks(text):
            body = body.rstrip('\n')
            name = head.split('(')[0].strip()
            lim = limit_for(head)
            n = len(body)

            if lim and n > lim:
                print('   제한초과 %-22s %d / %d' % (name, n, lim))
                fails += 1
            else:
                print('   OK       %-22s %4d / %s' % (name, n, lim or '-'))

            if '간단한 설명' in head or 'short description' in head.lower():
                px = text_width(body)
                if px is None:
                    print('            (글꼴이 없어 폭은 못 쟀습니다)')
                elif px > ONE_LINE:
                    lines = wrap_at(body, ONE_LINE)
                    tail = lines[-1]
                    print('   큰글씨   %s — %d줄로 접힙니다 (폭 %.0f > %.0f)'
                          % (name, len(lines), px, ONE_LINE))
                    for l in lines:
                        print('            | %s' % l)
                    # 2026-11-17부터 실패로 치지 않는다 — 한 줄 맞춤보다 검색
                    # 유입을 택했다 (listing.md). 어떻게 접히는지만 알린다.
                    if text_width(tail) < ONE_LINE * 0.45:
                        print('            └ 끝에 「%s」만 남습니다 (참고).' % tail)
                else:
                    print('            큰 글씨 한 줄에 들어갑니다 '
                          '(폭 %.0f / %.0f)' % (px, ONE_LINE))

            for lineno, ln in wrapped_prose(body):
                print('   줄바꿈   %s %d행: %s…' % (name, lineno, ln[:38]))
                print('            └ 줄글을 접지 마십시오. 한 문단은 한 줄로.')
                fails += 1

    if fails:
        print('\n%d건. 고치고 다시 검사하십시오.' % fails)
        return 1
    print('\n모두 통과. 그대로 붙여넣으셔도 됩니다.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
