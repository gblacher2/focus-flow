# Brief: login-item-notfound-ux (2026-07-12)

**Author:** Antigravity (drafted from screenshot) · **Executor:** Antigravity · **Repo:** ~/GitHub & Coding Projects/focus-flow

## Objective

Replace the two scary red error messages shown in Settings when `SMAppService` reports `.notFound` with a clear, non-alarming inline explanation that disables the toggle and tells the user what to do.

## Context

`SMAppService.mainApp` returns `.notFound` (and `register()` throws "Operation not permitted")
when the app bundle is not in a location macOS's login-item subsystem recognises (e.g. running
from `dist/FocusFlow.app` inside the repo, not from `/Applications`). This is expected in dev,
but also happens when the user runs the distributable from a folder other than `/Applications`.

Current behaviour (bad):
- Status text "Unavailable for this app bundle" shown in **orange** (attention colour)
- After the user flips the toggle, a red error "The operation couldn't be completed. Operation not
  permitted" appears below it
- The toggle stays visually on even though registration failed

Desired behaviour:
- When `loginItemStatus == .notFound`, the toggle is **disabled** (`.disabled(true)`)
- Status text reads: "Move FocusFlow to /Applications to enable launch at login."
  shown in `.secondary` colour (not orange — this is not a user error)
- No red error text is shown for this specific case (the red path is reserved for
  unexpected errors)
- `loginItemStatusNeedsAttention` returns `false` for `.notFound` (it is informational, not
  actionable via Settings)
- Attempting to call `setLaunchAtLogin` while status is `.notFound` is a no-op (guard at top)

## In scope

- `Sources/FocusFlow/App/AppModel.swift` — `loginItemStatusDescription`, `loginItemStatusNeedsAttention`, `setLaunchAtLogin`
- `Sources/FocusFlow/Views/SettingsView.swift` — the Behavior section toggle + status row
- `Sources/FocusFlow/Views/OnboardingView.swift` — same login-item block (keep in sync)
- `Sources/FocusFlow/Services/LoginItemService.swift` — no changes needed, but review

## Out of scope

- Do not add any new `SMAppService` error handling paths beyond what is described above
- Do not change the bundle location logic, the build script, or packaging
- Do not attempt to fix the underlying `SMAppService.notFound` root cause (moving the app is
  the correct fix for end users)
- No new features, settings, or UI components

## Acceptance criteria

1. When the app is running from a location where `SMAppService.mainApp.status == .notFound`,
   the "Launch FocusFlow at login" toggle is disabled (grayed out, non-interactive).
2. The status text below the toggle reads "Move FocusFlow to /Applications to enable launch at
   login." in secondary (non-orange) colour.
3. No red error text appears for the `.notFound` case — not on first load, not after toggling.
4. `loginItemStatusNeedsAttention` returns `false` when status is `.notFound`.
5. `setLaunchAtLogin` is a safe no-op (returns immediately without throwing or setting
   `loginItemErrorMessage`) when status is `.notFound`.
6. When status is anything other than `.notFound`, all existing behaviour is preserved.
7. `swift build` passes with no new warnings or errors.
8. `swift run SelfTests` passes.
9. `./script/build_and_run.sh --verify` passes (app launches successfully).

## Verification

```bash
# 1. Build
swift build

# 2. Self-test suite
swift run SelfTests

# 3. Bundle + launch check
./script/build_and_run.sh --verify
```

Visual check (manual): open Settings → Timer tab → Behavior section. With the app running from
`dist/`, confirm the toggle is greyed out, status text is secondary-coloured, and no red text
appears. Flip the toggle (it should be non-interactive). No red text should ever appear.

## Report

## Execution report — 2026-07-12

### Files changed

- `Sources/FocusFlow/App/AppModel.swift`
  - `setLaunchAtLogin`: added early `guard loginItemStatus != .notFound else { return }` (no-op for unavailable bundles)
  - `loginItemStatusDescription` `.notFound` case: changed from `"Unavailable for this app bundle"` to `"Move FocusFlow to /Applications to enable launch at login."`
  - `loginItemStatusNeedsAttention`: removed `|| loginItemStatus == .notFound` — status is informational, not attention-worthy
- `Sources/FocusFlow/Views/SettingsView.swift`
  - Launch-at-login toggle: added `.disabled(app.loginItemStatus == .notFound)`
- `Sources/FocusFlow/Views/OnboardingView.swift`
  - Launch-at-login toggle: added `.disabled(app.loginItemStatus == .notFound)`

### Verification output

```
# swift build
[3/8] Compiling FocusFlow AppModel.swift
[4/8] Compiling FocusFlow OnboardingView.swift
[5/8] Compiling FocusFlow SettingsView.swift
[6/8] Emitting module FocusFlow
[7/9] Linking FocusFlow
[8/9] Applying FocusFlow
Build complete! (1.20s)

# swift run SelfTests
== Summary ==
  177 passed, 0 failed

# ./script/build_and_run.sh --verify
Build complete! (0.11s)
(exit 0 — pgrep confirmed process running)
```

### Deviations from brief

None. All acceptance criteria met as specified.

### Open questions

None.
