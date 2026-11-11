#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
mkdir -p build
xcrun swift build --disable-sandbox --scratch-path .build --cache-path .build/cache --config-path .build/config --security-path .build/security --configuration release --arch arm64 2>&1 | tee build/build.log
app="$PWD/build/MarbleScroll.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
binpath=$(xcrun swift build --disable-sandbox --scratch-path .build --cache-path .build/cache --config-path .build/config --security-path .build/security --configuration release --arch arm64 --show-bin-path)
cp "$binpath/MarbleScroll" "$app/Contents/MacOS/MarbleScroll"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
codesign --force --sign - --options runtime --identifier com.kaushr.MarbleScroll "$app"
codesign --verify --strict --verbose=2 "$app"
file "$app/Contents/MacOS/MarbleScroll"
printf 'Built (not installed or launched): %s\n' "$app"
