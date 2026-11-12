# MarbleScroll threat model

## Overview

Implementation reviewed: `97638e97c052780fe46af5135b55abe4025c5173`. Independent architecture review plus parent verification; static review and mock tests only. Final follow-up changes measure self resident memory in mock mode and use Session.route for the benchmark; input/recovery behavior is unchanged. New Swift source, no DragScroll event handling or recovery reuse.

| Component | Responsibility / evidence |
| --- | --- |
| AppKit entry/menu | Normal startup constructs no tap; mock benchmark branches before AppDelegate. Explicit flag/action/consent for live input (Sources/MarbleScroll/Entry.swift:8-19; AppDelegate.swift:164-185) |
| MarbleCore | Pure state machine, bounded converter, eligibility/lifecycle owner and injected output contract (Sources/MarbleCore/Interaction.swift:27-95; Sources/MarbleCore/Settings.swift:17-67; Sources/MarbleCore/Session.swift:27-74) |
| NativeInput | Global mouse-only HID-entry tap, pointer motion suppression and tagged scroll output (Sources/MarbleScroll/NativeInput.swift:31-108) |
| SafetyLatch | Synchronized emergency inhibition/token ownership; native invalidation outside the lock (Sources/MarbleCore/SafetyLatch.swift:5-25; NativeInput.swift:19-23) |
| TrackballPresence | USB registry notifications, not raw HID input or physical source attribution (Sources/MarbleScroll/NativeInput.swift:112-168) |
| Configuration / login | Validated UserDefaults JSON and explicit ServiceManagement action (Sources/MarbleScroll/Configuration.swift:6-17; AppDelegate.swift:226-231) |

### Effective resources

| Workflow | Resource/capability | Configuration chain and effective value | Recipients / control |
| --- | --- | --- | --- |
| Live scrolling | Global mouse filtering | --allow-live-input -> menu action -> cancel-default scope consent -> configured secondary button -> USB presence -> existing AX trust -> inhibited gate arm; HID-entry/head-insert/default tap; mask only movement, three drags, other down/up | Native adapter/core and OS event consumers. Session repeats eligibility checks. NativeInput.swift:31-69; Sources/MarbleCore/Session.swift:27-35; AppDelegate.swift:164-185 |
| Button detection | Global read-only secondary-down observation | Explicit detect action/consent -> same launch/AX/presence gate -> listen-only HID-entry tap; ends after first down or ten seconds | Number reaches confirmation dialog; original event passes. NativeInput.swift:38,48-56,80-83; AppDelegate.swift:201-223 |
| Device discovery | Registry metadata | IOUSBHostDevice idVendor=0x046D/idProduct=0xC408; registry IDs track match/removal, no IOHID open/input report | Local status/eligibility. NativeInput.swift:112-168 |
| Settings | Current-user preferences | Packaged ID com.kaushr.MarbleScroll -> UserDefaults.standard -> settings.v1 JSON -> Codable/finite/range checks | App only; OS resolves backing file. Raw SwiftPM executable's domain/path is not explicitly pinned. Resources/Info.plist; Configuration.swift:6-17; Sources/MarbleCore/Settings.swift:17-31 |
| Emergency | Process-owned tap token | SIGUSR1 on independent Dispatch queue -> inhibit/detach -> CG tap disable/Mach-port invalidate -> queued session cleanup; TERM/INT invalidate then exit | Same-user process signal authority. Sources/MarbleCore/SafetyLatch.swift:5-25; NativeInput.swift:19-23; AppDelegate.swift:82-94 |
| Login | Main-app registration | Explicit menu action -> disable -> confirm registration -> SMAppService.mainApp | macOS Login Items. Off unless user acts; startup does not auto-enable. AppDelegate.swift:226-231 |
| Local build | App bundle | Reviewed dependency-free SwiftPM/Xcode sources -> build/MarbleScroll.app -> ad-hoc hardened-runtime signature; no custom entitlement | Local directory only; no install/launch/release. Package.swift; scripts/build.sh |

Source paths without a prefix in this model refer to Sources/MarbleScroll unless otherwise stated.

## Threat model, boundaries and assumptions

Assets: ordinary pointer/button availability and integrity; existing Accessibility authorization; trusted executable identity; bounded local settings; user control of activation, global-scope consent and login registration. No input history, credential, remote service or tenant data is maintained.

Boundaries:
- Human/OS -> live filtering authority. A launch argument alone is insufficient: menu scope consent, configuration, presence, permission and latch checks follow. No AX/CG permission-request API is used.
- Global events -> recognized gesture/output. Other mice can drive the same mode. The mask excludes keyboard, modifier-flags, wheel, tablet and primary down/up events. Reserved button downs/ups are consumed in ordinary operation; cancellation may pass an unmatched secondary up instead of retaining interception or synthesizing a click.
- Registry -> presence. VID/PID is not authenticated hardware identity or event attribution. Matching only prevents activation when no matching device is known.
- Preferences -> native behavior. Decode/type/finite/range controls are enforced. Enabled/consent/lock state is not saved. Same-user edits are owner capability, not a newly bypassed privilege boundary.
- Main loop -> independent signal queue. Session/UI/timers/notifications are main-owned by convention; only the token latch is shared. The latch atomically inhibits and detaches, rejects duplicate ownership, and invalidates outside its lock.
- Source/build -> executable. Only native frameworks/system runtime; no package downloads, embedded third-party binaries, app updater or privileged helper. Ad-hoc signing gives local integrity, not a verified publisher or notarization.

Realistic actors: local owner who can edit defaults/signal/use menus; another pointing device; a process already granted OS input-injection authority; malicious replacement hardware with a matching VID/PID; someone controlling source/download/toolchain before execution. No remote entry point, keyboard logging, external credential store or lesser-privilege input-injection route is established. A same-account executable replacement is not credited as gaining the same account again.

User-provided boundary: development/compilation/mock tests and public source push are authorized. Installation, live filtering, permission grants, login startup, macOS security changes and release binaries remain outside current authorization.

Assumptions/unknowns:
- Native HID-entry tap creation without elevation, suppression before cursor update, OS delivery and actual Sequoia TCC/crash behavior are not verified. Failure to create a tap stays disabled; no administrator or warp/seizure fallback.
- Ordinary termination should remove a process-owned tap; no cursor association/suppression/device grab is changed. OS behavior still needs physical acceptance.
- Revocation is checked per session event and menu opening, not by idle polling. If callbacks stop after TCC removal, OS delivery behavior must be verified.
- An emergency signal can interleave after the final pre-post gate check. One scroll may post and the subsequent gate check may also pass that original movement. This is bounded in-flight behavior, not evidence of persistent rearming; no zero-event-after-signal guarantee.
- Native tapPostEvent returns no delivery acknowledgment. A false injected emitter/failed allocation is handled; silent OS/app rejection cannot be detected.
- Mock tests cover the same Session.route and generic latch used by production. Native Mach-port invalidation, IOKit notifications, UI rendering, TCC and cross-app pointer/scroll behavior remain untested.

## Attack surface, mitigations and scenarios

These are architectural scenarios and acceptance risks, not claims of validated exploit vulnerabilities.

| Priority | Scenario / capability gain | Prerequisite and impact | Controls / mitigation / evidence |
| --- | --- | --- | --- |
| High operational | Lost permission, timeout or process crash disrupts ordinary input | Active user-authorized tap; potential input availability failure | Pass current input on lost eligibility; disable/invalidate, reset all state; one timeout recovery; no persistent cursor/device manipulation. Sources/MarbleCore/Session.swift:37-74; NativeInput.swift:39-108. Hardware recovery remains a release blocker |
| Medium operational | Concurrent emergency and pending timeout rearm | Enabled session + timeout and signal | Atomic inhibit latch prevents future arms until new explicit action; core concurrent mock test. Sources/MarbleCore/SafetyLatch.swift:5-25; Tests/MarbleCoreTests/SafetyLatchTests.swift:5-37. Bounded in-flight event caveat retained |
| Medium scope | Another pointer contributes global movement/button events | User explicitly accepts global fallback | No false isolation claim; launch flag, scope consent and presence requirement. AppDelegate.swift:164-185. Strict isolation requires another reviewed backend |
| Medium permission | Approved binary has broader OS authority than mouse-only need | User grants Accessibility to that executable | No automatic request, no keyboard mask or UI-tree scraping; source review/local build/ad-hoc integrity. Permission expansion needs separate consent. NativeInput.swift:31-56; docs/SECURITY.md |
| Low local reliability | Malformed preferences/extreme deltas cause unintended output | Same-user configuration or OS-authorized input | Codable/type validation, finite/range clamps, bounded output/fraction reset. Sources/MarbleCore/Settings.swift:17-67; Sources/MarbleCore/Interaction.swift:40-95. No new privileged attacker boundary |
| Low local availability | Same-user signal spoofing disables app | Ability to signal same-user process | Safe disable, no credential/service/privilege gain; explicit user re-enable. AppDelegate.swift:82-94 |
| Supply-chain conditional | Modified source/toolchain or untrusted binary uses granted AX authority | Control before execution and human approval | New repo/history, MIT source, no dependencies/updater/download scripts, build locally; distribution authenticity still an operator/toolchain trust prerequisite. Package.swift; scripts/build.sh; docs/INSTALLATION.md |

No demonstrated attacker-boundary vulnerability emerged from this architecture pass. That statement does not certify malware absence or native input safety.

## Severity calibration

- Critical: an immediately actionable, source-supported severe compromise of a separate security boundary. None established.
- High security: a realistic high-impact/high-likelihood privilege or data boundary failure. Broad AX authority alone is an intentional capability with user consent, not proof of such an exploit.
- Medium security: an established serious boundary impact with limited reachability, not merely an unverified TCC hypothesis.
- Low security: a concrete, constrained new boundary failure. Same-user defaults edits or process signals with no privilege gain are not automatically findings.
- Operational severity is separate: losing ordinary input is a high release-blocking safety concern even without an attacker. Core mock success cannot lower that risk to a verified safe hardware result.

Repository: https://github.com/kaushr/MarbleScroll
Version: 97638e97c052780fe46af5135b55abe4025c5173
