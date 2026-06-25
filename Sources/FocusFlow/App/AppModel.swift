import AppKit
import FocusFlowCore
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var engine: TimerEngine
    @Published private(set) var records: [SessionRecord]
    @Published private(set) var tags: [Tag]
    @Published var preferences: TimerPreferences
    @Published var sessionTitle: String
    @Published var selectedTagID: UUID?
    @Published var errorMessage: String?
    @Published private(set) var shortcutStatus: ShortcutService.Status = .inactive
    @Published private(set) var notificationPermissionStatus: NotificationPermissionStatus = .unknown

    private let sessionStore: SessionStore?
    private let runtimeStore: RuntimeStore?
    private let preferenceStore = PreferencesStore()
    private let notificationService = NotificationService()
    private let soundService = SoundService()
    private let shortcutService = ShortcutService()
    private var ticker: Foundation.Timer?

    init() {
        let loadedPreferences = preferenceStore.load()
        self.preferences = loadedPreferences
        self.sessionStore = try? SessionStore()
        self.runtimeStore = try? RuntimeStore()
        let loadedEngine = (try? runtimeStore?.load(preferences: loadedPreferences)) ?? TimerEngine(preferences: loadedPreferences)
        self.engine = loadedEngine
        self.records = sessionStore?.data.records ?? []
        self.tags = sessionStore?.data.tags ?? SessionStoreData.defaultTags
        self.sessionTitle = loadedEngine.title
        self.selectedTagID = loadedEngine.tagID

        refreshRecoveredTimer()
        syncTicker()
        Task { await refreshNotificationPermissionStatus() }
        configureShortcuts()
    }

    var menuBarTitle: String {
        DurationFormatter.clock(engine.remainingSeconds)
    }

    var selectedTag: Tag? {
        guard let selectedTagID else { return nil }
        return tags.first { $0.id == selectedTagID }
    }

    var menuBarSystemImage: String {
        switch engine.phase {
        case .ready: "circle"
        case .focus: "circle.fill"
        case .shortBreak, .longBreak: "cup.and.saucer.fill"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle"
        }
    }

    var primaryActionTitle: String {
        engine.isRunning ? "Pause" : "Start"
    }

    var primaryActionSystemImage: String {
        engine.isRunning ? "pause.fill" : "play.fill"
    }

    var statusLine: String {
        switch engine.phase {
        case .ready:
            "Ready"
        case .focus, .shortBreak, .longBreak:
            engine.displayPhase.displayName
        case .paused:
            "\(engine.displayPhase.displayName) · Paused"
        case .completed:
            "Next: \(engine.pendingPhase.displayName)"
        }
    }

    var progress: Double {
        guard engine.plannedSeconds > 0 else { return 0 }
        return 1 - (Double(engine.remainingSeconds) / Double(engine.plannedSeconds))
    }

    func toggleTimer() {
        objectWillChange.send()
        if engine.isRunning {
            engine.pause(now: Date())
        } else {
            engine.start(now: Date(), preferences: preferences)
        }
        persistRuntime()
        syncTicker()
    }

    func skip() {
        objectWillChange.send()
        if let event = engine.skip(now: Date(), preferences: preferences) {
            handle(event)
        }
        persistRuntime()
        syncTicker()
    }

    func previous() {
        objectWillChange.send()
        engine.previous(now: Date(), preferences: preferences)
        persistRuntime()
        syncTicker()
    }

    func resetCycle() {
        objectWillChange.send()
        engine.resetCycle(preferences: preferences)
        persistRuntime()
        syncTicker()
    }

    func setSessionTitle(_ title: String) {
        sessionTitle = title
        objectWillChange.send()
        engine.setTitle(title)
        persistRuntime()
    }

    func setSelectedTagID(_ id: UUID?) {
        selectedTagID = id
        objectWillChange.send()
        engine.setTagID(id)
        persistRuntime()
    }

    func updatePreferences(_ transform: (inout TimerPreferences) -> Void) {
        let notificationsWereEnabled = preferences.notificationsEnabled
        var next = preferences
        transform(&next)
        next.validate()
        preferences = next
        preferenceStore.save(next)
        objectWillChange.send()
        engine.applyPreferences(next, now: Date())
        Task {
            if !notificationsWereEnabled && next.notificationsEnabled {
                await requestNotificationPermission()
            } else {
                await refreshNotificationPermissionStatus()
            }
        }
        persistRuntime()
    }

    /// The built-in preset matching the current durations, or `nil` when custom.
    var activePreset: SessionPreset? {
        preferences.matchingPreset
    }

    /// Applies a session preset's durations and cycle length, persisting and
    /// live-updating the idle timer through the shared preferences path.
    func applyPreset(_ preset: SessionPreset) {
        updatePreferences { $0.apply(preset) }
    }

    func requestNotificationPermission() async {
        notificationPermissionStatus = await notificationService.requestAuthorization()
    }

    func refreshNotificationPermissionStatus() async {
        notificationPermissionStatus = await notificationService.authorizationStatus()
    }

    func openNotificationSettings() {
        notificationService.openSystemNotificationSettings()
    }

    func addTag(title: String, colorName: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try sessionStore?.upsertTag(Tag(title: trimmed, colorName: colorName))
            reloadSessionData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTag(id: UUID) {
        do {
            try sessionStore?.deleteTag(id: id)
            if selectedTagID == id {
                setSelectedTagID(nil)
            }
            reloadSessionData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRecord(id: UUID) {
        do {
            try sessionStore?.deleteRecord(id: id)
            reloadSessionData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetStatistics() {
        do {
            try sessionStore?.resetRecords()
            reloadSessionData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "FocusFlow Sessions.csv"
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.writeCSV(to: url)
            }
        }
    }

    func performShortcut(_ action: TimerShortcutAction) {
        switch action {
        case .toggleTimer:
            toggleTimer()
        case .skip:
            skip()
        case .reset:
            resetCycle()
        case .showTimer:
            showTimerWindowIfAvailable()
        }
    }

    /// Runs the per-second ticker only while a phase is actually counting down.
    /// When idle/paused/completed there is no timer, so the app does no per-second
    /// work — no CPU wakeups, no disk writes — and macOS can nap it.
    private func syncTicker() {
        if engine.isRunning {
            startTicker()
        } else {
            stopTicker()
        }
    }

    private func startTicker() {
        guard ticker == nil else { return }
        let timer = Foundation.Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        // Let macOS coalesce the wakeup with other timers to save energy, and use
        // .common mode so the countdown keeps updating while menus/sheets are open.
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard engine.isRunning else {
            stopTicker()
            return
        }
        // Redraw the countdown each second, but only touch the disk when the phase
        // actually transitions — remaining time is derived from the saved targetEnd,
        // so per-second persistence would be pure I/O for no recovery benefit.
        objectWillChange.send()
        if let event = engine.tick(now: Date(), preferences: preferences) {
            handle(event)
            persistRuntime()
            syncTicker()
        }
    }

    private func refreshRecoveredTimer() {
        objectWillChange.send()
        if let event = engine.tick(now: Date(), preferences: preferences) {
            handle(event)
        }
        persistRuntime()
    }

    private func handle(_ event: TimerEvent) {
        let completedPhase: CompletedPhase
        let completed: Bool

        switch event {
        case .phaseCompleted(let phase):
            completedPhase = phase
            completed = true
        case .phaseSkipped(let phase):
            completedPhase = phase
            completed = false
        }

        let record = SessionRecord(
            phase: completedPhase.phase,
            title: completedPhase.title,
            tagID: completedPhase.tagID,
            startedAt: completedPhase.startedAt,
            endedAt: completedPhase.endedAt,
            plannedSeconds: completedPhase.plannedSeconds,
            actualSeconds: completedPhase.actualSeconds,
            completed: completed,
            interruptionCount: completedPhase.interruptionCount
        )

        do {
            try sessionStore?.addRecord(record)
            reloadSessionData()
        } catch {
            errorMessage = error.localizedDescription
        }

        if completed {
            playCompletionFeedback(for: completedPhase.phase, nextPhase: completedPhase.nextPhase)
        }
    }

    private func playCompletionFeedback(for phase: TimerPhase, nextPhase: TimerPhase) {
        if preferences.soundsEnabled {
            soundService.play(phase == .focus ? preferences.focusCompleteSound : preferences.breakCompleteSound)
        }

        guard preferences.notificationsEnabled else { return }
        if phase == .focus {
            notificationService.notify(
                title: "Focus complete",
                body: "Next: \(nextPhase.displayName)",
                sound: preferences.focusCompleteSound
            )
        } else {
            notificationService.notify(
                title: "Break complete",
                body: "Ready for focus",
                sound: preferences.breakCompleteSound
            )
        }
    }

    private func configureShortcuts() {
        shortcutStatus = shortcutService.install { [weak self] action in
            Task { @MainActor in
                self?.performShortcut(action)
            }
        }
    }

    private func persistRuntime() {
        do {
            try runtimeStore?.save(engine)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadSessionData() {
        records = sessionStore?.data.records ?? []
        tags = sessionStore?.data.tags ?? []
    }

    private func writeCSV(to url: URL) {
        do {
            let csv = CSVExporter.export(records: records, tags: tags)
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showTimerWindowIfAvailable() {
        let app = NSApplication.shared
        if let timerWindow = app.windows.first(where: { $0.title == "FocusFlow" }) {
            if timerWindow.isMiniaturized {
                timerWindow.deminiaturize(nil)
            }
            timerWindow.makeKeyAndOrderFront(nil)
        }
        app.activate(ignoringOtherApps: true)
    }
}
