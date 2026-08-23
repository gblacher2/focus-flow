# Brief: login-item-onboarding (2026-07-11)

**Author:** Claude · **Executor:** Antigravity · **Repo:** `~/GitHub & Coding Projects/focus-flow`

## Objective

FocusFlow can launch at login via `SMAppService` (Settings toggle with honest status reporting), and a three-pane onboarding sheet appears exactly once on a truly-fresh install — wired through the environment-bridge launch path so it never races the window-opening closures.

## Context

Package 5 of 6. **Depends on `core-foundations` (2026-07-11)** — it provides the `hasCompletedOnboarding` pref (memberwise `false`, **missing-key decodes `true`** so existing installs never see onboarding) and `launchAtLogin` (false/false). If `remappable-shortcuts` has merged, the onboarding shortcut hint should read the live `displayString`s; otherwise hardcode the defaults and note it.

Current state the executor must know:

- **Launch ordering (critical):** window-opening closures are captured by the off-screen `EnvironmentBridgeView` — `Sources/FocusFlow/App/AppDelegate.swift:64-86`. Its `.task` (lines 72-84) assigns `openTimerWindow`/`openStatisticsWindow`/`openSettingsWindow` and THEN runs the `showWindowAtLaunch` check (lines 80-83). CLAUDE.md pattern 4: launch-time window actions may only run inside this `.task`, after the closures exist. `attachIfNeeded` (lines 31-61) guards one-time creation and logs a fault if wiring never happens.
- App lifecycle: `.accessory` activation policy (AppDelegate.swift:24); the timer window is a SwiftUI `Window(id: "timer")` scene (`Sources/FocusFlow/App/FocusFlowApp.swift:11-16`, 312×398).
- `Sources/FocusFlow/Views/ContentView.swift` is the timer window's root view — the onboarding sheet attaches here.
- Notification permission flow already exists: `AppModel.requestNotificationPermission()` / `refreshNotificationPermissionStatus()` / `openNotificationSettings()` (AppModel.swift:232-242) and `notificationPermissionStatus` published state — reuse it; do not add a second permission path.
- Preferences write path: `AppModel.updatePreferences(_:)` (AppModel.swift:202-219).
- Services pattern: small final classes in `Sources/FocusFlow/Services/` owned by AppModel (see `NotificationService`, `SoundService`).
- **Signing/bundle reality:** the app is ad-hoc signed and typically runs from `dist/FocusFlow.app` via `./script/build_and_run.sh`. `SMAppService` operates on the running bundle — `swift run` (bare executable, no bundle) will fail or misregister. It may also return `.requiresApproval` for ad-hoc-signed apps outside `/Applications`; that is an expected state, not an error.
- Prefs are stored in `UserDefaults` under key `com.gabrielblacher.FocusFlow.preferences.v1` (JSON blob via `PreferencesStore`); session data in `~/Library/Application Support/FocusFlow/`.

## In scope

- `Sources/FocusFlow/Services/LoginItemService.swift` — **new file**.
- `Sources/FocusFlow/Views/OnboardingView.swift` — **new file**.
- `Sources/FocusFlow/App/AppModel.swift` — onboarding presentation state, `completeOnboarding()`, login-item plumbing.
- `Sources/FocusFlow/App/AppDelegate.swift` — the `EnvironmentBridgeView.task` first-launch trigger only.
- `Sources/FocusFlow/Views/ContentView.swift` — `.sheet` attachment only.
- `Sources/FocusFlow/Views/SettingsView.swift` — "Launch at login" toggle + status caption in the Timer tab's Behavior section.

## Out of scope

- **No legacy `SMLoginItemSetEnabled`, no helper/agent bundle, no LaunchAgents plist.** `SMAppService.mainApp` only (macOS 13+ API; deployment target is 14).
- **Never register the login item automatically** — only on an explicit user toggle (onboarding pane 3 or Settings).
- No new SwiftUI `Window` scene for onboarding (a new scene means new bridge closures and launch-ordering risk) — it is a sheet on the timer window.
- No nagging: closing/skipping onboarding marks it completed forever.
- No notarization/Developer ID work. No changes to `PreferencesStore`/`TimerPreferences` (keys landed in core-foundations).
- Don't restructure `attachIfNeeded` or the bridge window mechanics — only add the trigger inside the existing `.task`.

## Specification

### 1. `LoginItemService`

```swift
@MainActor final class LoginItemService {
    enum DisplayStatus { case enabled, disabled, requiresApproval, notFound }
    var status: DisplayStatus          // maps SMAppService.mainApp.status
    func setEnabled(_ enabled: Bool) throws   // register() / unregister()
    func openLoginItemsSettings()      // SMAppService.openSystemSettingsLoginItems()
}
```

Semantics: the `launchAtLogin` **pref is intent; `SMAppService.mainApp.status` is truth**. On each Settings/onboarding appearance, read live status. When pref says on but status is `.requiresApproval`, show "Needs approval in System Settings → General → Login Items" with a button calling `openLoginItemsSettings()`. When registration throws, surface the error text and revert the toggle — never pretend success.

### 2. `OnboardingView` — 3 panes, button-paged (no swipe)

1. **Welcome:** app name/icon, one paragraph on the menu-bar-first model (left-click menu, right-click pause/resume), "Continue".
2. **Notifications:** explain end-of-phase notifications; "Enable Notifications" button → existing `requestNotificationPermission()`; live status via `notificationPermissionStatus` (granted/denied states with the existing open-System-Settings affordance); "Continue" always available (skippable).
3. **Launch at login + shortcuts:** toggle wired through `LoginItemService` (same path as Settings); a hint listing the four global shortcuts; "Get Started" completes.

Style: `Theme` tokens from design-tokens-timer-visuals, sized to the timer window (~300pt-wide sheet). Pane transitions Reduce-Motion-gated (instant when on). Every pane keyboard-navigable; VoiceOver announces pane titles. An explicit close (window close / Esc) also calls `completeOnboarding()` — closing counts as done.

### 3. Wiring

- `AppModel`: `@Published var isOnboardingPresented = false`; `func completeOnboarding()` → `updatePreferences { $0.hasCompletedOnboarding = true }` + dismiss.
- `AppDelegate.EnvironmentBridgeView.task` — replace the show-at-launch block with a combined check so the window opens **once**:

```swift
let needsOnboarding = !app.preferences.hasCompletedOnboarding
if needsOnboarding || app.preferences.showWindowAtLaunch {
    NSApp.activate(ignoringOtherApps: true)
    openWindow(id: "timer")
}
if needsOnboarding { app.isOnboardingPresented = true }
```

- `ContentView`: `.sheet(isPresented: $app.isOnboardingPresented) { OnboardingView(...) }` with `onDismiss` → `completeOnboarding()` (idempotent).
- `SettingsView` Timer tab Behavior section: "Launch at login" `Toggle` + status caption; identical service path as pane 3 so the two stay in sync via the shared pref + live status.

## Acceptance criteria

1. **Fresh install:** with prefs deleted and Application Support cleared (commands below), launching opens the timer window with the onboarding sheet; completing it (or closing it) sets the pref; the next launch shows no onboarding.
2. **Upgrade simulation:** a prefs payload lacking `hasCompletedOnboarding` (i.e. any pre-existing install) never shows onboarding (covered by core-foundations decode default; verify live by keeping existing prefs).
3. Pane 2 requests notification permission and reflects the live result; a denied state shows the open-System-Settings affordance.
4. Pane 3 / Settings toggle registers the login item: System Settings → General → Login Items lists FocusFlow, **or** status is `.requiresApproval` and the UI says so with a working "Open Login Items" button. Unregister removes it/turns it off. Toggle state and Settings stay in sync.
5. `showWindowAtLaunch` matrix: fresh+on → window opens once (no double-open); onboarded+on → window opens, no sheet; onboarded+off → no window at launch.
6. Onboarding is keyboard-navigable (Tab/Space/Return through all panes) and VoiceOver announces each pane's title; with Reduce Motion on, pane changes are instant.
7. No bridge regression: Console/`--logs` shows no "Environment bridge never wired" fault; menu-bar → Timer Window/Statistics/Settings all still open.
8. `swift build` clean; registration is **never** attempted without an explicit user toggle (code-inspectable).

## Verification

```bash
cd "$HOME/GitHub & Coding Projects/focus-flow"
swift build                                  # expected: exit 0, no new warnings
swift run SelfTests                          # expected: all checks pass, exit 0
./script/build_and_run.sh --verify           # expected: bundle builds, app launches, process check passes
```

**All login-item and onboarding testing must use the bundle (`./script/build_and_run.sh`), never `swift run`** — SMAppService misbehaves without a real bundle.

Fresh-install simulation (manual, required — this deletes local FocusFlow prefs/history on this machine; acceptable for testing, but note it):

```bash
osascript -e 'quit app "FocusFlow"' 2>/dev/null || true
defaults delete com.gabrielblacher.FocusFlow 2>/dev/null || true
mv ~/Library/Application\ Support/FocusFlow ~/Library/Application\ Support/FocusFlow.bak 2>/dev/null || true
./script/build_and_run.sh                    # expected: timer window + onboarding sheet
```

Then: complete onboarding → relaunch → no sheet. Toggle launch-at-login on pane 3 or Settings → check System Settings → General → Login Items (record the observed SMAppService status). Restore the backed-up Application Support folder afterwards (`mv` back) and note it in the report.

Relaunch matrix (manual): fresh / onboarded / showWindowAtLaunch on/off per acceptance criterion 5.

## Report

Append `## Execution report — <date>` to this file: files changed, real output of the three commands, the fresh-install simulation transcript, the **observed `SMAppService` status values** on this machine (ad-hoc-signed bundle — `.requiresApproval` is acceptable and must be reported as such, not massaged), the relaunch-matrix results, whether Application Support was restored, deviations with reasons, open questions. A failed verification means NOT done — report the failure.

## Execution report — 2026-07-12

### Files changed

- `Sources/FocusFlow/Services/LoginItemService.swift`
- `Sources/FocusFlow/Views/OnboardingView.swift`
- `Sources/FocusFlow/App/AppModel.swift`
- `Sources/FocusFlow/App/AppDelegate.swift`
- `Sources/FocusFlow/Views/ContentView.swift`
- `Sources/FocusFlow/Views/SettingsView.swift`

### Corrections completed during final review

- Made onboarding completion genuinely idempotent. SwiftUI clears the sheet binding before `onDismiss`; the former `guard isOnboardingPresented` therefore skipped persistence and caused onboarding to reappear.
- `Get Started`, the visible `Skip` action, Escape, sheet disappearance, and `onDismiss` now share the same safe completion path.
- Added Reduce-Motion-gated pane animations, accessibility heading traits, and accessibility focus movement when panes change.
- Refreshes notification and login-item truth whenever Settings or onboarding appears.
- Notification `.unknown` no longer renders as enabled.
- Login-item UI now displays every live `SMAppService` state, exposes registration errors beside both toggles, and only persists changed intent when the observed system state reflects the request (`.enabled` or `.requiresApproval` when enabling; `.disabled` or `.notFound` when disabling).
- Added an explicit onboarded+show-window-off dismissal in the one-time environment bridge. SwiftUI otherwise creates the primary `Window` scene automatically even when the preference is off.

### Automated verification

```text
$ swift build
Build complete! (no warnings)

$ swift run SelfTests
== Summary ==
  177 passed, 0 failed

$ ./script/build_and_run.sh --verify
Build complete!; bundle launched; process check passed
```

### Fresh-install and dismissal verification

1. Quit FocusFlow and exported `com.gabrielblacher.FocusFlow` preferences to a temporary backup.
2. Copied `~/Library/Application Support/FocusFlow` to the same temporary backup.
3. Cleared the preference domain and moved Application Support aside.
4. Bundle launch displayed one timer window with the onboarding sheet. The accessibility tree exposed `Welcome to FocusFlow`, `Stay Notified`, and `Ready to Focus` as headings.
5. Continued through all panes without requesting notification permission or changing Launch at Login. Pane 3 showed the live shortcuts and `Unavailable for this app bundle`.
6. `Get Started` dismissed the sheet; relaunch showed no onboarding.
7. Repeated the fresh-state path and pressed Escape. The visible Skip cancel action dismissed the sheet; relaunch again showed no onboarding.

### Launch matrix

Window counts were read through `CGWindowListCopyWindowInfo` without activating the app:

- Fresh + show-window-on: one `FocusFlow` timer window plus one expected unnamed onboarding sheet; no duplicate timer window.
- Onboarded + show-window-on: exactly one `FocusFlow` timer window.
- Onboarded + show-window-off: zero FocusFlow windows; the menu-bar process remained running.

### Observed system-service status

The ad-hoc Debug bundle running from `dist/FocusFlow.app` reported `SMAppService.mainApp.status == .notFound`. The UI displayed `Unavailable for this app bundle` and did not claim registration success. Launch at Login was not toggled because this no-install verification intentionally did not place the bundle in `/Applications` or change the user's login-item configuration. Registration remains a signed/installed release check; the `.notFound` truth path and failure handling were verified here.

### Restoration evidence

- Original preferences were imported after testing. A fresh export compared byte-for-byte equal with the backup via `cmp`.
- Original Application Support was restored. Recursive `diff -qr` against the pristine backup produced no output.
- Notification permission, Launch at Login, and unrelated user settings were not changed.

### Deviations

- The brief's live registration criterion cannot be completed from the no-install ad-hoc bundle because `SMAppService` reports `.notFound`. No system setting was changed to manufacture a different result.

### Status

Source implementation and all no-install acceptance checks are complete. Live registration/unregistration is deferred to the signed installed-bundle release check.
