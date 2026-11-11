# Architecture decision: explicit global fallback, disabled by default

MarbleScroll is new Swift source and fresh Git history. No DragScroll code, binaries, build settings, cursor-warp technique or recovery logic is reused.

## Device isolation investigation

| Mechanism | Device identity | Can suppress only that device? | Trade-off |
| --- | --- | --- | --- |
| Public Core Graphics mouse event fields | No documented ordinary-mouse USB identity. Event number pairs clicks; source PID/state identify event sources, not physical USB mice | No reliable supported attribution found | Must disclose global scope; do not guess based on timing, private field numbers or PID |
| IOHIDManager, nonexclusive input observation with VID/PID matching | Yes, HID device/element callbacks | Does not remove the corresponding mouse event from the Quartz stream | Raw observation alone cannot freeze the pointer; correlating it with Quartz is race-prone with two devices. May need Input Monitoring |
| IOHIDManager exclusive seizure | Yes | Removes normal delivery for seized device | Requires replaying ordinary movement and every button; crash/revoke/disconnect recovery becomes much riskier; not chosen |
| DriverKit / private IOHIDEvent APIs | Potentially | Different privileges/entitlements or unsupported API | Excessive scope, distribution complexity, not chosen |

Decision: **no claim of device-isolated interception**. Use event-driven IOKit USB registry presence/removal notifications for `046D:C408`, without opening/seizing HID input or requesting Input Monitoring. Scrolling requires presence plus explicit per-session consent to global mouse filtering. Other pointing devices can drive the active mode. Default launch cannot create a tap: it requires `--allow-live-input`, the user's menu action, a scope-consent dialog, a configured secondary button, and existing Accessibility trust. Consent/enabled/locked state is never persisted. Reconnect/wake never auto-enables.

This deliberately exposes a limitation instead of shipping unreliable device attribution. If strict per-device isolation is mandatory, leave this backend disabled; a future device-specific backend needs its own review and hardware validation.

Sources: [CGEventField](https://developer.apple.com/documentation/coregraphics/cgeventfield) documents mouse event numbers, source metadata, and tablet-only identifiers. [IOHIDDeviceOpen](https://developer.apple.com/documentation/iokit/1588670-iohiddeviceopen) documents exclusive seizure. [IOHIDManager](https://developer.apple.com/documentation/iokit/iohidmanager_h) documents matching/input callbacks. This architectural conclusion is an inference from those supported interfaces, not a proof no possible driver solution exists.

## Input path and safety

The native adapter requests a mouse-only **HID-entry Core Graphics tap**, where dropping motion can precede cursor updates. It returns a replacement scroll event at the same pipeline position. No cursor warp, cursor disassociation, global suppression interval, grabbed device, synthetic click, or external input daemon is used. If an unprivileged process cannot create that tap, stay disabled: no administrator request or later-stage/warp fallback. Apple's documentation describes restrictions on HID-level taps; exact Sequoia/TCC behavior and pointer stability must be verified manually after approval. A compiled implementation is not a claim that a live tap or pointer lock was tested.

Mask: movement plus all three dragged variants, other-button down/up. No left/right down/up, keyboard, flagsChanged, wheel or tablet subscriptions. Other-button events pass unless the configured button is reserved. The same configured button uses paired consumed downs/ups during ordinary operation; cancellation prioritizes restoring all input even if an unmatched side-button up subsequently passes. No synthetic down can leave a button held.

`MarbleCore` is platform-independent state/configuration/lifecycle logic. The `Session` checks permission and presence before every input decision; failure returns the original event and closes the tap. Backend shutdown first disarms a synchronized safety gate, then disables/invalidates its CFMachPort. Output creation failure also returns the physical event. Synthetic scrolls carry a marker and are excluded from the tap mask. A timeout permits one fresh tap per enable session, resets click/lock state, and never restores a lock. User-disabled taps, revocation, disconnect, sleep, session deactivation and emergency disable require explicit re-enable. No idle permission polling or auto-enable on wake.

Native callback, state machine, timers, USB notifications and menu are owned by the main run loop. No waiting, modal UI or file I/O in the tap callback; status updates are queued/coalesced. One-shot timers only recognize holds/double-click expiry or bounded timeout recovery. An independent DispatchSource signal queue can invalidate the tap even while the main thread is busy. SIGUSR1 disables; SIGTERM/SIGINT invalidate then exit. SIGKILL/crash relies on the OS removing process-owned Mach resources: no system-wide cursor state is changed. This substantially limits residual effects; actual crash/revoke recovery remains a hardware-test acceptance item, not an absolute software guarantee.

## Interaction policy

States: NORMAL, BUTTON_PRESSED, TEMPORARY_SCROLL, WAITING_FOR_SECOND_CLICK, LOCKED_SCROLL. Press reserves the chosen button. Movement below threshold is buffered; crossing threshold immediately scrolls the full buffer and disqualifies that press from lock recognition. A one-shot hold deadline enters temporary mode even without movement. Release exits temporary mode immediately. A short click waits for a second down; system double-click timing is used unless overridden. Interval is first-down to second-down, inclusive at the boundary. A second down locks, its up retains lock. A down while locked unlocks immediately; repeated downs before its up are ignored. Moving after the first release passes through normally and cancels double-click eligibility after the configured threshold. Threshold zero intentionally makes any movement cancel click recognition.

Scroll conversion has independent axes, bounded sensitivity/speed, reverse direction, optional bounded acceleration and fractional residuals. No momentum or idle scroll generator exists. Settings changes stop scrolling first. Enabled/consent/lock state never survives app restart.

## UI, persistence and packaging

AppKit status item and settings panel, no normal Dock icon. UserDefaults stores only validated configuration. Login startup is an explicit ServiceManagement main-app action, off by default, never configured by build/tests. MIT license; native frameworks only. SwiftPM runs mock tests with the Command Line Tools; a standard Xcode app project compiles the same Swift files. Build script creates an arm64 macOS 15 app with ad-hoc local signing; it does not install or launch it.
