# FocusFlow — Design Handoff for Claude Code

## What is FocusFlow

A native macOS SwiftUI menu-bar-first Pomodoro timer. Quiet, calm, Mac-native utility — not flashy, not a dashboard. Inspired by Flow for macOS in spirit but with original design and code.

**Bundle ID:** `com.gabrielblacher.FocusFlow`
**Project path:** repository root
**Min deployment:** macOS 14 (Sonoma)
**Build system:** SwiftPM (no Xcode project, Command Line Tools compatible)

---

## Project Structure

```
focus-flow/
├── Package.swift                          # SwiftPM manifest, macOS 14+, Swift 6
├── Sources/
│   ├── FocusFlow/                         # App target (executable)
│   │   ├── App/
│   │   │   ├── FocusFlowApp.swift         # @main, Scene definitions (Window, Settings)
│   │   │   ├── AppModel.swift             # Central @MainActor ObservableObject — all state & actions
│   │   │   ├── AppDelegate.swift          # Sets activation policy to .accessory, hosts environment bridge
│   │   │   ├── StatusItemController.swift  # Controls NSStatusItem and dropdown menu (AppKit)
│   │   │   └── FocusFlowCommands.swift    # macOS menu bar Commands (Timer menu)
│   │   ├── Views/
│   │   │   ├── ContentView.swift          # Timer window — ring, controls, title/tag
│   │   │   ├── SettingsView.swift         # Tabbed settings — Timer, Notifications, Tags, Shortcuts
│   │   │   └── StatisticsView.swift       # Session history — summary tiles, filtered list, export
│   │   ├── Services/
│   │   │   ├── NotificationService.swift  # UNUserNotificationCenter wrapper
│   │   │   ├── PreferencesStore.swift     # UserDefaults persistence for TimerPreferences
│   │   │   ├── ShortcutService.swift      # Global/local keyboard shortcut monitor (NSEvent)
│   │   │   └── SoundService.swift         # NSSound playback
│   │   ├── Stores/                        # (empty — stores are in Services/)
│   │   ├── Models/                        # (empty — models are in FocusFlowCore)
│   │   └── Support/
│   │       ├── AppFormatters.swift        # DateFormatter instances (dateTime, time, dayHeader)
│   │       ├── ControlButtonStyle.swift   # Circular button style w/ hover & press feedback
│   │       └── Palette.swift              # Color.phase(_:) / Color.tag(_:) helpers
│   └── FocusFlowCore/                     # Library target (no AppKit dependency)
│       ├── Models/
│       │   ├── TimerEngine.swift          # Pure state machine: phases, tick, start/pause/skip/reset
│       │   ├── TimerPhase.swift           # Enum: ready, focus, shortBreak, longBreak, paused, completed
│       │   ├── TimerPreferences.swift     # Duration/behavior prefs + TimerSound enum
│       │   └── SessionModels.swift        # Tag, SessionRecord, SessionStoreData, StatisticsSummary
│       ├── Services/
│       │   └── CSVExporter.swift          # CSV export for session records
│       ├── Stores/
│       │   ├── SessionStore.swift         # JSON file persistence for sessions + tags
│       │   └── RuntimeStore.swift         # JSON file persistence for TimerEngine state (crash recovery)
│       └── Support/
│           ├── DurationFormatter.swift    # clock("25:00") and compact("2h 15m") formatters
│           └── StatisticsCalculator.swift # Filtering by period/tag, summary aggregation
├── Tests/FocusFlowTests/                  # Tests against FocusFlowCore
├── script/
│   ├── build_and_run.sh                   # Build & optional --verify/--logs/--build-only flag
│   └── package_release.sh                 # Ad-hoc sign + zip a distributable build into dist/
└── .codex/environments/environment.toml
```

---

## Architecture

### Data flow

```
AppModel (ObservableObject, @MainActor)
  ├── engine: TimerEngine        — value-type state machine, ticked every 1s
  ├── preferences: TimerPreferences
  ├── records: [SessionRecord]   — loaded from SessionStore (JSON file)
  ├── tags: [Tag]                — loaded from SessionStore
  ├── sessionTitle: String
  ├── selectedTagID: UUID?
  └── shortcutStatus: ShortcutService.Status
```

All views observe `AppModel` via `@ObservedObject`. Actions go through `AppModel` methods which mutate the engine and persist state.

### Timer lifecycle

```
.ready → .focus → .paused/.completed → .shortBreak → .focus → ... → .longBreak → .focus
```

- `TimerEngine` is a `Codable` struct — pure value type, no side effects
- `AppModel.tick()` runs once per second via `Foundation.Timer`, but **only while a phase is counting down** — `syncTicker()` starts the timer on run and invalidates it when idle/paused/completed, so the app does zero per-second work (no CPU wakeups, no disk writes) when not running
- Runtime state is persisted on phase transitions and user actions, **not** every tick — remaining time is derived from the saved `targetEnd`, so per-second saves add nothing for crash recovery
- Phase transitions emit `TimerEvent` (.phaseCompleted / .phaseSkipped)
- Events create `SessionRecord` entries persisted to disk

### Scene layout (FocusFlowApp.swift)

| Scene | ID | Size |
|---|---|---|
| Timer Window | `"timer"` | 312×398 default |
| Statistics Window | `"statistics"` | 740×520 default |
| Settings | native `Settings` scene | 460×400 |
| NSStatusItem (AppKit) | — | AppKit menu bar icon & dropdown menu |

The app runs as `.accessory` (no dock icon) — it's menu-bar-first.

---

## Current Design State (after UX refinement pass)

### Timer Window (ContentView.swift)
- Centered layout: ring → controls → title/tag
- **Ring:** 198×198, 6pt stroke, angular gradient matching phase color, `.easeInOut` animation (skipped under Reduce Motion)
- **Time:** 48pt, `weight: .light`, `.rounded` design, monospaced digits
- **Phase label:** below time inside ring — e.g. "Focus · 1/4", "Short Break · 2/4", "Next: Short Break"
- **Controls:** circular primary play/pause (44×44, tinted background), plain icon buttons for prev/skip/reset (30×30) — `ControlButtonStyle` (Support/ControlButtonStyle.swift) adds hover/press feedback
- **Title:** borderless centered `TextField`, placeholder "What are you working on?"
- **Tag:** `Menu`-based picker with `Circle().fill()` color dots, `.menuStyle(.borderlessButton)`

### Menu Bar (StatusItemController.swift)
- **Icon + time** shown in menu bar (e.g. `● 23:15`) using a native AppKit `NSStatusItem` button. The countdown text is hidden whenever the timer is not running — idle (`.ready`/`.completed`) and `.paused` alike — unless the "Show countdown in menu bar when not running" preference (Settings → Timer tab → Behavior; default off for fresh installs, but a missing persisted key migrates to on) is enabled. While a phase is running (focus or break), the icon becomes a progress-filling glyph (`circle.dotted.circle` with a symbol configuration `variableValue` tracking `AppModel.progress`, 0→1) instead of the static symbol, with phase color (blue/green) still carrying the focus-vs-break distinction. Non-running states keep static symbols: `circle` (ready), `pause.circle` (paused), `checkmark.circle` (completed).
- **Right-click shortcut**: Right-clicking the status item button in any non-running state acts immediately (via `app.toggleTimer()`) — it resumes when `.paused`, starts focus when `.ready`, and starts the next phase when `.completed`. Only while a phase is actively running does right-clicking behave exactly like left-clicking, opening the menu.
- **Dropdown menu**: Built natively using `NSMenu` and `NSMenuItem` wrappers.
  - **Header rows**: Row 1 is always shown as the composite status text, e.g. "Ready", "Focusing · 23:15", "Focus Paused · 23:15", "Next: Short Break". Row 2 appears only when a session title and/or tag is set, e.g. "Writing report · Study".
  - **Actions**: Contextual labels like "Start Focus", "Pause Timer", "Resume", "Skip Phase", and "Reset Cycle".
  - **Windows section**: Timer Window, Statistics, Settings…
  - **Quit**: "Quit FocusFlow"

### Settings (SettingsView.swift)
- 4 tabs: Timer, Notifications, Tags, Shortcuts
- **Timer tab:** "Session Preset" section (Classic / Deep Work / Flow rows, checkmark on the active one, "Custom durations" when none match) + "Durations" section (steppers) + "Behavior" section (toggles), `.formStyle(.grouped)`. Presets are defined in `FocusFlowCore/Models/SessionPreset.swift`; applied via `AppModel.applyPreset(_:)`; the active preset is `TimerPreferences.matchingPreset`.
- **Notifications tab:** toggles + "Completion Sounds" section with pickers
- **Tags tab:** add row (TextField + color picker + plus button) + list with delete
- **Shortcuts tab:** status with icon/color (green globe = global, orange warning = local-only) + guidance text + key bindings

### Statistics (StatisticsView.swift)
- **Toolbar:** segmented period picker, tag filter, incomplete toggle, ellipsis menu (Export CSV, Reset with confirmation dialog)
- **Summary tiles:** 4 tiles with SF Symbol icon accents — Focus Sessions, Focus Time, Breaks, Interruptions
- **Session list:** grouped into day sections with "Today"/"Yesterday"/date headers (`AppFormatters.dayHeader`), phase icon (brain/cup), title, time/duration, tag dot, phase label
- **Empty state:** `ContentUnavailableView` with "Completed sessions will appear here."

---

## Design Principles

1. **Menu-bar-first** — the app lives in the menu bar. Timer window is secondary.
2. **Calm & native** — system materials, adaptive colors, no custom chrome. macOS patterns.
3. **No dashboard feel** — no nested cards, no marketing layout. It's a utility.
4. **Restrained color** — phase colors (accent/green/teal) used sparingly on ring, dots, icons. Everything else is system text colors.
5. **Quick control** — one-click play/pause, keyboard shortcut for everything.
6. **Compact** — timer window is 340px wide. Menu dropdown is narrow. Don't make things wider than they need to be.

---

## Phase → Color Mapping

| Phase | Color | Usage |
|---|---|---|
| Focus | `.accentColor` (system blue) | ring, primary button tint, summary icons |
| Short Break | `.green` | ring, icons |
| Long Break | `.teal` | ring |
| Ready/Paused/Completed | `.secondary` | ring, muted states |

---

## Tag Colors

Tags use named colors: `"blue"`, `"green"`, `"orange"`, `"purple"`, `"pink"`. Mapped via `Color.tag(_:)` in `Support/Palette.swift`:

```swift
extension Color {
    static func tag(_ name: String) -> Color {
        switch name {
        case "green": .green
        case "orange": .orange
        case "purple": .purple
        case "pink": .pink
        default: .blue
        }
    }
}
```

**Important:** Use `Circle().fill(color)` for tag dots — not `Image(systemName:).foregroundStyle()` — because Menu label styling overrides SF Symbol foreground colors.

---

## Build & Verify

```bash
# From the repository root
# Build
swift build

# Self-tests (swift test silently no-ops on this CLT-only machine — do not use it)
swift run SelfTests

# Full verify
./script/build_and_run.sh --verify
```

All three must pass after any change. The project uses Swift 6 strict concurrency.

---

## What NOT to Do

- Don't add app/web blocking (Phase 2)
- Don't add iCloud sync, widgets, calendar sync, Health sync, or AppleScript
- Don't copy Flow's exact visuals, text, sounds, or assets
- Don't rewrite the architecture — edit views and AppModel only
- Don't use Xcode-only workflows (no .xcodeproj, no asset catalogs)
- Don't make the timer window wider than ~360px
- Don't add nested cards or dashboard layouts
- Don't make it look like a landing page

---

## Areas Open for Further Design Work

- **Typography polish** — extend the existing typography tokens consistently through Settings and Onboarding (timer and Statistics typography is already tokenized)
- **Window appearance** — toolbar and window-chrome styling remains open (native vibrancy/material is already implemented)
- **Color refinement** — subjective phase-palette and dark-mode tuning remains open (focus follows the system accent; break colors are centralized)
- **Empty states** — richer illustrations or guidance remain open (basic guided empty states are already implemented)
- **Accessibility** — Dynamic Type adaptation and validation remain open (VoiceOver labels and Reduce Motion behavior are already implemented across the key surfaces)
