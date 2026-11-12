# Supervised hardware test — in progress

Date: November 11, 2026, America/Los_Angeles. Host: macOS 15.7.8 (24G824), Apple Silicon.

The user approved live T-BC21 testing, the global fallback and Accessibility. Launch at login remains disabled; no binary release is authorized or published. This document supersedes the original pre-test status only for the observations listed below.

## Connection and eligibility

- User reports the trackball is connected through a **KVM switch + USB hub + USB-C** and confirmed readiness.
- Unrestricted USB metadata inspection observed Logitech USB Trackball, vendor `046D`, product `C408`, USB location `0x00110000`. The restricted shell initially could not enumerate the device; this was not evidence of disconnection.
- The native setup window reports **Trackball: connected**. Registry eligibility therefore works through the current KVM/hub path. KVM switching/disconnect behavior has not yet been exercised.
- Added the exact local build to macOS Accessibility using System Settings, with the user performing Touch ID authentication. No Input Monitoring, Full Disk Access or Screen Recording grant was made for MarbleScroll. No TCC database modification or security bypass was used.

## Setup issue and correction

The user reported that pressing/rolling and double-clicking the physical button did nothing. Reading only MarbleScroll's own preference domain confirmed **no saved button mapping**. No successful scroll-mode activation or failed native scrolling was established from this attempt.

Added a visible first-run **Setup & Status** window with Detect Small Button, explicit Enable Scrolling, prerequisite/state text, settings and emergency disable. The app still starts disabled and does not begin detection/interception automatically. It opens this window when unconfigured or when explicitly reopened. Code commit: `6562199adb2173f4b5ee788e367dd0e6b4947dc3`.

The fix passed all **74 mock tests** (0.017 seconds reported test execution), compiled in Release arm64, and passed strict signature verification. Rebuilding changed ad-hoc identity; the new setup correctly reported Accessibility missing even though System Settings still displayed the stale entry as on. Removed only that stale MarbleScroll entry and re-added the exact rebuilt bundle. The detector then passed the live-flag/device/AX checks and displayed its observation-consent dialog.

New executable SHA-256:

```text
69cb524d47f7b0fec71ece77b1e053527d28e57a8af50c741ef88ba900a02617
```

## Recovery observations

- Verified the initial disabled app process and terminated it using its SIGTERM handler before relaunch/rebuild. A subsequent process appeared at the expected executable path. This is a disabled-state termination observation, not a crash-while-scrolling test.
- Sent SIGUSR1 to the verified earlier test process after the reported nonactivation. No claim is made that scrolling was active beforehand.
- Read-only `CGGetEventTapList` metadata for the rebuilt process showed **no active/registered tap while setup awaited consent**. The helper filters output to the target PID, reads no event content, creates no tap and requests no permissions. Its source is `scripts/tap-status.swift`.
- Accepted the detector dialog under the existing live-test approval. The setup window reported Listening, and native metadata verified a HID-entry (`tapPoint=0`), enabled **listen-only** tap with event mask `0x02000000` (secondary mouse-button down only). This establishes native detector creation with Accessibility alone on this Mac; no Input Monitoring or root privilege was needed. No physical button event was captured in that timed observation. The window returned to Normal/Disabled after the ten-second timeout.
- A later metadata check again returned no taps for the app PID. While the setup window was disabled and waiting, `ps` reported 0.0% instantaneous CPU and 64,736 KiB RSS (about 63.2 MiB), with 0.49 seconds accumulated CPU over 6:50 process lifetime. This includes startup/UI operations and is a single native setup sample, not a controlled idle benchmark or an enabled-scrolling measurement.

## Pending physical acceptance

The user subsequently reported “works” / “worked.” Reading MarbleScroll's own saved preferences confirmed **CG button 3**, and native metadata showed an enabled modifying HID-entry tap with mask `0x0e0000e0`. This supports successful user setup and native tap activation. The user suspected an existing double-click action on button 3 had caused the earlier issue; that cause has not been independently established, and no OS button binding was changed.

Individual hold/release, lock/unlock, stationary-pointer, cross-application and active failure-recovery cases have not been separately observed or measured by the agent. KVM/disconnect, sleep/wake and enabled native performance remain pending acceptance checks. The reported working behavior must not be expanded into a completed per-application or crash/revocation safety test matrix.

The local scroll fixture `Tests/Fixtures/ScrollSurface.html` provides two-axis overflow and transient pointer/wheel/scroll counters for the next test. It has no network requests, keyboard listeners or persistent storage. It has not yet produced a hardware result.

Do not interpret setup/permission success or mock tests as a physical scrolling pass. Follow [hardware testing](HARDWARE_TESTING.md) and record actual outcomes before continuous use or any binary release.

## UX follow-up

At the user's request, detection now lives in Configure Button: an unchecked **Enable Button Detection** option first makes **Start Tracking** available; only that second click starts observation. The detected button appears inline for explicit selection and Save. Unchecking, Stop Tracking, timeout, closing or cancelling stops tracking. The choice is not persisted. During detection, clicks pass through, so the UI asks for a single press rather than a double-click.

Settings now has Cancel and Escape, both discarding draft edits. Setup & Status is retained and has a separate Close/Escape control that only dismisses the window, leaving the menu-bar app running. Scrolling Enabled starts directly without the repeated session popup; Reverse Direction is immediately below it and changes both axes without disabling the session. Ordinary restart and safety failures still reset activation.

Verified against the preceding `bbce37f` build using native UI:

- Changed speed from 2.0 to 7.0, clicked Cancel, reopened settings: speed remained 2.0. Escape also closed settings.
- The missing-Accessibility notice had a Cancel button and dismissed without enabling.
- Checking detection displayed Ready and enabled Start Tracking; read-only tap metadata remained empty. The separate Start click displayed Tracking; Cancel closed the window and returned to Normal/Disabled.
- Enable Scrolling went directly to Enabled without a popup; the next click disabled it.
- Saved button 3 remained intact. No login startup or binary release was configured.

Final Close-button build: source commit `c71bea660d10d3a03c2b406d7133bf8fdbecf07a`, executable SHA-256 `aa3b4fab543166db16cca940e7e877ab203a91156e991598aa1c84b994af976f`. Release arm64 compilation and strict signature verification pass. The core suite has **84 passing tests**, including two-step detection cancellation/rearm and live reverse-direction state/residual handling.

The Mac locked during the final build's Accessibility-entry refresh; completion of that refresh and the final Setup Close/Escape UI check are pending user unlock. A locally retained previous build is under ignored `build/PreviousWorking/`; only the main build path should be launched to avoid ambiguous bundle-ID lookup. App stops during these updates were deliberate verified-process SIGTERM operations, not observed crashes.
