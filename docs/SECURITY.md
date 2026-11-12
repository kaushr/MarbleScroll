# Security design and review

MarbleScroll is a local input utility. Source and build configuration were reviewed during implementation; this is not a malware-free certification, independent penetration test or proof of macOS recovery behavior. See [threat model](THREAT_MODEL.md), [architecture](ARCHITECTURE.md), [reference audit](REFERENCE_AUDIT.md) and [hardware acceptance procedure](HARDWARE_TESTING.md).

## Permissions and authority

| Capability | Implementation / policy |
| --- | --- |
| Accessibility | Read-only `AXIsProcessTrusted` checks. Needed by the proposed modifying tap/scroll-output path. The grant permits broader computer control than this utility uses; the user must approve that risk before adding it manually. No trust-prompt API is called |
| Input Monitoring | Not requested. No IOHIDManager open or input report subscription. Whether this macOS configuration needs additional TCC authority to create the proposed tap is unverified; if required, stop and seek separate approval instead of granting it |
| Keyboard | No key, modifier-flags, hotkey or global AppKit keyboard monitor. Menu shortcuts are ordinary app-local AppKit menu behavior |
| USB discovery | Event-driven IOKit registry matching for vendor/product metadata and removal. No input access or device seizure. Presence is a gate, not proof of event origin |
| Login startup | Optional `SMAppService.mainApp` registration only on explicit menu action. Not registered by build/test/default launch. Not necessary for scrolling |
| Files | Validated settings in UserDefaults only. No input logs, arbitrary content scan, browser, clipboard, Keychain or screen access |
| Network | No URLSession, sockets, telemetry, analytics, remote configuration or updater. Links in documentation are references; no runtime network client |
| Privilege | No root/admin prompt, helper, launch daemon, extension, injected library or third-party dependency |

No Full Disk Access, Screen Recording or system security setting changes. No quarantine removal, Gatekeeper bypass, `sudo`, downloaded binaries or unsigned third-party package execution in the build workflow. The app is intentionally unsandboxed because a sandboxed distribution is not assumed to support its filtering behavior. Ad-hoc local signing enables hardened runtime, with no custom entitlements; it does not establish a verified publisher or notarization.

## Fail-open properties implemented

1. Ordinary launches cannot create a tap without `--allow-live-input`. Enabling still requires a user action, global-scope dialog, verified secondary button configuration, trackball presence and existing Accessibility trust. Enabled/consent/lock state is never saved.
2. Input is transformed by a process-owned mouse-only event tap. No cursor warp, disassociation, suppression interval or seized device persists outside that process. Crash/SIGKILL should remove the process-owned tap via OS teardown; actual Sequoia behavior remains an acceptance test.
3. Each input decision checks permission and device presence. If either fails, the physical event passes and the session stops. Idle revocation is discovered on the next event/menu check; there is no idle polling timer. An idle invalidated tap is not treated as proof of a live pointer failure.
4. Tap creation/run-loop-source failure invalidates partial resources. Scroll-output allocation failure disarms input and returns the original physical event. Disabled-tap callback first invalidates the port; only one timeout recovery is allowed per explicit enable, after a one-shot delay, in NORMAL state. User-disabled taps never auto-recover.
5. Sleep, session deactivation, device removal, settings changes and quit invalidate the tap and cancel recognition/recovery timers. Reconnect/wake/permission restoration never auto-enable.
6. SIGUSR1 runs on an independent dispatch queue, inhibits future arms and invalidates the tap; SIGTERM/SIGINT do the same then exit. An already in-flight event can race with the signal between the last gate check and output/suppression. Do not promise zero transformed events after signal delivery. No state can remain grabbed by a helper after process death.
7. No keyboard interception is used for emergency control. Terminal `kill -USR1 PID`, Activity Monitor or process termination are independent of the tap callback. A single configured-button down also exits a lock during ordinary operation.
8. Synthetic wheels carry a marker and are excluded from the interception mask. Settings/deltas are finite and bounded; fractions accumulate without an idle scroll source. There are no synthetic clicks or injected key events.

## Review conclusions and limits

- All implementation is new Swift; no DragScroll event-handling/recovery code was copied.
- Source review found no runtime networking, analytics, input logging, arbitrary filesystem access, subprocess execution, custom dynamic loading, hidden auto-start or external dependency.
- Build chain: local SwiftPM manifest with no packages/plugins; shell scripts only compile/test/package/sign reviewed local source. No Xcode Run Script phases or workflow downloads. `--disable-sandbox` applies only to SwiftPM's subprocess manifest sandbox inside this restricted development environment; it changes no macOS security setting and does not disable Gatekeeper or the machine sandbox. The manifest is reviewed local code with no dependencies.
- **Device isolation remains a functional limitation.** Public mouse CGEvents cannot reliably identify the USB mouse; global interception requires explicit consent. A second pointer can scroll while mode is active. Do not describe this as device-isolated input.
- **Pointer stability and OS failure recovery are unverified.** Dropping movement at the requested HID-entry tap is the intended pre-cursor mechanism. Apple documents restrictions on creating such taps; failure leaves the app disabled. Never run as root or silently substitute cursor-warp/seizure behavior to make it work.
- Core mock tests verify state/lifecycle contracts and backend cleanup calls. They cannot verify actual TCC enforcement, CFMachPort invalidation, OS scheduling, event ordering, pointer freeze, library callback behavior or cross-application scroll acceptance.
- The native scroll-post API has no delivery acknowledgment. Allocation failures and a mock emitter returning false are handled; silent OS/application rejection of a posted scroll cannot be detected by that contract.
- Local same-user synthetic mouse injection, fake VID/PID hardware and UserDefaults tampering are possible assumptions; they are not authenticated physical user intent. No new cross-user privilege boundary is claimed.
- No adversarial/physical inputs, permissions or native taps were exercised during development. Actual UI rendering and launch-at-login registration remain untested. No release binary is published.

Treat physical acceptance as a release blocker. Stop on drift, stuck input, unexpected permissions, unbounded recovery, or changes to another pointer's behavior beyond the disclosed global mode. A hardware result must be recorded with OS/build, executable digest, permissions and exact app tested.
