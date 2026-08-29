# 새로 필요한 문구 (ko / en)

`lib/l10n/app_localizations_ko.dart`와 `_en.dart` 양쪽에 키를 추가한다. 키 이름은 제안이며, 기존 파일의 명명 규칙에 맞춰 조정해도 된다.
**영문은 초안이다 — 검수 필요.**

## 탭 · 셸

| key | ko | en |
| --- | --- | --- |
| `tabAssets` | 자산 | Assets |
| `tabRebalancing` | 리밸런싱 | Rebalance |
| `tabSettlement` | 결산 | Returns |
| `tabMore` | 더보기 | More |

## 결산 — 전체 (v22a)

| key | ko | en |
| --- | --- | --- |
| `periodWeekly` / `Monthly` / `Quarterly` / `Yearly` | 주간 / 월간 / 분기 / 연간 | Weekly / Monthly / Quarterly / Yearly |
| `netDepositExcluded` | 순입금 {amount}은 제외 | Excludes {amount} net deposits |
| `pnlBreakdownInline` | 실현 {realized} · 평가 {unrealized} · 수수료 {fees} | Realized {realized} · Unrealized {unrealized} · Fees {fees} |
| `periodClosed` | 마감 | Closed |
| `tapBarToSelectPeriod` | 막대를 눌러 기간 선택 | Tap a bar to pick a period |
| `contributionByPortfolio` | 포트별 기여 | Contribution by portfolio |
| `contributionValue` | 기여 {pct}% ({pp}%p) | {pct}% of return ({pp}pp) |
| `excludedFromSettlement` | {count}종목 결산 제외 | {count} holdings excluded |
| `convert` | 전환 | Convert |
| `tradesSummary` | 매도 {sells}건 · 배당 {dividends}건 | {sells} sells · {dividends} dividends |
| `noTradesFxIncluded` | 거래 없음 · 환율 {amount} 포함 | No trades · includes {amount} FX |
| `dividendsOnlyCounted` | 배당 {count}건 · {items}종목만 집계 | {count} dividends · {items} holdings counted |
| `excludedBadge` | {count}종목 제외 | {count} excluded |

## 결산 — 포트별 (v22b)

| key | ko | en |
| --- | --- | --- |
| `noCashFlowInPortfolio` | 이 포트는 입출금 없음 | No deposits or withdrawals |
| `quarterInProgress` | {quarter}분기 진행 중 · {days}일 경과 | Q{quarter} in progress · day {days} |
| `realizedFromSells` | 매도 실현손익 | Realized (sells) |
| `dividends` | 배당 | Dividends |
| `unrealizedChange` | 평가손익 변동 | Change in unrealized |
| `feesAndTax` | 수수료 · 세금 | Fees & tax |
| `dividendTaxIncluded` | 배당세 포함 | incl. dividend tax |
| `holdingsLabel` | 보유분 | Holdings |
| `total` | 합계 | Total |
| `contributionByHolding` | 종목별 기여 | Contribution by holding |
| `beforeFees` | 수수료 전 값 | before fees |

## 결산 — 점프 시트 (v22c)

| key | ko | en |
| --- | --- | --- |
| `selectPeriod` | 기간 선택 | Select period |
| `scopedTo` | {name} 기준 | For {name} |
| `inProgressShort` | 진행중 | in progress |
| `sheetScopeNote` | 칸의 손익은 이 포트만의 값입니다 — 전체 결산의 기간은 그대로 유지됩니다 | Figures shown are for this portfolio only — the overall period stays as it is |
| `viewPeriodCta` | {year}년 {label} 보기 | View {label} {year} |

## 더보기 (v23a)

| key | ko | en |
| --- | --- | --- |
| `groupPortfolio` | 포트폴리오 | Portfolios |
| `groupTradingCalc` | 거래 · 계산 | Trading & math |
| `groupSettlementAlerts` | 결산 · 알림 | Returns & alerts |
| `groupDataApp` | 데이터 · 앱 | Data & app |
| `managePortfoliosItems` | 포트폴리오 · 종목 관리 | Portfolios & holdings |
| `targetWeightThreshold` | 목표 비중 · 허용 편차 | Target weights & tolerance |
| `fractionalTrading` | 소수점 거래 | Fractional shares |
| `perAccountSetting` | 계좌별로 켜집니다 | Enabled per account |
| `accountsCount` | {count}개 계좌 | {count} accounts |
| `feesTaxSetting` | 수수료 · 세금 | Fees & tax |
| `feeRateSummary` | 매매 {rate}% · 배당세 {tax}% | Trading {rate}% · dividend tax {tax}% |
| `fxBasis` | 환율 기준 | Exchange rate basis |
| `fxBasisSummary` | 거래일 환율 저장 · 평가는 현재 환율 | Stored at trade date · valued at current rate |
| `settlementBasis` | 결산 기준 | Return basis |
| `settlementBasisSummary` | 실현+평가 · 순입금 제외 | Realized + unrealized · net deposits excluded |
| `periodCloseAlert` | 기간 마감 알림 | Period close alert |
| `largestUnitOnly` | 가장 큰 단위 하나 | Largest unit only |
| `importTransactions` | 거래내역 불러오기 | Import transactions |
| `backupExport` | 백업 · 내보내기 | Backup & export |
| `removeAds` | 광고 없이 쓰기 | Remove ads |
| `perMonth` | 월 {price} | {price}/month |

## 소수점 거래 설정 (v23b)

| key | ko | en |
| --- | --- | --- |
| `perAccountSettings` | 계좌별 설정 | Per-account settings |
| `fractionalAvailable` | 해외주식 · 소수점 매매 가능 | Foreign equities · fractional supported |
| `fractionalPartialItems` | 해외 ETF {count}종목만 해당 | Applies to {count} foreign ETFs |
| `fractionalUnavailableKr` | 국내 상장 ETF는 소수점 매매 불가 | Korean-listed ETFs cannot be traded fractionally |
| `quantityRounding` | 수량 반올림 | Quantity rounding |
| `roundingMinDeviation` | 편차가 가장 작아지는 수량 | Quantity that minimizes drift |
| `roundingMinDeviationSub` | 소수점 넷째 자리까지 | Up to 4 decimal places |
| `roundingFloorCash` | 현금이 남는 쪽으로 내림 | Round down, leave cash |
| `roundingFloorCashSub` | 예산을 넘지 않습니다 | Never exceeds your budget |
| `previewHeading` | 지금 조정 제안이 이렇게 바뀝니다 | How your next adjustment changes |
| `wholeShares` | 주 단위 | Whole shares |
| `fractional` | 소수점 | Fractional |
| `driftRemaining` | 편차 {pp}%p 남음 | {pp}pp drift left |
| `driftValue` | 편차 {pp}%p | {pp}pp drift |
| `staysWholeShares` | {name}은 계속 주 단위로 계산합니다 | {name} keeps whole-share math |

## 시세 갱신 상태 (v13e)

| key | ko | en |
| --- | --- | --- |
| `refreshing` | 시세 갱신 중 | Refreshing prices |
| `refreshBasis` | {time} 시세 기준 | As of {time} |
| `refreshFailed` | 갱신 실패 · {time} 시세 | Refresh failed · as of {time} |
| `retry` | 다시 시도 | Retry |
| `closingBasis` | {time} 종가 기준 | At {time} close |

## 시장 칩

| key | ko | en |
| --- | --- | --- |
| `marketKr` | KR | KR |
| `marketUs` | US | US |
| `marketCash` | 현금 | Cash |

## 숫자 표기 규칙

- 통화 기호는 `MainCurrencyNotifier.currency`(KRW/USD)에 따른다. 시안은 KRW 기준(`₩11,772,880`).
- 한국어 로케일의 축약(`+20.7만`)은 ko에서만. en은 `+207K` 형태로 축약하거나 축약하지 않는다.
- 수익률은 소수 둘째 자리(`+2.31%`), 기여도 %p는 소수 둘째(`+1.65%p`), 종목 수익률은 소수 첫째(`+8.9%`)로 시안에 맞춘다.
- 부호는 `+` / `−`(U+2212, 하이픈 아님)를 쓴다.
