# Current verification status

Updated November 11, 2026 (America/Los_Angeles). This is the sole current build/test/performance/hardware results log. It replaces BUILD_RESULTS.md, TEST_RESULTS.md, PERFORMANCE.md and HARDWARE_RESULTS.md; their dated versions remain in Git history through `918230d`. The independent DragScroll audit remains unchanged in the reference fork.

**Compiled prototype; physical acceptance incomplete.** User approval covers supervised T-BC21 testing, global fallback and Accessibility. Launch at login must remain disabled. No binary release is authorized or published. Installation has not been performed.

## Current source and automated results

Implementation: `1987100`. Build/CI configuration: `26c4e9768f71e19f8df9f330446f1571e43c8c72`. See [review response](REVIEW_RESPONSE.md) for the supplied static review of older `3a42c42`.

| Check | Result and scope |
| --- | --- |
| Local automated suite | **PASS: 105 mock tests**, zero failures, 0.017 seconds reported execution. Swift 6 mode, no compiler warnings |
| Local Release arm64 app | **PASS**, SwiftPM build and strict ad-hoc signature verification. Built separately; candidate not installed or launched with native UI/input |
| Project / Info.plist syntax | **PASS**, plutil lint; all twelve Swift implementation files referenced in Xcode |
| macOS CI | **PASS**, [run 43163348589](https://github.com/kaushr/MarbleScroll/actions/runs/43163348589), exact revision 26c4e97; Xcode 16.4, Swift 6.1.2 |
| CI mocks | **PASS: 105 tests**, zero failures, 0.017 seconds reported execution |
| CI SwiftPM build | **PASS**, Release arm64 bundle and signature |
| Actual Xcode build | **PASS in CI**, Release arm64, BUILD SUCCEEDED; strict signature verification passed. AppIntents metadata extraction emitted an informational skipped-extraction warning because this app does not use AppIntents |
| Local Xcode engine | **Unavailable**, Command Line Tools selected and no full Xcode installed. No developer-directory change/download performed; CI supplies actual Xcode evidence |
| SwiftPM manifest sandbox | Enabled by default. Local nested command sandbox rejected sandbox_apply; the same default scripts passed outside that nested sandbox. Optional restricted-host opt-out is explicit, not the default |
| Signing identity | Read-only local check: zero valid code-signing identities. Default remains ad-hoc; no certificate/trust change made |
| Candidate hardware/UI | **NOT TESTED**. Older-build observations below must not be treated as acceptance of this candidate |

Local host: Apple Silicon, macOS Sequoia 15.7.8 (24G824), Swift 6.1.2, SDK 15.5. Candidate minimum macOS 15.0, arm64. Local candidate:

```text
build/ReviewCandidate/MarbleScroll.app
SHA-256 (Contents/MacOS/MarbleScroll):
678bbbd8c0c2c25a5f38726c91e3d78ef7205b49d63d86e7d25d6fcff296d4c1
```

The regular `build/MarbleScroll.app` was not overwritten or restarted for this review. Build products/logs are ignored and have not been uploaded as artifacts or releases. Source was pushed to the public MIT repository only.

## What the tests establish

The original core tests cover normal movement, press, hold/move/release, double-click/lock/unlock, rapid/duplicate clicks, timing boundaries, direction and both axes, synthetic recursion rejection, malformed inputs/settings, device disconnect, permission revocation, tap failure/bounded recovery, termination/restart and emergency inhibition. Saved configuration and gesture state remain separate; enabled/lock state is not persisted.

The current additions exercise production `MouseTapRouter` logic with fake resources: unarmed pass-through, marker bypass, timeout/user-disable classification, disarm-before-fault notification, permission loss in both modes, one-shot pass-through detection, ignoring primary/unhandled events, missing route, output allocation failure, and emergency inhibition before emission. Permission cache expiry/forced refresh/backwards/nonfinite time, menu-open detection preservation, cancelled/replaced recovery tickets, every localized start error, and the new 300 ms hold default are covered. Generation protection is also used by native detection timers/results.

**Limits:** no mock proves CFMachPort/source creation or invalidation, TCC enforcement, native callback ordering, successful scroll delivery, pointer freeze, app compatibility, real timeout scheduling or OS crash teardown. Those remain hardware/integration gates. Native input/timers use the main run loop and can still be delayed by UI load despite cached/coalesced work.

## Performance evidence

Current candidate `--mock-benchmark` branches before NSApplication/AppDelegate, IOKit, AX and native tap construction. It uses a fake backend/output; no hardware input or permission request:

| Metric | Current mock result |
| --- | ---: |
| Disabled idle timed wait | 5.010 seconds |
| CPU over that interval | 0.0009% |
| Resident memory after wait | 2.75 MiB |
| Routed mock motion events | 1,000,000 |
| Elapsed / mean per event | 0.0850 seconds / 0.0850 microseconds |
| Resident memory afterward | 2.86 MiB |
| Output checksum | -6,000,000 |

CPU uses self getrusage user+system delta divided by monotonic elapsed time. RSS uses self MACH_TASK_BASIC_INFO. This is a core-path lower bound: it excludes AX queries, native event creation/posting, UI, registry callbacks and rendering. A five-second near-zero idle sample does not establish production energy/soak behavior.

Earlier native disabled setup sample (before current source): ps reported 0.0% instantaneous CPU, 64,736 KiB RSS (about 63.2 MiB), 0.49 accumulated CPU seconds over 6:50 process lifetime. It includes startup/UI activity and is not a controlled idle benchmark. **Enabled native CPU, memory, latency and long-duration reliability remain unmeasured.**

## Historical supervised observations

These are dated older-build observations, not a completed acceptance matrix:

- User connected the trackball through **KVM + hub + USB-C**. Unrestricted USB registry metadata found Logitech USB Trackball `046D:C408`, location 0x00110000; native presence reported connected. Initial restricted-shell enumeration missed it; that was not proof of disconnection. KVM switching remains untested.
- User performed Touch ID and manually added the exact local app to Accessibility. No MarbleScroll Input Monitoring, Full Disk Access or Screen Recording grant, TCC database edit or security bypass was performed. Ad-hoc rebuilds subsequently required stale-entry removal/re-addition.
- Initial nonactivation had no saved button mapping. After setup, user reported “works” / “worked”; reading the app's preferences confirmed **CG button 3**. Existing button-3 double-click behavior was suspected by the user, not established as the cause; no OS binding was changed.
- Read-only CGGetEventTapList metadata established no tap while waiting/disabled; detection created an enabled HID-entry listen-only secondary-down tap (mask 0x02000000); a later modifying tap had mask 0x0e0000e0. This demonstrated native creation with Accessibility alone on this Mac, not pointer stability or isolation.
- Older disabled processes were deliberately stopped with verified-path SIGTERM during updates. SIGUSR1 was also sent, but prior active scrolling was not established. Neither observation proves recovery from active scrolling or an unexpected crash.
- On `bbce37f`, native UI verified settings Cancel discarded speed 7.0 (reopen showed saved 2.0), Escape closed settings, missing-permission notice had Cancel, detection readiness created no tap, separate Start created tracking, Cancel stopped it, and Scrolling Enabled toggled directly without another popup.
- `c71bea6` added Setup & Status Close/Escape and compiled/signed successfully (84 mocks). Its executable digest was aa3b4fab543166db16cca940e7e877ab203a91156e991598aa1c84b994af976f. The Mac locked during final Accessibility refresh; its completion and final Close/Escape native check were not observed. No current-candidate UI result is inferred from that interrupted operation.

## Remaining gates and known limitations

1. **First: visible pointer and scroll target must stay stationary while hold/locked scrolling.** Dropping mouse motion is an unverified hypothesis. Neither application pointer-event counters nor successful scrolling proves cursor freeze. Follow the first gate in [hardware testing](HARDWARE_TESTING.md). Stop on drift; do not silently add warp/disassociation.
2. Independently verify each hold/release/lock/unlock case, then cross-application two-axis behavior. User-reported working behavior is partial evidence, not a full pass.
3. Test active emergency disable, disconnect/KVM switch, sleep/session change, permission revocation and termination/crash recovery under supervision. Permission snapshots may take up to 250 ms of active input to notice revocation; OS enforcement may act sooner. One in-flight event may race emergency invalidation.
4. The Core Graphics fallback is **global**, gated only by trackball presence. Other mice/trackpads can drive the active mode. No reliable physical-device attribution is claimed.
5. Native scroll posting has no delivery acknowledgment. Apps need actual scrollable content/overflow and pointer hit-testing support; horizontal support varies.
6. New settings default to a 0.30-second hold threshold. Previously saved 0.18-second or custom values remain unchanged; select 0.30 in Settings to try the new default on an existing profile.
7. Ad-hoc signing still causes permission churn. The candidate needs an exact-bundle grant check before live use; no grant, certificate provisioning or live launch was performed in this review.
8. Login startup remains off and untested. Normal launches no longer need a terminal flag but always require explicit enable; --no-live-input provides inert UI diagnostics. No release readiness is claimed.

Do not enable continuous daily use or publish a binary until the physical gates pass. Keep the separate reference audit intact and label every new result with exact source/build, permissions, app/version and actual observation.

## Resumed check after Git reconciliation

Fetched origin and verified local HEAD, origin/main and GitHub main all at 839286be480e40c2ba4e19a8ab15ca5718314566, with a clean working tree, zero commits ahead/behind and no stashes. CI for that exact revision also passed: [run 43163878754](https://github.com/kaushr/MarbleScroll/actions/runs/43163878754).

The existing regular-bundle process (PID 6746, older c71bea6 artifact) was still running. Native Setup & Status showed **Scrolling disabled**, saved CG button 3, trackball not detected and Accessibility missing. The user is away from the trackball, so physical testing is deferred. No process was stopped/restarted, no candidate was launched and no permission or login setting was changed during this check. This is an older-build UI observation, not current-candidate acceptance.
