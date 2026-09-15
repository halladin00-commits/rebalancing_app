# 스토어 스크린샷

**이미 만들어 뒀습니다.** `screenshots/framed/` 다섯 장을 그대로 올리시면
됩니다. 아래는 다시 만들어야 할 때를 위한 기록입니다.

| 순서 | 파일 | 화면 | 문구 |
|---|---|---|---|
| 1 | `1_asset` | 자산 탭 | 흩어진 계좌를 한곳에서 |
| 2 | `2_drift` | 리밸런싱 → 연금저축 | 목표에서 얼마나 벗어났는지 |
| 3 | `3_plan` | 조정 제안 | 몇 주를 사고팔지 계산합니다 |
| 4 | `4_settle` | 결산 탭 (5월) | 이번 달은 얼마였는지 |
| 5 | `5_item` | 종목 상세 | 종목마다 수량 · 단가 · 비중 |

순서가 곧 이야기입니다 — 「흩어진 걸 모아서 → 얼마나 틀어졌는지 보고 →
몇 주를 사고팔지 알고 → 지나고 나서 얼마였는지 본다」.

3번이 가장 중요합니다. **이 앱을 받을 이유가 그 화면 하나**에 들어 있습니다.

## 잔고는 가짜, 시세는 진짜

`demo_portfolio.json`은 `tools/make_demo_data.py`가 만듭니다.

- **수량은 지어낸 값**입니다. 총 7,811만원 — 실제 잔고는 한 숫자도 안 들어갑니다.
- **시세와 매수 시점은 진짜**입니다. 야후 파이낸스에서 받아 씁니다.

왜 섞어 쓰나 — 전부 지어내면 **결산이 망가집니다.** 결산은 기간 시작·끝의
시세를 받아서 계산하는데, 지어낸 현재가와 받아온 과거 시세가 어긋나
한 달에 −9,600만원 같은 값이 나왔습니다.

채권 하나(`KODEX 종합채권`)는 일부러 마이너스로 둡니다. 전부 파랗기만 한
계좌는 없고, 손실 색도 보여줘야 합니다.

## 다시 만드는 법

```
python tools/make_demo_data.py       # 시세 받아 가짜 포트폴리오 생성
adb push docs/store/demo_portfolio.json /sdcard/Download/zz_demo.json
# 앱에서 더보기 → 복원 → zz_demo.json
python tools/frame_screenshots.py    # 찍은 것을 스토어 규격으로 감싸기
```

화면을 찍을 때 **미리 해 둘 것 세 가지**:

1. **상태 표시줄 고정** — 안 하면 장마다 시계가 다르고, 비행기 모드에서
   찍은 장만 ✈ 표시가 붙습니다.
   ```
   adb shell settings put global sysui_demo_allowed 1
   adb shell am broadcast -a com.android.systemui.demo -e command enter
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
   adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e fully true
   adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```
2. **결산 탭을 먼저, 망을 켠 채로** 열어 과거 시세를 받아 둡니다. 한 번
   받아 두면 망을 끊어도 그대로 남습니다.
3. 그 다음 **비행기 모드**로 나머지를 찍습니다. 망이 붙어 있으면 자산 탭과
   종목 상세에 **배너 광고가 찍힙니다.**

## 규격 — 찍은 그대로는 못 올립니다

Play는 **긴 쪽이 짧은 쪽의 두 배를 넘으면 받지 않습니다.** 요즘 폰은
20:9(1080×2400 = 2.22배)라 그대로는 막힙니다. `frame_screenshots.py`가
1440×2560(16:9) 딥그린 바탕에 얹고 문구를 붙여 이 문제를 없앱니다.

그 밖에 — 2~8장, PNG/JPEG, 각 면 320~3840px.
