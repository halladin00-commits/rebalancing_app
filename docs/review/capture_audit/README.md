# 캡처 전수 점검 기록

화면과 그림이 어긋난 일이 **스물네 번** 있었다. 전부 눈으로만 보이는
차이라 예외도 로그도 안 남는다. 그래서 그림을 실제로 꺼내 화면과 나란히
놓고 보는 수밖에 없었다.

## 무엇이 뿌리였나

전부 하나다 — **캡처가 화면의 일부를 손으로 옮겨 적었다.** 그리고 화면만
고쳐졌다.

## 어떻게 막았나

한 자리씩 고치는 것으로는 안 끝났다(일곱 번을 그렇게 했다). 규칙을 바꿨다.

| 규칙 | 지키는 시험 |
|---|---|
| `_buildCapture` 본문에 `TextStyle(`이 0개 | `capture_contract_test` |
| `_capture…Row` 같은 캡처 전용 행 함수를 두지 않는다 | `contribution_row_shared_test` |
| 목록을 자르면 「…외 N건」을 함께 낸다 | `capture_truncation_test` |
| 결산 캡처가 「결산 제외」 띠를 싣는다 | `capture_truncation_test` |
| 차트 기간 글씨를 화면과 캡처가 같은 함수로 낸다 | `capture_truncation_test` |

시험은 전부 **되살려 넣어 실제로 실패하는 것**을 확인했다. 안 잡히는
시험은 없는 것과 같다.

## 그래도 못 잡는 것

**구역이 통째로 없는 것**은 코드에 안 보인다. 「거래 내역이 빠졌다」는
없는 코드라 찾을 수가 없다. 실제로 그렇게 네 개(거래 내역 · 결산 제외 띠 ·
기간 라벨 · 현재→목표)가 나왔고, 전부 **그림을 꺼내 보고** 찾았다.

그래서 캡처를 고치면 **여덟 장을 다시 뽑아 화면과 맞대어 본다.**

## 어떻게 뽑나

```
sh tools/build_review.sh android-x64      # 에뮬레이터용
adb install -r build/app/outputs/flutter-apk/app-x86_64-release.apk
adb push docs/store/demo_portfolio.json /sdcard/Download/zz_demo.json
```

먼저 해 둘 것 — **비행기 모드**(안 그러면 그림에 배너 광고가 찍힌다),
**상태 표시줄 고정**(장마다 시계가 달라지지 않게). 자세한 명령은
`docs/store/screenshots.md`에 있다.

평범한 자료로는 안 보이는 것들이 있다. **예외 상태를 따로 만들어** 본다 —
예수금 · 소수점 수량 · 시세 없는 종목 · 종목 10개 이상 · 거래 20건 이상 ·
추가 입금 모드 · 마감된 결산 기간 · 영어 화면.

## 그림

| 파일 | 무엇 |
|---|---|
| `after_fixes.png` | 거래 내역 · 기간 라벨 · 환율 배지 |
| `edge_cases.png` | 결산 제외 띠 · 목록 잘림 · 거래 20건 · 시세 없음 |
| `locale_and_states.png` | 영어 화면 · 유지 상태 |
| `closed_period.png` | 마감된 결산 기간 |
