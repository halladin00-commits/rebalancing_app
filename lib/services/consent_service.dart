import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 유럽 사용자에게 광고 동의를 받는다 (Google UMP).
///
/// 왜 필요한가
///   2024년부터 AdMob은 EEA·영국·스위스 사용자에게 광고를 띄우려면
///   **인증된 동의 창**을 먼저 띄우도록 요구한다. 없으면 그 지역에서
///   광고가 제한된다. 이 앱은 유럽에도 배포된다.
///
/// 지역은 누가 가르는가
///   **우리가 가르지 않는다.** Google SDK가 기기 IP로 판단해서
///   「동의가 필요한 지역인지」를 알려준다. 한국 사용자에게는 창이 뜨지
///   않고 [canShowAds]가 바로 참이 된다. 나라 목록을 앱에 적어 두면
///   규정이 바뀔 때마다 앱을 새로 내야 한다.
///
/// 동의 창의 **내용은 코드에 없다.** AdMob 콘솔의 「개인정보 보호 및 메시지」
/// 에서 만든 것을 SDK가 내려받아 띄운다. 콘솔에 메시지가 없으면
/// [ConsentInformation.isConsentFormAvailable]이 거짓이라 아무것도 안 뜬다.
class ConsentService {
  ConsentService._();

  static final Completer<void> _resolved = Completer<void>();

  /// 동의 상태를 알아낼 때까지 기다린다.
  ///
  /// 광고를 붙이는 쪽은 이걸 기다린 뒤 [canShowAds]를 본다. 기다리지 않고
  /// 먼저 요청하면 **동의를 받기 전에 광고가 나가는** 바로 그 위반이 된다.
  static Future<void> get resolved => _resolved.future;

  static bool _canShowAds = false;

  /// 지금 광고를 요청해도 되는가.
  ///
  /// 동의가 필요 없는 지역이면 참, 유럽에서 동의를 받았으면 참,
  /// 아직 모르거나 거부했으면 거짓이다.
  static bool get canShowAds => _canShowAds;

  /// 앱을 켤 때 한 번 부른다.
  ///
  /// 실패해도 **앱은 그대로 돌아간다.** 망이 없거나 Google이 응답하지
  /// 않는다고 앱이 멈추면, 광고 때문에 앱을 못 쓰는 꼴이 된다. 그때는
  /// 광고만 안 나온다.
  static Future<void> gather() async {
    final formDone = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        // 「필요하면 띄운다」 — 필요 없는 지역에서는 아무것도 안 한다.
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {
          // 창을 못 띄웠다. 아래에서 canRequestAds가 거짓이 되어
          // 광고가 안 나갈 뿐, 앱은 멀쩡하다.
        }
        if (!formDone.isCompleted) formDone.complete();
      },
      (FormError error) {
        // 망이 없을 때 여기로 온다. 전에 받아 둔 동의가 있으면
        // canRequestAds가 그 값을 그대로 돌려준다.
        if (!formDone.isCompleted) formDone.complete();
      },
    );

    await formDone.future;
    try {
      _canShowAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      _canShowAds = false;
    }
    if (!_resolved.isCompleted) _resolved.complete();
  }

  /// 「광고 설정」 줄을 더보기에 보여야 하는가.
  ///
  /// 유럽 사용자는 **한 번 정한 동의를 나중에 바꿀 수 있어야 한다.** 그
  /// 통로가 없으면 그것만으로 정책 위반이다. 한국 사용자에게는 거짓이라
  /// 줄 자체가 안 보인다 — 쓸 데 없는 설정을 늘리지 않는다.
  static Future<bool> isPrivacyOptionsRequired() async {
    try {
      final s =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return s == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// 동의를 다시 고르는 창을 띄운다. 실패하면 참이 아닌 값을 돌려준다.
  static Future<bool> showPrivacyOptions() async {
    try {
      FormError? failed;
      await ConsentForm.showPrivacyOptionsForm((e) => failed = e);
      if (failed != null) return false;
      // 거부로 바꿨으면 이 순간부터 광고를 멈춰야 한다.
      _canShowAds = await ConsentInformation.instance.canRequestAds();
      return true;
    } catch (_) {
      return false;
    }
  }
}
