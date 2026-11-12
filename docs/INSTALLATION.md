# Build and permission setup

This phase delivered a locally built app only. No installation, app UI launch, permission grant, live interception or login registration was performed. Binary releases are not published.

## Build from source

On an Apple Silicon Mac with Apple's Command Line Tools (Swift 6.1 or later) or full Xcode:

```sh
./scripts/test.sh
./scripts/build.sh
```

The build writes `build/MarbleScroll.app` and logs under `build/`. It uses native frameworks only, targets arm64/macOS 15.0 and later, and signs the bundle ad-hoc with hardened runtime. There is no dependency download, install script, launch or permission request. No paid Apple Developer account is needed. Build/cache directories are ignored by Git.

The scripts use project-local SwiftPM caches. SwiftPM's manifest sandbox is disabled for this nested restricted development host; this does not change OS settings. Review the dependency-free local `Package.swift` before running. A standard `MarbleScroll.xcodeproj` and shared app scheme are also included; the scheme has no live-input argument. Mock tests run with `swift test`, rather than an empty Xcode test target.

The active developer directory on the implementation host was Command Line Tools. `xcodebuild` therefore could not validate the project through Xcode's build engine. Project/plist syntax and the same-module source configuration can be checked independently; see [build results](BUILD_RESULTS.md). Full Xcode validation remains outstanding; do not change the selected developer directory automatically.

## Install and launch — only after separate approval

1. Complete the manual test approval and review [scope and permissions](SECURITY.md). Keep an independent pointer/Terminal available.
2. If approved to install, copy your locally built app to a stable location such as `~/Applications/MarbleScroll.app`. Moving/rebuilding may change TCC identity; use a fixed bundle for testing.
3. A normal Finder launch stays disabled and cannot create a tap. It does not request permission. This is useful for UI inspection once app launch is approved.
4. After approval for the broader Accessibility grant, add **that exact bundle** manually in System Settings → Privacy & Security → Accessibility. This authority is broader than mouse-only access. Do not add Terminal/Xcode/Codex instead; do not grant Full Disk Access or Screen Recording.
5. Only after live input testing is approved, launch that fixed bundle with:

   ```sh
   open "$HOME/Applications/MarbleScroll.app" --args --allow-live-input
   ```

6. Open Configure Button. Check Enable Button Detection, which makes Start Tracking available without monitoring yet. Click Start Tracking, press the chosen small button once within ten seconds, select Use Detected Button, then Save. Observation is global and passes through; never assume particular physical numbers. Cancel/Escape discards edits and stops tracking. Setup & Status has Close/Escape to dismiss only that window.
7. Review the global filtering disclosure and choose Scrolling Enabled. That control enables directly; no extra session popup appears. Uncheck it to disable. Reverse Direction sits immediately below it and flips both axes without switching scrolling off. Trackball presence is required, but another pointer can still drive scrolling. Restart and safety failures reset activation; login startup remains off unless separately authorized.
8. If tap creation is denied or macOS requires Input Monitoring, stop. This version does not ask for that extra permission; review and obtain separate approval. Do not run as root or use a private API/warp workaround.

Launch at Login is optional and off by default. Register it only through the explicit menu action after approval and stable installation; system confirmation may be required. Even a login launch stays disabled and has no live-input argument. Login startup does not imply permission to enable filtering.

## Signing and launch restrictions

Ad-hoc signing is local integrity signing, not Developer ID/notarization. A downloaded build may encounter Gatekeeper restrictions; no such binary is distributed here. Prefer rebuilding source locally. If using full Xcode with a free personal development identity, select it deliberately and record the resulting signature; no team/keychain identity was provisioned here. Do not disable Gatekeeper, remove quarantine automatically or change security settings. Record the exact failure and use supported macOS user approval only after the user authorizes it.
