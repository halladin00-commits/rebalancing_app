# Play Console listing — English (v1.1.0)

Copy and paste as-is. Everything fits inside Play's limits.

> **These are not translations of the Korean.** Play shows one listing per
> language, and a reader of the English one never sees the Korean. Korean
> turns of phrase (「몇 주를 사고팔지」, 「엑셀을 켤 일이 없어집니다」) were
> rewritten as things an English speaker would actually say.
>
> The app's own English wording is the authority for terminology — the
> settlement tab is **Returns**, not "Settlement"; the setting is a
> **threshold**, and holdings **drift**. A listing that names things
> differently from the screen is a listing that confuses.

---

## Release notes (App version → Release notes, 500 char limit)

```
v1.1.0 — The whole app, redrawn

✨ New
• New icon and a redesigned interface throughout
• A first-run intro: what target weights and thresholds mean
• Edit target weights and thresholds right where the numbers appear
• Save and share an image from a holding's screen too

🔧 Changed calculation
• Fixed what the threshold means. Only holdings past it are adjusted, so quantities may differ from the previous version

🔔 Reminders now arrive at 1 PM, and monthly ones can land on the last day
```

> **Do not drop the "Changed calculation" item.** Existing users notice the
> changed quantities before they notice anything else. Left unsaid, it reads
> as a bug.

---

## Short description (80 char limit)

```
Balance your stocks and ETFs, down to the exact share count
```

58 characters. **It leads with what the app is.** This one line is all most
people read before deciding, and "your weights have drifted from target"
only means something to someone who already rebalances.

**This slot renders as a large headline.** The earlier line — "Track your
stocks and ETFs, and see how many shares to buy or sell." — was two flat
clauses strung together with *and*, and it wrapped onto three lines with a
stub at the end. One clause plus the payoff phrase reads better big, and
mirrors the Korean, which does the same thing with 「…부터 …까지」.

---

## Full description (4000 char limit)

> **Line breaks come through exactly as typed.** No blank line needed
> between bullets (verified).
>
> Which cuts both ways — **never hard-wrap prose.** A paragraph folded at 70
> columns for readability shows up on the store folded, mid-sentence. Keep
> each paragraph on one line however long it runs.
> `python tools/check_listing.py` catches folded lines.
>
> **Do not judge this from the Console's "asset review" pane.** That pane
> drops the stored text straight into HTML, so every run of line breaks
> collapses to one line and tags like `<b>` show up as literal characters.
> It is not what the live listing looks like.
>
> Markdown does nothing — `**bold**` shows its asterisks. `<b>…</b>` is the
> way to bold. Left out here because the `■` markers already do the work.

```
See holdings scattered across several accounts in one place. Set a target weight for each, and when prices push those weights off target, the app tells you exactly how many shares to buy or sell. No more spreadsheets.

Covers stocks and ETFs listed in Korea and the United States.


■ Assets

• Keep accounts apart — brokerage, ISA, retirement — and still see one combined total
• Korean and US prices and the exchange rate are fetched for you
• Unrealized gain and daily change, per account and per holding
• Chart your total over a week, a month, or a year


■ Rebalancing

• Set a target weight per holding and see how far each one has drifted
• Only holdings past your threshold are flagged — small drift is left alone
• Get the actual number of shares to buy or sell
• Exchange rates and trading fees are built into the math
• Putting money in or taking some out? The plan is calculated around it
• Accounts that allow fractional shares are worked out to the decimal


■ Returns

• Weekly, monthly, quarterly and yearly returns — pick any period
• See which account and which holding contributed how much
• Money paid in and taken out is excluded from the return


■ Transactions

• Record buys and sells by date, quantity and price — share count and average cost follow on their own
• Import a transaction file from your broker in one go


■ Save and share

• Turn your assets, an adjustment plan, a period's returns, or a single holding into one image


■ Reminders

• On the days you pick, hear how far your weights have drifted
• When a month, quarter or year closes, hear what that period returned
• Reminders are built on your device. Nothing promotional is ever sent


■ Who it's for

• Anyone who rebalances stocks and ETFs on a schedule
• Anyone holding across several accounts with no single view of the whole
• Anyone who reaches for a calculator or a spreadsheet every single time
• Anyone who wants to know how this month, or this quarter, actually went


■ Privacy

• Portfolios, transactions and valuations stay on your device. They are never sent to a server
• Fetching prices sends ticker symbols only — never your quantities or amounts
• Back up and restore to carry everything to a new phone


■ Please note

This app is a calculator for your own reference. It does not give investment advice and it does not place trades — orders go through your broker. Prices come from public data sources and can be delayed or wrong.
```
