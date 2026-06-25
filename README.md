# FocusFlow

Native macOS SwiftUI menu-bar Pomodoro timer. Quiet, menu-bar-first utility — no dock icon. Supports focus sessions, short/long breaks, session tagging, statistics, CSV export, and global keyboard shortcuts.

**Requirements:** macOS 14+ (Sonoma) · Swift 6 · SwiftPM · Command Line Tools (no full Xcode needed)

---

## Build & Run

```bash
# Build and launch as .app bundle (required — do not use `open .build/...` directly)
./script/build_and_run.sh

# Build, launch, and verify the process is running (CI / post-change check)
./script/build_and_run.sh --verify

# Other modes
./script/build_and_run.sh --debug      # launch under lldb
./script/build_and_run.sh --logs       # stream os_log output
```

> **IMPORTANT:** `swift test` silently no-ops on this machine (Command Line Tools only — no XCTest runner). The authoritative post-change verification path is `./script/build_and_run.sh --verify`.

`swift build` alone is fine for a compile check.

---

## Project Structure

```
Sources/
  FocusFlow/         # executable target — App, Views, Services, Support
  FocusFlowCore/     # library target — Models, Stores, Services (pure logic, no AppKit)
Tests/FocusFlowTests/
script/build_and_run.sh
```

Key files: `AppModel.swift` (central `@MainActor` state), `TimerEngine.swift` (pure state machine), `SessionStore.swift` (JSON persistence).

---

## Architecture Notes

- Single `@ObservableObject` (`AppModel`) observed by all views; no other shared state.
- `TimerEngine` is a `Codable` value type — no side effects, no AppKit dependency.
- Ticker only runs during active countdown phases; zero CPU wakeups when idle.
- Bundle ID: `com.gabrielblacher.FocusFlow`
