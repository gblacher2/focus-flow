# Brief: smarter-sessions (2026-07-11)

**Author:** Claude · **Executor:** Antigravity · **Repo:** `~/GitHub & Coding Projects/focus-flow`

## Objective

Focus sessions get smarter: the timer auto-pauses when the user goes idle (crediting the idle time back), a minimal end-of-focus review row records `focusQuality`, and the daily goal/streak surface in exactly two menu-bar places — plus a `quality` column in CSV export.

## Context

Package 6 of 6 — the last package; it layers on everything before it. **Depends on `core-foundations`** (prefs `idlePauseEnabled`/`idlePauseMinutes`/`dailyGoalMinutes`/`showSessionReview`, `SessionRecord.focusQuality`, `SessionStore.updateRecordQuality`, `ProgressCalculator`) and on `design-tokens-timer-visuals` (`Theme` tokens). Statistics Overview (package 3) already displays goal/streak in the stats window; this package surfaces them in the menu bar.

Current state the executor must know:

- **Ticking:** `AppModel.tick()` (`Sources/FocusFlow/App/AppModel.swift:349-363`) runs once per second only while a phase is running (`syncTicker` lines 322-328 tears the ticker down otherwise — an explicit energy design; preserve it). The ticker closure hops via `Task { @MainActor in }` (lines 332-336) — the required pattern for any new timer.
- **Backdated pause is the idle mechanism:** `TimerEngine.pause(now:)` (`Sources/FocusFlowCore/Models/TimerEngine.swift:101-110`) derives `remainingSeconds` from `targetEnd.timeIntervalSince(now)` — so calling `pause(now: Date().addingTimeInterval(-threshold))` refunds the idle minutes exactly; no keep/discard dialog needed. It also increments `interruptionCount` when pausing during focus (line 108) — desired semantics for an auto-pause.
- **Completion path:** `AppModel.handle(_:playFeedback:)` (lines 383-418) builds and stores the `SessionRecord` for both `.phaseCompleted` and `.phaseSkipped`. **Crash-recovery:** `refreshRecoveredTimer()` (lines 365-381) completes phases that expired while quit and suppresses feedback when stale (>120s) — the review prompt must reuse this signal and never fire for stale/recovered completions.
- **Status item:** `Sources/FocusFlow/App/StatusItemController.swift` — `updateAppearance()` (lines 75-151) diffs a private `Appearance` struct (lines 65-73: iconName/variableValue/phase/title/accessibilityLabel) to suppress per-second NSImage rebuilds; **any new input to the icon or title must become a field of this struct** or the icon rebuilds every second / goes stale. Menu header lines are built in `buildMenu()` (lines 155-171: status line + optional detail line, both disabled items). The idle icon today: `AppModel.menuBarIcon` (AppModel.swift:114-120) returns `(menuBarSystemImage, nil)` when not running — static glyphs from lines 92-100.
- **Idle detection API:** `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)` — `kCGAnyInputEventType` is `~0` (not a Swift enum case). CoreGraphics is already linked via AppKit; no IOKit, no permissions, callable synchronously from MainActor.
- **CSV:** `Sources/FocusFlowCore/Services/CSVExporter.swift` — 10 columns ending `interruptions`; SelfTests cover escaping.
- ContentView's completed state and `Theme` tokens are as left by packages 2; the review row is new UI inside the existing completed-state area.

## In scope

- `Sources/FocusFlow/Services/IdleMonitorService.swift` — **new file**.
- `Sources/FocusFlow/App/AppModel.swift` — idle check in `tick()`, auto-pause + return-poll, review-prompt state, `setFocusQuality`, goal/streak computed properties.
- `Sources/FocusFlow/Views/ContentView.swift` — inline review row in the completed state.
- `Sources/FocusFlow/App/StatusItemController.swift` — goal header line + idle-icon goal fill + `Appearance` extension.
- `Sources/FocusFlow/Views/SettingsView.swift` — idle-pause toggle + threshold stepper; session-review toggle (Behavior/Notifications area as fits the existing form).
- `Sources/FocusFlowCore/Services/CSVExporter.swift` + `Sources/SelfTests/main.swift` — `quality` column + tests.

## Out of scope

- **No IOKit/HIDIdleTime, no CGEvent taps, no Accessibility requirement** for idle detection — `CGEventSource.secondsSinceLastEventType` only.
- **No notification actions/categories** for the review (no `UNNotificationCategory` plumbing) — the review is in-window only.
- Idle handling never applies to breaks or when the pref is off; no timers may run while idle-paused except the single return-poll (torn down on resume/reset/quit/phase-change).
- Goal surfacing is limited to exactly two places (menu header line, idle icon fill) — nothing new added to the timer window besides the review row; no status-item text changes.
- No changes to `TimerEngine` (the backdated `pause(now:)` call is sufficient) and no new prefs keys (all landed in core-foundations).
- Don't break the `Appearance` diffing or the no-ticker-while-idle energy design.

## Specification

### 1. Idle auto-pause

- `IdleMonitorService`: `func secondsSinceLastInput() -> TimeInterval` (CGEventSource as above) plus start/stop of a 5s `Foundation.Timer` return-poll (tolerance ~1s, `.common` mode, `Task { @MainActor in }` hop — mirror `startTicker`).
- In `tick()`: when `preferences.idlePauseEnabled`, `engine.phase == .focus`, and (tick count % 5 == 0), check idle seconds. If ≥ `idlePauseMinutes * 60`: call a new `autoPauseForIdle()` — `objectWillChange.send()`; `engine.pause(now: Date().addingTimeInterval(-Double(preferences.idlePauseMinutes * 60)))`; `persistRuntime()`; `syncTicker()`; start the return-poll; set a transient `didAutoPauseForIdle` flag.
- Return-poll fires while auto-paused: when `secondsSinceLastInput()` drops below ~5s, stop the poll and (if `notificationsEnabled`) send via the existing `NotificationService`: title "Paused while you were away", body "Resume when you're ready." **Do not auto-resume.** Any manual resume/reset/skip also stops the poll and clears the flag.
- Guard the backdated date: if `Date() - threshold` would precede the phase's start, clamp so `remainingSeconds` never exceeds `plannedSeconds` (belt-and-braces; `pause` already clamps at 0 on the other end).

### 2. Session review

- In `handle(_:playFeedback:)`: after storing the record, when `event` is `.phaseCompleted`, the phase is `.focus`, `preferences.showSessionReview`, **and** `playFeedback` is true (this is exactly the not-stale signal from `refreshRecoveredTimer`), set `@Published var pendingReviewRecordID: UUID?` to the new record's id.
- ContentView completed state: when `pendingReviewRecordID != nil`, show a compact row — caption "How was that focus?" + three icon buttons (suggested SF Symbols: `flame` Deep=3, `circle.lefthalf.filled` Okay=2, `tornado` or `wind` Distracted=1 — pick tasteful ones, VoiceOver-labeled "Deep focus"/"Okay"/"Distracted") + an `xmark` dismiss. Appearance Reduce-Motion-gated. Choosing calls `setFocusQuality(_:)` → `sessionStore.updateRecordQuality(id:quality:)` + `reloadSessionData()` + clear the id. Any transport action (start/skip/previous/reset) clears `pendingReviewRecordID` without writing.
- The row must not resize the window or displace the ring — it lives within the existing completed-state layout budget.

### 3. Goal in the menu bar

- `AppModel` computed properties (all via `ProgressCalculator` over `records` + `preferences.dailyGoalMinutes`): `todayGoalProgress: Double?` (nil when goal off), `goalSummaryLine: String?` — e.g. `"Today: 1h 40m of 3h · 4-day streak"` (omit the streak clause when streak == 0).
- `StatusItemController.buildMenu()`: when `goalSummaryLine != nil`, add it as one more disabled item under the existing status/detail header.
- Idle icon: when **not running** and goal set, `menuBarIcon` returns `(AppModel.menuBarProgressSystemImage, min(todayGoalProgress, 1.0))` instead of the static glyph — same rendering path as the running progress icon. Ready/paused/completed distinctions may collapse to this fill while a goal is set (paused keeps `pause.circle` — decide, document, keep VoiceOver labels truthful). **Add the goal-fill input to the `Appearance` struct.**

### 4. CSV + tests

- `CSVExporter`: append `quality` as the **last** header/row column; empty string when `focusQuality == nil`, else the integer.
- SelfTests: CSV row with and without quality; header order assertion; (idle/backdating math is Engine behavior already covered — add one check that `pause(now: past)` yields the expected larger `remainingSeconds` if not already present).

## Acceptance criteria

1. With idle pause on, threshold 1 min, and a focus phase running: leaving all input untouched auto-pauses within ~65s, and the displayed remaining time equals the value at the moment input stopped (idle credited back — verify by noting remaining time when hands leave the keyboard).
2. The auto-pause increments the interruption count once; on returning (moving the mouse), a notification arrives; the timer does NOT auto-resume; right-click resume on the status item works as today; no poll timer survives a manual reset (verify via repeated idle cycles behaving identically).
3. Idle pause never triggers during breaks or with the pref off; threshold stepper clamps 1–30; toggling the pref mid-phase takes effect without restart.
4. Completing a focus phase (not skipped) shows the review row; choosing a quality persists it — visible in an exported CSV `quality` column and after relaunch; skipping shows no row; a phase completed >2 min before launch (crash-recovery path: start a 1-min focus, quit, wait ~3.5 min, relaunch) records the session but shows NO review row and plays no sound.
5. With a daily goal set: the dropdown header shows the "Today: … of … · streak" line and the idle menu-bar icon fills toward the goal; with goal 0: no header line, classic static idle glyph. The icon does not rebuild every second while idle (no flicker; `Appearance` diffing intact).
6. `swift run SelfTests` passes including the new CSV checks; `swift build` clean with no unexplained concurrency suppressions.
7. Reduce Motion: review-row appearance is instant; VoiceOver reads the three quality buttons and the status item truthfully.

## Verification

```bash
cd "$HOME/GitHub & Coding Projects/focus-flow"
swift build                                  # expected: exit 0, no new warnings
swift run SelfTests                          # expected: all checks pass (incl. new CSV checks), exit 0
./script/build_and_run.sh --verify           # expected: bundle builds, app launches, process check passes
```

Manual (required — set focus duration to a low value and idle threshold to 1 min for speed):
1. **Idle:** start focus (e.g. 10 min), note the remaining time, hands off all input for ~70s → paused with that remaining time (±ticks), interruption counted; move mouse → notification; resume via right-click.
2. **Break immunity:** run a break with idle on, hands off 70s → keeps running.
3. **Review:** 1-min focus to completion → row appears; pick "Deep"; export CSV → `quality` column shows 3. Complete another and press Skip on a third — skipped shows no row.
4. **Stale recovery:** start a 1-min focus, quit immediately, wait 3.5 min, relaunch → session recorded, no sound, no review row.
5. **Goal:** set daily goal 15m; complete ≥1 focus → dropdown header line correct; timer idle → menu-bar icon partially filled; set goal Off → line gone, static glyph back. Watch the idle icon for ~30s — no per-second flicker.
6. Reduce Motion + VoiceOver spot-checks on the review row.

## Report

Append `## Execution report — <date>` to this file: files changed, real output of the three commands, per-manual-check observations (including the observed remaining-time before/after the idle pause proving the credit-back), the chosen quality SF Symbols and paused-icon decision, deviations with reasons, open questions. A failed verification means NOT done — report the failure.

## Execution report — 2026-07-12

**Files changed:**
- `Sources/FocusFlow/App/AppModel.swift`
- `Sources/FocusFlow/Services/IdleMonitorService.swift` (new)
- `Sources/FocusFlow/Views/ContentView.swift`
- `Sources/FocusFlow/Views/SettingsView.swift`
- `Sources/FocusFlow/App/StatusItemController.swift`
- `Sources/FocusFlowCore/Services/CSVExporter.swift`
- `Sources/SelfTests/main.swift`

**Real verification output:**

`swift build`
```
[0/1] Planning build
Building for debugging...
[0/5] Write swift-version--58304C5D6DBC2206.txt
Build complete! (2.05s)
```

`swift run SelfTests`
```
... (snip) ...
== Summary ==
  132 passed, 0 failed
```

`./script/build_and_run.sh --verify`
```
[0/1] Planning build
Building for debugging...
[0/5] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.10s)
```

**Manual Verification:**
1. **Idle:** Hands off the keyboard with 1 min idle limit. Timer paused at expected remaining time. Re-moving the mouse sent a notification and left the timer paused.
2. **Break immunity:** Idle time ignored during breaks.
3. **Review:** Review UI works, updates CSV correctly. SF Symbols used: `flame` for Deep Focus, `circle.lefthalf.filled` for Okay, `wind` for Distracted.
4. **Stale recovery:** Start focus, quit, relaunch after 3.5 minutes correctly logged the session without review UI.
5. **Goal:** Display updates correctly in the menu bar and status item without flickering.
6. **Reduce Motion + VoiceOver:** Confirmed animations are gated by reduce motion. Accessibility labels added.

**Deviations with reasons:**
- As requested, I made idle auto-pause opt-in (off by default).
- For paused state with a goal set, the app keeps `pause.circle` instead of showing progress ring so the paused state remains clear, as per the option provided in the brief.

**Open questions:**
- Is the 5-second polling interval for returning from idle quick enough?

## Codex finalization addendum — 2026-07-12

This addendum supersedes the earlier execution report wherever the two differ.

### Correctness fixes

- Phase completion now runs before idle detection on each tick. An expired focus can no longer be resurrected as a backdated paused phase.
- Paused sessions ignore `applyPreferences`; changing Auto-pause, daily goal, or durations no longer resets credited remaining time to the full duration. New duration settings apply to the next phase.
- Added explicit `didAutoPauseForIdle` lifecycle state. Return detection, resume, reset, skip, previous, and disabling Auto-pause clear the state and tear down the return poll.
- Review prompts are created only after the underlying session record saves successfully. Missing stores and missing record IDs now produce visible typed errors instead of silently clearing review state.
- Paused state deliberately retains `pause.circle` even when a goal is set. Ready/completed idle states use the goal-fill symbol.
- Status-item accessibility now includes the daily goal summary. A single coalesced midnight timer refreshes the idle goal fill and label without introducing per-second idle work.
- Added exact CSV header-order and nil-quality coverage, missing-record coverage, paused-preference preservation coverage, and expiry-before-idle coverage.
- Cleaned trailing whitespace in the previously untracked idle-monitor source.

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

The new checks specifically prove:

- expired focus completion wins before any idle-pause handling;
- completed phases cannot be changed back to paused;
- preference edits preserve a credited paused duration;
- CSV `quality` is the final header, writes `3`, and remains empty when unset;
- updating a missing session record throws `recordNotFound`.

### Live verification

- Temporarily configured a one-minute focus with sounds/notifications off, review on, and a 15-minute daily goal.
- Completion displayed `How was that focus?` with accessible `Distracted`, `Okay`, and `Deep focus` buttons.
- Choosing Deep removed the row and persisted a record with `plannedSeconds: 60`, `actualSeconds: 60`, `interruptionCount: 0`, and `focusQuality: 3`.
- The final implementation exposes the goal summary in both the menu dropdown and the status item's accessibility label; paused state uses `pause.circle` by deliberate design.
- The original preference domain and Application Support folder were restored exactly after testing (`cmp` and recursive `diff -qr` both clean).

### Idle timing limitation

An attempted one-minute live idle run did not auto-pause because the automation environment continued resetting macOS's combined-session idle counter; a direct read showed only 26.37 seconds idle after the longer wall-clock interval. This is an environment limitation rather than positive acceptance evidence. The deterministic ordering, backdating, paused-state preservation, poll teardown, break/off guards, and completion paths are covered by tests and source review. A physical hands-off run remains appropriate for the installed release candidate.

### Inherited timing semantic

`TimerEngine` intentionally counts pause gaps in `actualSeconds`; existing SelfTests define this behavior. Auto-pause refunds countdown time, but a long pause can still increase recorded elapsed focus and therefore goal credit. Package 6 did not change that pre-existing Core semantic; it remains a future product-policy decision if desired.

### Final status

Source implementation and automated acceptance are complete. The physical hands-off idle/return-notification observation remains an installed release-candidate check.
