# Physical T-BC21 acceptance procedure — approval required

**Not performed.** Automated tests use fake events/backends only. The earlier USB registry read confirmed `046D:C408`; it did not test buttons, scrolling or recovery. Obtain separate approval before app UI launch, installation, permissions or live filtering. Do not run DragScroll during these tests.

## Preparation and recovery

- Review the architecture: this is a **global** fallback while a matching trackball is present. Accept that limitation explicitly or do not enable it. Keep another pointer and a Terminal window available, although global mode can affect both pointers while active.
- Record macOS version/build, app commit/hash/signature and existing TCC grants. Keep the default no-login configuration. Test a locally built, fixed-location bundle.
- After approved launch, record the MarbleScroll PID with Activity Monitor or `pgrep -x MarbleScroll`. Prepare `kill -USR1 PID` in Terminal to disable input from an independent signal queue. Also know `kill -TERM PID` and Activity Monitor → Force Quit. No keyboard event tap is needed. Never reboot as a normal recovery step for this app.
- First inspect the inert UI with no Accessibility grant: Enable/Detect must refuse; ordinary input must be unchanged. No prompt should appear. Stop if an unexpected permission or security change is requested.
- Grant Accessibility only after explicit approval. If Input Monitoring is requested/required, pause for a separate review/approval. Do not grant extra permissions to work around a failing tap.

## Device and button mapping

1. Confirm the connected device VID/PID and product label. Record whether any other pointer/remapper is present.
2. Launch with the explicit live-input argument, then use the ten-second button detector only after its global-observation dialog. Press one physical small button; record zero-based CG and one-based display values. Repeat for the other small button. Detector must leave ordinary clicking intact and stop after one observation/timeout.
3. Select the intended button; other buttons must remain functional. Primary buttons 0/1 cannot be configured.
4. Disconnect the trackball: enable/detect must refuse. Reconnect: scrolling must stay off until explicitly enabled again.

## Interaction matrix

After enabling with explicit global consent, verify each item and record pass/fail:

| Test | Expected |
| --- | --- |
| Move without activation | Ordinary pointer, no synthetic scroll |
| Short single click | No persistent scroll; pointer normal after release |
| Hold and roll immediately | After at most the configured movement threshold, smooth two-axis scroll; no pointer movement |
| Hold without movement, then roll | Temporary mode at hold deadline; next movement scrolls |
| Release while temporarily scrolling | Immediate normal pointer; no momentum/tail |
| Double-click | Locks on second down; releasing it leaves lock active |
| Single click while locked | Unlocks on down; release does not relock |
| Move between clicks | Pointer moves normally after first release; travel past threshold cancels recognition |
| Hold/roll then click | Temporary scroll is not mistaken for first click of a lock |
| Rapid/duplicate clicks | Deterministic state; no surprise lock, stray generated clicks or stuck button |
| Other buttons, modifiers and drags | Ordinary unrelated buttons; no keyboard interception. Verify primary button ups still work |
| Second mouse/trackpad | Demonstrates disclosed global behavior; never claim it is isolated |
| Reverse, low/high speed and separate axes | Expected sign/sensitivity, stable pointer, no runaway output |

Watch pointer position using visible landmarks or an independently reviewed measurement tool; do not grant Screen Recording just to measure this. Any pointer drift is a failing acceptance result. Do not add cursor warping as a workaround.

## Applications

Test Chrome, Safari, Firefox, Finder, VS Code, Preview and another available PDF viewer. Record exact versions and document/window type. Place the pointer at several positions **within the intended scrollable region**, including away from scrollbars; scroll routing follows the native location, not keyboard focus or an arbitrary window. Outside a scrollable region/macOS scroll target, scrolling is not guaranteed. Test nested panes separately.

Use a horizontally overflowing document for horizontal tests. Apps/documents that do not expose horizontal scroll will ignore that axis; distinguish that from a converter failure. This app does not force an application to scroll, remap horizontal input to vertical or bypass its scroll hit testing.

## Supervised safety tests

Run one scenario at a time with Terminal recovery prepared:

- Disable using the menu during temporary and locked mode: normal pointer returns; no auto-enable.
- Send SIGUSR1 during each mode, including near a timer/recovery boundary: port invalidates and remains inhibited. One already in-flight event may race; sustained interception after disable is a failure.
- Disconnect while pressed/locked; reconnect: ordinary input restored and scrolling remains disabled.
- Sleep/wake, lock/switch session: state cancelled, no auto-enable or stale click sequence.
- Revoke Accessibility while active **only after explicit approval for this safety test**: the next event must pass and the app must disable; an idle revoke may be noticed at the next event/menu check. If the OS stops delivering callbacks, the tap must already cease filtering. Stop on any deviation; do not repeatedly reproduce a loss of input.
- Terminate with SIGTERM and, in a separately approved crash-recovery test, SIGKILL while pressed/locked: normal pointer must remain functional after OS process teardown. Restart must be disabled/NORMAL.
- Timeout/creation/allocation failures are mock-tested. Do not hang the main thread or inject native faults in a live session without an additional reviewed test harness. Native timeout behavior is therefore still an explicit manual validation gap.

Record failures, event sequence, app state and recovery action without logging keyboard/clipboard/screen content. If recovery cannot be demonstrated with termination, do not use the app continuously or publish a binary release.

## Performance acceptance

With the approved native app idle and then scrolling, measure process CPU, resident memory, energy and event/cursor latency with Activity Monitor/Instruments. Observe idle for at least 60 seconds and record hardware/load. Compare disabled versus enabled idle and sustained scrolling in several apps. The included mock benchmark is a lower-bound/core-path measurement, not a substitute for real native-tap latency/CPU or a long-duration reliability soak.
