# -*- coding: utf-8 -*-
"""폰 스크린샷을 스토어에 올릴 수 있는 그림으로 감싼다.

왜 감싸나 — 두 가지다.

  1. **비율.** Play는 긴 쪽이 짧은 쪽의 두 배를 넘으면 안 받는다. 요즘 폰은
     20:9(1080×2400 = 2.22배)라 **찍은 그대로는 업로드가 막힌다.**
  2. 목록에서는 그림이 손톱만 하게 보인다. 한 줄 설명이 붙어 있어야
     무엇을 보여주는 화면인지 알아본다.

바탕은 앱 헤더와 같은 딥그린이다. 스토어에서 본 색이 앱을 열었을 때
그대로 나오는 편이 낫다.

쓰는 법:  python tools/frame_screenshots.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icons import BRAND, ACCENT, LIGHT  # noqa: E402
from make_store_assets import _font  # noqa: E402

SRC = 'docs/store/screenshots'
OUT = 'docs/store/screenshots/framed'

W, H = 1440, 2560          # 16:9 — 두 배 규칙 안에 넉넉히 든다
SHOT_W = 1030
SIDE_PAD = (W - SHOT_W) // 2
BOTTOM = 44
RADIUS = 34

# 다섯 장이 한 편의 이야기다 —
# 「흩어진 걸 모아서 → 얼마나 틀어졌는지 보고 → 몇 주를 사고팔지 알고 →
#   지나고 나서 얼마였는지 본다」
CAPS = [
    ('1_asset',  '흩어진 계좌를 한곳에서'),
    ('2_drift',  '목표에서 얼마나 벗어났는지'),
    ('3_plan',   '몇 주를 사고팔지 계산합니다'),
    ('4_settle', '이번 달은 얼마였는지'),
    ('5_item',   '종목마다 수량 · 단가 · 비중'),
]


def rounded(img, r):
    """모서리를 깎는다. 화면 네 귀퉁이가 각지면 그림이 아니라 캡처로 보인다."""
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.size[0] - 1,
                                         img.size[1] - 1], r, fill=255)
    out = img.convert('RGBA')
    out.putalpha(m)
    return out


def caption_font(draw):
    """**다섯 장이 같은 글자 크기**를 쓴다.

    장마다 따로 맞추면 짧은 문구만 커져, 목록에 나란히 놓였을 때 크기가
    들쭉날쭉해 보인다. 가장 긴 문구를 기준으로 한 번만 정한다.
    """
    budget = W - 150
    size = 74
    while size > 40:
        f = _font(size)
        if max(draw.textlength(c, font=f) for _, c in CAPS) <= budget:
            return f
        size -= 2
    return _font(40)


def frame(path, caption, font):
    shot = Image.open(path).convert('RGB')
    h = round(shot.size[1] * SHOT_W / shot.size[0])
    shot = rounded(shot.resize((SHOT_W, h), Image.LANCZOS), RADIUS)

    img = Image.new('RGB', (W, H), BRAND[:3])
    y = H - BOTTOM - h

    # 그림자 — 딥그린 위에 딥그린 화면이 얹히므로 경계가 없으면 뭉개진다
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [SIDE_PAD, y + 10, SIDE_PAD + SHOT_W, y + h + 10],
        RADIUS, fill=(0, 0, 0, 105))
    img.paste(Image.alpha_composite(
        img.convert('RGBA'), sh.filter(ImageFilter.GaussianBlur(22))
    ).convert('RGB'), (0, 0))
    img.paste(shot, (SIDE_PAD, y), shot)

    d = ImageDraw.Draw(img)

    tw = d.textlength(caption, font=font)
    d.text(((W - tw) / 2, (y - font.size) / 2 + 4), caption, font=font,
           fill=LIGHT[:3])

    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    font = caption_font(ImageDraw.Draw(Image.new('RGB', (W, H))))
    for name, cap in CAPS:
        src = os.path.join(SRC, name + '.png')
        if not os.path.exists(src):
            print('  없음: %s' % src)
            continue
        img = frame(src, cap, font)
        dst = os.path.join(OUT, name + '.png')
        img.save(dst)
        print('  %-34s %dx%d  %s' % (dst, img.size[0], img.size[1], cap))
    print('\n  → %s 를 Play Console에 올리십시오.' % OUT)


if __name__ == '__main__':
    main()
