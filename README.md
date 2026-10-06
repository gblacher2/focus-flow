# FocusFlow

Native macOS SwiftUI menu-bar Pomodoro timer. Quiet, menu-bar-first utility — no dock icon. Supports focus sessions, short/long breaks, session tagging, statistics, CSV export, and global keyboard shortcuts.

**Requirements:** macOS 14+ (Sonoma) · Swift 6 · SwiftPM · Command Line Tools (no full Xcode needed)

---

## Build & Run

```bash
# Compile check only
swift build

# In-process self-test suite (FocusFlowCore regressions)
swift run SelfTests

# Build and launch as .app bundle (required — do not use `open .build/...` directly)
./script/build_and_run.sh

# Build, launch, and verify the process is running
./script/build_and_run.sh --verify

# Package an ad-hoc-signed ZIP into dist/ (first launch: right-click > Open)
./script/package_release.sh

# Other modes
./script/build_and_run.sh --debug       # launch under lldb
./script/build_and_run.sh --logs        # stream os_log output
./script/build_and_run.sh --telemetry   # subsystem log stream
./script/build_and_run.sh --build-only  # assemble bundle without launching
```

> **IMPORTANT:** `swift test` silently no-ops on this machine (Command Line Tools only — no XCTest runner). `Sources/SelfTests/main.swift` ports the `Tests/FocusFlowTests` assertions; run them with `swift run SelfTests`. CI runs `swift build`, `swift run SelfTests`, and `git diff --check`. The full post-change verification path is `swift build` + `swift run SelfTests` + `./script/build_and_run.sh --verify`.

---

## Project Structure

```
Sources/
  FocusFlow/         # executable target — App, Views, Services, Support
  FocusFlowCore/     # library target — Models, Stores, Services (pure logic, no AppKit)
  SelfTests/         # executable — ports Tests/FocusFlowTests (`swift run SelfTests`)
Tests/FocusFlowTests/  # XCTest sources; not run on CLT-only machines
script/build_and_run.sh
script/package_release.sh
```

Key files: `AppModel.swift` (central `@MainActor` state), `TimerEngine.swift` (pure state machine), `SessionStore.swift` (JSON persistence).

---

## Architecture Notes

- Single `@ObservableObject` (`AppModel`) observed by all views; no other shared state.
- `TimerEngine` is a `Codable` value type — no side effects, no AppKit dependency.
- Ticker only runs during active countdown phases; zero CPU wakeups when idle.
- Bundle ID: `com.gabrielblacher.FocusFlow`
