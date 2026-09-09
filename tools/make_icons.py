# -*- coding: utf-8 -*-
"""앱 아이콘 자산을 한 번에 만든다.

마크: 「목표 비중」 — 네 조각으로 나뉜 고리(포트폴리오)와 가운데 점(목표).
과녁이자 원형 그래프로 동시에 읽힌다.

손으로 그린 PNG를 다섯 해상도에 흩어 두면 하나만 고쳐도 나머지가 안 맞는다.
치수를 여기 한 곳에 두고 전부 다시 뽑는다.

쓰는 법:  python tools/make_icons.py
"""
import os

from PIL import Image, ImageDraw

# ── 색 (앱이 실제로 쓰는 값과 같아야 홈 화면과 앱 안이 이어진다) ──
BRAND = (14, 79, 73, 255)     # #0E4F49  딥그린 · 앱 헤더와 같은 색
MINT = (143, 231, 176, 255)   # #8FE7B0  딥그린 위 강조색
CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)

# ── 치수 (보이는 아이콘 한 변에 대한 비율) ──
#
# 어댑티브 아이콘은 108 중 가운데 72만 보인다는 보장이 있다. 그래서 비율의
# 기준은 캔버스가 아니라 **보이는 크기**다. 캔버스를 기준으로 잡으면 마크가
# 실제로는 1.5배 크게 보인다.
RING_OUTER = 0.325   # 고리 바깥 반지름
RING_WIDTH = 0.095   # 고리 두께
DOT = 0.072          # 가운데 점 반지름
GAP = 0.042          # 십자 틈 너비
CORNER = 0.223       # 옛 아이콘 모서리 (안드로이드가 쓰는 값에 가깝게)

SUPER = 4            # 곱해 그렸다 줄인다 — PIL은 계단이 지므로

RES = 'android/app/src/main/res'


def render(canvas, visible, bg, mark, hole, rounded=False):
    """마크를 그린다.

    canvas   최종 그림 한 변 (px)
    visible  실제로 보이는 크기 (px). 어댑티브는 canvas의 2/3.
    bg       바탕색. None이면 투명.
    mark     고리와 점의 색.
    hole     고리 안쪽과 십자 틈을 무엇으로 뚫을지.
             바탕이 있으면 바탕색, 투명 자산이면 CLEAR.
    """
    c = canvas * SUPER
    v = visible * SUPER
    img = Image.new('RGBA', (c, c), CLEAR)
    d = ImageDraw.Draw(img)
    mid = c / 2

    if bg is not None:
        if rounded:
            d.rounded_rectangle([0, 0, c - 1, c - 1], radius=CORNER * v, fill=bg)
        else:
            d.rectangle([0, 0, c, c], fill=bg)

    outer = RING_OUTER * v
    inner = outer - RING_WIDTH * v
    dot = DOT * v
    gap = GAP * v / 2

    d.ellipse([mid - outer, mid - outer, mid + outer, mid + outer], fill=mark)
    d.ellipse([mid - inner, mid - inner, mid + inner, mid + inner], fill=hole)

    # 십자로 갈라 네 조각을 만든다 — 과녁으로 읽히는 자리다.
    pad = outer + 2
    d.rectangle([mid - gap, mid - pad, mid + gap, mid + pad], fill=hole)
    d.rectangle([mid - pad, mid - gap, mid + pad, mid + gap], fill=hole)

    d.ellipse([mid - dot, mid - dot, mid + dot, mid + dot], fill=mark)

    return img.resize((canvas, canvas), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print('  %-58s %dx%d' % (path.split('res/')[-1], *img.size))


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

    # 밀도별 배수. mdpi가 1배.
    densities = [
        ('mdpi', 1.0),
        ('hdpi', 1.5),
        ('xhdpi', 2.0),
        ('xxhdpi', 3.0),
        ('xxxhdpi', 4.0),
    ]

    print('── 어댑티브 아이콘 (전경) ──')
    for name, k in densities:
        n = int(round(108 * k))
        img = render(n, n * 2 // 3, None, MINT, CLEAR)
        save(img, '%s/mipmap-%s/ic_launcher_foreground.png' % (RES, name))

    # 안드로이드 13 테마 아이콘. 시스템이 색을 입히므로 흰 실루엣으로 둔다.
    print('── 어댑티브 아이콘 (단색 · 안드로이드 13 테마) ──')
    for name, k in densities:
        n = int(round(108 * k))
        img = render(n, n * 2 // 3, None, WHITE, CLEAR)
        save(img, '%s/mipmap-%s/ic_launcher_monochrome.png' % (RES, name))

    print('── 옛 아이콘 (안드로이드 7 이하) ──')
    for name, k in densities:
        n = int(round(48 * k))
        img = render(n, n, BRAND, MINT, BRAND, rounded=True)
        save(img, '%s/mipmap-%s/ic_launcher.png' % (RES, name))

    # 상태바 아이콘은 **알파만** 쓴다. 색을 넣으면 안드로이드 5 이상에서
    # 흰 덩어리로 뭉개진다 — 지금까지 런처 아이콘을 그대로 써서 그랬다.
    print('── 알림(상태바) 아이콘 ──')
    for name, k in densities:
        n = int(round(24 * k))
        img = render(n, int(n * 0.92), None, WHITE, CLEAR)
        save(img, '%s/drawable-%s/ic_stat_notify.png' % (RES, name))

    # 미리 볼 큰 그림
    save(render(512, 512, BRAND, MINT, BRAND, rounded=True),
         'docs/review/icon_preview_512.png')
    save(render(512, 512, None, MINT, CLEAR), 'docs/review/icon_mark_512.png')

    print('\n끝. 색을 바꾸려면 이 파일 위쪽 BRAND · MINT만 고치면 된다.')


if __name__ == '__main__':
    main()
