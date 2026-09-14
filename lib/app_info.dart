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
const appVersion = '1.0.0';

/// `pubspec.yaml`의 `version:` 에서 `+` 뒤 숫자.
const appBuild = '13';

/// 사용자에게 보이는 판 번호.
const appVersionLabel = '$appVersion ($appBuild)';
