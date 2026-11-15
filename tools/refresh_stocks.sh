#!/usr/bin/env bash
# 앱에 넣어 두는 종목 목록(assets/kr_stocks.json)을 서버의 오늘 목록으로 바꾼다.
#
# 이 목록은 받아 둔 목록이 없는 폰(첫 실행·인터넷 없음)이 쓴다. 출시한 날에서
# 멈춰 있으므로 **스토어에 올릴 빌드를 만들기 전에 한 번 돌린다.**
#
#   tools/refresh_stocks.sh
set -euo pipefail
cd "$(dirname "$0")/.."

url=https://halladin00-commits.github.io/stock-data/stocks.json
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsS -m 120 -o "$tmp" "$url"

# 서버 목록이 한쪽이 빈 채로 나간 적이 있다 — 모자라면 바꾸지 않는다
python -I - "$tmp" <<'EOF'
import collections, io, json, sys
d = json.load(io.open(sys.argv[1], encoding='utf-8-sig'))
c = collections.Counter(
    'KR ETF' if s.get('ty') == 'E' else 'US' if s['m'] == 'US' else 'KR'
    for s in d)
print(dict(c))
need = {'KR': 2000, 'KR ETF': 100, 'US': 8000}
short = [k for k, n in need.items() if c[k] < n]
if short:
    sys.exit('short: %s - not replaced' % ', '.join(short))
EOF

cp "$tmp" assets/kr_stocks.json
echo "assets/kr_stocks.json replaced"
