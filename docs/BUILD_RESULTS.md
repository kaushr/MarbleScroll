# Build results

Date: November 11, 2026. Implementation commit: `97638e97c052780fe46af5135b55abe4025c5173`.

Host: macOS Sequoia 15.7.8 (24G824), Apple Silicon. Compiler: Apple Swift 6.1.2. Active developer directory: `/Library/Developer/CommandLineTools`; installed macOS SDK: 15.5.

| Check | Result |
| --- | --- |
| `./scripts/test.sh` | PASS: 74 mock tests, zero failures |
| `./scripts/build.sh` | PASS: Release arm64 executable and local `.app` bundle |
| Bundle signature | PASS: `codesign --verify --strict --verbose=2`; ad-hoc signature with hardened-runtime flags, identifier `com.kaushr.MarbleScroll`, no Team ID or custom entitlement keys |
| Architecture/deployment | `file`: Mach-O 64-bit arm64; `vtool`: minimum macOS 15.0, SDK 15.5 |
| Library inspection | `otool -L`: only Apple system frameworks/runtime libraries; no bundled third-party code |
| Project and plist syntax | PASS: `plutil -lint`; all nine Swift implementation files are referenced in Xcode |
| Same-module source build | PASS using `xcrun swiftc -O -whole-module-optimization -swift-version 5 -target arm64-apple-macos15.0 ... Sources/MarbleCore/*.swift Sources/MarbleScroll/*.swift`; validates the Xcode source layout without `SWIFT_PACKAGE` imports |
| Full Xcode build engine | NOT AVAILABLE: `xcodebuild` refused because the selected directory is Command Line Tools; exact error below |
| Native app UI/live input | NOT RUN; neither compilation nor mock mode is physical acceptance |

Exact Xcode diagnostic:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

Full Xcode project build validation remains outstanding. No Xcode installation/download or selected-directory change was performed. The same-module compiler check is useful evidence but is not an `xcodebuild` success claim.

Local bundle: `build/MarbleScroll.app`. Executable: `build/MarbleScroll.app/Contents/MacOS/MarbleScroll` (301,856 bytes); bundle disk usage reported by `du -sh`: 308 KiB.

SHA-256 of that executable:

```text
7257955ed3cd54ff11424acdd39c489d05967c4d2f1f18f7cc56c4d765fc5fda
```

Rebuilds/toolchain changes may alter bytes/signing identity. Logs (`build/tests.log`, `build/build.log`, `build/xcodebuild.log`, `build/same-module-build.log`, `build/signature.log`, `build/mock-benchmark.log`) remain local and are ignored by Git. `build/` and `.build/` contain no source of record.

The locally built executable was run only with `--mock-benchmark`, which branches before native UI/IOKit/tap initialization. No app was installed or run with live interception, no TCC grant was made, and no login item or macOS security setting was changed. Binary artifacts are not committed or published as a release.


## Latest UX build

The historical artifact above is superseded locally by source c71bea660d10d3a03c2b406d7133bf8fdbecf07a. Release arm64 compilation and strict ad-hoc signature verification pass. The executable SHA-256 is aa3b4fab543166db16cca940e7e877ab203a91156e991598aa1c84b994af976f. The Xcode project includes all eleven Swift implementation files. The current core suite has 84 passing tests. See HARDWARE_RESULTS.md for native UI observations and the pending final permission refresh. No binary release was published.
