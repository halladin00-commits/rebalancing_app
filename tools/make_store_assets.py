# -*- coding: utf-8 -*-
"""스토어 등록정보에 올릴 그림을 만든다.

앱 안에 들어가는 그림은 `make_icons.py`가 만든다. 여기서 만드는 것은
**Play Console에 따로 올리는** 것들이다 — 앱에는 안 들어간다.

  docs/store/icon_512.png       앱 아이콘   512×512  (필수)
  docs/store/feature_1024.png   그래픽 이미지 1024×500 (필수)

**마크는 `make_icons.py`에서 가져다 쓴다.** 여기서 다시 그리면 스토어의
아이콘과 폰에 깔린 아이콘이 조금씩 달라진다 — 나란히 놓고 볼 일이 없어
눈치채기 어려운데, 사용자는 홈 화면과 스토어를 오가며 본다.

쓰는 법:  python tools/make_store_assets.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icons import BRAND, ACCENT, LIGHT, CLEAR, full  # noqa: E402

OUT = 'docs/store'

# 그래픽 이미지 규격 (Play Console 고정값)
FEATURE_W, FEATURE_H = 1024, 500

# 아이콘 규격 (Play Console 고정값)
ICON = 512


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    img.convert('RGB').save(p, quality=95)
    print('  %-28s %dx%d' % (name, *img.size))


def make_icon():
    """스토어 아이콘 512×512.

    **모서리를 둥글게 만들지 않는다.** Play가 알아서 깎는다. 미리 깎아
    올리면 이중으로 깎여 귀퉁이가 비뚤어진다.
    """
    # `hole`에 바탕색을 넣는다. 투명으로 두면 RGB로 저장할 때 **검게**
    # 메워져, 틈과 고리 안쪽이 검은 아이콘이 나온다.
    return full(ICON, ICON, BRAND, BRAND, rounded=False)


def _font(size, bold=True):
    """글자. 시스템에 있는 것을 쓴다 — 없으면 기본 글꼴로 떨어진다."""
    names = (['malgunbd.ttf', 'malgun.ttf'] if bold else ['malgun.ttf'])
    for n in names:
        for d in (r'C:\Windows\Fonts', '/usr/share/fonts'):
            p = os.path.join(d, n)
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, size)
                except Exception:
                    pass
    return ImageFont.load_default()


def make_feature():
    """그래픽 이미지 1024×500.

    스토어 목록에서 **제목 위에 깔리는 넓은 띠**다. 작게 줄여 보이기도
    하므로 글자를 많이 넣지 않는다 — 마크와 이름, 한 줄 설명까지다.

    바탕은 앱 헤더와 같은 딥그린이다. 스토어에서 본 색이 앱을 열었을 때
    그대로 나와야 「같은 것」으로 읽힌다.
    """
    img = Image.new('RGB', (FEATURE_W, FEATURE_H), BRAND[:3])
    d = ImageDraw.Draw(img)

    # 마크 — 타일 없이 마크만 얹는다. 배경이 이미 딥그린이라 타일이 겹치면
    # 네모가 한 겹 더 생겨 지저분하다.
    # `full`이 안에서 초과표본해 매끈하게 그려 준다.
    mark_px = 168
    mark = full(mark_px, mark_px, CLEAR, CLEAR)
    mx, my = 96, 118
    img.paste(mark, (mx, my), mark)

    # 이름
    f_name = _font(78)
    d.text((mx + mark_px + 30, my + 34), 'REBALANCING',
           font=f_name, fill=LIGHT[:3])

    # 한 줄 설명 — 마크 왼쪽 변에 맞춘다
    # **한 줄이 넘치면 안 된다.** 들어가는 크기를 재서 줄인다 — 글꼴이
    # 기기마다 다를 수 있어 눈으로 맞춰 두면 언젠가 잘린다.
    sub = '목표 비중에서 얼마나 벗어났는지, 몇 주를 사고팔지'
    right_edge = FEATURE_W - mx
    size = 44
    while size > 22:
        f_sub = _font(size, bold=False)
        if d.textlength(sub, font=f_sub) <= right_edge - mx:
            break
        size -= 2
    d.text((mx, my + mark_px + 46), sub, font=f_sub, fill=ACCENT[:3])

    return img


def main():
    print('스토어 자산')
    save(make_icon(), 'icon_512.png')
    save(make_feature(), 'feature_1024.png')
    print('\n  → docs/store/ 에 있습니다. Play Console에 올리십시오.')


if __name__ == '__main__':
    main()
