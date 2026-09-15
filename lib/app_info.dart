/// 앱 이름과 판 번호.
///
/// `package_info_plus` 같은 꾸러미를 더하지 않고 여기 적어 둔다. 꾸러미
/// 하나가 하는 일이 이 문자열 하나뿐이면 값이 안 맞는다.
///
/// 대신 **손으로 적은 값은 반드시 어긋난다.** 판을 올리면서 여기를 잊는다.
/// `test/app_info_test.dart`가 `pubspec.yaml`과 맞는지 매번 확인하므로,
/// 잊으면 시험이 깨져 바로 안다.
library;

const appName = 'Rebalancing';

/// `pubspec.yaml`의 `version:`과 **같아야 한다.**
const appVersion = '1.1.0';

/// `pubspec.yaml`의 `version:` 에서 `+` 뒤 숫자.
const appBuild = '14';

/// 사용자에게 보이는 판 번호.
const appVersionLabel = '$appVersion ($appBuild)';

/// 개인정보처리방침 주소.
///
/// 문서는 저장소의 `docs/privacy.html`이고, GitHub Pages가 그대로 내보낸다.
/// **주소가 죽으면 스토어 심사에서 반려된다** — 파일 이름이나 Pages 설정을
/// 건드릴 때는 이 주소가 살아 있는지 먼저 확인할 것.
const privacyPolicyUrl =
    'https://halladin00-commits.github.io/rebalancing_app/privacy.html';
