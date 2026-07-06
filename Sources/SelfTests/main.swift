// SelfTests
//
// A plain-Swift, in-process replacement for `swift test`, which silently
// no-ops on this machine (Command Line Tools only, no XCTest runner — see
// CLAUDE.md). This target ports the meaningful assertions from
// Tests/FocusFlowTests/*.swift into a runnable `main.swift` so regressions
// in FocusFlowCore's state-machine and calculator logic actually get caught.
//
// Run with: swift run SelfTests

import FocusFlowCore
import Foundation

// MARK: - Minimal assertion helper

final class TestRunner {
    private(set) var passCount = 0
    private(set) var failCount = 0
    private var currentGroup = ""

    func group(_ name: String, _ body: () -> Void) {
        currentGroup = name
        print("\n== \(name) ==")
        body()
    }

    func check(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #fileID, line: Int = #line) {
        if condition() {
            passCount += 1
            print("  PASS: \(message)")
        } else {
            failCount += 1
            print("  FAIL: \(message) (\(file):\(line))")
        }
    }

    func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #fileID, line: Int = #line) {
        check(actual == expected, "\(message) — expected \(expected), got \(actual)", file: file, line: line)
    }

    func expectThrows(_ message: String, _ body: () throws -> Void, file: String = #fileID, line: Int = #line) {
        do {
            try body()
            check(false, "\(message) (expected throw, none occurred)", file: file, line: line)
        } catch {
            check(true, message, file: file, line: line)
        }
    }

    func expectNoThrow(_ message: String, _ body: () throws -> Void, file: String = #fileID, line: Int = #line) {
        do {
            try body()
            check(true, message, file: file, line: line)
        } catch {
            check(false, "\(message) (unexpected throw: \(error))", file: file, line: line)
        }
    }

    func summarize() -> Int32 {
        print("\n== Summary ==")
        print("  \(passCount) passed, \(failCount) failed")
        return failCount == 0 ? 0 : 1
    }
}

let t = TestRunner()

// MARK: - Temp directory helper (mirrors Tests/FocusFlowTests/TestSupport.swift)

func temporaryURL() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

// MARK: - SessionPreset tests

t.group("SessionPreset") {
    let presets = SessionPreset.all
    t.checkEqual(presets.map(\.id), ["classic", "deepWork", "flow"], "built-in presets are distinct and ordered")
    t.checkEqual(Set(presets.map(\.id)).count, presets.count, "preset ids are unique")

    for preset in SessionPreset.all {
        var prefs = TimerPreferences()
        prefs.apply(preset)
        t.checkEqual(prefs.focusMinutes, preset.focusMinutes, "\(preset.id): focusMinutes applied")
        t.checkEqual(prefs.shortBreakMinutes, preset.shortBreakMinutes, "\(preset.id): shortBreakMinutes applied")
        t.checkEqual(prefs.longBreakMinutes, preset.longBreakMinutes, "\(preset.id): longBreakMinutes applied")
        t.checkEqual(prefs.sessionsBeforeLongBreak, preset.sessionsBeforeLongBreak, "\(preset.id): sessionsBeforeLongBreak applied")
        t.checkEqual(prefs.matchingPreset?.id, preset.id, "\(preset.id): matchingPreset round-trips")
    }

    t.checkEqual(TimerPreferences().matchingPreset?.id, "classic", "default preferences match classic preset")

    let flow = SessionPreset.all.first { $0.id == "flow" }
    t.checkEqual(flow?.focusMinutes, 90, "flow preset focus is 90 minutes")
    t.checkEqual(flow?.shortBreakMinutes, 20, "flow preset short break is 20 minutes")

    var custom = TimerPreferences()
    custom.apply(SessionPreset.all[1]) // Deep Work
    custom.focusMinutes = 47 // off-preset fine-tune
    t.check(custom.matchingPreset == nil, "custom durations have no matching preset")

    let classic = SessionPreset.all[0]
    t.checkEqual(classic.durationSummary, "25 / 5 min", "preset duration summary reads focus over break")
}

// MARK: - TimerPreferences decoding tests

t.group("TimerPreferences decoding") {
    // Backward compatibility: JSON persisted before `showWindowAtLaunch`
    // existed must still decode — a missing key should default to false
    // not throw (which would send PreferencesStore.load() down its
    // all-defaults fallback and silently wipe the user's real settings).
    let oldShapeJSON = """
    {
        "focusMinutes": 42,
        "shortBreakMinutes": 7,
        "longBreakMinutes": 20,
        "sessionsBeforeLongBreak": 3,
        "autoStartBreaks": true,
        "autoStartFocus": false,
        "notificationsEnabled": false,
        "soundsEnabled": true,
        "focusCompleteSound": "Hero",
        "breakCompleteSound": "Pop"
    }
    """.data(using: .utf8)!

    do {
        let decoded = try JSONDecoder().decode(TimerPreferences.self, from: oldShapeJSON)
        t.checkEqual(decoded.focusMinutes, 42, "old-shape JSON preserves focusMinutes")
        t.checkEqual(decoded.shortBreakMinutes, 7, "old-shape JSON preserves shortBreakMinutes")
        t.checkEqual(decoded.longBreakMinutes, 20, "old-shape JSON preserves longBreakMinutes")
        t.checkEqual(decoded.sessionsBeforeLongBreak, 3, "old-shape JSON preserves sessionsBeforeLongBreak")
        t.checkEqual(decoded.autoStartBreaks, true, "old-shape JSON preserves autoStartBreaks")
        t.checkEqual(decoded.autoStartFocus, false, "old-shape JSON preserves autoStartFocus")
        t.checkEqual(decoded.notificationsEnabled, false, "old-shape JSON preserves notificationsEnabled")
        t.checkEqual(decoded.soundsEnabled, true, "old-shape JSON preserves soundsEnabled")
        t.checkEqual(decoded.focusCompleteSound, .hero, "old-shape JSON preserves focusCompleteSound")
        t.checkEqual(decoded.breakCompleteSound, .pop, "old-shape JSON preserves breakCompleteSound")
        t.checkEqual(decoded.showWindowAtLaunch, false, "old-shape JSON defaults showWindowAtLaunch to false")
    } catch {
        t.check(false, "decoding old-shape JSON threw: \(error)")
    }

}

// MARK: - SessionStore tests

func sampleRecord(
    phase: TimerPhase = .focus,
    title: String = "Session",
    tagID: UUID? = nil,
    startedAt: Date = Date(timeIntervalSince1970: 1_000),
    actualSeconds: Int = 1_500,
    completed: Bool = true
) -> SessionRecord {
    SessionRecord(
        phase: phase,
        title: title,
        tagID: tagID,
        startedAt: startedAt,
        endedAt: startedAt.addingTimeInterval(TimeInterval(actualSeconds)),
        plannedSeconds: actualSeconds,
        actualSeconds: actualSeconds,
        completed: completed,
        interruptionCount: 0
    )
}

t.group("SessionStore") {
    do {
        let url = temporaryURL().appending(path: "sessions.json")
        let store = try SessionStore(url: url)
        let tag = Tag(title: "Deep Work", colorName: "blue")
        let record = sampleRecord(tagID: tag.id)

        try store.upsertTag(tag)
        try store.addRecord(record)

        let reloaded = try SessionStore(url: url)
        t.check(reloaded.data.tags.contains(tag), "persisted tag round-trips through reload")
        t.check(reloaded.data.records.contains(record), "persisted record round-trips through reload")
    } catch {
        t.check(false, "storePersistsRecordsAndTags threw: \(error)")
    }

    do {
        let url = temporaryURL().appending(path: "sessions.json")
        let store = try SessionStore(url: url)
        let tag = Tag(title: "Study", colorName: "green")

        try store.upsertTag(tag)
        try store.addRecord(sampleRecord(tagID: tag.id))
        try store.deleteTag(id: tag.id)

        t.check(!store.data.tags.contains(tag), "deleting tag removes it from store")
        t.check(store.data.records.first?.tagID == nil, "deleting tag clears record assignment")
    } catch {
        t.check(false, "deletingTagClearsRecordAssignments threw: \(error)")
    }

    let tag = Tag(title: "Study, CFA", colorName: "green")
    let record = sampleRecord(title: "Read \"Ethics\"", tagID: tag.id)
    let csv = CSVExporter.export(records: [record], tags: [tag])
    t.check(csv.contains("\"Read \"\"Ethics\"\"\""), "CSV exporter escapes embedded quotes")
    t.check(csv.contains("\"Study, CFA\""), "CSV exporter quotes fields with commas")
}

// MARK: - StatisticsCalculator tests

func statsRecord(startedAt: Date) -> SessionRecord {
    SessionRecord(
        phase: .focus,
        title: "Session",
        tagID: nil,
        startedAt: startedAt,
        endedAt: startedAt.addingTimeInterval(1_500),
        plannedSeconds: 1_500,
        actualSeconds: 1_500,
        completed: true,
        interruptionCount: 0
    )
}

t.group("StatisticsCalculator") {
    let now = Date(timeIntervalSince1970: 2_000)
    let records = [
        sampleRecord(startedAt: now, actualSeconds: 1_500, completed: true),
        sampleRecord(phase: .shortBreak, startedAt: now, actualSeconds: 300, completed: true),
        sampleRecord(startedAt: now, actualSeconds: 100, completed: false)
    ]

    let filtered = StatisticsCalculator.records(
        from: records,
        period: .day,
        tagID: nil,
        showIncomplete: false,
        now: now
    )
    let summary = StatisticsCalculator.summary(for: filtered)

    t.checkEqual(filtered.count, 2, "filtering excludes incomplete records")
    t.checkEqual(summary.completedFocusCount, 1, "summary counts completed focus sessions")
    t.checkEqual(summary.completedBreakCount, 1, "summary counts completed break sessions")
    t.checkEqual(summary.totalFocusSeconds, 1_500, "summary sums focus seconds")
    t.checkEqual(summary.totalBreakSeconds, 300, "summary sums break seconds")

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let day1 = Date(timeIntervalSince1970: 1_000_000)
    let day2 = day1.addingTimeInterval(60 * 60 * 24 * 3)

    let groupedInput = [
        statsRecord(startedAt: day2.addingTimeInterval(7_200)),
        statsRecord(startedAt: day2),
        statsRecord(startedAt: day1)
    ]
    let groups = StatisticsCalculator.grouped(records: groupedInput, calendar: calendar)

    t.checkEqual(groups.count, 2, "grouped buckets records into two days")
    t.checkEqual(groups[0].day, calendar.startOfDay(for: day2), "most recent day bucket comes first")
    t.checkEqual(groups[1].day, calendar.startOfDay(for: day1), "older day bucket comes second")
    t.checkEqual(groups[0].records.count, 2, "recent bucket holds both same-day records")
    t.checkEqual(groups[0].records.first?.startedAt, day2.addingTimeInterval(7_200), "input order preserved within bucket")
    t.checkEqual(groups[1].records.count, 1, "older bucket holds single record")

    t.check(StatisticsCalculator.grouped(records: []).isEmpty, "grouped returns empty for no records")
}

// MARK: - TimerEngine tests

let shortPreferences = TimerPreferences(
    focusMinutes: 1,
    shortBreakMinutes: 1,
    longBreakMinutes: 2,
    sessionsBeforeLongBreak: 2,
    autoStartBreaks: false,
    autoStartFocus: false,
    notificationsEnabled: false,
    soundsEnabled: false
)

let engineStart = Date(timeIntervalSince1970: 1_000)

t.group("TimerEngine") {
    // focusCompletionQueuesShortBreak
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)
        let event = engine.tick(now: engineStart.addingTimeInterval(60), preferences: shortPreferences)

        let expected = TimerEvent.phaseCompleted(CompletedPhase(
            phase: .focus,
            nextPhase: .shortBreak,
            title: "",
            tagID: nil,
            startedAt: engineStart,
            endedAt: engineStart.addingTimeInterval(60),
            plannedSeconds: 60,
            actualSeconds: 60,
            interruptionCount: 0
        ))
        t.checkEqual(event, expected, "focus completion produces expected phaseCompleted event")
        t.checkEqual(engine.phase, .completed, "engine phase is .completed after focus tick expiry")
        t.checkEqual(engine.pendingPhase, .shortBreak, "pending phase queues short break")
        t.checkEqual(engine.focusSessionsCompletedInCycle, 1, "focus session count increments")
    }

    // longBreakCadenceAfterConfiguredFocusCount
    //
    // NOTE: the equivalent XCTest (Tests/FocusFlowTests/TimerEngineTests.swift,
    // longBreakCadenceAfterConfiguredFocusCount) uses tick offsets of 91s/152s
    // for the short-break and second-focus phases, but shortBreakMinutes is 1
    // (60s) in `shortPreferences`, so the short break (started at 61s) doesn't
    // target-expire until 121s — a tick at 91s is a no-op. That timing bug in
    // the never-actually-run XCTest suite was caught by running this port; the
    // offsets below (121s short-break end, 182s second-focus end) are the
    // correct values for the configured durations.
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)
        _ = engine.tick(now: engineStart.addingTimeInterval(60), preferences: shortPreferences)
        engine.start(now: engineStart.addingTimeInterval(61), preferences: shortPreferences)
        _ = engine.tick(now: engineStart.addingTimeInterval(121), preferences: shortPreferences)
        engine.start(now: engineStart.addingTimeInterval(122), preferences: shortPreferences)
        let event = engine.tick(now: engineStart.addingTimeInterval(182), preferences: shortPreferences)

        if case .phaseCompleted(let completed) = event {
            t.checkEqual(completed.phase, .focus, "long break cadence: completed phase is focus")
            t.checkEqual(completed.nextPhase, .longBreak, "long break cadence: next phase is long break")
            t.checkEqual(engine.pendingPhase, .longBreak, "long break cadence: engine pending phase is long break")
        } else {
            t.check(false, "expected a completed focus phase for long break cadence")
        }
    }

    // pauseResumeKeepsRemainingTimeAndCountsInterruption
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)
        engine.pause(now: engineStart.addingTimeInterval(10))

        t.checkEqual(engine.phase, .paused, "engine pauses correctly")
        t.checkEqual(engine.remainingSeconds, 50, "remaining time preserved across pause")

        engine.start(now: engineStart.addingTimeInterval(20), preferences: shortPreferences)
        t.check(engine.tick(now: engineStart.addingTimeInterval(69), preferences: shortPreferences) == nil, "tick before expiry yields no event")

        let event = engine.tick(now: engineStart.addingTimeInterval(70), preferences: shortPreferences)
        if case .phaseCompleted(let completed) = event {
            t.checkEqual(completed.interruptionCount, 1, "resume after pause counts one interruption")
            t.checkEqual(completed.actualSeconds, 70, "actual seconds accounts for paused gap")
        } else {
            t.check(false, "expected resumed focus to complete")
        }
    }

    // skipRecordsSkippedPhaseAndQueuesNextPhase
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)
        let event = engine.skip(now: engineStart.addingTimeInterval(15), preferences: shortPreferences)

        if case .phaseSkipped(let skipped) = event {
            t.checkEqual(skipped.phase, .focus, "skip records the skipped phase as focus")
            t.checkEqual(skipped.actualSeconds, 15, "skip records elapsed seconds")
            t.checkEqual(engine.pendingPhase, .shortBreak, "skip queues short break as next phase")
        } else {
            t.check(false, "expected skipped phase event")
        }
    }

    // resetCycleReturnsToReadyFocusDuration
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)
        _ = engine.tick(now: engineStart.addingTimeInterval(60), preferences: shortPreferences)
        engine.resetCycle(preferences: shortPreferences)

        t.checkEqual(engine.phase, .ready, "reset cycle returns engine to ready")
        t.checkEqual(engine.pendingPhase, .focus, "reset cycle queues focus as pending phase")
        t.checkEqual(engine.remainingSeconds, 60, "reset cycle restores full focus duration")
        t.checkEqual(engine.focusSessionsCompletedInCycle, 0, "reset cycle clears completed-session count")
    }

    // runtimeRestoreCanCompleteExpiredPhase
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)

        let url = temporaryURL().appending(path: "runtime.json")
        let store = RuntimeStore(url: url)
        do {
            try store.save(engine)
            var restored = try store.load(preferences: shortPreferences)
            let event = restored.tick(now: engineStart.addingTimeInterval(65), preferences: shortPreferences)

            if case .phaseCompleted(let completed) = event {
                t.checkEqual(completed.phase, .focus, "restored engine completes the focus phase")
                t.checkEqual(restored.pendingPhase, .shortBreak, "restored engine queues short break")
            } else {
                t.check(false, "expected restored phase to complete")
            }
        } catch {
            t.check(false, "runtimeRestoreCanCompleteExpiredPhase threw: \(error)")
        }
    }

    // preferenceValidationClampsUnsafeValues
    do {
        let preferences = TimerPreferences(
            focusMinutes: -5,
            shortBreakMinutes: 0,
            longBreakMinutes: 999,
            sessionsBeforeLongBreak: 99
        )

        t.checkEqual(preferences.focusMinutes, 1, "negative focus minutes clamp to 1")
        t.checkEqual(preferences.shortBreakMinutes, 1, "zero short break minutes clamp to 1")
        t.checkEqual(preferences.longBreakMinutes, 240, "excessive long break minutes clamp to 240")
        t.checkEqual(preferences.sessionsBeforeLongBreak, 12, "excessive sessions-before-long-break clamps to 12")
    }
}

exit(t.summarize())
