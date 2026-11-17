# -*- coding: utf-8 -*-
"""Fake portfolio for the **English** store screenshots.

Same idea as make_demo_data.py: prices and buy dates are real (public),
share counts are invented. US-listed ETFs in USD accounts, because an
English reader should not have to decode Korean fund names.

Usage:  python tools/make_demo_data_en.py
"""
import io
import json
import datetime
import urllib.request

OUT = 'docs/store/demo_portfolio_en.json'
H = {'User-Agent': 'Mozilla/5.0'}


def yahoo(ticker, **q):
    url = 'https://query1.finance.yahoo.com/v8/finance/chart/%s?%s' % (
        ticker, '&'.join('%s=%s' % kv for kv in q.items()))
    raw = urllib.request.urlopen(
        urllib.request.Request(url, headers=H), timeout=30).read()
    return json.loads(raw)['chart']['result'][0]


def now_price(ticker):
    m = yahoo(ticker, interval='1d', range='1d')['meta']
    return (float(m['regularMarketPrice']),
            float(m.get('previousClose') or m['chartPreviousClose']))


def closes(ticker, a, b):
    r = yahoo(ticker, interval='1d',
              period1=int(a.timestamp()), period2=int(b.timestamp()))
    out = {}
    for t, c in zip(r['timestamp'], r['indicators']['quote'][0]['close']):
        if c is not None:
            out[datetime.datetime.fromtimestamp(t).date()] = float(c)
    return out


def close_near(series, day):
    return min(series.items(), key=lambda kv: abs(
        (kv[0] - day.date()).days))[1]


def ms(d):
    return int(d.timestamp() * 1000)


# (ticker, name, target %, drift %p, wanted unrealized return)
PLAN = [
    ('Roth IRA', 40_000, 3.0, [
        ('VOO', 'Vanguard S&P 500 ETF', 50, +6.0, 0.11),
        ('VXUS', 'Vanguard Total Intl Stock', 30, -4.0, 0.07),
        ('BND', 'Vanguard Total Bond Market', 20, -2.0, 0.01),
    ]),
    ('Traditional IRA', 21_000, 3.0, [
        ('VTI', 'Vanguard Total Stock Market', 40, +1.5, 0.11),
        ('VEA', 'Vanguard Developed Markets', 30, -1.0, 0.05),
        ('BND', 'Vanguard Total Bond Market', 30, -0.5, 0.00),
    ]),
    ('Brokerage', 17_000, 5.0, [
        ('QQQ', 'Invesco QQQ Trust', 60, +8.5, 0.12),
        ('SCHD', 'Schwab US Dividend Equity', 40, -8.5, 0.06),
    ]),
]

CANDIDATES = [datetime.datetime(y, m, 10, 10, 30)
              for y, m in ([(2025, m) for m in range(3, 13)] +
                           [(2026, m) for m in range(1, 5)])]


def pick_lots(series, px, shares, want):
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
                    best = (gap, [(n1, d1, round(p1, 2)), (n2, d2, round(p2, 2))])
    return best[1]


cache_now, cache_hist = {}, {}
out, log = [], []

for name, total, thr, rows in PLAN:
    items = []
    for tk, label, tgt, drift, want in rows:
        if tk not in cache_now:
            cache_now[tk] = now_price(tk)
        px, prev = cache_now[tk]
        shares = round(total * (tgt + drift) / 100.0 / px)
        if tk not in cache_hist:
            cache_hist[tk] = closes(tk, datetime.datetime(2025, 2, 20),
                                    datetime.datetime(2026, 8, 1))
        lots = pick_lots(cache_hist[tk], px, shares, want)
        txs = [{'id': '%s-%s-%d' % (name, tk, k), 'date': ms(d),
                'quantity': n, 'price': pr}
               for k, (n, d, pr) in enumerate(lots, 1)]
        avg = sum(t['price'] * t['quantity'] for t in txs) / shares
        items.append({
            'id': '%s-%s' % (name, tk), 'name': label, 'ticker': tk,
            'market': 'US', 'isCash': False, 'inWeight': True,
            'targetWeight': tgt, 'shares': shares,
            'avgPrice': round(avg, 2), 'currentPrice': px,
            'previousClose': prev, 'transactions': txs,
            'createdAt': lots[0][1].strftime('%Y-%m-%d'),
        })
        log.append('  %-28s %4d sh @ %8.2f  avg %8.2f  target %2d%%' % (
            label, shares, px, avg, tgt))
    val = sum(i['shares'] * i['currentPrice'] for i in items)
    log.append('%s total $%s\n' % (name, '{:,.0f}'.format(val)))
    out.append({
        'id': name, 'name': name, 'currency': 'USD',
        'commissionEnabled': False, 'commissionRate': 0.0,
        'exchangeAuto': True, 'exchangeRate': 1380.0,
        'rebalancingThreshold': thr, 'items': items,
        'lastUpdated': ms(datetime.datetime.now()),
        'additionalInvestment': 0,
    })

io.open(OUT, 'w', encoding='utf-8').write(
    json.dumps(out, ensure_ascii=False, indent=1))
print('\n'.join(log))
print('-> ' + OUT)
