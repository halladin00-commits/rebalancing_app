import json
from datetime import datetime, timezone
from pykrx import stock as krx

stocks = []

for market in ['KOSPI', 'KOSDAQ']:
    m_code = 'KS' if market == 'KOSPI' else 'KQ'
    tickers = krx.get_market_ticker_list(market=market)
    for ticker in tickers:
        try:
            name = krx.get_market_ticker_name(ticker)
            if name:
                stocks.append({"t": ticker, "n": name, "m": m_code})
        except Exception:
            pass

print(f"수집 완료: {len(stocks)}개 종목")

with open('stocks.json', 'w', encoding='utf-8') as f:
    json.dump(stocks, f, ensure_ascii=False, separators=(',', ':'))

meta = {
    "updated_at": datetime.now(timezone.utc).isoformat(),
    "total": len(stocks),
    "kr_stocks": len(stocks)
}
with open('meta.json', 'w', encoding='utf-8') as f:
    json.dump(meta, f)

print(f"저장 완료: stocks.json ({len(stocks)}건), meta.json")
