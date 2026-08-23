import Foundation

public enum TimerEvent: Equatable, Sendable {
    case phaseCompleted(CompletedPhase)
    case phaseSkipped(CompletedPhase)
}

public struct CompletedPhase: Codable, Equatable, Sendable {
    public var phase: TimerPhase
    public var nextPhase: TimerPhase
    public var title: String
    public var tagID: UUID?
    public var startedAt: Date
    public var endedAt: Date
    public var plannedSeconds: Int
    public var actualSeconds: Int
    public var interruptionCount: Int

    public init(
        phase: TimerPhase,
        nextPhase: TimerPhase,
        title: String,
        tagID: UUID?,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        actualSeconds: Int,
        interruptionCount: Int
    ) {
        self.phase = phase
        self.nextPhase = nextPhase
        self.title = title
        self.tagID = tagID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.interruptionCount = interruptionCount
    }
}

public struct TimerEngine: Codable, Equatable, Sendable {
    public private(set) var phase: TimerPhase
    public private(set) var activePhase: TimerPhase
    public private(set) var pendingPhase: TimerPhase
    public private(set) var remainingSeconds: Int
    public private(set) var plannedSeconds: Int
    public private(set) var focusSessionsCompletedInCycle: Int
    public private(set) var title: String
    public private(set) var tagID: UUID?
    public private(set) var startedAt: Date?
    public private(set) var targetEnd: Date?
    public private(set) var interruptionCount: Int

    public init(preferences: TimerPreferences = TimerPreferences()) {
        let preferences = preferences.validated()
        self.phase = .ready
        self.activePhase = .focus
        self.pendingPhase = .focus
        self.remainingSeconds = preferences.focusSeconds
        self.plannedSeconds = preferences.focusSeconds
        self.focusSessionsCompletedInCycle = 0
        self.title = ""
        self.tagID = nil
        self.startedAt = nil
        self.targetEnd = nil
        self.interruptionCount = 0
    }

    public var isRunning: Bool {
        phase.isRunningPhase
    }

    public var displayPhase: TimerPhase {
        phase == .paused || phase == .completed ? activePhase : phase
    }

    public mutating func setTitle(_ title: String) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func setTagID(_ tagID: UUID?) {
        self.tagID = tagID
    }

    public mutating func start(now: Date, preferences: TimerPreferences) {
        let preferences = preferences.validated()
        switch phase {
        case .ready:
            begin(.focus, now: now, preferences: preferences)
        case .paused:
            phase = activePhase
            targetEnd = now.addingTimeInterval(TimeInterval(remainingSeconds))
        case .completed:
            begin(pendingPhase, now: now, preferences: preferences)
        case .focus, .shortBreak, .longBreak:
            break
        }
    }

    public mutating func pause(now: Date) {
        guard phase.isRunningPhase else { return }
        remainingSeconds = max(0, Int(ceil((targetEnd ?? now).timeIntervalSince(now))))
        activePhase = phase
        phase = .paused
        targetEnd = nil
        if activePhase == .focus {
            interruptionCount += 1
        }
    }

    public mutating func tick(now: Date, preferences: TimerPreferences) -> TimerEvent? {
        guard phase.isRunningPhase, let targetEnd else { return nil }
        remainingSeconds = max(0, Int(ceil(targetEnd.timeIntervalSince(now))))
        guard now >= targetEnd else { return nil }
        let completed = completeCurrentPhase(now: targetEnd, preferences: preferences.validated())
        return .phaseCompleted(completed)
    }

    public mutating func skip(now: Date, preferences: TimerPreferences) -> TimerEvent? {
        guard phase.isRunningPhase || phase == .paused || phase == .completed else {
            begin(.focus, now: now, preferences: preferences.validated())
            return nil
        }

        if phase == .completed {
            begin(pendingPhase, now: now, preferences: preferences.validated())
            return nil
        }

        if phase == .paused {
            phase = activePhase
        }

        let skipped = completeCurrentPhase(now: now, preferences: preferences.validated())
        return .phaseSkipped(skipped)
    }

    public mutating func previous(now: Date, preferences: TimerPreferences) {
        let preferences = preferences.validated()
        switch displayPhase {
        case .focus:
            begin(.focus, now: now, preferences: preferences)
        case .shortBreak, .longBreak:
            focusSessionsCompletedInCycle = max(0, focusSessionsCompletedInCycle - 1)
            begin(.focus, now: now, preferences: preferences)
        case .ready, .paused, .completed:
            begin(.focus, now: now, preferences: preferences)
        }
    }

    public mutating func resetCycle(preferences: TimerPreferences) {
        let preferences = preferences.validated()
        phase = .ready
        activePhase = .focus
        pendingPhase = .focus
        remainingSeconds = preferences.focusSeconds
        plannedSeconds = preferences.focusSeconds
        focusSessionsCompletedInCycle = 0
        startedAt = nil
        targetEnd = nil
        interruptionCount = 0
    }

    public mutating func applyPreferences(_ preferences: TimerPreferences, now: Date) {
        let preferences = preferences.validated()
        // A paused phase owns a credited remaining duration. Unrelated settings
        // edits (or even duration edits) apply to the next phase, not retroactively.
        guard !phase.isRunningPhase, phase != .paused else { return }
        let next = phase == .completed ? pendingPhase : displayPhase
        remainingSeconds = duration(for: next, preferences: preferences)
        plannedSeconds = remainingSeconds
    }

    private mutating func begin(_ newPhase: TimerPhase, now: Date, preferences: TimerPreferences) {
        let runningPhase = newPhase.isRunningPhase ? newPhase : .focus
        activePhase = runningPhase
        phase = runningPhase
        pendingPhase = runningPhase
        plannedSeconds = duration(for: runningPhase, preferences: preferences)
        remainingSeconds = plannedSeconds
        startedAt = now
        targetEnd = now.addingTimeInterval(TimeInterval(plannedSeconds))
        interruptionCount = 0
    }

    private mutating func completeCurrentPhase(now: Date, preferences: TimerPreferences) -> CompletedPhase {
        let completedPhase = displayPhase
        let startDate = startedAt ?? now.addingTimeInterval(-TimeInterval(plannedSeconds))
        let actualSeconds = max(0, Int(now.timeIntervalSince(startDate)))
        let next = nextPhase(after: completedPhase, preferences: preferences)
        let completed = CompletedPhase(
            phase: completedPhase,
            nextPhase: next,
            title: title,
            tagID: tagID,
            startedAt: startDate,
            endedAt: now,
            plannedSeconds: plannedSeconds,
            actualSeconds: actualSeconds,
            interruptionCount: interruptionCount
        )

        if completedPhase == .focus {
            focusSessionsCompletedInCycle += 1
        }

        activePhase = next
        pendingPhase = next
        plannedSeconds = duration(for: next, preferences: preferences)
        remainingSeconds = plannedSeconds
        startedAt = nil
        targetEnd = nil
        interruptionCount = 0

        if (completedPhase == .focus && preferences.autoStartBreaks) ||
            (completedPhase.isBreak && preferences.autoStartFocus) {
            begin(next, now: now, preferences: preferences)
        } else {
            phase = .completed
        }

        return completed
    }

    private func nextPhase(after phase: TimerPhase, preferences: TimerPreferences) -> TimerPhase {
        switch phase {
        case .focus:
            let completed = focusSessionsCompletedInCycle + 1
            return completed.isMultiple(of: preferences.sessionsBeforeLongBreak) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak, .ready, .paused, .completed:
            return .focus
        }
    }

    private func duration(for phase: TimerPhase, preferences: TimerPreferences) -> Int {
        switch phase {
        case .focus, .ready, .paused, .completed:
            preferences.focusSeconds
        case .shortBreak:
            preferences.shortBreakSeconds
        case .longBreak:
            preferences.longBreakSeconds
        }
    }
}
