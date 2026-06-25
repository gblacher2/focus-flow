import FocusFlowCore
import Testing
import Foundation

private let start = Date(timeIntervalSince1970: 1_000)

@Test func focusCompletionQueuesShortBreak() throws {
    var engine = TimerEngine(preferences: shortPreferences)

    engine.start(now: start, preferences: shortPreferences)
    let event = engine.tick(now: start.addingTimeInterval(60), preferences: shortPreferences)

    #expect(event == .phaseCompleted(CompletedPhase(
        phase: .focus,
        nextPhase: .shortBreak,
        title: "",
        tagID: nil,
        startedAt: start,
        endedAt: start.addingTimeInterval(60),
        plannedSeconds: 60,
        actualSeconds: 60,
        interruptionCount: 0
    )))
    #expect(engine.phase == .completed)
    #expect(engine.pendingPhase == .shortBreak)
    #expect(engine.focusSessionsCompletedInCycle == 1)
}

@Test func longBreakCadenceAfterConfiguredFocusCount() {
    var engine = TimerEngine(preferences: shortPreferences)

    engine.start(now: start, preferences: shortPreferences)
    _ = engine.tick(now: start.addingTimeInterval(60), preferences: shortPreferences)
    engine.start(now: start.addingTimeInterval(61), preferences: shortPreferences)
    _ = engine.tick(now: start.addingTimeInterval(91), preferences: shortPreferences)
    engine.start(now: start.addingTimeInterval(92), preferences: shortPreferences)
    let event = engine.tick(now: start.addingTimeInterval(152), preferences: shortPreferences)

    if case .phaseCompleted(let completed) = event {
        #expect(completed.phase == .focus)
        #expect(completed.nextPhase == .longBreak)
        #expect(engine.pendingPhase == .longBreak)
    } else {
        Issue.record("Expected a completed focus phase")
    }
}

@Test func pauseResumeKeepsRemainingTimeAndCountsInterruption() {
    var engine = TimerEngine(preferences: shortPreferences)

    engine.start(now: start, preferences: shortPreferences)
    engine.pause(now: start.addingTimeInterval(10))

    #expect(engine.phase == .paused)
    #expect(engine.remainingSeconds == 50)

    engine.start(now: start.addingTimeInterval(20), preferences: shortPreferences)
    #expect(engine.tick(now: start.addingTimeInterval(69), preferences: shortPreferences) == nil)

    let event = engine.tick(now: start.addingTimeInterval(70), preferences: shortPreferences)
    if case .phaseCompleted(let completed) = event {
        #expect(completed.interruptionCount == 1)
        #expect(completed.actualSeconds == 70)
    } else {
        Issue.record("Expected resumed focus to complete")
    }
}

@Test func skipRecordsSkippedPhaseAndQueuesNextPhase() {
    var engine = TimerEngine(preferences: shortPreferences)

    engine.start(now: start, preferences: shortPreferences)
    let event = engine.skip(now: start.addingTimeInterval(15), preferences: shortPreferences)

    if case .phaseSkipped(let skipped) = event {
        #expect(skipped.phase == .focus)
        #expect(skipped.actualSeconds == 15)
        #expect(engine.pendingPhase == .shortBreak)
    } else {
        Issue.record("Expected skipped phase")
    }
}

@Test func resetCycleReturnsToReadyFocusDuration() {
    var engine = TimerEngine(preferences: shortPreferences)

    engine.start(now: start, preferences: shortPreferences)
    _ = engine.tick(now: start.addingTimeInterval(60), preferences: shortPreferences)
    engine.resetCycle(preferences: shortPreferences)

    #expect(engine.phase == .ready)
    #expect(engine.pendingPhase == .focus)
    #expect(engine.remainingSeconds == 60)
    #expect(engine.focusSessionsCompletedInCycle == 0)
}

@Test func runtimeRestoreCanCompleteExpiredPhase() throws {
    var engine = TimerEngine(preferences: shortPreferences)
    engine.start(now: start, preferences: shortPreferences)

    let url = temporaryURL().appending(path: "runtime.json")
    let store = RuntimeStore(url: url)
    try store.save(engine)

    var restored = try store.load(preferences: shortPreferences)
    let event = restored.tick(now: start.addingTimeInterval(65), preferences: shortPreferences)

    if case .phaseCompleted(let completed) = event {
        #expect(completed.phase == .focus)
        #expect(restored.pendingPhase == .shortBreak)
    } else {
        Issue.record("Expected restored phase to complete")
    }
}

@Test func preferenceValidationClampsUnsafeValues() {
    let preferences = TimerPreferences(
        focusMinutes: -5,
        shortBreakMinutes: 0,
        longBreakMinutes: 999,
        sessionsBeforeLongBreak: 99
    )

    #expect(preferences.focusMinutes == 1)
    #expect(preferences.shortBreakMinutes == 1)
    #expect(preferences.longBreakMinutes == 240)
    #expect(preferences.sessionsBeforeLongBreak == 12)
}

private var shortPreferences: TimerPreferences {
    TimerPreferences(
        focusMinutes: 1,
        shortBreakMinutes: 1,
        longBreakMinutes: 2,
        sessionsBeforeLongBreak: 2,
        autoStartBreaks: false,
        autoStartFocus: false,
        notificationsEnabled: false,
        soundsEnabled: false
    )
}
