import FocusFlowCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: AppModel
    @State private var newTagTitle = ""
    @State private var newTagColor = "blue"
    @State private var duplicateMessage: String?

    var body: some View {
        TabView {
            timerSettings
                .tabItem { Label("Timer", systemImage: "timer") }

            feedbackSettings
                .tabItem { Label("Notifications", systemImage: "bell") }

            tagSettings
                .tabItem { Label("Tags", systemImage: "tag") }

            shortcutSettings
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .task {
            app.refreshLoginItemStatus()
            await app.refreshNotificationPermissionStatus()
        }
        .controlSize(.small)
        .frame(width: 460, height: 400)
    }

    // MARK: - Timer

    private var timerSettings: some View {
        Form {
            Section("Session Preset") {
                ForEach(SessionPreset.all) { preset in
                    Button {
                        app.applyPreset(preset)
                    } label: {
                        presetRow(preset)
                    }
                    .buttonStyle(.plain)
                }

                if app.activePreset == nil {
                    Label("Custom durations", systemImage: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Durations") {
                Stepper(value: preferenceBinding(\.focusMinutes), in: 1...240) {
                    SettingsRow("Focus", value: "\(app.preferences.focusMinutes) min")
                }

                Stepper(value: preferenceBinding(\.shortBreakMinutes), in: 1...120) {
                    SettingsRow("Short Break", value: "\(app.preferences.shortBreakMinutes) min")
                }

                Stepper(value: preferenceBinding(\.longBreakMinutes), in: 1...240) {
                    SettingsRow("Long Break", value: "\(app.preferences.longBreakMinutes) min")
                }

                Stepper(value: preferenceBinding(\.sessionsBeforeLongBreak), in: 1...12) {
                    SettingsRow("Sessions before long break", value: "\(app.preferences.sessionsBeforeLongBreak)")
                }

                Stepper(value: preferenceBinding(\.dailyGoalMinutes), in: 0...1440, step: 15) {
                    SettingsRow("Daily Goal", value: formatDailyGoal(app.preferences.dailyGoalMinutes))
                }
            }

            Section("Behavior") {
                Toggle("Launch FocusFlow at login", isOn: Binding(
                    get: { app.preferences.launchAtLogin },
                    set: { app.setLaunchAtLogin($0) }
                ))
                .disabled(app.loginItemStatus == .notFound)

                HStack {
                    Text(app.loginItemStatusDescription)
                        .font(.caption)
                        .foregroundStyle(app.loginItemStatusNeedsAttention ? .orange : .secondary)

                    Spacer()

                    if app.loginItemStatus == .requiresApproval {
                        Button("Open Login Items") {
                            app.openLoginItemsSettings()
                        }
                    }
                }

                if let loginError = app.loginItemErrorMessage {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Start breaks automatically", isOn: preferenceBinding(\.autoStartBreaks))
                Toggle("Start focus automatically", isOn: preferenceBinding(\.autoStartFocus))
                Toggle("Show timer window at launch", isOn: preferenceBinding(\.showWindowAtLaunch))
                Toggle("Show countdown in menu bar when not running", isOn: preferenceBinding(\.showCountdownWhenIdle))
                Toggle("Auto-pause when away", isOn: preferenceBinding(\.idlePauseEnabled))

                if app.preferences.idlePauseEnabled {
                    Stepper(value: preferenceBinding(\.idlePauseMinutes), in: 1...30) {
                        SettingsRow("Idle pause delay", value: "\(app.preferences.idlePauseMinutes) min")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .formBottomBreathingRoom()
    }

    // MARK: - Feedback

    private var feedbackSettings: some View {
        Form {
            Section("Phase Alerts") {
                LabeledContent("macOS permission") {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: notificationStatusIcon)
                            .font(.caption)
                            .foregroundStyle(notificationStatusColor)
                        Text(app.notificationPermissionStatus.displayName)
                    }
                }

                Toggle("Show notifications", isOn: preferenceBinding(\.notificationsEnabled))
                Toggle("Ask for focus quality", isOn: preferenceBinding(\.showSessionReview))

                Text(notificationExplanationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: Theme.Spacing.sm) {
                    if app.notificationPermissionStatus == .notDetermined {
                        Button("Request Permission") {
                            Task {
                                await app.requestNotificationPermission()
                            }
                        }
                    } else if app.notificationPermissionStatus == .denied {
                        Button("Open Notifications Settings") {
                            app.openNotificationSettings()
                        }
                    }

                    Button("Refresh Status") {
                        Task {
                            await app.refreshNotificationPermissionStatus()
                        }
                    }

                    Spacer()
                }
            }

            Section("Completion Sounds") {
                Toggle("Play sounds", isOn: preferenceBinding(\.soundsEnabled))

                HStack {
                    Picker("After focus", selection: preferenceBinding(\.focusCompleteSound)) {
                        ForEach(TimerSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    Button {
                        app.previewSound(app.preferences.focusCompleteSound)
                    } label: {
                        Image(systemName: "play.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Preview sound")
                }

                HStack {
                    Picker("After break", selection: preferenceBinding(\.breakCompleteSound)) {
                        ForEach(TimerSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    Button {
                        app.previewSound(app.preferences.breakCompleteSound)
                    } label: {
                        Image(systemName: "play.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Preview sound")
                }
            }
            .disabled(!app.preferences.soundsEnabled)
        }
        .formStyle(.grouped)
        .formBottomBreathingRoom()
    }

    // MARK: - Tags

    private var tagSettings: some View {
        VStack(spacing: 0) {
            // New tag row
            HStack(spacing: Theme.Spacing.sm) {
                TextField("New tag name", text: $newTagTitle)
                    .textFieldStyle(.roundedBorder)

                Picker(selection: $newTagColor) {
                    ForEach(TagPalette.names, id: \.self) { color in
                        HStack(spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(Color.tag(color))
                                .frame(width: 7, height: 7)
                            Text(color.capitalized)
                        }
                        .tag(color)
                    }
                } label: {
                    EmptyView()
                }
                .frame(width: 112)

                Button {
                    app.addTag(title: newTagTitle, colorName: newTagColor)
                    newTagTitle = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(newTagTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add tag")
            }
            .padding(Theme.Spacing.md)

            Divider()

            List {
                if app.tags.isEmpty {
                    ContentUnavailableView {
                        Label("No Tags", systemImage: "tag")
                    } description: {
                        Text("Add a tag to categorize your focus sessions.")
                    }
                } else {
                    ForEach(app.tags) { tag in
                        HStack(spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(Color.tag(tag.colorName))
                                .frame(width: 7, height: 7)
                            Text(tag.title)
                                .font(.body)
                            Spacer()
                            Button(role: .destructive) {
                                app.deleteTag(id: tag.id)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete \(tag.title)")
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Shortcuts

    private var shortcutSettings: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: shortcutStatusIcon)
                            .foregroundStyle(shortcutStatusColor)
                            .font(.caption)
                        Text(app.shortcutStatus.displayName)
                    }
                }

                if app.shortcutStatus == .localOnly {
                    Text("Global shortcuts require Accessibility access. Open System Settings → Privacy & Security → Accessibility and grant access to FocusFlow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Recheck Access") {
                        app.recheckShortcuts()
                    }
                }
            }

            Section("Key Bindings") {
                let def = TimerPreferences()
                shortcutRow(title: "Toggle Timer", keyPath: \.toggleShortcut, defaultSpec: def.toggleShortcut)
                shortcutRow(title: "Skip Phase", keyPath: \.skipShortcut, defaultSpec: def.skipShortcut)
                shortcutRow(title: "Reset Cycle", keyPath: \.resetShortcut, defaultSpec: def.resetShortcut)
                shortcutRow(title: "Show Timer", keyPath: \.showTimerShortcut, defaultSpec: def.showTimerShortcut)

                Button("Restore Defaults") {
                    app.updatePreferences { prefs in
                        prefs.toggleShortcut = def.toggleShortcut
                        prefs.skipShortcut = def.skipShortcut
                        prefs.resetShortcut = def.resetShortcut
                        prefs.showTimerShortcut = def.showTimerShortcut
                    }
                }
            }

            if let msg = duplicateMessage {
                Section {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
            }

            if app.shortcutStatus == .localOnly {
                Section {
                    Text("Shortcuts work while FocusFlow is focused. Grant Accessibility access for global shortcuts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .formBottomBreathingRoom()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func presetRow(_ preset: SessionPreset) -> some View {
        let isActive = app.activePreset?.id == preset.id

        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(preset.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(preset.durationSummary)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(preset.bestFor)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preset.name) preset, \(preset.durationSummary)")
        .accessibilityHint(preset.bestFor)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
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

    @ViewBuilder
    private func shortcutRow(title: String, keyPath: WritableKeyPath<TimerPreferences, ShortcutSpec>, defaultSpec: ShortcutSpec) -> some View {
        HStack {
            Text(title)
            Spacer()
            ShortcutRecorderView(
                title: title,
                spec: preferenceBinding(keyPath),
                defaultSpec: defaultSpec,
                onDuplicate: showDuplicateMessage,
                otherSpecs: otherShortcutSpecs(excluding: keyPath)
            )
            .frame(width: 140, height: 26)

            Button {
                assignShortcut(defaultSpec, to: keyPath)
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.plain)
            .help("Reset to default")
            .foregroundStyle(.secondary)
        }
    }

    private func otherShortcutSpecs(
        excluding keyPath: WritableKeyPath<TimerPreferences, ShortcutSpec>
    ) -> [ShortcutSpec] {
        let assignments: [(WritableKeyPath<TimerPreferences, ShortcutSpec>, ShortcutSpec)] = [
            (\TimerPreferences.toggleShortcut, app.preferences.toggleShortcut),
            (\TimerPreferences.skipShortcut, app.preferences.skipShortcut),
            (\TimerPreferences.resetShortcut, app.preferences.resetShortcut),
            (\TimerPreferences.showTimerShortcut, app.preferences.showTimerShortcut)
        ]
        return assignments
            .filter { $0.0 != keyPath }
            .map { $0.1 }
    }

    private func assignShortcut(
        _ candidate: ShortcutSpec,
        to keyPath: WritableKeyPath<TimerPreferences, ShortcutSpec>
    ) {
        if otherShortcutSpecs(excluding: keyPath).contains(where: { $0.conflicts(with: candidate) }) {
            showDuplicateMessage(candidate)
            return
        }
        app.updatePreferences { preferences in
            preferences[keyPath: keyPath] = candidate
        }
    }

    private func showDuplicateMessage(_ duplicateSpec: ShortcutSpec) {
        duplicateMessage = "Shortcut \(duplicateSpec.displayString) is already used."
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if duplicateMessage?.contains(duplicateSpec.displayString) == true {
                duplicateMessage = nil
            }
        }
    }

    private var shortcutStatusIcon: String {
        switch app.shortcutStatus {
        case .inactive: "circle"
        case .activeGlobal: "globe"
        case .localOnly: "exclamationmark.triangle"
        }
    }

    private var shortcutStatusColor: Color {
        switch app.shortcutStatus {
        case .inactive: .secondary
        case .activeGlobal: .green
        case .localOnly: .orange
        }
    }

    private var notificationStatusIcon: String {
        switch app.notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral:
            "checkmark.circle.fill"
        case .notDetermined:
            "questionmark.circle"
        case .denied:
            "xmark.octagon.fill"
        case .unknown:
            "exclamationmark.triangle.fill"
        }
    }

    private var notificationStatusColor: Color {
        switch app.notificationPermissionStatus {
        case .authorized:
            .green
        case .provisional, .ephemeral:
            .blue
        case .notDetermined:
            .secondary
        case .denied:
            .red
        case .unknown:
            .orange
        }
    }

    private var notificationExplanationText: String {
        if !app.preferences.notificationsEnabled {
            switch app.notificationPermissionStatus {
            case .denied:
                return "FocusFlow notifications are off, and macOS is also blocking FocusFlow. Turn notifications on in FocusFlow, then open Notifications Settings and allow alerts."
            case .authorized:
                return "FocusFlow notifications are off, so phase alerts will not appear even though macOS permission is already allowed."
            case .provisional, .ephemeral:
                return "FocusFlow notifications are off, so phase alerts will not appear even though macOS can still deliver them."
            case .notDetermined:
                return "FocusFlow notifications are off, so phase alerts will not appear. Turn this on to ask macOS for permission."
            case .unknown:
                return "FocusFlow notifications are off, so phase alerts will not appear."
            }
        }

        switch app.notificationPermissionStatus {
        case .authorized:
            return "macOS permission is granted, so phase alerts should appear when a phase completes."
        case .provisional:
            return "macOS is delivering alerts quietly. Phase alerts can still appear, but they may be grouped into Notification Center."
        case .ephemeral:
            return "Temporary notification access is active for this session."
        case .notDetermined:
            return "FocusFlow has not asked macOS for permission yet. Turn notifications on to prompt for access, or use Request Permission."
        case .denied:
            return "macOS is blocking FocusFlow notifications. Open Notifications Settings for FocusFlow and allow alerts."
        case .unknown:
            return "The current macOS notification permission could not be read."
        }
    }

    private func formatDailyGoal(_ minutes: Int) -> String {
        if minutes == 0 { return "Off" }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

private extension View {
    func formBottomBreathingRoom() -> some View {
        safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: Theme.Spacing.md)
        }
    }
}

private struct SettingsRow: View {
    var title: String
    var value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
