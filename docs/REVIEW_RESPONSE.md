# Static review response

The supplied review examined `3a42c42`. Changes below were compared with the newer `918230d` baseline and implemented in `1987100`, with build/CI work in `26c4e97`. [STATUS.md](STATUS.md) is the sole current results log.

| Review point | Disposition |
| --- | --- |
| Dropping movement may not freeze pointer | Valid **unverified, release-blocking hypothesis**. Removed the claim that HID-entry dropping precedes cursor updates. Pointer/target stability is now the first physical gate. No warp/disassociation added. Apple's cursor-control docs do not settle this callback ordering |
| AX and login queries on hot path | Permission snapshot revalidates at most every 250 ms of active input, forced for explicit enable/menu/recovery. Refresh uses cached AX/login values; ServiceManagement status only in menu-open/login actions. No idle timer. Bounded cache delays revocation observation by up to 250 ms; OS enforcement may act earlier |
| 180 ms hold | New default/fallback 300 ms. Saved thresholds preserved. Movement crossing threshold still scrolls immediately. Added a 200 ms first-click regression test |
| Opening menu kills detection | Already fixed before this review by the tracking-state guard. Extracted the exact menu policy and added a regression test |
| Generic StartError message | All cases implement LocalizedError with actionable descriptions; every case tested |
| Login cannot enable without CLI flag | Removed the authoring-only positive flag requirement. Every normal/login launch remains disabled until explicit UI enable. Added --no-live-input for inert diagnostics. Login registration remains off and physically untested |
| Native callback has no tests | Extracted production MouseTapRouter and PermissionSnapshot. New mocks exercise disabled taps, revocation, one-shot pass-through detection, synthetic bypass, output failure and emergency races. Generation tickets protect stale recovery/detection work. Actual CFMachPort/source allocation, OS invalidation, TCC, delivery and GUI remain integration gaps |
| Signing churn | Build accepts explicitly selected existing identity; provisions/trusts nothing. No valid identity available here. Ad-hoc remains default; no claim that self-signing automatically fixes TCC |
| Xcode project not built | Added actual Xcode Release build/signature validation to macOS CI. Keep the project because it is an original deliverable; see run evidence in STATUS.md |
| --disable-sandbox default | Removed from defaults; restricted-host opt-in only. Normal manifest-sandboxed mock tests/build pass when run outside the nested command sandbox |
| Swift 5 mode | Package/Xcode use Swift 6. AppDelegate main actor, explicit main-loop bridges and callback queue assertions; the locked emergency latch is the documented manual Sendable boundary |
| Shared settings menu / About | Scroll Speed focuses speed in the shared panel. About no longer disables scrolling; configuration editing still does |
| Contradictory dated logs | Consolidated build/test/performance/hardware evidence into STATUS.md, with dated provenance. Removed four superseded log pages; their historical versions remain in Git |
| Missing CI | Added read-only macOS validation with no third-party actions, downloaded executables, signing secrets, app launch or release publication |

The review correctly distinguishes pure state-machine evidence from native correctness. Passing mocks and builds cannot close the pointer, OS teardown or application compatibility gates. No DragScroll event-handling/recovery source was reused.
