#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export ANDROID_SIGNING_PROPERTIES="${ANDROID_SIGNING_PROPERTIES:-$HOME/.config/boxill-android-signing/eatsoon/signing.properties}"
if [ ! -f "$ANDROID_SIGNING_PROPERTIES" ]; then
  echo "Missing private Android signing properties: $ANDROID_SIGNING_PROPERTIES" >&2
  exit 1
fi
rc_config="${REVENUECAT_BUILD_CONFIG:-$HOME/.config/boxill-app-build/eatsoon/revenuecat.json}"
if [ ! -f "$rc_config" ]; then
  echo "Missing private RevenueCat build configuration: $rc_config" >&2
  exit 1
fi
if [ -x ../.toolchains/flutter-3.47.6/bin/flutter ]; then
  ../.toolchains/flutter-3.47.6/bin/flutter build appbundle --release --target-platform=android-arm64,android-x64 --dart-define-from-file="$rc_config" "$@"
else
  flutter build appbundle --release --target-platform=android-arm64,android-x64 --dart-define-from-file="$rc_config" "$@"
fi
