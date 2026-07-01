# FocusFlow — Build / Run / Test

## Build / Run / Test

```bash
# Compile check only
swift build

# Run the in-process self-test suite (FocusFlowCore regressions) — see below
swift run SelfTests

# Build, assemble .app bundle, and launch
./script/build_and_run.sh

# Full post-change verification (build + launch + process check) — use this after every change
./script/build_and_run.sh --verify

# Stream os_log output while running
./script/build_and_run.sh --logs

# Package an ad-hoc-signed distributable ZIP into dist/
./script/package_release.sh
```

**Do NOT run `swift test`.** On this machine (Command Line Tools only, no full Xcode),
`swift test` silently exits 0 without running any tests. The Tests/FocusFlowTests/*.swift
suite is effectively dead — use `swift run SelfTests` instead, which ports the same
assertions into a plain executable target (`Sources/SelfTests/main.swift`) that actually
runs and returns a non-zero exit code on failure. The correct end-to-end verification path
is `swift run SelfTests` followed by `./script/build_and_run.sh --verify`.

---

## Conventions / Gotchas

- **CLT-only build environment.** No Xcode.app installed. SwiftPM only. `xcodebuild` and
  XCTest runner are unavailable. All build/run/verify must go through `swift build` or
  `./script/build_and_run.sh`.
- **Swift 6 strict concurrency.** All shared state must be `@MainActor`-isolated or
  `Sendable`. Do not suppress warnings with `@preconcurrency` or `nonisolated(unsafe)`
  without a comment explaining why it is safe.
- **No Xcode project.** No `.xcodeproj`, no asset catalogs. Icons live at `AppIcon.icns`
  in the repo root and are copied into the bundle by `build_and_run.sh`.
- **SwiftUI + AppKit.** The app target uses AppKit (menus, NSEvent, NSSound). The Core
  library target must stay AppKit-free — it is tested in isolation.
- **Do not widen the timer window.** Max ~360 px. Menu-bar dropdown stays narrow.
- **No feature scope creep.** No iCloud sync, widgets, web blocking, or calendar sync.
  No `.xcodeproj`. See `HANDOFF.md` for the full "what NOT to do" list.
- **Bundle ID:** `com.gabrielblacher.FocusFlow` · **Min macOS:** 14.0
