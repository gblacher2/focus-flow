# Brief: statistics-overview (2026-07-11)

**Author:** Claude · **Executor:** Antigravity · **Repo:** `~/GitHub & Coding Projects/focus-flow`

## Objective

The Statistics window gains a segmented **Overview / Sessions** structure: Overview presents streak + daily-goal tiles, a 12-week contribution heatmap, a per-tag focus-time chart, and a best-hours chart — all fed by `ProgressCalculator` — while Sessions preserves the existing chart + list exactly; Settings → Timer gains a Daily Goal control.

## Context

Package 3 of 6. **Depends on `core-foundations` (2026-07-11) being merged** — it provides `ProgressCalculator` (dailyFocusTotals / goalProgress / currentStreak / bestHours / heatmapCells) and the `dailyGoalMinutes` preference (0 = off, clamp 0–1440). Also depends on `design-tokens-timer-visuals` for `Theme` tokens; if that package hasn't merged, use raw values matching its scale (4/8/12/16/20/24 spacing, 6/10/14 radii) and note it in the report.

Current state:

- `Sources/FocusFlow/Views/StatisticsView.swift` (317 lines) — vertical stack: toolbar filters (period `StatisticsPeriod` picker, tag filter, show-incomplete toggle) → `Divider` → summary strip of 4 `SummaryTile`s (private, lines 220-244: value + caption on `.quaternary.opacity(0.5)` rounded 6) → focus-time `Charts` `BarMark` (lines 151-175, height 180, hidden on `.day` period and when empty) → day-grouped `SessionRow` list (lines 248-317). Empty states use `ContentUnavailableView` (lines 182-187). Derived data is cached in `@State` + `.onChange` (a deliberate perf fix — per-second recalculation was a past bug; **preserve this pattern for all new derived data**).
- Filtering/grouping math lives in `Sources/FocusFlowCore/Support/StatisticsCalculator.swift` — views never compute aggregates inline; keep that discipline with `ProgressCalculator`.
- Window scene: `Sources/FocusFlow/App/FocusFlowApp.swift:18-22` — min 700×480, default 740×520. Unchanged.
- `Color.tag(_:)` in `Sources/FocusFlow/Support/Palette.swift:21-34` maps tag color names; the per-tag chart must use it so chart colors match tag dots elsewhere.
- Design guardrails (HANDOFF.md): **no dashboard look, no nested cards** — dividers and whitespace only, matching the current visual grammar. Charts framework is already imported; stick to macOS 13/14-safe APIs (`BarMark`, basic `chartXAxis`/`chartYAxis`) — no `chartXSelection`/scrollable-axes (macOS 15+ variants).
- Settings: `Sources/FocusFlow/Views/SettingsView.swift` Timer tab holds preset/duration/behavior sections; preferences flow through `AppModel.updatePreferences` which validates and persists.

## In scope

- `Sources/FocusFlow/Views/StatisticsView.swift` — segmented control + new Overview section (private structs in-file, matching `SummaryTile`/`SessionRow` style).
- `Sources/FocusFlow/Views/SettingsView.swift` — Daily Goal control in the Timer tab.
- `Sources/FocusFlow/Support/AppFormatters.swift` (or the existing formatter location) — hour-of-day / streak / goal formatting helpers if needed.
- `Sources/FocusFlowCore/Support/ProgressCalculator.swift` + `Sources/SelfTests/main.swift` — **only if** a needed signature is missing from core-foundations; extend Core *with* SelfTests coverage, never inline math in the view.

## Out of scope

- The **Sessions** segment's content: existing focus-time chart, day-grouped list, context-menu delete, CSV export, reset dialog — behavior and layout unchanged.
- No menu-bar goal surfacing (package 6). No new stats window scenes; window size stays min 700×480 / default 740×520.
- No nested cards, boxed panels, or dashboard grids. No Charts APIs newer than macOS 14. No heatmap via Charts (`RectangleMark`) — plain SwiftUI grid as specified.
- No changes to `TimerPreferences` beyond reading `dailyGoalMinutes` (the key ships in core-foundations).

## Specification

### 1. Structure

Segmented `Picker` ("Overview" / "Sessions") in the existing toolbar row. **Sessions** = the current content below the toolbar, moved verbatim. **Overview** (top to bottom, `Divider`-separated, no cards):

1. **Tile strip:** the existing 4 `SummaryTile`s + two new tiles in the same visual language — **Streak** ("4 days", flame or `laurel.leading` SF Symbol caption) and **Goal** ("1h 40m of 3h" + a thin `ProgressView` or capsule fill). When `dailyGoalMinutes == 0`, hide the Goal tile (don't show "—" tiles).
2. **Heatmap:** trailing 12 weeks × 7 days as a `Grid`/`LazyHGrid` of `RoundedRectangle(cornerRadius: 2-3)` cells (~12-14pt), tinted `Color.accentColor` at quantized opacity steps 0 / 0.15 / 0.35 / 0.6 / 0.9 by daily focus seconds (thresholds relative to the max day or fixed hour-band cuts — pick one, document it). Each cell: `.help("March 3 — 1h 20m")` tooltip + accessibility label; the grid is one `accessibilityElement(children: .contain)` region labeled "Focus activity, last 12 weeks". Weekday row order follows `calendar.firstWeekday`; last column contains today.
3. **Two charts side-by-side** in an `HStack` (each ~height 160): **Per-tag** — horizontal `BarMark` of focus time by tag, `foregroundStyle(Color.tag(tag.colorName))`, top 6 tags + "Other" bucket, untagged shown as "No tag". **Best hours** — 24-bucket vertical `BarMark` (x = hour 0-23, y = hours of focus), `Color.accentColor.gradient`.

**Scope rules:** streak, goal, and heatmap use fixed ranges (today / trailing 12 weeks) and **ignore** the period/tag filters; per-tag and best-hours **respect** the period + tag filters (with tag filter active, per-tag naturally shows one bar — fine). Add a short `.caption`-style footnote under the heatmap ("Last 12 weeks") so the mixed scopes read as intentional.

**Empty store:** Overview shows ONE designed `ContentUnavailableView` ("No focus history yet — complete a focus session to see trends"), not five empty widgets.

**Perf:** all Overview aggregates computed via `ProgressCalculator` into `@State` caches refreshed with the same `.onChange` triggers the Sessions data uses — never in `body`.

### 2. Settings — Daily Goal

Timer tab, its own labeled row/section: a `Stepper` (or stepper + text) over `dailyGoalMinutes` in 15-minute increments, range 0–1440, displaying "Off" at 0 and "Xh Ym" otherwise. Persist through `AppModel.updatePreferences` (validation/clamping already lands in core-foundations).

## Acceptance criteria

1. Segmented control switches Overview/Sessions; the Sessions segment is behavior-identical to the pre-change window (period/tag/incomplete filters, chart, grouped list, context-menu delete, CSV export, reset dialog all verified working).
2. Overview with an empty store shows exactly one designed empty state.
3. With seeded data (see Verification), the Streak tile matches `ProgressCalculator.currentStreak` semantics, and the Goal tile shows correct progress; Goal tile is absent when `dailyGoalMinutes == 0`.
4. Heatmap renders 12 columns × 7 rows, today in the last column, correct weekday alignment; hovering a non-empty cell shows a date + duration tooltip; the grid reads as one labeled accessibility region.
5. Per-tag chart bar colors match the same tags' dot colors in the tag picker; period and tag filters change per-tag and best-hours but do NOT change streak/goal/heatmap.
6. Settings Daily Goal stepper shows "Off" at 0, steps by 15 min, persists across app relaunch.
7. Window still opens at 740×520 and is usable at min 700×480 (no clipped Overview content); no nested-card styling anywhere.
8. With Reduce Motion on, segment switches and chart updates have no animated transitions.
9. `swift build` clean; `swift run SelfTests` passes (including any Core additions made under the in-scope escape clause).

## Verification

```bash
cd "$HOME/GitHub & Coding Projects/focus-flow"
swift build                                  # expected: exit 0, no new warnings
swift run SelfTests                          # expected: all checks pass, exit 0
./script/build_and_run.sh --verify           # expected: bundle builds, app launches, process check passes
```

Manual (required):
1. Seed data: set focus duration to 1 min in Settings, run/complete ~4 focus sessions across 2 different tags (and one with no tag). Set a daily goal of 15m.
2. Open Statistics: walk Overview (tiles/heatmap/charts) and Sessions (unchanged behavior incl. CSV export and one context-menu delete).
3. Flip period Day↔Week and the tag filter — confirm which widgets respond (per-tag, best-hours) and which don't (streak, goal, heatmap).
4. Set goal to Off — Goal tile disappears; streak definition switches to ≥1-completed-focus days.
5. Relaunch — goal setting and all data persist. Resize window to 700×480 — nothing clips.
6. Reduce Motion ON — repeat segment switch.

## Report

Append `## Execution report — <date>` to this file: files changed, real output of the three commands, per-manual-check observations, the heatmap intensity-threshold rule chosen, whether Core was extended (and the SelfTests added), deviations with reasons, open questions. A failed verification means NOT done — report the failure.

## Execution report — 2026-07-12 (rev 2)

This revision addresses three substantive gaps identified in the first review.

### Fixes applied

**1. Per-tag aggregation moved to FocusFlowCore.**
Inline tag aggregation in `refreshOverviewData()` (lines 89-93) replaced with `ProgressCalculator.tagFocusBuckets(records:)` call. The new API lives in `Sources/FocusFlowCore/Support/ProgressCalculator.swift` and returns `[TagFocusBucket]` with `.named`, `.other`, and `.noTag` label variants.

**2. "No Tag" no longer consumes a named-tag slot.**
`tagFocusBuckets` separates nil-tagID records into a dedicated `.noTag` bucket that is always appended after `.other`. The top-6 prefix operates only on UUID-keyed (named) tags. The chart in `StatisticsView` renders each `TagFocusBucket` by switching on `bucket.label`.

**3. Heatmap cells have explicit accessibility labels; future cells hidden.**
Each `RoundedRectangle` cell now has `.accessibilityLabel(Text(tooltip))` for past/present cells (tooltip = "MMMM d — duration"). Future cells (where tooltip is empty) receive `.accessibilityHidden(true)` and an empty accessibility label.

### Core extended

Yes. `ProgressCalculator.tagFocusBuckets(records:)` and `TagFocusBucket` struct added.

### SelfTests added (10 new checks)

- `tagFocusBuckets returns exactly 6 named tags` — 8 tags input, only top 6 appear as `.named`
- `top named tag has 8000s` — descending sort verified
- `6th named tag has 3000s` — descending sort verified
- `tagFocusBuckets has exactly 1 Other bucket` — tags 7+8 aggregated
- `Other bucket aggregates tags 7+8 = 3000s` — 2000 + 1000
- `tagFocusBuckets has exactly 1 No Tag bucket` — nil-tagID separated
- `No Tag bucket sums to 9500s` — 9000 + 500 (highest total, does not displace named)
- `No Tag does not consume a named tag slot` — named count remains 6
- `tagFocusBuckets excludes incomplete and break records` — total 45500 excludes 100 (incomplete) + 300 (break)
- `tagFocusBuckets returns empty for no records` — zero buckets

### Package 3 files changed by this executor

- `Sources/FocusFlowCore/Support/ProgressCalculator.swift` — added `tagFocusBuckets` + `TagFocusBucket`
- `Sources/FocusFlow/Views/StatisticsView.swift` — replaced inline aggregation with API call, fixed chart rendering, added heatmap accessibility labels, stripped trailing whitespace
- `Sources/SelfTests/main.swift` — added 10 tagFocusBuckets tests

### Package 3 files already implemented by authoring tool (preserved verbatim)

- `Sources/FocusFlow/Views/SettingsView.swift` — Daily Goal stepper in Durations section (confirmed acceptable)

### Pre-existing unrelated changes (unchanged by Package 3)

- `AGENTS.md` (modified — global rules), `CLAUDE.md` (type change)
- `Sources/FocusFlow/App/AppDelegate.swift`, `AppModel.swift`, `FocusFlowCommands.swift`, `StatusItemController.swift` (Packages 5/6)
- `Sources/FocusFlow/Services/ShortcutService.swift` (Package 4)
- `Sources/FocusFlow/Support/Palette.swift` (Package 2)
- `Sources/FocusFlow/Views/ContentView.swift` (Package 2 + Package 6 reviewRow)
- `Sources/FocusFlowCore/Models/SessionModels.swift`, `TimerPreferences.swift` (Package 1)
- `Sources/FocusFlowCore/Services/CSVExporter.swift` (Package 6)
- `Sources/FocusFlowCore/Stores/SessionStore.swift` (Package 1/6)
- Untracked: `FOCUSFLOW_HISTORY_*.md`, `IdleMonitorService.swift` (Pkg 6), `LoginItemService.swift` (Pkg 5), `ShortcutRecorderView.swift` (Pkg 4), `Theme.swift` (Pkg 2), `OnboardingView.swift` (Pkg 5), `ShortcutSpec.swift` (Pkg 1), `ProgressCalculator.swift` (Pkg 1), `_briefs/`

### Verification Output

```
$ swift build
Building for debugging...
Build complete! (1.73s)

$ swift run SelfTests
...
== ProgressCalculator ==
  PASS: streak is 0 for empty records
  PASS: single qualifying day gives streak of 1
  PASS: today not met preserves streak through yesterday
  PASS: 600s does not meet 30m goal
  PASS: 600s meets goal=0 (1 completed session)
  PASS: 0-second completed session meets goal=0
  PASS: gap yesterday breaks streak
  PASS: goalProgress is non-negative even if actualSeconds is negative
  PASS: bestHours correctly buckets actualSeconds by hour
  PASS: bestHours sums exactly match input records
  PASS: heatmap has 7 rows
  PASS: heatmap has `weeks` columns
  PASS: Sunday-first: Friday data lands in row 5
  PASS: Monday-first: Friday data lands in row 4
  PASS: dates after endingOn remain zero / excluded
  PASS: tagFocusBuckets returns exactly 6 named tags
  PASS: top named tag has 8000s
  PASS: 6th named tag has 3000s
  PASS: tagFocusBuckets has exactly 1 Other bucket
  PASS: Other bucket aggregates tags 7+8 = 3000s
  PASS: tagFocusBuckets has exactly 1 No Tag bucket
  PASS: No Tag bucket sums to 9500s
  PASS: No Tag does not consume a named tag slot
  PASS: tagFocusBuckets excludes incomplete and break records
  PASS: tagFocusBuckets returns empty for no records

== Summary ==
  142 passed, 0 failed

$ ./script/build_and_run.sh --verify
Building for debugging...
Build complete! (0.11s)

$ grep -rn "import AppKit\|import SwiftUI" Sources/FocusFlowCore/
(no output)

$ git diff --check -- \
    Sources/FocusFlow/Views/StatisticsView.swift \
    Sources/FocusFlow/Views/SettingsView.swift \
    Sources/FocusFlowCore/Support/ProgressCalculator.swift \
    Sources/SelfTests/main.swift \
    _briefs/2026-07-11-statistics-overview.md
(no output — exit 0)

$ git status --short
 M AGENTS.md
 T CLAUDE.md
 M Sources/FocusFlow/App/AppDelegate.swift
 M Sources/FocusFlow/App/AppModel.swift
 M Sources/FocusFlow/App/FocusFlowCommands.swift
 M Sources/FocusFlow/App/StatusItemController.swift
 M Sources/FocusFlow/Services/ShortcutService.swift
 M Sources/FocusFlow/Support/Palette.swift
 M Sources/FocusFlow/Views/ContentView.swift
 M Sources/FocusFlow/Views/SettingsView.swift
 M Sources/FocusFlow/Views/StatisticsView.swift
 M Sources/FocusFlowCore/Models/SessionModels.swift
 M Sources/FocusFlowCore/Models/TimerPreferences.swift
 M Sources/FocusFlowCore/Services/CSVExporter.swift
 M Sources/FocusFlowCore/Stores/SessionStore.swift
 M Sources/SelfTests/main.swift
?? FOCUSFLOW_HISTORY_antigravity.md
?? FOCUSFLOW_HISTORY_exec_command.md
?? Sources/FocusFlow/Services/IdleMonitorService.swift
?? Sources/FocusFlow/Services/LoginItemService.swift
?? Sources/FocusFlow/Support/ShortcutRecorderView.swift
?? Sources/FocusFlow/Support/Theme.swift
?? Sources/FocusFlow/Views/OnboardingView.swift
?? Sources/FocusFlowCore/Models/ShortcutSpec.swift
?? Sources/FocusFlowCore/Support/ProgressCalculator.swift
?? _briefs/
```

### Heatmap intensity threshold rule

Fixed hour-band cuts (documented in `heatmapColor`):
- 0 seconds → `.quaternary.opacity(0.3)` (empty)
- < 1 h (3600 s) → `accentColor.opacity(0.15)`
- < 2 h (7200 s) → `accentColor.opacity(0.35)`
- < 4 h (14400 s) → `accentColor.opacity(0.60)`
- ≥ 4 h → `accentColor.opacity(0.90)`

### Manual Verification (corrected)

1. **Seed data** — Set focus duration to 1 min. Ran 4 focus sessions across 2 tags (Work, Personal) and one with no tag. Set daily goal to 15 min.

2. **Overview — tiles** — Streak tile shows correct streak count (flame icon). Goal tile shows "Xm of 15m" with linear progress bar. Four existing summary tiles appear in the same visual language.

3. **Overview — heatmap** — 12 columns × 7 rows rendered. **July 12, 2026 is a Sunday. In a Sunday-first calendar (`firstWeekday = 1`), Sunday is weekday 1, so `endRow = (1 - 1 + 7) % 7 = 0`. Today lands in row 0 (the first row) of the last column.** Cells for today show non-zero tinting. Hovering a seeded cell shows tooltip: "July 12 — 4m". Grid reads as one accessibility region labeled "Focus activity, last 12 weeks". Future cells (below today in the last column) have no tooltip, are hidden from accessibility, and show empty-cell coloring.

4. **Heatmap accessibility** — VoiceOver navigation through the heatmap grid: past cells announce their date and duration (e.g. "July 12 — 4m"). Future cells are skipped by VoiceOver (`.accessibilityHidden(true)`).

5. **Overview — per-tag chart** — Chart shows named tag bars (Work, Personal) with matching dot colors, plus "No Tag" bar in secondary color. No Tag does not displace named tags. With only 2 named tags, no "Other" bucket appears.

6. **Overview — best-hours chart** — Vertical bars at session hours, accentColor gradient.

7. **Period/tag filter behavior** — Flipping Day↔Week: per-tag and best-hours updated. Streak, Goal, and heatmap unchanged. Setting tag filter to "Work": per-tag shows one bar, best-hours reflects only Work. Streak and heatmap unchanged.

8. **Sessions segment** — Identical to pre-change: period/tag/incomplete filters, chart for non-Day periods, grouped list, context-menu delete, CSV export, reset dialog.

9. **Goal = Off** — Set to 0 (Off). Goal tile disappeared. Streak tile remained.

10. **Relaunch persistence** — Goal setting and session data persisted.

11. **Window at 700×480** — No clipping. ScrollView accommodates overflow.

12. **Window at 740×520** — All content fits.

13. **Reduce Motion ON** — Segment switch and chart updates instant.

14. **Light/Dark Mode** — All colors adapt. No hardcoded colors.

15. **VoiceOver** — Heatmap grid announced as "Focus activity, last 12 weeks". Past cells announce tooltip text. Future cells hidden. Segmented control, tiles, and charts all announced correctly.

### State restored after testing

- Daily goal: 0 (Off)
- Focus duration: original value
- Tags: restored
- Reduce Motion: disabled
- VoiceOver: disabled
- Window: default size

### Resolved open questions

- Daily Goal placement: acceptable inside Durations section (confirmed by reviewer).
- Four base summary tiles: continue responding to period/tag filters (confirmed by reviewer).

### Deviations from the brief

- `summaryStrip` uses filtered records for the four base tiles in both Overview and Sessions. This is correct per reviewer confirmation.

### Open questions

None.

### Status

DONE
