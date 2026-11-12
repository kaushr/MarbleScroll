# MarbleScroll

A small native Swift macOS menu-bar utility for button-controlled trackball scrolling. MIT licensed; no packages, network services, telemetry, updater, privileged helper or keyboard interception.

**Status: compiled prototype; automated mocks tested; live input and hardware validation pending.** Normal launches are inert. Live operation requires `--allow-live-input`, an explicit enable action, per-session global-scope consent, a configured secondary button, a connected `046D:C408` trackball and an existing Accessibility grant. No permission request is made automatically.

- Hold the chosen small button and roll to scroll on two axes; release to restore pointer movement.
- Double-click the same button to lock; single-click to unlock.
- Settings: speed, direction, independent axis sensitivity, optional acceleration, click/hold/movement thresholds.
- Menu disable, SIGUSR1 emergency disable, lifecycle cancellation and bounded tap recovery.
- Build for Apple Silicon, minimum macOS 15.0; target environment Sequoia 15.7.8.

**Device limitation:** VID/PID presence is checked, but the Core Graphics fallback filters the global mouse stream. It cannot reliably attribute movement to the trackball. It is never enabled without explicit consent. No HID device is seized. Pointer stability and fail-open behavior are implemented but require physical acceptance testing before normal use.

See [architecture and isolation trade-offs](docs/ARCHITECTURE.md), [security design](docs/SECURITY.md), [threat model](docs/THREAT_MODEL.md), [test results](docs/TEST_RESULTS.md), [build results](docs/BUILD_RESULTS.md), [mock performance measurements](docs/PERFORMANCE.md), [build/install/permissions](docs/INSTALLATION.md), [manual hardware test](docs/HARDWARE_TESTING.md), and [troubleshooting/removal](docs/TROUBLESHOOTING.md).

```sh
./scripts/test.sh
./scripts/build.sh
```

Output: `build/MarbleScroll.app`. Building does not install, launch, grant permissions, configure login startup or publish a binary. Xcode users can open `MarbleScroll.xcodeproj`; the SwiftPM test suite also works with Apple's Command Line Tools. A paid developer account is not required.

## Attribution

[DragScroll by Emre Yolcu](https://github.com/emreyolcu/drag-scroll) and [Kaushik's reference fork](https://github.com/kaushr/drag-scroll) informed the behavioral idea of turning trackball X/Y deltas into two-axis scrolling while a button mode is active. The fork preserves the [completed static security audit](https://github.com/kaushr/drag-scroll/blob/48fabc0/docs/SECURITY_AUDIT.md), covering source commit `879bd0e6f4f1aae239364c5e7e49f19746729993` (also the fork's reference implementation at audit time).

MarbleScroll is an independent repository with fresh history. No DragScroll source, event-handling implementation, cursor-warp/suppression technique, recovery code, build configuration, or binaries were copied. The hold/double-click state machine, safety architecture, UI and tests are new. DragScroll is MIT licensed; its original source/license remain in the reference fork.

Copyright 2026 Kaushik Ruparel. See [MIT license](LICENSE).
