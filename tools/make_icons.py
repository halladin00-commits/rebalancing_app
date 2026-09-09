# -*- coding: utf-8 -*-
"""앱 아이콘 자산을 한 번에 만든다.

마크: 「목표 비중」 — 세 조각으로 나뉜 고리와 가운데 점.
과녁이자 원형 그래프로 동시에 읽힌다.

치수와 색은 **채택된 시안을 픽셀로 재서** 가져왔다. 눈으로 보고 옮겨 그리면
조각 수도 비율도 틀린다 (실제로 4등분으로 잘못 그린 적이 있다).
잰 값은 아래 주석에 남긴다.

쓰는 법:
    python tools/make_icons.py            # 자산 전체를 res/ 에 굽는다
    python tools/make_icons.py --preview  # docs/review/ 에 미리보기만
"""
import math
import os
import sys

from PIL import Image, ImageDraw

# ── 색 ──
#
# 시안 원본에서 잰 값: 바탕 (9,82,78) · 민트 (119,209,174) · 밝은색 (249,247,240)
# 앱이 실제로 쓰는 값으로 맞춘다. 홈 화면과 앱 안이 이어져야 해서다.
BRAND = (14, 79, 73, 255)     # #0E4F49  딥그린 · 앱 헤더·스플래시와 같은 색
ACCENT = (143, 231, 176, 255)  # #8FE7B0  딥그린 위 강조색
LIGHT = (251, 248, 241, 255)   # #FBF8F1  앱 크림 배경색
CLEAR = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)

# ── 치수 (보이는 아이콘 한 변에 대한 비율) ──
#
# 어댑티브 아이콘은 108 중 가운데 72만 보인다는 보장이 있다. 그래서 비율의
# 기준은 캔버스가 아니라 **보이는 크기**다.
#
# 값은 시안 원본을 재서 얻었다. 재는 법:
#   1) 원본을 6배 확대하고 타일 경계를 소수점으로 찾는다
#   2) 타일이 정사각형이 아니면(원본은 가로로 3.6% 늘어나 있었다)
#      **정사각형으로 편 뒤** 잰다. 안 그러면 각도마다 반지름이 달라진다
#   3) 점과 고리는 가장자리 한 점이 아니라 **넓이**로 잰다 — 잡음에 강하다
# 이 값으로 계산한 고리 넓이가 실제와 0.4% 차이였다.
RING_OUTER = 0.307   # 고리 바깥 반지름 (잰 값 0.3066)
RING_INNER = 0.190   # 고리 안쪽 반지름 (잰 값 0.1898)
DOT = 0.058          # 가운데 점 반지름 (넓이로 잰 값 0.0582)
GAP = 0.0355         # 틈 **폭** (잰 값 0.0355)
CORNER = 0.2025      # 옛 아이콘 모서리 (잰 값)

# 틈이 놓이는 자리. 12시가 0이고 시계 방향.
GAPS = (0.0, 120.0, 240.0)

# 조각의 색. 12시부터 시계 방향으로 오른쪽 → 아래 → 왼쪽.
# 원본은 **오른쪽 조각과 가운데 점만** 진한 민트고 나머지 둘은 밝은색이다.
SEGMENT_ROLES = ('accent', 'light', 'light')

SUPER = 4            # 곱해 그렸다 줄인다 — PIL은 계단이 지므로
RES = 'android/app/src/main/res'


def render(canvas, visible, bg, roles, dot_role, hole, rounded=False):
    """마크를 그린다.

    canvas    최종 그림 한 변 (px)
    visible   실제로 보이는 크기 (px). 어댑티브는 canvas의 2/3.
    bg        바탕색. None이면 투명.
    roles     조각 세 개의 색 (12시부터 시계 방향).
    dot_role  가운데 점 색.
    hole      고리 안쪽과 틈을 무엇으로 뚫을지.
    """
    c = canvas * SUPER
    v = visible * SUPER
    img = Image.new('RGBA', (c, c), CLEAR)
    d = ImageDraw.Draw(img)
    mid = c / 2.0

    if bg is not None:
        if rounded:
            d.rounded_rectangle([0, 0, c - 1, c - 1], radius=CORNER * v, fill=bg)
        else:
            d.rectangle([0, 0, c, c], fill=bg)

    outer = RING_OUTER * v
    inner = RING_INNER * v
    box = [mid - outer, mid - outer, mid + outer, mid + outer]

    # 조각을 부채꼴로 그린다. 틈은 여기서 만들지 않는다 — 부채꼴로 틈을
    # 내면 중심으로 갈수록 좁아져 **양 변이 벌어진다.** 원본은 폭이
    # 일정한 홈이라 양 변이 평행하다 (원본에서 안쪽 0.0359, 바깥 0.0350로
    # 거의 같음을 확인했다. 부채꼴이면 1.46배 차이가 나야 한다).
    #
    # PIL의 각도는 3시가 0이고 시계 방향이라, 12시 기준에서 90을 뺀다.
    for i in range(3):
        start = GAPS[i]
        end = GAPS[(i + 1) % 3]
        if end <= start:
            end += 360.0
        d.pieslice(box, start - 90.0, end - 90.0, fill=roles[i])

    d.ellipse([mid - inner, mid - inner, mid + inner, mid + inner], fill=hole)

    # 폭이 일정한 홈을 세 개 판다 — 양 변이 평행해진다.
    half = GAP * v / 2.0
    reach = outer * 1.2
    for deg in GAPS:
        a = math.radians(deg)
        # 12시가 0, 시계 방향. 그림 좌표는 y가 아래로 간다.
        ux, uy = math.sin(a), -math.cos(a)     # 밖으로 나가는 방향
        vx, vy = math.cos(a), math.sin(a)      # 그와 직각
        d.polygon([
            (mid + vx * half, mid + vy * half),
            (mid + ux * reach + vx * half, mid + uy * reach + vy * half),
            (mid + ux * reach - vx * half, mid + uy * reach - vy * half),
            (mid - vx * half, mid - vy * half),
        ], fill=hole)

    # 홈보다 **나중에** 그린다. 먼저 그리면 홈이 점을 가른다.
    dot = DOT * v
    d.ellipse([mid - dot, mid - dot, mid + dot, mid + dot], fill=dot_role)

    return img.resize((canvas, canvas), Image.LANCZOS)


def full(canvas, visible, bg, hole, rounded=False):
    """색이 다 들어간 판."""
    role = {'accent': ACCENT, 'light': LIGHT}
    return render(canvas, visible, bg,
                  tuple(role[r] for r in SEGMENT_ROLES), ACCENT, hole,
                  rounded=rounded)


def mono(canvas, visible):
    """단색 판. 시스템이 색을 입히므로 흰 실루엣으로 둔다."""
    return render(canvas, visible, None, (WHITE, WHITE, WHITE), WHITE, CLEAR)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print('  %-58s %dx%d' % (path.replace('\\', '/').split('res/')[-1], *img.size))


DENSITIES = [('mdpi', 1.0), ('hdpi', 1.5), ('xhdpi', 2.0),
             ('xxhdpi', 3.0), ('xxxhdpi', 4.0)]


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    preview_only = '--preview' in sys.argv

    print('── 미리보기 ──')
    save(full(512, 512, BRAND, BRAND, rounded=True), 'docs/review/icon_512.png')
    save(full(512, 512, None, CLEAR), 'docs/review/icon_mark_512.png')
    save(mono(512, 512), 'docs/review/icon_mono_512.png')
    for n in (192, 96, 64, 48, 32):
        save(full(n, n, BRAND, BRAND, rounded=True),
             'docs/review/icon_%d.png' % n)

    if preview_only:
        print('\n미리보기만 만들었다. 자산을 굽으려면 --preview 없이 다시.')
        return

    print('── 어댑티브 아이콘 (전경) ──')
    for name, k in DENSITIES:
        n = int(round(108 * k))
        save(full(n, n * 2 // 3, None, CLEAR),
             '%s/mipmap-%s/ic_launcher_foreground.png' % (RES, name))

    print('── 어댑티브 아이콘 (단색 · 안드로이드 13 테마) ──')
    for name, k in DENSITIES:
        n = int(round(108 * k))
        save(mono(n, n * 2 // 3),
             '%s/mipmap-%s/ic_launcher_monochrome.png' % (RES, name))

    print('── 옛 아이콘 (안드로이드 7 이하) ──')
    for name, k in DENSITIES:
        n = int(round(48 * k))
        save(full(n, n, BRAND, BRAND, rounded=True),
             '%s/mipmap-%s/ic_launcher.png' % (RES, name))

    # 상태바 아이콘은 **알파만** 쓴다. 색을 넣으면 안드로이드 5 이상에서
    # 흰 덩어리로 뭉갠다.
    print('── 알림(상태바) 아이콘 ──')
    for name, k in DENSITIES:
        n = int(round(24 * k))
        save(mono(n, int(n * 0.92)),
             '%s/drawable-%s/ic_stat_notify.png' % (RES, name))

    print('\n끝. 색은 이 파일 위쪽 BRAND · ACCENT · LIGHT만 고치면 된다.')


if __name__ == '__main__':
    main()
