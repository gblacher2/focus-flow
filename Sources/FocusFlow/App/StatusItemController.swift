import AppKit
import Combine
import FocusFlowCore
import SwiftUI

/// Owns the app's `NSStatusItem` and handles left/right click directly via
/// `sendAction(on:)`. This replaces SwiftUI's `MenuBarExtra` so that we have
/// full control over mouse events:
///
/// - **Left-click**: shows the dropdown menu (same actions as the old MenuBarView).
/// - **Right-click while not running**: resumes immediately or starts the next phase.
/// - **Right-click while running**: shows the dropdown menu (same as left-click).
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let app: AppModel
    private var cancellable: AnyCancellable?

    init(app: AppModel) {
        self.app = app
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateAppearance()

        // Re-render the button whenever AppModel publishes a change.
        // `objectWillChange` fires *before* the mutation, so we dispatch to
        // the next run-loop cycle so the new values are visible.
        cancellable = app.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAppearance()
            }
    }

    // MARK: - Click Handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp, app.performStatusItemSecondaryAction() {
            return
        }

        // Left-click, or right-click while a phase is already running, shows the menu.
        let menu = buildMenu()
        statusItem.menu = menu
        sender.performClick(nil)   // re-triggers the click, which now opens the menu
        statusItem.menu = nil      // clear so next click routes to our action again
    }

    // MARK: - Appearance

    private func updateAppearance() {
        guard let button = statusItem.button else { return }

        let phase = app.engine.displayPhase
        let showsCountdown = app.showsMenuBarCountdown

        // --- Icon ---
        let iconName: String
        if app.engine.isRunning {
            iconName = AppModel.menuBarProgressSystemImage
        } else {
            iconName = app.menuBarSystemImage
        }

        let nsColor = NSColor(Color.phase(phase))
        var config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        config = config.applying(.init(paletteColors: [nsColor]))
        if app.engine.isRunning {
            config = config.applying(.init(hierarchicalColor: nsColor))
        }

        if app.engine.isRunning {
            button.image = NSImage(
                systemSymbolName: iconName,
                variableValue: app.progress,
                accessibilityDescription: "FocusFlow"
            )?.withSymbolConfiguration(config)
        } else {
            button.image = NSImage(
                systemSymbolName: iconName,
                accessibilityDescription: "FocusFlow"
            )?.withSymbolConfiguration(config)
        }
        button.image?.isTemplate = false

        // --- Title (countdown text) ---
        if showsCountdown {
            let font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize, weight: .medium
            )
            button.attributedTitle = NSAttributedString(
                string: " \(DurationFormatter.clock(app.engine.remainingSeconds))",
                attributes: [.font: font]
            )
        } else {
            button.title = ""
        }

        // --- Accessibility ---
        let label: String
        if showsCountdown {
            label = "FocusFlow timer \(DurationFormatter.clock(app.engine.remainingSeconds))"
        } else {
            switch app.engine.phase {
            case .paused:
                label = "FocusFlow timer, paused"
            case .completed:
                label = "FocusFlow timer, next \(app.engine.pendingPhase.displayName)"
            case .ready:
                label = "FocusFlow timer, idle"
            case .focus, .shortBreak, .longBreak:
                label = "FocusFlow timer"
            }
        }
        button.setAccessibilityLabel(label)
    }

    // MARK: - Menu Construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // ── Status header ──
        let statusItem = NSMenuItem()
        statusItem.title = statusLine
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if let detail = detailLine {
            let detailItem = NSMenuItem()
            detailItem.title = detail
            detailItem.isEnabled = false
            menu.addItem(detailItem)
        }

        menu.addItem(.separator())

        // ── Primary action ──
        let primary = NSMenuItem(
            title: primaryLabel,
            action: #selector(doToggleTimer),
            keyEquivalent: " "
        )
        primary.keyEquivalentModifierMask = [.command, .option, .control]
        primary.target = self
        menu.addItem(primary)

        // ── Skip ──
        let skip = NSMenuItem(
            title: "Skip Phase",
            action: #selector(doSkip),
            keyEquivalent: String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))
        )
        skip.keyEquivalentModifierMask = [.command, .option, .control]
        skip.target = self
        menu.addItem(skip)

        // ── Previous ──
        let prev = NSMenuItem(title: "Previous Phase", action: #selector(doPrevious), keyEquivalent: "")
        prev.target = self
        menu.addItem(prev)

        // ── Reset ──
        let reset = NSMenuItem(title: "Reset Cycle", action: #selector(doResetCycle), keyEquivalent: "r")
        reset.keyEquivalentModifierMask = [.command, .option, .control]
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        // ── Quick settings submenus ──
        menu.addItem(focusDurationMenuItem())
        menu.addItem(breakDurationMenuItem())
        menu.addItem(longBreakAfterMenuItem())
        menu.addItem(autoStartMenuItem())

        menu.addItem(.separator())

        // ── Windows ──
        let timerWin = NSMenuItem(title: "Timer Window", action: #selector(doOpenTimerWindow), keyEquivalent: "f")
        timerWin.keyEquivalentModifierMask = [.command, .option, .control]
        timerWin.target = self
        menu.addItem(timerWin)

        let stats = NSMenuItem(title: "Statistics", action: #selector(doOpenStatisticsWindow), keyEquivalent: "")
        stats.target = self
        menu.addItem(stats)

        let settings = NSMenuItem(title: "Settings…", action: #selector(doOpenSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit FocusFlow", action: #selector(doQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Menu Actions

    @objc private func doToggleTimer() { app.toggleTimer() }
    @objc private func doSkip() { app.skip() }
    @objc private func doPrevious() { app.previous() }
    @objc private func doResetCycle() { app.resetCycle() }

    @objc private func doOpenTimerWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let closure = app.openTimerWindow {
            closure()
        } else {
            showExistingWindow(titled: "FocusFlow")
        }
    }

    @objc private func doOpenStatisticsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let closure = app.openStatisticsWindow {
            closure()
        } else {
            showExistingWindow(titled: "Statistics")
        }
    }

    @objc private func doOpenSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let closure = app.openSettingsWindow {
            closure()
        } else {
            // Fallback: use the standard AppKit selector for Settings scenes
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func showExistingWindow(titled title: String) {
        if let window = NSApp.windows.first(where: { $0.title == title }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func doQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Status Text Helpers

    private var statusLine: String {
        if app.engine.phase == .completed {
            return "Next: \(app.engine.pendingPhase.displayName)"
        }
        if app.engine.isRunning || app.engine.phase == .paused {
            return "\(statusTitle) · \(DurationFormatter.clock(app.engine.remainingSeconds))"
        }
        return statusTitle
    }

    private var statusTitle: String {
        switch app.engine.phase {
        case .ready: "Ready"
        case .focus: "Focusing"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        case .paused: "\(app.engine.displayPhase.displayName) Paused"
        case .completed: "Phase Complete"
        }
    }

    private var detailLine: String? {
        let parts = [app.sessionTitle, app.selectedTag?.title]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var primaryLabel: String {
        switch app.engine.phase {
        case .ready: "Start Focus"
        case .focus: "Pause Timer"
        case .shortBreak, .longBreak: "Pause Break"
        case .paused: "Resume"
        case .completed: "Start \(app.engine.pendingPhase.displayName)"
        }
    }

    // MARK: - Quick-Setting Submenus

    private func focusDurationMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Focus Duration", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for minutes in [15, 20, 25, 30, 45, 50, 60, 90] {
            let mi = NSMenuItem(title: "\(minutes) min", action: #selector(setFocusDuration(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = minutes
            mi.state = app.preferences.focusMinutes == minutes ? .on : .off
            sub.addItem(mi)
        }
        item.submenu = sub
        return item
    }

    @objc private func setFocusDuration(_ sender: NSMenuItem) {
        app.updatePreferences { $0.focusMinutes = sender.tag }
    }

    private func breakDurationMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Break Duration", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let shortHeader = NSMenuItem(title: "Short Break", action: nil, keyEquivalent: "")
        shortHeader.isEnabled = false
        sub.addItem(shortHeader)
        for minutes in [5, 10] {
            let mi = NSMenuItem(title: "  \(minutes) min", action: #selector(setShortBreakDuration(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = minutes
            mi.state = app.preferences.shortBreakMinutes == minutes ? .on : .off
            sub.addItem(mi)
        }

        let longHeader = NSMenuItem(title: "Long Break", action: nil, keyEquivalent: "")
        longHeader.isEnabled = false
        sub.addItem(longHeader)
        for minutes in [15, 20, 30] {
            let mi = NSMenuItem(title: "  \(minutes) min", action: #selector(setLongBreakDuration(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = minutes
            mi.state = app.preferences.longBreakMinutes == minutes ? .on : .off
            sub.addItem(mi)
        }

        item.submenu = sub
        return item
    }

    @objc private func setShortBreakDuration(_ sender: NSMenuItem) {
        app.updatePreferences { $0.shortBreakMinutes = sender.tag }
    }

    @objc private func setLongBreakDuration(_ sender: NSMenuItem) {
        app.updatePreferences { $0.longBreakMinutes = sender.tag }
    }

    private func longBreakAfterMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Long Break After", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for count in 1...10 {
            let mi = NSMenuItem(
                title: "\(count) \(count == 1 ? "session" : "sessions")",
                action: #selector(setLongBreakAfter(_:)),
                keyEquivalent: ""
            )
            mi.target = self
            mi.tag = count
            mi.state = app.preferences.sessionsBeforeLongBreak == count ? .on : .off
            sub.addItem(mi)
        }
        item.submenu = sub
        return item
    }

    @objc private func setLongBreakAfter(_ sender: NSMenuItem) {
        app.updatePreferences { $0.sessionsBeforeLongBreak = sender.tag }
    }

    private func autoStartMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Auto-Start", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let breaks = NSMenuItem(title: "Start Breaks", action: #selector(toggleAutoStartBreaks), keyEquivalent: "")
        breaks.target = self
        breaks.state = app.preferences.autoStartBreaks ? .on : .off
        sub.addItem(breaks)

        let focus = NSMenuItem(title: "Start Focus", action: #selector(toggleAutoStartFocus), keyEquivalent: "")
        focus.target = self
        focus.state = app.preferences.autoStartFocus ? .on : .off
        sub.addItem(focus)

        item.submenu = sub
        return item
    }

    @objc private func toggleAutoStartBreaks() {
        app.updatePreferences { $0.autoStartBreaks.toggle() }
    }

    @objc private func toggleAutoStartFocus() {
        app.updatePreferences { $0.autoStartFocus.toggle() }
    }
}
