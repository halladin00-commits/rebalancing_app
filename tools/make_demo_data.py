# -*- coding: utf-8 -*-
"""스토어 스크린샷용 **가짜 포트폴리오**를 만든다.

왜 이 방식인가
  값을 손으로 지어내면 **결산이 망가진다.** 결산은 기간 시작·끝의 시세를
  야후에서 받아 계산하는데, 지어낸 현재가와 받아온 과거 시세가 어긋나
  한 달에 −9,600만원 같은 값이 나왔다.

  그래서 **시세는 진짜를 쓰고 수량만 가짜로 쓴다.** 종목코드는 공개
  정보이고, 사용자의 실제 잔고는 어디에도 들어가지 않는다.

쓰는 법:  python tools/make_demo_data.py
"""
import io
import json
import datetime
import urllib.request

OUT = 'docs/store/demo_portfolio.json'
H = {'User-Agent': 'Mozilla/5.0'}


def yahoo(ticker, **q):
    url = 'https://query1.finance.yahoo.com/v8/finance/chart/%s.KS?%s' % (
        ticker, '&'.join('%s=%s' % kv for kv in q.items()))
    raw = urllib.request.urlopen(
        urllib.request.Request(url, headers=H), timeout=30).read()
    return json.loads(raw)['chart']['result'][0]


def now_price(ticker):
    m = yahoo(ticker, interval='1d', range='1d')['meta']
    return (float(m['regularMarketPrice']),
            float(m.get('previousClose') or m['chartPreviousClose']))


def closes(ticker, a, b):
    """[a]~[b]의 일별 종가 {날짜: 값}."""
    r = yahoo(ticker, interval='1d',
              period1=int(a.timestamp()), period2=int(b.timestamp()))
    out = {}
    for t, c in zip(r['timestamp'], r['indicators']['quote'][0]['close']):
        if c is not None:
            out[datetime.datetime.fromtimestamp(t).date()] = float(c)
    return out


def close_near(series, day):
    """[day]에 가장 가까운 거래일의 종가."""
    return min(series.items(), key=lambda kv: abs(
        (kv[0] - day.date()).days))[1]


def ms(d):
    return int(d.timestamp() * 1000)


# ── 포트폴리오 설계 ──
#
# `drift`는 **목표에서 일부러 벗어나게 둔 정도**(%p)다. 전부 딱 맞으면
# 「조정 제안」 화면이 빌 것이 없다고 나와, 이 앱을 받을 이유가 담긴
# 화면을 스크린샷에 못 담는다. 한두 종목만 눈에 띄게 벌려 둔다.
# 마지막 숫자는 **노리는 평가수익률**이다.
#
# 왜 종목마다 정하나 — 날짜를 아무렇게나 집으면 전 종목이 마이너스로 나온다.
# 실제로 한 번 총 평가손익이 −409만원이 되어 스토어 첫 장이 「전부 손실난
# 앱」이 됐다. 시세는 진짜를 쓰되 **언제 샀는지**를 골라 그럴듯하게 만든다.
#
# 채권 하나는 일부러 마이너스로 둔다. 전부 파랗기만 하면 손실 색을 못 보여
# 주고, 무엇보다 그런 계좌는 없다.
PLAN = [
    ('연금저축', 40_000_000, 3.0, [
        ('360750', 'TIGER 미국S&P500', 50, +6.0, 0.11),
        ('069500', 'KODEX 200', 30, -4.0, 0.07),
        ('411060', 'ACE KRX금현물', 20, -2.0, 0.09),
    ]),
    ('ISA계좌', 21_000_000, 3.0, [
        ('360750', 'TIGER 미국S&P500', 40, +1.5, 0.11),
        ('251350', 'KODEX MSCI선진국', 30, -1.0, 0.05),
        ('273130', 'KODEX 종합채권(AA-이상)액티브', 30, -0.5, 0.00),
    ]),
    ('위탁계좌', 17_000_000, 5.0, [
        ('133690', 'TIGER 미국나스닥100', 60, +8.5, 0.12),
        ('458730', 'TIGER 미국배당다우존스', 40, -8.5, 0.06),
    ]),
]

# 매수 후보일 — 이 중 두 날을 골라 산 것으로 한다
#
# 1년 넘게 들고 있는 것으로 둔다. 몇 달 치만 후보로 두면 그 구간에 죽
# 내린 종목은 **어느 날을 골라도 마이너스**라, 채권·금 ETF가 전부 손실로
# 나왔다. 오래 들고 있는 편이 이 앱을 쓰는 사람의 모습이기도 하다.
CANDIDATES = [datetime.datetime(y, m, 10, 10, 30)
              for y, m in ([(2025, m) for m in range(3, 13)] +
                           [(2026, m) for m in range(1, 5)])]

# 종목마다 목표로 하는 **평가수익률**.
#
# 왜 정해 두나 — 날짜를 아무렇게나 고르면 전 종목이 마이너스로 나온다.
# 실제로 3~7월 아무 날이나 집었더니 총 평가손익이 −409만원이 되어,
# 스토어 첫 장이 「전부 손실난 앱」이 됐다. 시세는 진짜를 쓰되
# **언제 샀는지**를 골라 그럴듯한 수익 구간을 만든다.
def pick_lots(series, px, shares, want):
    """평균단가가 `px/(1+want)`에 가장 가까워지는 두 날·두 수량을 고른다."""
    target = px / (1.0 + want)
    best = None
    for i, d1 in enumerate(CANDIDATES):
        for d2 in CANDIDATES[i + 1:]:
            p1, p2 = close_near(series, d1), close_near(series, d2)
            for r in (0.6, 0.4):
                n1 = round(shares * r)
                n2 = shares - n1
                if n1 <= 0 or n2 <= 0:
                    continue
                avg = (p1 * n1 + p2 * n2) / shares
                gap = abs(avg - target)
                if best is None or gap < best[0]:
                    best = (gap, [(n1, d1, round(p1)), (n2, d2, round(p2))])
    return best[1]


cache_now, cache_hist = {}, {}
out = []

for name, total, thr, rows in PLAN:
    items = []
    for i, (tk, label, tgt, drift, want) in enumerate(rows):
        if tk not in cache_now:
            cache_now[tk] = now_price(tk)
        px, prev = cache_now[tk]

        shares = round(total * (tgt + drift) / 100.0 / px)

        if tk not in cache_hist:
            cache_hist[tk] = closes(
                tk, datetime.datetime(2025, 2, 20),
                datetime.datetime(2026, 8, 1))
        lots = pick_lots(cache_hist[tk], px, shares, want)
        txs = [{'id': '%s-%d' % (tk, k), 'date': ms(d),
                'quantity': n, 'price': pr}
               for k, (n, d, pr) in enumerate(lots, 1)]
        d1 = lots[0][1]

        avg = sum(t['price'] * t['quantity'] for t in txs) / shares
        items.append({
            'id': tk + 'i', 'name': label, 'ticker': tk, 'market': 'KR',
            'isCash': False, 'inWeight': True, 'targetWeight': tgt,
            'shares': shares, 'avgPrice': round(avg, 2),
            'currentPrice': px, 'previousClose': prev,
            'transactions': txs,
            'createdAt': d1.strftime('%Y-%m-%d'),
        })
        print('  %-24s %5d주 @%9s  목표 %2d%% (현재 %.1f%%)' % (
            label, shares, '{:,}'.format(int(px)), tgt,
            shares * px / total * 100))

    val = sum(i['shares'] * i['currentPrice'] for i in items)
    print('%s 합계 ₩%s\n' % (name, '{:,}'.format(int(val))))
    out.append({
        'id': name, 'name': name, 'currency': 'KRW',
        'commissionEnabled': True, 'commissionRate': 0.015,
        'exchangeAuto': True, 'exchangeRate': 1380.0,
        'priceAuto': True, 'rebalancingThreshold': thr,
        'items': items, 'lastUpdated': ms(datetime.datetime.now()),
        'additionalInvestment': 0,
    })

grand = sum(i['shares'] * i['currentPrice'] for p in out for i in p['items'])
print('총 ₩%s' % '{:,}'.format(int(grand)))
json.dump(out, io.open(OUT, 'w', encoding='utf-8'), ensure_ascii=False)
print('→ %s' % OUT)
