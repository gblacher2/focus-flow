import AppKit
import FocusFlowCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var app: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            statusHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            // Primary action
            Button {
                app.toggleTimer()
            } label: {
                Label(primaryLabel, systemImage: app.primaryActionSystemImage)
            }
            .keyboardShortcut(.space, modifiers: [.command, .option, .control])

            // Timer navigation
            Button("Skip Phase") {
                app.skip()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .control])

            Button("Previous Phase") {
                app.previous()
            }

            Button("Reset Cycle") {
                app.resetCycle()
            }
            .keyboardShortcut("r", modifiers: [.command, .option, .control])

            Divider()

            quickTimerSettings

            Divider()

            // Windows
            Button("Timer Window") {
                activate()
                openWindow(id: "timer")
            }
            .keyboardShortcut("f", modifiers: [.command, .option, .control])

            Button("Statistics") {
                activate()
                openWindow(id: "statistics")
            }

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }

            Divider()

            Button("Quit FocusFlow") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: app.menuBarSystemImage)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                Text(statusTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if app.engine.isRunning || app.engine.phase == .paused {
                    Text(DurationFormatter.clock(app.engine.remainingSeconds))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if !app.sessionTitle.isEmpty {
                Text(app.sessionTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let tag = app.selectedTag {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.tag(tag.colorName))
                        .frame(width: 7, height: 7)
                    Text(tag.title)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if app.engine.isRunning || app.engine.phase == .paused {
                // Micro progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                            .frame(height: 3)

                        Capsule()
                            .fill(statusColor)
                            .frame(width: max(2, geo.size.width * app.progress), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Quick Settings

    private var quickTimerSettings: some View {
        Group {
            Menu {
                ForEach([15, 20, 25, 30, 45, 50, 60, 90], id: \.self) { minutes in
                    presetButton(
                        "\(minutes) min",
                        isSelected: app.preferences.focusMinutes == minutes
                    ) {
                        app.updatePreferences { $0.focusMinutes = minutes }
                    }
                }
            } label: {
                Label("Focus Duration", systemImage: "timer")
            }

            Menu {
                Section("Short Break") {
                    ForEach([5, 10], id: \.self) { minutes in
                        presetButton(
                            "\(minutes) min",
                            isSelected: app.preferences.shortBreakMinutes == minutes
                        ) {
                            app.updatePreferences { $0.shortBreakMinutes = minutes }
                        }
                    }
                }

                Section("Long Break") {
                    ForEach([15, 20, 30], id: \.self) { minutes in
                        presetButton(
                            "\(minutes) min",
                            isSelected: app.preferences.longBreakMinutes == minutes
                        ) {
                            app.updatePreferences { $0.longBreakMinutes = minutes }
                        }
                    }
                }
            } label: {
                Label("Break Duration", systemImage: "cup.and.saucer")
            }

            Menu {
                ForEach(1...10, id: \.self) { count in
                    presetButton(
                        "\(count) \(count == 1 ? "session" : "sessions")",
                        isSelected: app.preferences.sessionsBeforeLongBreak == count
                    ) {
                        app.updatePreferences { $0.sessionsBeforeLongBreak = count }
                    }
                }
            } label: {
                Label("Long Break After", systemImage: "repeat")
            }

            Menu {
                Toggle("Start Breaks", isOn: preferenceBinding(\.autoStartBreaks))
                Toggle("Start Focus", isOn: preferenceBinding(\.autoStartFocus))
            } label: {
                Label("Auto-Start", systemImage: "play.circle")
            }
        }
    }

    // MARK: - Helpers

    private var primaryLabel: String {
        switch app.engine.phase {
        case .ready:
            "Start Focus"
        case .focus:
            "Pause Timer"
        case .shortBreak, .longBreak:
            "Pause Break"
        case .paused:
            "Resume"
        case .completed:
            "Start \(app.engine.pendingPhase.displayName)"
        }
    }

    private var statusTitle: String {
        switch app.engine.phase {
        case .ready:
            "Ready"
        case .focus:
            "Focusing"
        case .shortBreak:
            "Short Break"
        case .longBreak:
            "Long Break"
        case .paused:
            "\(app.engine.displayPhase.displayName) Paused"
        case .completed:
            "Phase Complete"
        }
    }

    private var statusColor: Color {
        Color.phase(app.engine.displayPhase)
    }

    private func presetButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Text(title)
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<TimerPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { app.preferences[keyPath: keyPath] },
            set: { value in
                app.updatePreferences { preferences in
                    preferences[keyPath: keyPath] = value
                }
            }
        )
    }

    private func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
