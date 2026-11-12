# Automated test results

Date: November 11, 2026. Host: Apple Silicon, macOS 15.7.8 (24G824), Swift 6.1.2. Framework: Apple's bundled Swift Testing, no third-party dependency.

Command: `./scripts/test.sh`.

**Result: 74 tests passed, zero failures.** Final run reported 0.016 seconds of test execution (compilation is separate). The parameterized stop-reason test exercises eight reason variants. All tests use mock events, fake eligibility and a fake backend/token; none creates a native event tap, opens HID input, requests TCC permissions or launches the menu UI. Build/test commands did not install the app, register login startup or change security settings.

| Required case | Automated evidence |
| --- | --- |
| Normal movement, button press | `normalPointerMovementPasses`, `configuredPressReservesButton` |
| Hold/move and release | `holdDeadlineActivatesTemporary`, `moveStartsScrollingWithoutHoldDelay`, `releasingTemporaryRestoresPointerImmediately` |
| Double-click, locked motion, single-click unlock | `doubleClickLocksOnSecondDown`, `secondReleaseRetainsLock`, `singleDownUnlocksImmediately` |
| Rapid repeated presses | Duplicate-down tests, `repeatedRapidClicksRemainDeterministic` (300 clicks) |
| Double-click timing boundary | Inclusive boundary, immediately after boundary, custom interval and down-to-down tests |
| Temporary vs lock recognition | `temporaryNeverBecomesFirstClickOfLock`, exact-hold boundary, buffered jitter and interclick movement tests |
| Unrelated buttons | `unrelatedButtonsAlwaysPass`, unmatched-release pass-through |
| Disconnect/reconnect | Missing device, temporary/locked disconnect, event-time fallback and no auto-enable on reconnect |
| Permission loss/restoration | Missing permission, notification/event-time revoke, no auto-enable on restoration |
| Tap failure | Partial initialization cleanup, user-disabled tap, one timeout recovery, failed recovery, eligibility loss during recovery |
| Emergency/failure concurrency | Initial inhibition, exactly-once invalidation, duplicate ownership rejection, inhibition blocks rearm, 1,000 concurrent mock arm/stop operations |
| App termination/restart, sleep/session loss | Eight stop-reason variants reset and pass input; restart creates a disabled/NORMAL session |
| Scroll reversal/horizontal/sensitivity | Dedicated sign, axis independence, disabled axis, acceleration and bounded extreme-delta tests |
| Synthetic recursion prevention | Marked synthetic events cannot change state/time or reach mock output; real native mask/tag exclusion reviewed statically |
| Output construction failure | False injected emitter passes original input, resets interaction, stops backend; successful and zero-output routes also tested |
| Configuration and robustness | Codable round-trip excludes enabled/lock/consent; malformed JSON; finite/range defaults; nonfinite movement and backwards time fail open |
| Long mixed input sequence | 20,000 deterministic mixed events preserve pressed/waiting state invariants |

Test sources: [interaction](../Tests/MarbleCoreTests/InteractionTests.swift), [recovery](../Tests/MarbleCoreTests/RecoveryTests.swift), [latch](../Tests/MarbleCoreTests/SafetyLatchTests.swift), [scroll/settings](../Tests/MarbleCoreTests/ScrollTests.swift). Final raw output remains locally in `build/tests.log` (ignored by Git).

## Scope limits

Tests assert the production pure state machine, `Session.route`, lifecycle owner and generic safety latch. They prove the mock backend receives cleanup calls and a false emitter result releases the event. They do not prove real CFMachPort invalidation, event posting/delivery, permission enforcement, sleep notifications, primary-button interactions inside actual apps, or OS removal of a tap after SIGKILL. No scroll delivery acknowledgment is available from the native post API.

The first UI compile found an ambiguous Swift String conversion, which was corrected. An early unrelated-button test supplied backwards timestamps and correctly triggered the state machine's fail-open reset; the fixture was corrected to monotonic timestamps. The final result above includes these corrections and the later routing/latch tests.

Native UI, T-BC21 button mapping, pointer stability, other-mouse interaction, permission revocation, crash recovery and cross-application behavior remain **not tested**. Use the separate approved [manual procedure](HARDWARE_TESTING.md). Performance is reported separately and labeled as mock-only.
