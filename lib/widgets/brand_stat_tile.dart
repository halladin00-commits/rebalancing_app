import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/design_system.dart';
import '../utils/money_format.dart';

/// 딥그린 헤더 위의 손익 타일 — 「평가손익」·「전일대비」.
///
/// **네 군데가 각자 그리고 있었다.** 자산 탭·포트 상세·종목 상세, 그리고
/// 캡처. 모양이 같아 보이니 새 화면을 만들 때마다 옮겨 적었고, 한 곳을
/// 고치면 나머지 셋이 그 자리에 남았다. 실제로 자산 탭만 두 줄로 고쳤더니
/// 나머지 셋이 세 줄로 남아 화면마다 다른 앱처럼 보였다.
///
/// 나란히 놓고 볼 일이 없어 **눈으로는 안 걸린다.** 그래서 위젯 하나로
/// 묶는다. `test/brand_tile_test.dart`가 복사본이 다시 생기면 잡는다.
///
/// ## 배치
///
///     평가손익            +14.86%
///               +₩205,705,773
///
/// 이름표와 퍼센트는 둘 다 짧다. 한 줄에 같이 두면 **금액이 줄 하나를
/// 통째로 쓴다.** 셋을 세로로 쌓으면 타일이 그만큼 높아져 딥그린 헤더가
/// 첫 화면의 3분의 1을 먹고, 금액과 퍼센트를 한 줄에 붙이면 긴 쪽(금액)이
/// 좁아진 자리에 맞추느라 [FittedBox]에 눌려 작아진다.
///
/// 숫자는 오른쪽으로 맞춘다 — 두 타일의 값이 같은 선에 선다.
class BrandStatTile extends StatelessWidget {
  /// 「평가손익」·「전일대비」.
  final String label;

  /// 금액. 살 때 값이 없는 종목이 섞여 있으면 null이고 「—」로 적는다.
  final double? amount;

  /// 수익률. [amount]와 같이 있거나 같이 없다.
  final double? pct;

  final String currency;

  /// 오름·내림 색. **넘겨받는다** — 캡처는 Provider가 없는 딴 트리에서
  /// 그려져 안에서 찾으면 릴리즈 빌드에서 회색 사각형이 저장된다.
  final PnlColorNotifier pnlColors;

  const BrandStatTile({
    super.key,
    required this.label,
    required this.amount,
    required this.pct,
    required this.currency,
    required this.pnlColors,
  });

  @override
  Widget build(BuildContext context) {
    final has = amount != null && pct != null;
    final isPos = (amount ?? 0) >= 0;
    final color = !has
        ? context.onBrandSecondary
        : (isPos ? pnlColors.onBrandPositive : pnlColors.onBrandNegative);
    final sign = isPos ? '+' : '−';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Flexible이 아니라 Expanded다 — 이름표가 남은 자리를 채워야
              // 퍼센트가 오른쪽 끝으로 밀린다.
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: DS.body,
                        fontWeight: FontWeight.w600,
                        color: context.onBrandSecondary)),
              ),
              const SizedBox(width: 6),
              Text(
                has ? '$sign${pct!.abs().toStringAsFixed(2)}%' : '—',
                style: TextStyle(
                    fontSize: DS.body,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              has ? '$sign${fmtMoney(amount!.abs(), currency)}' : '—',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }
}
