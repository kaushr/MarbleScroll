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
xcrun swift test "${swiftpm_options[@]}" 2>&1 | tee build/tests.log
