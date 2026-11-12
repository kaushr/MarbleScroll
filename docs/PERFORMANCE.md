# Performance measurements — mock path only

Date: November 11, 2026. Release implementation commit `97638e97c052780fe46af5135b55abe4025c5173`; Apple Silicon, macOS 15.7.8, Swift 6.1.2.

Command, run as an authorized automated mock harness:

```sh
build/MarbleScroll.app/Contents/MacOS/MarbleScroll --mock-benchmark
```

This path uses a fake backend and fake permission/device closures. It branches before NSApplication/AppDelegate, registry discovery, ServiceManagement or event-tap creation. It does not request permissions or use physical input.

| Metric | Observed |
| --- | ---: |
| Disabled mock idle interval | 5.005 seconds |
| CPU over that idle interval | 0.0004% (below 0.01%; short sample) |
| Current resident memory after idle | 2.75 MiB |
| Core routing workload | 1,000,000 mock movement events |
| Workload elapsed | 0.0693 seconds |
| Mean core processing time per event | 0.0693 microseconds |
| Current resident memory after workload | 2.88 MiB |
| Output checksum | -6,000,000, consistent with both axes being converted |

CPU is the delta of process user+system CPU from `getrusage(RUSAGE_SELF)` divided by monotonic elapsed wall time. Current resident memory comes from self `task_info(MACH_TASK_BASIC_INFO)`; `ru_maxrss` also reported 2.75 MiB after idle. No other process is inspected. An attempted external `ps` sample was denied by the development sandbox; no permission escalation was made. The in-process self measurements succeeded.

Idle harness uses one timed semaphore wait, not a polling loop. The hot path uses the same production `Session.route`, converter and state machine with a checksum emitter. It excludes AX checks, actual Core Graphics event allocation/posting, application/UI work and rendering. These results are a **core/mock baseline**, not the menu-bar application's enabled idle footprint or end-to-end scrolling latency. The five-second near-zero CPU result is too short for a production energy/soak conclusion.

The native design is event-driven: main-run-loop event tap and USB notifications; one-shot recognition, button-probe and bounded-recovery timers; an independent signal dispatch queue. No idle permission poll, momentum timer, permanent scroll worker or recurring background job is implemented.

Real disabled/enabled UI CPU/RSS, scroll latency, energy and long-running reliability remain unmeasured because native operation is awaiting approval. Use the 60-second idle and sustained-scroll procedure in [hardware testing](HARDWARE_TESTING.md). Do not substitute this benchmark for those acceptance results.
