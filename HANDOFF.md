# FocusFlow — Design Handoff for Claude Code

## What is FocusFlow

A native macOS SwiftUI menu-bar-first Pomodoro timer. Quiet, calm, Mac-native utility — not flashy, not a dashboard. Inspired by Flow for macOS in spirit but with original design and code.

**Bundle ID:** `com.gabrielblacher.FocusFlow`
**Project path:** `/Users/gabrielblacher/Projects/focus-flow`
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
│   │   │   ├── FocusFlowApp.swift         # @main, Scene definitions (Window, MenuBarExtra, Settings)
│   │   │   ├── AppModel.swift             # Central @MainActor ObservableObject — all state & actions
│   │   │   ├── AppDelegate.swift          # Sets activation policy to .accessory (menu-bar app)
│   │   │   └── FocusFlowCommands.swift    # macOS menu bar Commands (Timer menu)
│   │   ├── Views/
│   │   │   ├── ContentView.swift          # Timer window — ring, controls, title/tag
│   │   │   ├── MenuBarView.swift          # MenuBarExtra dropdown — status header, actions
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
| MenuBarExtra | — | dropdown menu |

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

### Menu Bar (MenuBarView.swift)
- **Icon + time** always shown in menu bar (e.g. `● 23:15`)
- **Dropdown header:** phase name, time, session title, micro progress bar (3pt capsule)
- **Actions:** contextual labels — "Start Focus", "Pause Timer", "Resume", "Skip Phase", etc.
- **Windows section:** Timer Window, Statistics, Settings…
- **Quit:** "Quit FocusFlow"

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
cd /Users/gabrielblacher/Projects/focus-flow

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

- **Typography polish** — font weights, sizes, spacing in all views
- **Animations** — ring transitions, phase change animations, control feedback
- **Window appearance** — vibrancy, materials, toolbar style
- **Color refinement** — whether accent blue is the right focus color, dark mode tuning
- **Menu bar dropdown** — whether the status header is too tall, progress bar styling
- **Statistics** — chart/graph for focus time (day-grouped headers already implemented)
- **Empty states** — illustrations or more helpful guidance
- **Accessibility** — Dynamic Type support (VoiceOver labels and Reduce Motion are already implemented in ContentView/ControlButtonStyle)
- **Sound picker** — preview button in settings
- **Onboarding** — first-launch experience (if needed)
