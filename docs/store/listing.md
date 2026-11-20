# Play Console 스토어 등록정보 (v1.2.0, 2026-11-20 출시)

지금 스토어에 올라가 있는 내용 전부입니다. 한국어·영어 둘 다 여기 있습니다.
**코드 블록(회색 상자) 안은 그대로 복사해 붙입니다.** 바깥 글은 왜 그렇게
썼는지 적은 메모입니다.

다음 판을 준비할 때도 이 파일을 고칩니다. 이전 판 문구는 git 기록에 남아
있습니다.

붙이기 전에 `python tools/check_listing.py`로 글자 수와 줄바꿈을 검사합니다.

---

## 공통 규칙

- **줄바꿈은 적은 그대로 스토어에 나갑니다.** 그래서 줄글을 중간에서 접으면
  안 됩니다. 원고를 70자에서 접어 뒀더니 스토어에 「…목표 비중을 정해 /
  둡니다.」처럼 문장 한복판에서 끊겨 나갔습니다. 한 문단은 아무리 길어도
  한 줄입니다.
- **Console의 「애셋 리뷰」 화면으로 판단하지 않습니다.** 줄바꿈이 전부 뭉쳐
  보여 실제 스토어와 다릅니다.
- **마크다운은 안 됩니다.** `**굵게**`는 별표가 그대로 보입니다. 굵게는
  `<b>…</b>`이지만 `■` 기호로 충분해 안 씁니다.
- **영어는 번역이 아닙니다.** 영어 독자는 한국어판을 보지 않습니다. 영어로
  자연스럽게 다시 썼고, 용어는 앱 영어 화면을 따릅니다(결산 = **Returns**,
  허용 편차 = **threshold**, 벗어남 = **drift**).
- **증권사 이름과 「14곳」 같은 숫자는 쓰지 않습니다.** 증권사가 화면을
  바꾸면 안 읽히는 곳이 생기고, 내건 숫자가 틀리면 별점 1개가 됩니다. 남의
  상표를 설명에 쓰는 것도 Play가 문제 삼을 수 있습니다.

---

## 출시 노트 (언어마다 500자 제한)

Play Console 「출시 노트」 칸에 상자째 붙입니다. `<ko-KR>` 같은 태그로 언어가 나뉩니다.

```
<ko-KR>
v1.2.0 — 증권사 잔고 화면을 캡처하면 종목이 들어옵니다

✨ 새로워진 것
• 잔고 캡처로 불러오기: 증권사 앱의 잔고 화면을 캡처해 고르면 종목·수량·평단가를 읽어 옵니다. 국내·미국 증권사 앱을 읽으며, 이미지는 기기 밖으로 나가지 않습니다
• 미국 종목을 한글 이름으로 찾습니다 (애플 → AAPL)
• 백업한 지 30일이 지나면 첫 화면에서 알려드립니다
• 포트폴리오 메뉴에서 리밸런싱으로 바로 갑니다

🔧 바뀐 것
• 시세는 늘 자동으로 받습니다. 포트폴리오별 「시세」 스위치를 없앴습니다. 꺼 두셨다면 다음 새로고침에 받은 시세로 바뀝니다
• 소수점 매매 수량은 늘 내림합니다. 반올림을 고르셨다면 제안 수량이 달라질 수 있습니다
• 검색에 없어 직접 입력한 종목은 현재가를 넣어야 조정 제안이 나옵니다
</ko-KR>
<en-US>
v1.2.0 — Import your holdings from a screenshot

✨ New
• Pick screenshots of your broker app's holdings screen and the app reads the stocks, quantities and average cost. Images never leave your device
• A reminder on the home screen when your last backup is over 30 days old
• Jump to Rebalance from a portfolio's menu

🔧 Changed
• Prices are always fetched; the per-portfolio switch is gone
• Fractional quantities always round down
• Holdings entered by hand need a current price
</en-US>
```

- **「바뀐 것」을 빼지 않습니다.** 쓰던 분의 숫자가 어제와 달라지는 변경은 적어 두지 않으면 버그로 읽힙니다.
- 영어판에는 한글 이름 검색을 뺐습니다. 영어 독자에게 의미가 없습니다.

---

# 한국어 (ko-KR)

## 앱 이름 (30자 제한)

```
리밸런싱 - 포트폴리오 자산배분 계산기
```

검색어 넷(리밸런싱·포트폴리오·자산배분·계산기)이 다 들어 있어 손대지 않습니다.

## 간단한 설명 (80자 제한)

```
주식·ETF 리밸런싱 계산기. ISA·연금저축·미국주식 비중과 사고팔 수량, 수익률을 한 번에
```

- **2026-11-17 결정: 한 줄 맞춤을 버리고 검색 유입을 택했습니다.** 폰에서
  세 줄쯤으로 접힙니다.
- 앱 이름에 없는 단어(주식·ETF·ISA·연금저축·미국주식·비중·수익률)를
  채웠습니다. 「ISA 리밸런싱」처럼 붙여 치는 검색을 노립니다.
- 단어를 더 넣지 않습니다. 검색어만 늘어놓으면 Play 정책 위반입니다.
  「무료」 같은 가격 홍보도 못 씁니다.
- 효과는 Play Console 유입 보고서에서 「스토어 검색」 설치 수 전후로 잽니다.

## 자세한 설명 (4000자 제한)

```
여러 계좌에 흩어진 주식·ETF 포트폴리오를 한곳에서 보고 리밸런싱합니다. 종목마다 목표 비중을 정해 두면, 시세가 움직여 비중이 밀렸을 때 무엇을 몇 주 사고팔면 되는지 계산해 드립니다. 엑셀을 켤 일이 없어집니다.


■ 잔고 캡처로 시작

• 증권사 앱의 잔고 화면을 캡처해 고르면 종목·수량·평단가를 읽어 옵니다
• 국내 주요 증권사와 미국 증권사 앱의 화면을 읽습니다
• 읽은 내용은 넣기 전에 확인하고 고를 수 있습니다
• 이미지는 기기 안에서만 읽습니다. 어디로도 보내지 않습니다


■ 자산 현황

• 위탁계좌·ISA·연금저축·IRP처럼 계좌별로 나눠 관리하고, 합계는 한 화면에서 봅니다
• 국내·미국 주식 현재가와 환율을 자동으로 받아옵니다
• 미국 종목도 한글 이름으로 찾습니다
• 평가손익과 전일대비를 계좌별·종목별로 확인합니다
• 자산 추이를 1주부터 1년까지 기간을 바꿔 가며 봅니다


■ 리밸런싱 계산

• 종목마다 목표 비중을 정해 두면, 지금 비중이 얼마나 벗어났는지 보여줍니다
• 허용 편차를 넘어선 종목만 조정 대상으로 잡습니다
• 무엇을 몇 주 사고팔면 되는지 그대로 알려드립니다
• 환율과 거래 수수료를 반영해 계산합니다
• 추가로 넣을 돈이나 뺄 돈이 있어도 그에 맞춰 계산합니다
• 소수점 매매를 하는 계좌는 소수점까지 계산합니다


■ 기간별 결산

• 주간·월간·분기·연간 수익률을 기간을 골라 확인합니다
• 어느 계좌가, 어느 종목이 얼마나 기여했는지 나눠 봅니다
• 넣고 뺀 돈은 수익률에서 제외해 계산합니다


■ 거래 내역

• 매수·매도를 날짜·수량·단가로 기록하면 보유 수량과 평단가가 자동으로 잡힙니다
• 증권사에서 받은 거래 내역 파일을 올리면 한 번에 들어옵니다


■ 이미지로 저장·공유

• 자산 현황, 조정 제안, 기간 결산, 종목 상세를 그림 한 장으로 저장하거나 공유합니다


■ 알림

• 정해 둔 날에 비중이 얼마나 벌어졌는지 알려드립니다
• 월·분기·연이 끝나면 그 기간 수익률을 알려드립니다
• 알림은 기기 안에서 만들어집니다. 광고나 홍보는 보내지 않습니다


■ 이런 분께

• 자산배분 포트폴리오를 정기적으로 리밸런싱하시는 분
• 여러 계좌에 나눠 담아 전체 비중이 한눈에 안 들어오는 분
• 매도·매수 수량을 매번 계산기나 엑셀로 두드리던 분
• 내 투자가 이번 달·이번 분기에 어땠는지 알고 싶은 분


■ 개인정보

• 포트폴리오·거래 내역·평가금액은 기기 안에만 저장됩니다. 서버로 보내지 않습니다
• 잔고 캡처 이미지도 기기 안에서만 읽습니다
• 시세 조회에는 종목코드만 보냅니다. 보유 수량이나 금액은 보내지 않습니다
• 백업·복원으로 기기를 바꿔도 그대로 옮길 수 있고, 백업한 지 오래되면 알려드립니다


■ 안내

이 앱은 참고용 계산 도구입니다. 투자 자문이나 매매 중개를 하지 않으며, 주문은 증권사에서 직접 하셔야 합니다. 시세는 외부 공개 데이터를 쓰므로 지연이나 오류가 있을 수 있습니다. 잔고 캡처는 글자를 읽어 옮기는 기능이라 틀리게 읽을 수 있으니, 넣기 전에 확인해 주십시오.
```

「잔고 캡처로 시작」을 맨 앞에 둔 이유: 받을지 말지를 가르는 기능입니다.
손으로 다 넣어야 하는 앱은 거기서 닫습니다.

## 스크린샷

`screenshots_next/framed/` 다섯 장을 순서대로 올립니다(1440×2560, 투명도 없는 PNG).

| 순서 | 파일 | 제목 | 설명 줄 |
|---|---|---|---|
| 1 | `1_drift` | 처음 정한 비중, 아직 그대로일까요? | 주가가 움직이면 비중도 달라집니다 |
| 2 | `2_plan` | 무엇을 몇 주 사고팔지 계산해 드립니다 | 벗어난 비중을 처음 정한 대로 되돌립니다 |
| 3 | `3_capture` | 보유 종목 입력은 캡처 한 장으로 | 증권사 앱 화면에서 종목과 수량을 읽어 옵니다 |
| 4 | `4_accounts` | 여러 증권 계좌를 한 화면에서 | 계좌별로 나눠 관리하고, 전체도 함께 봅니다 |
| 5 | `5_returns` | 이번 달 수익을 한눈에 | 주 · 월 · 분기 · 연 단위 수익률을 계산해 줍니다 |

---

# English (en-US)

## App name (30 char limit)

```
Rebalancing - Stock Calculator
```

- 30자를 꽉 채웁니다. 전에는 「Rebalancing - Portfolio Tool」이었는데,
  「tool」로 검색하는 사람은 없습니다.
- **앱 이름 「Rebalancing」을 앞에 둡니다.** 홈 화면 이름과 공유 이미지 로고가
  이 단어라서, 그 그림을 본 사람이 스토어에서 같은 단어를 찾게 합니다.
- 뺀 후보:
  - 「- ETFs」: 뜬금없어 보입니다.
  - 「Stock Manager」: 재고 관리로 읽힙니다.
  - 「port」: 포트폴리오를 이렇게 줄여 쓰지 않습니다.

## Short description (80 char limit)

```
Rebalance your stock & ETF portfolio, down to the exact share count
```

- 이름에 못 넣은 검색어(ETF, portfolio)를 담았습니다.
- 사람들이 실제로 치는 동사 「Rebalance」로 시작합니다.

## Full description (4000 char limit)

```
A portfolio rebalancing calculator and tracker for stocks and ETFs. See holdings scattered across several accounts in one place. Set a target weight for each, and when prices push those weights off target, the app tells you how many shares to buy or sell. No more spreadsheets.

Covers listings in Korea and the United States.


■ Start from a screenshot

• Pick screenshots of your broker app's holdings screen — the app reads the stocks, quantities and average cost
• Works with the positions screens of major US and Korean broker apps
• Review what was read and choose what to add before anything is saved
• Images are read on your device. They are never uploaded


■ Assets

• Keep accounts apart — brokerage, IRA, 401(k) — and still see one combined total
• Korean and US prices and the exchange rate are fetched for you
• Unrealized gain and daily change, per account and per holding
• Chart your total over a week, a month, or a year


■ Rebalancing

• Set a target weight per holding and see how far each one has drifted
• Only holdings past your threshold are flagged — small drift is left alone
• Get the actual number of shares to buy or sell
• Exchange rates and trading fees are built into the math
• Putting money in or taking some out? The plan is calculated around it
• Accounts that trade fractional shares are worked out to the decimal


■ Returns

• Weekly, monthly, quarterly and yearly returns — pick any period
• See which account and which holding contributed how much
• Money paid in and taken out is excluded from the return


■ Transactions

• Record buys and sells by date, quantity and price — share count and average cost follow on their own
• Upload a transaction file from your broker and it all comes in at once


■ Save and share

• Turn your assets, an adjustment plan, a period's returns, or a single holding into one image


■ Reminders

• On the days you pick, hear how far your weights have drifted
• When a month, quarter or year closes, hear what that period returned
• Reminders are built on your device. Nothing promotional is ever sent


■ Who it's for

• Index-fund and ETF investors who keep a fixed asset allocation and rebalance on a schedule
• Anyone holding across several accounts with no single view of the whole
• Anyone who reaches for a calculator or a spreadsheet every single time
• Anyone who wants to know how this month, or this quarter, actually went


■ Privacy

• Portfolios, transactions and valuations stay on your device. They are never sent to a server
• Screenshots you import are read on your device too
• Fetching prices sends ticker symbols only — never your quantities or amounts
• Back up and restore to carry everything to a new phone — the app reminds you when a backup is overdue


■ Please note

This app is a calculator for your own reference. It does not give investment advice and it does not place trades — orders go through your broker. Prices come from public data sources and can be delayed or wrong. Screenshot import reads text from an image and can misread it — check the result before you add it.
```

## Screenshots

`screenshots_next/framed_en/` 다섯 장을 순서대로 올립니다. 한국어판과 같은 순서와
같은 구성이지만, 문구는 영어로 새로 썼습니다.

| # | File | Headline | Subline |
|---|---|---|---|
| 1 | `1_drift` | Has your portfolio drifted off target? | Prices move, and your weights move with them |
| 2 | `2_plan` | Know exactly what to buy and sell | Share counts that bring you back to target |
| 3 | `3_capture` | Add your holdings from a screenshot | Reads symbols and quantities off your broker app |
| 4 | `4_accounts` | All your accounts on one screen | Keep accounts separate and still see the total |
| 5 | `5_returns` | Your returns, month by month | Weekly to yearly returns, calculated for you |

화면은 미국 예시 데이터(`tools/make_demo_data_en.py`)로 찍었습니다. Roth IRA,
Traditional IRA, Brokerage 세 계좌이고, 앱은 영어·달러로 설정했습니다. 원본
캡처는 `screenshots_next/en/`에 있습니다.

---

# 스크린샷을 다시 만들 때

## 사용자와 정한 것 (2026-11-17)

- **앱을 처음 보는 사람이 읽는 그림입니다.** 제목에 앱 안에서만 쓰는 말(목표
  비중·허용 편차·잔고 캡처·위탁·예수금)을 쓰지 않습니다. 「처음 정한 비중」
  「캡처 한 장」처럼 풀어 씁니다.
- **1·2번은 한 쌍입니다.** 1번이 묻고(비중이 그대로인가), 2번이 답합니다(몇 주
  사고팔지). 화면 속 용어가 가장 낯선 이 두 장에만 말풍선을 붙였습니다.
- **3번에는 지어낸 예시 잔고 표를 그렸습니다.** 어느 증권사 화면도 아니고
  「(예시)」라고 적었습니다. 표에는 평가금액 칸이 꼭 있어야 합니다. 없으면
  수량을 맞춰 볼 숫자가 없어 전부 「확인이 필요한 종목」으로 나옵니다.
- **「ISA · 연금저축 · 주식 계좌를 합쳐서 보여 줍니다」는 쓰지 않습니다.**
  계좌를 자동으로 연결하는 것처럼 읽힙니다.
- **종목 상세 장은 뺐습니다.** 어느 주식 앱에나 있는 기능입니다.
- **결산은 5월 화면입니다.** 6~11월은 실제 시세가 내려 손실로 나옵니다.
- **남은 흠:**
  - 화면 속 계좌 이름이 「위탁계좌」입니다.
  - 4번에 「조정 필요」「결산 준비」 카드가 보입니다.
  - 5번 제목은 「이번 달」인데 화면은 5월입니다.

## 만드는 법

1. **예시 데이터를 만들어 앱에 넣습니다.**
   - 한국어용은 `tools/make_demo_data.py`, 영어용은
     `tools/make_demo_data_en.py`가 만듭니다.
   - 수량은 지어낸 값이고, 시세와 매수 시점은 야후 파이낸스에서 받은
     진짜입니다. 전부 지어내면 과거 시세와 어긋나 결산이 망가집니다.
   - 만든 JSON을 `adb push`로 폰에 넣고, 앱 「더보기 → 복원」으로
     불러옵니다.
2. **상태 표시줄을 고정합니다.** 시계 09:30, 배터리 100%로 맞춥니다.
   `com.android.systemui.demo` 브로드캐스트를 씁니다.
3. **광고 없이 찍습니다.**
   - 비행기 모드에서 앱을 켠 뒤 망을 다시 켭니다.
   - 켤 때 망이 없으면 광고가 안 붙고, 그 뒤 망을 켜도 붙지 않습니다.
   - 비행기 모드인 채로 찍으면 결산이 전부 +₩0으로 나옵니다.
4. **잔고 캡처 장은 망이 켜져 있어야 합니다.** 시세로 수량을 맞춰 보기
   때문입니다.
5. **첫 화면의 백업 알림 카드는 「나중에」로 닫고 찍습니다.**
6. **찍은 것을 Claude Design 캔버스에 올려 감쌉니다.**
   - 캔버스 주소: https://claude.ai/artifact/FEVuSwt22cY7cFB6rxwPun
   - 내려받은 PNG는 투명도가 붙어 나옵니다(RGBA).
   - 올리기 전에 배경색 (10,58,53)으로 RGB로 바꿉니다. Play는 투명도 있는
     PNG를 받지 않습니다.

**규격**: 2~8장, PNG 또는 JPEG, 각 변 320~3840px. 긴 변은 짧은 변의 두 배를
넘으면 안 됩니다. 그래서 1080×2400 캡처를 1440×2560 바탕에 얹습니다.
