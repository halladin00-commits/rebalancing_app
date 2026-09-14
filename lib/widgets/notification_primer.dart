import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../theme/design_system.dart';

/// 시스템 알림 권한 창을 띄우기 **전에** 무엇을 보낼지 먼저 말한다.
///
/// 왜 필요한가
///   안드로이드는 알림 권한 창을 **사실상 한 번만** 띄워 준다. 두 번
///   거부당하면 그 뒤로는 요청해도 아무것도 안 뜬다. 그런데 앱을 처음 켠
///   사람은 그 창이 무엇에 대한 것인지 모르는 채로 받게 되고, 많은 사람이
///   반사적으로 「허용 안 함」을 누른다.
///
///   그 한 번을 **거부할 사람에게 쓰지 않는 것**이 요점이다. 여기서 먼저
///   물어보면, 관심 없는 사람은 「나중에」로 지나가고 시스템 창은 아껴
///   둔다. 나중에 마음이 바뀌어 더보기에서 켤 때 그 창이 제대로 뜬다.
///
/// 무엇을 적는가
///   **실제로 보내는 것만 적는다.** 부풀리면 켠 사람이 곧 끄고, 그때는
///   시스템 설정에서 꺼 버려서 되돌리기가 더 어렵다.
///
///   「광고는 보내지 않는다」를 적는 이유는, 반사적으로 거부하는 가장 큰
///   이유가 그것이기 때문이다. 이 앱의 알림은 전부 기기 안에서 만들어져
///   서버를 거치지 않으므로 **사실이다.**
class NotificationPrimer extends StatelessWidget {
  const NotificationPrimer({super.key});

  /// 한 번 물어봤다는 표시. 매번 물으면 그 자체가 성가신 알림이 된다.
  static const _keyAsked = 'notif_primer_asked';

  /// 필요하면 띄우고, **시스템 창을 띄워도 되는지** 답한다.
  ///
  /// 거짓이면 권한을 요청하지 않는다 — 요청하지 않았으므로 시스템의
  /// 「한 번」은 그대로 남는다.
  static Future<bool> askFirst(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyAsked) == true) return false;
    await prefs.setBool(_keyAsked, true);

    if (!context.mounted) return false;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NotificationPrimer(),
    );
    return yes == true;
  }

  @override
  Widget build(BuildContext context) {
    final isKo = Localizations.localeOf(context).languageCode == 'ko';

    // **[AlertDialog]를 쓰지 않는다.** 머티리얼 기본값이 그대로 나와서 이
    // 앱이 아니라 안드로이드 대화상자처럼 보인다 — 모서리도, 버튼도, 글자
    // 크기도 다른 화면과 따로 논다. 앱이 이미 쓰는 [Dialog] 모양을 따른다
    // (종료 확인 창과 같은 구성).
    return Dialog(
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 마크를 딥그린 원판에 얹는다 — 앱 아이콘과 같은 자리 느낌을 준다.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: context.appBarBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.notifications_none_rounded,
                  size: 21, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              isKo ? '알림을 받으시겠어요?' : 'Get reminders?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: context.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              isKo ? '두 가지만 보냅니다.' : 'We send just two things.',
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: context.textSecondary),
            ),
            const SizedBox(height: 14),
            // 두 줄을 카드로 묶는다 — 다른 화면의 목록과 같은 결이 된다.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              decoration: BoxDecoration(
                color: context.rowBg,
                borderRadius: BorderRadius.circular(DS.tileRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _point(
                    context,
                    isKo
                        ? '정해 둔 날에, 비중이 얼마나 벌어졌는지'
                        : 'How far your weights drifted, on the day you pick',
                  ),
                  const SizedBox(height: 10),
                  _point(
                    context,
                    isKo
                        ? '월·분기·연이 끝나면, 그 기간 수익률'
                        : 'Your return for each month, quarter and year',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isKo
                  ? '앱을 열지 않아도 챙길 수 있고, 언제든 끌 수 있습니다.\n'
                      '광고나 홍보는 보내지 않습니다.'
                  : "You don't have to open the app, and you can turn this "
                      'off any time. We never send ads.',
              style: TextStyle(
                  fontSize: 12, height: 1.55, color: context.textTertiary),
            ),
            const SizedBox(height: 20),
            // **「나중에」도 제대로 된 선택지로 보여야 한다.** 작게 흘려 놓으면
            // 떠밀린 느낌이 들고, 그 느낌으로 켠 알림은 곧 꺼진다.
            // 그래서 둘을 같은 크기로 나란히 둔다.
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: DS.buttonHeight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.borderColor),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DS.buttonRadius)),
                    ),
                    child: Text(isKo ? '나중에' : 'Not now',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: DS.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appBarBg,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DS.buttonRadius)),
                    ),
                    child: Text(isKo ? '알림 받기' : 'Turn on',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _point(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
                color: context.appBarBg, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.textPrimary)),
        ),
      ],
    );
  }
}
