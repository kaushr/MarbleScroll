#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
mkdir -p build
# SwiftPM's manifest sandbox stays enabled unless a restricted authoring host
# explicitly opts out. This does not alter macOS security configuration.
swiftpm_options=(--scratch-path .build --cache-path .build/cache --config-path .build/config --security-path .build/security)
if [[ "${MARBLESCROLL_SWIFTPM_DISABLE_SANDBOX:-0}" == "1" ]]; then
    swiftpm_options+=(--disable-sandbox)
fi
xcrun swift build "${swiftpm_options[@]}" --configuration release --arch arm64 2>&1 | tee build/build.log
app="${MARBLESCROLL_APP_PATH:-$PWD/build/MarbleScroll.app}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
binpath=$(xcrun swift build "${swiftpm_options[@]}" --configuration release --arch arm64 --show-bin-path)
cp "$binpath/MarbleScroll" "$app/Contents/MacOS/MarbleScroll"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
# Use an existing identity only when selected explicitly. No certificates or
# Keychain trust changes are created by this script.
codesign --force --sign "${MARBLESCROLL_SIGNING_IDENTITY:--}" --options runtime --identifier com.kaushr.MarbleScroll "$app"
codesign --verify --strict --verbose=2 "$app"
file "$app/Contents/MacOS/MarbleScroll"
printf 'Built (not installed or launched): %s\n' "$app"
