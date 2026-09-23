import AppKit
import ApplicationServices
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
    @Published var isOnboardingPresented = false
    @Published private(set) var loginItemStatus: LoginItemService.DisplayStatus = .notFound
    @Published private(set) var loginItemErrorMessage: String?
    @Published var pendingReviewRecordID: UUID?
    @Published private(set) var didAutoPauseForIdle = false

    /// Closures that open SwiftUI-managed windows. Wired lazily by
    /// `EnvironmentBridgeView` in AppDelegate.swift at launch. AppModel
    /// and StatusItemController can call these to open windows from
    /// non-SwiftUI code.
    var openTimerWindow: (() -> Void)?
    var openStatisticsWindow: (() -> Void)?
    var openSettingsWindow: (() -> Void)?

    /// The app's sole menu bar item. Created eagerly in `init()` so it
    /// exists immediately, even before any SwiftUI window opens.
    private(set) var statusItemController: StatusItemController?

    private let sessionStore: SessionStore?
    private let runtimeStore: RuntimeStore?
    private let preferenceStore = PreferencesStore()
    private let notificationService = NotificationService()
    private let soundService = SoundService()
    private let shortcutService = ShortcutService()
    private let loginItemService = LoginItemService()
    private let idleMonitorService = IdleMonitorService()
    private var ticker: Foundation.Timer?
    private var tickCount = 0
    private var didBecomeActiveTask: Task<Void, Never>?
    private var integrationBridge: IntegrationBridge?

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
        refreshLoginItemStatus()
        Task { await refreshNotificationPermissionStatus() }
        configureShortcuts()
        observeAppActivation()
        statusItemController = StatusItemController(app: self)

        // `NSApp.delegate as? AppDelegate` can never succeed under the SwiftUI
        // lifecycle — SwiftUI installs its own forwarding delegate — so the
        // adaptor-created instance is reached via AppDelegate.shared. That
        // instance does not exist yet while this @StateObject-owned model
        // initializes, so look it up on the next run-loop pass, once app
        // setup has completed. A wiring failure would silently leave the
        // window-opening closures unwired, so make it visible.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let delegate = AppDelegate.shared {
                delegate.attachIfNeeded(app: self)
            } else {
                AppDelegate.bridgeLog.fault("AppDelegate.shared is unset — environment bridge cannot attach")
            }
        }

        self.integrationBridge = IntegrationBridge(app: self)
    }

    deinit {
        didBecomeActiveTask?.cancel()
    }

    var menuBarTitle: String {
        DurationFormatter.clock(engine.remainingSeconds)
    }

    var todayGoalProgress: Double? {
        guard preferences.dailyGoalMinutes > 0 else { return nil }
        let goalSeconds = preferences.dailyGoalMinutes * 60
        let stats = ProgressCalculator.dailyFocusTotals(records: records)
        let today = Calendar.current.startOfDay(for: Date())
        let todaySeconds = stats[today] ?? 0
        return min(Double(todaySeconds) / Double(goalSeconds), 1.0)
    }

    var goalSummaryLine: String? {
        guard preferences.dailyGoalMinutes > 0 else { return nil }
        let goalSeconds = preferences.dailyGoalMinutes * 60
        let stats = ProgressCalculator.dailyFocusTotals(records: records)
        let today = Calendar.current.startOfDay(for: Date())
        let todaySeconds = stats[today] ?? 0
        let streak = ProgressCalculator.currentStreak(records: records, goalMinutes: preferences.dailyGoalMinutes, asOf: Date())

        let h = todaySeconds / 3600
        let m = (todaySeconds % 3600) / 60
        let todayStr = h > 0 ? "\(h)h \(m)m" : "\(m)m"

        let goalH = goalSeconds / 3600
        let goalM = (goalSeconds % 3600) / 60
        let goalStr = goalH > 0 && goalM > 0 ? "\(goalH)h \(goalM)m" : (goalH > 0 ? "\(goalH)h" : "\(goalM)m")

        if streak > 0 {
            return "Today: \(todayStr) of \(goalStr) · \(streak)-day streak"
        } else {
            return "Today: \(todayStr) of \(goalStr)"
        }
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

    /// The menu-bar icon while a phase is actively running: a single symbol
    /// whose fill grows with `progress` (0→1), replacing the static
    /// focus/break glyphs so the icon itself reflects live progress. Color
    /// still carries the focus-vs-break distinction via `Color.phase(_:)`.
    ///
    /// `progress.indicator` (SF Symbols 6 / macOS 15+) isn't available at
    /// this app's macOS 14 minimum deployment target, so `circle.dotted.circle`
    /// is used instead — it supports `variableValue` back to macOS 13.
    static let menuBarProgressSystemImage = "circle.dotted.circle"

    /// Icon name to render for the current state, plus the `variableValue`
    /// to apply (non-nil only while a phase is running).
    var menuBarIcon: (systemName: String, variableValue: Double?) {
        if engine.isRunning {
            return (Self.menuBarProgressSystemImage, progress)
        } else if engine.phase == .paused {
            // Paused state is more important than goal fill; the dropdown and
            // accessibility label still expose today's goal progress.
            return (menuBarSystemImage, nil)
        } else if let progress = todayGoalProgress {
            return (Self.menuBarProgressSystemImage, progress)
        } else {
            return (menuBarSystemImage, nil)
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

    /// Shows the countdown only while a phase is actively ticking down, unless
    /// the user explicitly opts into seeing it while the timer is not running.
    var showsMenuBarCountdown: Bool {
        engine.isRunning || preferences.showCountdownWhenIdle
    }

    func toggleTimer() {
        objectWillChange.send()
        clearIdlePauseState()
        pendingReviewRecordID = nil
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
        clearIdlePauseState()
        pendingReviewRecordID = nil
        if let event = engine.skip(now: Date(), preferences: preferences) {
            handle(event)
        }
        persistRuntime()
        syncTicker()
    }

    func previous() {
        objectWillChange.send()
        clearIdlePauseState()
        pendingReviewRecordID = nil
        engine.previous(now: Date(), preferences: preferences)
        persistRuntime()
        syncTicker()
    }

    func resetCycle() {
        objectWillChange.send()
        clearIdlePauseState()
        pendingReviewRecordID = nil
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
        let idlePauseWasEnabled = preferences.idlePauseEnabled
        let oldShortcuts = [
            preferences.toggleShortcut, preferences.skipShortcut,
            preferences.resetShortcut, preferences.showTimerShortcut
        ]
        var next = preferences
        transform(&next)
        next.validate()
        preferences = next
        preferenceStore.save(next)

        let newShortcuts = [
            next.toggleShortcut, next.skipShortcut,
            next.resetShortcut, next.showTimerShortcut
        ]
        if oldShortcuts != newShortcuts {
            recheckShortcuts()
        }
        if idlePauseWasEnabled && !next.idlePauseEnabled {
            clearIdlePauseState()
        }

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

    func completeOnboarding() {
        if !preferences.hasCompletedOnboarding {
            updatePreferences { $0.hasCompletedOnboarding = true }
        }
        isOnboardingPresented = false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        // Bundle is not in a location SMAppService can register. Silently
        // ignore the request — the toggle is disabled in the UI for this case.
        guard loginItemStatus != .notFound else { return }
        loginItemErrorMessage = nil
        do {
            try loginItemService.setEnabled(enabled)
            refreshLoginItemStatus()

            let reflectsRequestedState: Bool
            if enabled {
                reflectsRequestedState = loginItemStatus == .enabled
                    || loginItemStatus == .requiresApproval
            } else {
                reflectsRequestedState = loginItemStatus == .disabled
                    || loginItemStatus == .notFound
            }

            guard reflectsRequestedState else {
                let message = enabled
                    ? "FocusFlow could not register as a login item."
                    : "FocusFlow could not remove its login item."
                loginItemErrorMessage = message
                errorMessage = message
                return
            }

            updatePreferences { $0.launchAtLogin = enabled }
        } catch {
            loginItemErrorMessage = error.localizedDescription
            errorMessage = error.localizedDescription
        }
        refreshLoginItemStatus()
    }

    func openLoginItemsSettings() {
        loginItemService.openLoginItemsSettings()
    }

    func refreshLoginItemStatus() {
        loginItemStatus = loginItemService.status
    }

    var loginItemStatusDescription: String {
        switch loginItemStatus {
        case .enabled:
            "Enabled in System Settings"
        case .disabled:
            preferences.launchAtLogin
                ? "Disabled in System Settings; your preference is still on"
                : "Off"
        case .requiresApproval:
            "Needs approval in System Settings → General → Login Items"
        case .notFound:
            "Move FocusFlow to /Applications to enable launch at login."
        }
    }

    var loginItemStatusNeedsAttention: Bool {
        loginItemStatus == .requiresApproval
            || (loginItemStatus == .disabled && preferences.launchAtLogin)
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

    /// The status item's secondary click should immediately toggle the timer
    /// (pause if running, or resume/start if idle/paused).
    @discardableResult
    func performStatusItemSecondaryAction() -> Bool {
        toggleTimer()
        return true
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
        let now = Date()
        if let event = engine.tick(now: now, preferences: preferences) {
            handle(event)
            persistRuntime()
            syncTicker()
            return
        }

        // Completion above must win if the target end has already passed. Only
        // a still-running focus may be converted into an idle pause.
        tickCount += 1
        if preferences.idlePauseEnabled, engine.phase == .focus, tickCount % 5 == 0 {
            let idleSeconds = idleMonitorService.secondsSinceLastInput()
            if idleSeconds >= Double(preferences.idlePauseMinutes * 60) {
                autoPauseForIdle(idleSeconds: idleSeconds)
            }
        }
    }

    private func autoPauseForIdle(idleSeconds: TimeInterval) {
        objectWillChange.send()
        let now = Date()
        let backdated = now.addingTimeInterval(-idleSeconds)
        let start = engine.startedAt ?? Date.distantPast
        let clampedPause = max(backdated, start)

        engine.pause(now: clampedPause)
        didAutoPauseForIdle = true
        persistRuntime()
        syncTicker()

        idleMonitorService.startReturnPoll { [weak self] in
            guard let self = self else { return }
            self.didAutoPauseForIdle = false
            if self.preferences.notificationsEnabled {
                self.notificationService.notify(title: "Paused while you were away", body: "Resume when you're ready.")
            }
        }
    }

    private func refreshRecoveredTimer() {
        objectWillChange.send()
        if let event = engine.tick(now: Date(), preferences: preferences) {
            // If the phase actually finished while the app was quit (possibly hours
            // ago, e.g. at login), suppress the completion sound/notification for a
            // stale event — but still record the session below via handle().
            let staleThreshold: TimeInterval = 120
            let endedAt: Date
            switch event {
            case .phaseCompleted(let phase), .phaseSkipped(let phase):
                endedAt = phase.endedAt
            }
            let isStale = Date().timeIntervalSince(endedAt) > staleThreshold
            handle(event, playFeedback: !isStale)
        }
        persistRuntime()
    }

    private func handle(_ event: TimerEvent, playFeedback: Bool = true) {
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
            id: UUID(),
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

        var recordWasSaved = false
        do {
            guard let sessionStore else {
                throw SessionStoreError.storeUnavailable
            }
            try sessionStore.addRecord(record)
            recordWasSaved = true
            reloadSessionData()
        } catch {
            errorMessage = error.localizedDescription
        }

        if completed && playFeedback {
            if recordWasSaved, completedPhase.phase == .focus, preferences.showSessionReview {
                pendingReviewRecordID = record.id
            }
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
                body: "Next: \(nextPhase.displayName)"
            )
        } else {
            notificationService.notify(
                title: "Break complete",
                body: "Ready for focus"
            )
        }
    }

    func previewSound(_ sound: TimerSound) {
        soundService.play(sound)
    }

    private func configureShortcuts() {
        let specs: [TimerShortcutAction: ShortcutSpec] = [
            .toggleTimer: preferences.toggleShortcut,
            .skip: preferences.skipShortcut,
            .reset: preferences.resetShortcut,
            .showTimer: preferences.showTimerShortcut
        ]
        shortcutStatus = shortcutService.install(specs: specs) { [weak self] action in
            Task { @MainActor in
                self?.performShortcut(action)
            }
        }
    }

    /// Re-runs shortcut installation. Safe to call any time — `ShortcutService.install`
    /// always calls `stop()` first, so this never leaves duplicate monitors installed.
    /// Exposed so Settings can offer a manual "Recheck Access" action, and so we can
    /// upgrade from `.localOnly` to `.activeGlobal` automatically once the user grants
    /// Accessibility access without requiring a relaunch.
    func recheckShortcuts() {
        configureShortcuts()
    }

    /// Accessibility access can be granted while the app is already running (System
    /// Settings → Privacy & Security → Accessibility). Global shortcuts installed at
    /// launch stay dead until shortcuts are reconfigured, so re-check whenever the app
    /// becomes active again and status is currently local-only.
    private func observeAppActivation() {
        didBecomeActiveTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification)
            for await _ in notifications {
                guard let self else { return }
                if self.shortcutStatus == .localOnly && AXIsProcessTrusted() {
                    self.recheckShortcuts()
                }
                self.refreshLoginItemStatus()
            }
        }
    }

    private func persistRuntime() {
        do {
            try runtimeStore?.save(engine)
            integrationBridge?.postStateChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadSessionData() {
        records = sessionStore?.data.records ?? []
        tags = sessionStore?.data.tags ?? []
    }

    func setFocusQuality(_ quality: Int) {
        guard let id = pendingReviewRecordID else { return }
        do {
            guard let sessionStore else {
                throw SessionStoreError.storeUnavailable
            }
            try sessionStore.updateRecordQuality(id: id, quality: quality)
            reloadSessionData()
            pendingReviewRecordID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissReview() {
        pendingReviewRecordID = nil
    }

    private func clearIdlePauseState() {
        idleMonitorService.stopReturnPoll()
        didAutoPauseForIdle = false
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
        } else {
            // The window was closed (not just miniaturized), so no matching NSWindow
            // exists to bring forward. Ask the SwiftUI environment to open it again.
            openTimerWindow?()
        }
        app.activate(ignoringOtherApps: true)
    }
}
