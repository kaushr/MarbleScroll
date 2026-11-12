# MarbleScroll threat model

Current source review: `1987100`; build/CI configuration: `26c4e97`. Historical model and dated logs remain in Git history. Actual results and remaining acceptance gates are maintained only in [STATUS.md](STATUS.md).

## Assets and boundaries

Ordinary pointer/button availability is the primary asset. The user's Accessibility grant is broader than the mouse-only feature and belongs to the exact locally signed executable. Settings contain button/speed/timing preferences, not captured input. MarbleScroll has no network client, telemetry, keyboard interception, arbitrary file reader, clipboard access, privileged helper, updater or third-party package.

The OS event stream and application event consumers are outside MarbleScroll's control. Core Graphics does not provide reliable USB attribution for ordinary mouse events. Registry presence of 046D:C408 permits the disclosed **global fallback**, not device isolation. A second pointer or same-user synthetic mouse input can affect the active mode. VID/PID is not authenticated hardware identity.

| Surface | Capability and guard | Residual risk |
| --- | --- | --- |
| Startup and enable | Starts disabled. Explicit Scrolling Enabled action, configured secondary button, USB presence, existing AX trust, inhibit latch; diagnostic --no-live-input refuses starts | Same-user input is not a new authenticated intent boundary. No enable/lock state survives restart |
| Modifying tap | Movement/three drags/secondary down/up only; synthetic marker and wheel excluded from mask | Global scope; cursor-freeze hypothesis unverified. No keyboard, primary down/up or wheel interception |
| Detection | Unchecked readiness option, separate Start Tracking, listen-only secondary down; first result or ten-second expiry stops it | Clicks pass through and may invoke existing OS/app bindings |
| Permission | Cached AX status, active-input recheck within 250 ms; explicit enable/menu/recovery force queries | OS may revoke before cache expiry. If callbacks cease, the OS must already have stopped filtering; hardware acceptance required |
| Failures and timers | Physical input passes on policy/output failure; port invalidated before fault notification; one timeout recovery; generations reject stale delayed work | Native port creation/invalidation, scheduling, post delivery and OS crash teardown remain integration boundaries |
| Emergency | Independent signal queue inhibits and invalidates; SIGUSR1 disables, TERM/INT exits | One in-flight event may race the last armed check. SIGKILL/crash relies on OS resource teardown |
| Persistent state | Validated current-user UserDefaults; optional ServiceManagement registration only on explicit action | Same-user preference edits and signals can disable/alter operation; no privilege gain is claimed |
| Build/signing | Reviewed local source, no dependencies/Run Script phases; sandboxed SwiftPM by default; explicit existing-identity override | Toolchain/source compromise before AX approval remains a trust prerequisite. Ad-hoc signatures do not authenticate a publisher and cause grant churn |
| CI | Disposable macOS runner; read-only repository permission; exact source revision fetched; mocks and two build paths only | GitHub/Apple toolchain trust. No release artifacts, app launch, TCC grant or signing secret used |

## Operational risk priorities

**High, release blocking:** pointer drift or normal input disruption during scrolling, revocation, disconnect, sleep or termination. No actual exploit is claimed. Test pointer stability first, then active recovery. Do not add persistent cursor/disassociation state or device seizure to bypass a failing test.

**Medium:** another pointer drives global scrolling; disclosure and explicit enable limit surprise, not scope. Main-thread stalls can still time out a tap despite cached/coalesced work; bounded recovery does not establish latency or reliability. Test under UI load.

**Medium:** broader AX authority in a compromised binary. Build reviewed source locally, grant only the exact bundle, avoid unrelated permissions; no automatic updater/downloaded execution.

**Low:** malformed local settings and extreme deltas; validated finite/bounded conversion and deterministic reset protect availability. Mock tests exercise these contracts, not OS behavior.

No malware-free certification, complete native-safety proof or independent penetration test is claimed. See [security design](SECURITY.md), [architecture](ARCHITECTURE.md), [reference audit](REFERENCE_AUDIT.md) and [hardware procedure](HARDWARE_TESTING.md).
