# -*- coding: utf-8 -*-
"""스토어 등록정보에 올릴 그림을 만든다.

앱 안에 들어가는 그림은 `make_icons.py`가 만든다. 여기서 만드는 것은
**Play Console에 따로 올리는** 것들이다 — 앱에는 안 들어간다.

  docs/store/icon_512.png       앱 아이콘   512×512  (필수)
  docs/store/feature_1024.png   그래픽 이미지 1024×500 (필수)

**마크도 비중 막대도 앱에서 가져다 쓴다.** 여기서 따로 그리면 스토어에서
본 것과 앱을 열고 보는 것이 달라진다 — 사용자는 둘을 오가며 본다.

쓰는 법:  python tools/make_store_assets.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icons import BRAND, ACCENT, LIGHT, CLEAR, full  # noqa: E402

OUT = 'docs/store'

FEATURE_W, FEATURE_H = 1024, 500   # Play Console 고정값
ICON = 512                         # Play Console 고정값

# ── 앱이 쓰는 색 (lib/main.dart · lib/widgets/weight_bar.dart) ──
WARN = (156, 74, 22)        # #9C4A16  허용을 넘은 칸
OK_FILL = (169, 199, 191)   # #A9C7BF  허용 안에 든 칸
AMBER = (242, 195, 107)     # #F2C36B  딥그린 위 경고 숫자
CARD = (30, 94, 88)         # 딥그린 위에 흰색을 옅게 깐 것과 같은 결


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    img.convert('RGB').save(p, quality=95)
    print('  %-28s %dx%d' % (name, *img.size))


def _fit(draw, lines, budget, start, floor=30, bold=True):
    """[budget] 안에 들어가는 가장 큰 글자 크기를 찾는다.

    **눈으로 맞추지 않는다.** 글꼴이 다른 기계에서 만들면 그때 잘린다.
    실제로 한 번 잘려서 오른쪽 카드에 글자가 가렸다.
    """
    size = start
    while size > floor:
        f = _font(size, bold)
        if max(draw.textlength(t, font=f) for t in lines) <= budget:
            return f
        size -= 2
    return _font(floor, bold)


def _font(size, bold=True):
    names = ['malgunbd.ttf', 'malgun.ttf'] if bold else ['malgun.ttf']
    for n in names:
        for d in (r'C:\Windows\Fonts', '/usr/share/fonts/truetype'):
            p = os.path.join(d, n)
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, size)
                except Exception:
                    pass
    return ImageFont.load_default()


def make_icon():
    """스토어 아이콘 512×512.

    **모서리를 미리 깎지 않는다.** Play가 알아서 깎는다. 깎아 올리면
    이중으로 깎여 귀퉁이가 비뚤어진다.

    `hole`에 바탕색을 넣는다. 투명으로 두면 RGB로 저장할 때 검게 메워져
    틈과 고리 안쪽이 검은 아이콘이 나온다.
    """
    return full(ICON, ICON, BRAND, BRAND, rounded=False)


def _weight_bar(w, h, segments, threshold, scale=4):
    """앱의 비중 막대를 그대로 그린다.

    `lib/widgets/weight_bar.dart`와 같은 규칙이다 —

      · 칸 너비는 **현재 비중**, 세로선은 **목표 비중** 자리
      · 허용 편차 안에 들면 무채색, 넘으면 경고색
      · 방향(초과·미달)은 색이 아니라 **칸이 세로선보다 넓은가**가 말한다

    segments: [(현재, 목표), …]
    """
    W, H = w * scale, h * scale
    img = Image.new('RGBA', (W, H), CLEAR)
    d = ImageDraw.Draw(img)
    r = H / 2

    total = sum(max(0.0, c) for c, _ in segments)
    if total <= 0:
        return img.resize((w, h), Image.LANCZOS)

    x = 0.0
    for cur, tgt in segments:
        seg_w = W * (cur / total)
        over = abs(cur - tgt) >= threshold
        d.rounded_rectangle([x, 0, x + seg_w - scale, H], radius=r,
                            fill=WARN if over else OK_FILL)
        x += seg_w

    # 목표 세로선 — 마지막 경계(100%)는 긋지 않는다
    acc = 0.0
    for i in range(len(segments) - 1):
        acc += segments[i][1]
        if 0 < acc < 100:
            lx = W * acc / 100.0
            d.rectangle([lx - scale, -1, lx + scale, H + 1], fill=LIGHT[:3])

    return img.resize((w, h), Image.LANCZOS)


def make_feature():
    """그래픽 이미지 1024×500.

    **로고만 얹지 않는다.** 스토어 목록에서 눈에 남는 것은 이름이 아니라
    「이 앱이 무엇을 보여주는가」다. 그래서 앱이 실제로 그리는 비중 막대를
    그대로 넣는다 — 받고 나서 첫 화면에 같은 것이 나온다.

    작게 줄여 보이기도 하므로 글자는 큰 것 두 줄까지만 둔다.
    """
    img = Image.new('RGB', (FEATURE_W, FEATURE_H), BRAND[:3])
    d = ImageDraw.Draw(img)

    PAD = 64

    # ── 머리: 마크 + 이름 (작게) ──
    mark_px = 46
    mark = full(mark_px, mark_px, CLEAR, CLEAR)
    img.paste(mark, (PAD, PAD - 4), mark)
    d.text((PAD + mark_px + 16, PAD + 1), 'REBALANCING',
           font=_font(31), fill=LIGHT[:3])

    # ── 오른쪽 카드 자리를 먼저 잡는다 ──
    #
    # 글자를 먼저 그리면 카드가 그 위에 얹혀 글자를 가린다. 자리를 정하고
    # **남는 폭에 글자를 맞춘다.**
    card_x, card_y = 594, 172
    card_w, card_h = FEATURE_W - card_x - PAD, 162

    # ── 문장 두 줄 — **무엇을 하는 앱인지부터** ──
    head = ('주식 포트폴리오를', '비중대로 관리합니다')
    f_head = _fit(d, head, card_x - PAD - 40, 60)
    line_h = int(f_head.size * 1.28)
    y = 186
    for line in head:
        d.text((PAD, y), line, font=f_head, fill=LIGHT[:3])
        y += line_h
    d.rounded_rectangle([card_x, card_y, card_x + card_w, card_y + card_h],
                        radius=22, fill=CARD)

    bar_w = card_w - 56
    bar = _weight_bar(bar_w, 22, [(47, 40), (30, 30), (23, 30)], threshold=5)
    img.paste(bar, (card_x + 28, card_y + 40), bar)

    f_note = _font(21, bold=False)
    d.text((card_x + 28, card_y + 90), '세로선이 목표 비중',
           font=f_note, fill=(214, 224, 221))
    f_pp = _font(27)
    pp = '+7.0%p'
    d.text((card_x + card_w - 28 - d.textlength(pp, font=f_pp),
            card_y + 86), pp, font=f_pp, fill=AMBER)

    # ── 아래 한 줄 ──
    f_sub = _fit(d, ['벗어난 만큼, 몇 주를 사고팔지 계산해 드립니다'],
                 FEATURE_W - PAD * 2, 30, floor=20, bold=False)
    d.text((PAD, FEATURE_H - PAD - 30),
           '벗어난 만큼, 몇 주를 사고팔지 계산해 드립니다',
           font=f_sub, fill=ACCENT[:3])

    return img


def main():
    print('스토어 자산')
    save(make_icon(), 'icon_512.png')
    save(make_feature(), 'feature_1024.png')
    print('\n  → docs/store/ 에 있습니다. Play Console에 올리십시오.')


if __name__ == '__main__':
    main()
