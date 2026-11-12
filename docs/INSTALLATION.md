# Build, permissions and optional installation

Current observations and outstanding tests are in [STATUS.md](STATUS.md). Supervised global-mode/Accessibility testing is approved for this session; installation, login startup and binary releases have not been performed.

## Build from reviewed source

Apple Silicon, macOS 15 or later, Swift 6.1+ via Command Line Tools or Xcode:

```sh
./scripts/test.sh
./scripts/build.sh
```

Output: `build/MarbleScroll.app`; native frameworks only, no package downloads. Scripts compile/test/package/sign; they never install, launch, grant permissions or configure login startup. Logs/caches/build products are ignored by Git. SwiftPM's manifest sandbox is enabled by default. On a restricted authoring host that cannot nest it, explicitly opt in to `MARBLESCROLL_SWIFTPM_DISABLE_SANDBOX=1`; no OS setting is changed. Prefer normal sandboxing outside that host.

The Xcode project and shared scheme compile the same source in Swift 6. The macOS workflow runs mock tests, a SwiftPM arm64 build and an actual Xcode Release arm64 build. It launches no app and publishes no binaries. Local Command Line Tools alone cannot run `xcodebuild`; see current CI evidence in STATUS.md. Do not switch developer directories or download tools automatically.

Default signing is ad-hoc. To deliberately use an **existing** code-signing identity:

```sh
MARBLESCROLL_SIGNING_IDENTITY='Your existing identity' ./scripts/build.sh
```

The script creates no certificate and changes no Keychain trust. No valid signing identity was found on the implementation host. Ad-hoc rebuilds can invalidate Accessibility grants even when System Settings still shows the old entry on. A stable identity/designated requirement may help, but its behavior must be verified. No paid account is required for the default local build.

## Approved supervised launch

1. Use a fixed local bundle; keep an independent pointer and Terminal recovery command available. Do not install merely to test. Installation to `~/Applications` is a separate user action after approval.
2. Launch normally using Finder or `open /absolute/path/MarbleScroll.app`. It starts disabled/NORMAL, creates no tap and requests no permission. The old --allow-live-input argument is no longer required. For UI-only inspection, `open /absolute/path/MarbleScroll.app --args --no-live-input` refuses all tap starts.
3. With the broader permission risk approved, add **that exact bundle** manually in System Settings → Privacy & Security → Accessibility. Never grant unrelated Terminal/Xcode/Codex permissions, Full Disk Access or Screen Recording. If a rebuilt bundle is no longer recognized, quit it and remove/re-add only its stale entry manually. No TCC database reset/edit is needed.
4. Open Configure Button. Check Enable Button Detection (readiness only), then click Start Tracking. Press the small physical button **once** within ten seconds, choose Use Detected Button, then Save. Detection observes global secondary-button downs and passes clicks through; existing button actions may still happen. No button numbering is assumed. Cancel/Escape discards edits and stops tracking.
5. Review the global-mode disclosure and choose Scrolling Enabled. This directly activates without another popup, subject to device/button/AX eligibility. Uncheck it to disable. Reverse Direction flips both axes without disabling. Setup & Status Close/Escape only dismisses that window.
6. Perform the **pointer stability gate first**, then the remaining [hardware procedure](HARDWARE_TESTING.md). Restart, disconnect, sleep and nonrecoverable faults require explicit re-enable. There is no automatic lock restoration.
7. If Input Monitoring is requested/required, stop for separate approval. Do not grant extra permissions, run as root or weaken security to bypass a failing tap.

Launch at Login is optional and never enabled automatically. During this supervised test it must remain disabled. When separately approved after stable installation, its explicit menu action registers the current app with ServiceManagement. A login launch starts disabled; normal controls work without terminal arguments. Login registration itself has not been hardware tested.

## Distribution restrictions

Ad-hoc signing supplies local integrity, not a verified publisher or notarization. No release binary is published. Prefer building reviewed source locally; do not disable Gatekeeper, remove quarantine automatically or change security settings. Record any exact launch failure and use supported user approval only when authorized.
