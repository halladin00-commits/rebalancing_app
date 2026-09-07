#!/bin/sh
# 검토용 APK를 만든다 — 스토어판 옆에 따로 깔린다.
#
# 패키지명에 `.review`를 붙이고 앱 이름을 "Rebalancing 검토"로 바꿔 빌드한 뒤,
# android/ 를 원래대로 되돌린다. 스토어판과 나란히 깔려서 실기기에서
# 쓰던 데이터를 건드리지 않고 확인할 수 있다.
#
# `--split-per-abi`는 고정이다. 빼면 versionCode가 13으로 나와서
# 이미 깔린 4013보다 낮아 설치가 조용히 실패한다.
#
# 쓰는 법:
#   sh tools/build_review.sh              # 실기기용 arm64
#   sh tools/build_review.sh android-x64  # 에뮬레이터용 x86_64

set -e
cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain android/)" ]; then
  echo "android/ 에 커밋 안 된 변경이 있다. 되돌리기가 그걸 지운다." >&2
  git status --porcelain android/ >&2
  exit 1
fi

TARGET="${1:-android-arm64}"
case "$TARGET" in
  android-arm64) ABI=arm64-v8a ;;
  android-x64)   ABI=x86_64 ;;
  *) echo "모르는 타깃: $TARGET" >&2; exit 1 ;;
esac

restore() { git checkout -- android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml; }
trap restore EXIT

python - <<'PY'
import io
p = 'android/app/build.gradle.kts'
s = io.open(p, encoding='utf-8').read()
old = """        release {
            signingConfig ="""
assert old in s, 'release 블록을 못 찾았다'
s = s.replace(old, """        release {
            applicationIdSuffix = ".review"
            signingConfig =""", 1)
io.open(p, 'w', encoding='utf-8', newline='').write(s)

p = 'android/app/src/main/AndroidManifest.xml'
s = io.open(p, encoding='utf-8').read()
assert 'android:label="Rebalancing"' in s
s = s.replace('android:label="Rebalancing"', 'android:label="Rebalancing 검토"', 1)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('검토용 설정 적용')
PY

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/d/gradle_fresh}"
# `A11Y_ALWAYS`는 검토용 빌드에서만 켠다. Flutter는 캔버스에 그려서
# 접근성 트리가 없으면 `uiautomator`로 화면을 못 읽는다 — 이걸 켜야
# tools/ui.sh 로 화면을 글자로 확인하고 이름으로 누를 수 있다.
flutter build apk --release --split-per-abi --target-platform "$TARGET" --dart-define=A11Y_ALWAYS=true

APK="build/app/outputs/flutter-apk/app-$ABI-release.apk"
ls -l "$APK"
echo "APK=$APK"
