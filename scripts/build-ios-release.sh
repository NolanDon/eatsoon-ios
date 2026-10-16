#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
rc_config="${REVENUECAT_BUILD_CONFIG:-$HOME/.config/boxill-app-build/eatsoon/revenuecat.json}"
if [ ! -f "$rc_config" ]; then echo "Missing private RevenueCat build configuration: $rc_config" >&2; exit 1; fi
if [ -x ../.toolchains/flutter-3.47.6/bin/flutter ]; then
  ../.toolchains/flutter-3.47.6/bin/flutter build ipa --release --dart-define-from-file="$rc_config" "$@"
else
  flutter build ipa --release --dart-define-from-file="$rc_config" "$@"
fi
