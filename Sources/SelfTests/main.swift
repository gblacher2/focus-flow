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
    // Backward compatibility: JSON persisted before the newer menu bar/window
    // visibility flags existed must still decode, not throw (which would send
    // PreferencesStore.load() down its all-defaults fallback and silently wipe
    // the user's real settings). Missing keys default to each key's pre-key
    // behavior: showCountdownWhenIdle to true (old installs always showed the
    // idle countdown), showWindowAtLaunch to false.
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
        "breakCompleteSound": "Pop",
        "showWindowAtLaunch": false,
        "showCountdownWhenIdle": true
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
        t.checkEqual(decoded.showCountdownWhenIdle, true, "old-shape JSON defaults showCountdownWhenIdle to true")
        t.checkEqual(decoded.hasCompletedOnboarding, true, "old-shape JSON defaults hasCompletedOnboarding to true")
        t.checkEqual(decoded.launchAtLogin, false, "old-shape JSON defaults launchAtLogin to false")
        t.checkEqual(decoded.idlePauseEnabled, false, "old-shape JSON defaults idlePauseEnabled to false")
        t.checkEqual(decoded.idlePauseMinutes, 5, "old-shape JSON defaults idlePauseMinutes to 5")
        t.checkEqual(decoded.dailyGoalMinutes, 0, "old-shape JSON defaults dailyGoalMinutes to 0")
        t.checkEqual(decoded.showSessionReview, true, "old-shape JSON defaults showSessionReview to true")
        t.checkEqual(decoded.toggleShortcut, .defaultToggle, "old-shape JSON defaults toggleShortcut")
        t.checkEqual(decoded.skipShortcut, .defaultSkip, "old-shape JSON defaults skipShortcut")
        t.checkEqual(decoded.resetShortcut, .defaultReset, "old-shape JSON defaults resetShortcut")
        t.checkEqual(decoded.showTimerShortcut, .defaultShowTimer, "old-shape JSON defaults showTimerShortcut")
    } catch {
        t.check(false, "decoding old-shape JSON threw: \(error)")
    }

    // Full encode → decode round-trip with non-default values, so a dropped
    // or misnamed coding key can't hide behind the missing-key defaults.
    do {
        var prefs = TimerPreferences()
        prefs.focusMinutes = 33
        prefs.showCountdownWhenIdle = true
        prefs.showWindowAtLaunch = true
        prefs.idlePauseMinutes = 15
        prefs.dailyGoalMinutes = 45
        prefs.hasCompletedOnboarding = true
        prefs.launchAtLogin = true
        prefs.idlePauseEnabled = true
        prefs.showSessionReview = false
        prefs.toggleShortcut = ShortcutSpec(keyCode: 1, modifierRawValue: 2)
        prefs.skipShortcut = ShortcutSpec(keyCode: 2, modifierRawValue: 2)
        prefs.resetShortcut = ShortcutSpec(keyCode: 3, modifierRawValue: 2)
        prefs.showTimerShortcut = ShortcutSpec(keyCode: 4, modifierRawValue: 2)
        let data = try JSONEncoder().encode(prefs)
        let roundTripped = try JSONDecoder().decode(TimerPreferences.self, from: data)
        t.checkEqual(roundTripped.focusMinutes, 33, "encode/decode round-trip preserves focusMinutes")
        t.checkEqual(roundTripped.showCountdownWhenIdle, true, "encode/decode round-trip preserves showCountdownWhenIdle")
        t.checkEqual(roundTripped.showWindowAtLaunch, true, "encode/decode round-trip preserves showWindowAtLaunch")
        t.checkEqual(roundTripped.idlePauseMinutes, 15, "encode/decode round-trip preserves idlePauseMinutes")
        t.checkEqual(roundTripped.dailyGoalMinutes, 45, "encode/decode round-trip preserves dailyGoalMinutes")
        t.checkEqual(roundTripped.hasCompletedOnboarding, true, "encode/decode round-trip preserves hasCompletedOnboarding")
        t.checkEqual(roundTripped.launchAtLogin, true, "encode/decode round-trip preserves launchAtLogin")
        t.checkEqual(roundTripped.idlePauseEnabled, true, "encode/decode round-trip preserves idlePauseEnabled")
        t.checkEqual(roundTripped.showSessionReview, false, "encode/decode round-trip preserves showSessionReview")
        t.checkEqual(roundTripped.toggleShortcut, ShortcutSpec(keyCode: 1, modifierRawValue: 2), "encode/decode round-trip preserves toggleShortcut")
        t.checkEqual(roundTripped.skipShortcut, ShortcutSpec(keyCode: 2, modifierRawValue: 2), "encode/decode round-trip preserves skipShortcut")
        t.checkEqual(roundTripped.resetShortcut, ShortcutSpec(keyCode: 3, modifierRawValue: 2), "encode/decode round-trip preserves resetShortcut")
        t.checkEqual(roundTripped.showTimerShortcut, ShortcutSpec(keyCode: 4, modifierRawValue: 2), "encode/decode round-trip preserves showTimerShortcut")
        t.checkEqual(roundTripped, prefs, "encode/decode round-trip preserves full TimerPreferences equality")
    } catch {
        t.check(false, "encode/decode round-trip threw: \(error)")
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
        let url = temporaryURL().appending(path: "legacy-sessions.json")
        let json = """
        {
            "tags": [],
            "records": [
                {
                    "id": "123e4567-e89b-12d3-a456-426614174000",
                    "phase": "focus",
                    "title": "Old Session",
                    "startedAt": "2026-07-11T10:00:00Z",
                    "endedAt": "2026-07-11T10:25:00Z",
                    "plannedSeconds": 1500,
                    "actualSeconds": 1500,
                    "completed": true,
                    "interruptionCount": 0
                }
            ]
        }
        """.data(using: .utf8)!
        try json.write(to: url)
        let store = try SessionStore(url: url)
        t.checkEqual(store.data.records.first?.focusQuality, nil, "legacy session record loads with nil focusQuality")

        let id = UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!
        try store.updateRecordQuality(id: id, quality: 3)
        t.checkEqual(store.data.records.first?.focusQuality, 3, "updateRecordQuality sets quality in memory")

        let reloaded = try SessionStore(url: url)
        t.checkEqual(reloaded.data.records.first?.focusQuality, 3, "updateRecordQuality persists across reload")
    } catch {
        t.check(false, "legacy SessionStore fixture threw: \(error)")
    }

    do {
        let url = temporaryURL().appending(path: "missing-quality-record.json")
        let store = try SessionStore(url: url)
        let missingID = UUID()
        do {
            try store.updateRecordQuality(id: missingID, quality: 2)
            t.check(false, "updating a missing quality record throws")
        } catch let error as SessionStoreError {
            t.checkEqual(error, .recordNotFound(missingID), "missing quality record reports recordNotFound")
        }
    } catch {
        t.check(false, "missing quality record fixture threw: \(error)")
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
    var record = sampleRecord(title: "Read \"Ethics\"", tagID: tag.id)
    record.focusQuality = 3
    let csv = CSVExporter.export(records: [record], tags: [tag])
    let expectedHeader = "id,type,title,tag,started_at,ended_at,planned_seconds,actual_seconds,completed,interruptions,quality"
    t.checkEqual(csv.split(separator: "\n").first.map(String.init), expectedHeader, "CSV quality header is last in exact order")
    t.check(csv.contains("\"Read \"\"Ethics\"\"\""), "CSV exporter escapes embedded quotes")
    t.check(csv.contains("\"Study, CFA\""), "CSV exporter quotes fields with commas")
    t.check(csv.contains(",3\n"), "CSV exporter includes quality column")

    let nilQualityCSV = CSVExporter.export(records: [sampleRecord()], tags: [])
    let nilQualityRow = nilQualityCSV.split(separator: "\n").dropFirst().first.map(String.init)
    t.check(nilQualityRow?.hasSuffix(",") == true, "CSV exporter leaves quality empty when unset")
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

    // backdatedPauseRefundsIdleTime
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)

        let pauseTime = engineStart.addingTimeInterval(20) // 10 seconds ago

        engine.pause(now: pauseTime)

        t.checkEqual(engine.phase, .paused, "engine pauses correctly")
        t.checkEqual(engine.remainingSeconds, 40, "backdated pause correctly refunds idle time")
    }

    // pausedPreferencesPreserveCreditedRemainingTime
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)
        engine.pause(now: engineStart.addingTimeInterval(20))

        var changedPreferences = shortPreferences
        changedPreferences.focusMinutes = 10
        changedPreferences.dailyGoalMinutes = 60
        engine.applyPreferences(changedPreferences, now: engineStart.addingTimeInterval(21))

        t.checkEqual(engine.phase, .paused, "preference edits keep an idle-paused phase paused")
        t.checkEqual(engine.remainingSeconds, 40, "preference edits preserve credited paused remaining time")
        t.checkEqual(engine.plannedSeconds, 60, "new duration applies to a later phase, not the paused phase")
    }

    // completionWinsBeforeAnyBackdatedIdlePause
    do {
        var engine = TimerEngine(preferences: shortPreferences)
        engine.start(now: engineStart, preferences: shortPreferences)
        let event = engine.tick(now: engineStart.addingTimeInterval(60), preferences: shortPreferences)
        engine.pause(now: engineStart)

        if case .phaseCompleted(let completed) = event {
            t.checkEqual(completed.phase, .focus, "expired focus completes before idle-pause handling")
            t.checkEqual(engine.phase, .completed, "completed focus cannot be resurrected as paused")
        } else {
            t.check(false, "expected expired focus completion before idle-pause handling")
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
            sessionsBeforeLongBreak: 99,
            idlePauseMinutes: 0,
            dailyGoalMinutes: -5
        )

        t.checkEqual(preferences.focusMinutes, 1, "negative focus minutes clamp to 1")
        t.checkEqual(preferences.shortBreakMinutes, 1, "zero short break minutes clamp to 1")
        t.checkEqual(preferences.longBreakMinutes, 240, "excessive long break minutes clamp to 240")
        t.checkEqual(preferences.sessionsBeforeLongBreak, 12, "excessive sessions-before-long-break clamps to 12")
        t.checkEqual(preferences.idlePauseMinutes, 1, "zero idle pause minutes clamp to 1")
        t.checkEqual(preferences.dailyGoalMinutes, 0, "negative daily goal minutes clamp to 0")

        var prefs2 = TimerPreferences()
        prefs2.idlePauseMinutes = 99
        prefs2.dailyGoalMinutes = 9999
        prefs2.validate()
        t.checkEqual(prefs2.idlePauseMinutes, 30, "excessive idle pause minutes clamp to 30")
        t.checkEqual(prefs2.dailyGoalMinutes, 1440, "excessive daily goal minutes clamp to 1440")
    }
}

// MARK: - ShortcutSpec tests

t.group("ShortcutSpec") {
    // 1. Default mappings
    t.checkEqual(ShortcutSpec.defaultModifierMask, 0x1C0000, "defaultModifierMask is 0x1C0000")
    t.checkEqual(ShortcutSpec.defaultToggle.keyCode, 49, "toggle is space (49)")
    t.checkEqual(ShortcutSpec.defaultSkip.keyCode, 124, "skip is right arrow (124)")
    t.checkEqual(ShortcutSpec.defaultReset.keyCode, 15, "reset is R (15)")
    t.checkEqual(ShortcutSpec.defaultShowTimer.keyCode, 3, "show timer is F (3)")

    // 2. Codable round-trip
    let spec = ShortcutSpec.defaultToggle
    let data = try! JSONEncoder().encode(spec)
    let decoded = try! JSONDecoder().decode(ShortcutSpec.self, from: data)
    t.checkEqual(decoded, spec, "ShortcutSpec round-trips through Codable")

    // 3. Production modifier normalization, matching, and validation
    let specMatch = ShortcutSpec(keyCode: 49, modifierRawValue: 0x1C0000)
    t.check(specMatch.matches(eventKeyCode: 49, eventModifierRawValue: 0x1C0000), "Exact modifiers match")
    t.check(specMatch.matches(eventKeyCode: 49, eventModifierRawValue: 0x1C0000 | 0x200000 | 0x800000), "Hardware flags are normalized before matching")
    t.check(!specMatch.matches(eventKeyCode: 49, eventModifierRawValue: 0x1C0000 | 0x20000), "Extra Shift modifier is rejected")
    t.check(!specMatch.matches(eventKeyCode: 49, eventModifierRawValue: 0x1C0000 & ~0x100000), "Missing Command modifier is rejected")
    t.check(!specMatch.matches(eventKeyCode: 15, eventModifierRawValue: 0x1C0000), "Wrong key code is rejected")
    let noisyStoredSpec = ShortcutSpec(keyCode: 49, modifierRawValue: 0x1C0000 | 0x200000)
    t.check(noisyStoredSpec.matches(eventKeyCode: 49, eventModifierRawValue: 0x1C0000), "Stored hardware flags are normalized before matching")
    t.checkEqual(ShortcutSpec.normalizedModifierRawValue(0x1C0000 | 0x200000 | 0x800000), 0x1C0000, "Modifier normalizer strips hardware flags")
    t.check(!ShortcutSpec.isRecordableModifierRawValue(0), "Plain key modifiers are not recordable")
    t.check(!ShortcutSpec.isRecordableModifierRawValue(ShortcutSpec.shiftModifierMask), "Shift-only modifiers are not recordable")
    t.check(ShortcutSpec.isRecordableModifierRawValue(0x040000), "Control modifier is recordable")

    // 4. Production logical conflict detection
    let duplicate = ShortcutSpec(keyCode: 49, modifierRawValue: 0x1C0000 | 0x800000)
    t.check(specMatch.conflicts(with: duplicate), "Duplicate detection ignores hardware flag noise")
    t.check(!specMatch.conflicts(with: ShortcutSpec(keyCode: 124, modifierRawValue: 0x1C0000)), "Different key codes do not conflict")
    t.check(!specMatch.conflicts(with: ShortcutSpec(keyCode: 49, modifierRawValue: 0x1E0000)), "Different keyboard modifiers do not conflict")

    // 5. Key-equivalent / name mapping pure checks
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 49), " ", "Space keyEquivalent is ' '")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 126), "\u{F700}", "Up arrow uses NSUpArrowFunctionKey")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 125), "\u{F701}", "Down arrow uses NSDownArrowFunctionKey")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 123), "\u{F702}", "Left arrow uses NSLeftArrowFunctionKey")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 124), String(Character(UnicodeScalar(0xF703)!)), "Right arrow keyEquivalent is NSRightArrowFunctionKey")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 122), "\u{F704}", "F1 uses NSF1FunctionKey")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 111), "\u{F70F}", "F12 uses NSF12FunctionKey")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 33), "[", "Left bracket is representable")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 30), "]", "Right bracket is representable")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 15), "r", "R keyEquivalent is 'r'")
    t.checkEqual(ShortcutSpec.keyEquivalentString(for: 9999), nil, "Unrepresentable keyEquivalent is nil")

    t.checkEqual(ShortcutSpec(keyCode: 49, modifierRawValue: 0x1C0000).displayString, "⌃⌥⌘Space", "displayString formats modifiers and key name")
    t.checkEqual(ShortcutSpec(keyCode: 124, modifierRawValue: 0x1C0000).displayString, "⌃⌥⌘→", "displayString formats modifiers and arrow key name")
    t.checkEqual(ShortcutSpec(keyCode: 15, modifierRawValue: 0x1E0000).displayString, "⌃⌥⇧⌘R", "displayString formats shift modifier correctly")
}

// MARK: - ProgressCalculator tests

t.group("ProgressCalculator") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let asOf = Date(timeIntervalSince1970: 10_000_000)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: asOf)!
    let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: asOf)!

    // Empty records
    t.checkEqual(ProgressCalculator.currentStreak(records: [], goalMinutes: 30, asOf: asOf, calendar: calendar), 0, "streak is 0 for empty records")

    // Single qualifying day
    let record1 = sampleRecord(startedAt: yesterday, actualSeconds: 1800, completed: true)
    t.checkEqual(ProgressCalculator.currentStreak(records: [record1], goalMinutes: 30, asOf: asOf, calendar: calendar), 1, "single qualifying day gives streak of 1")

    // Today not yet met
    t.checkEqual(ProgressCalculator.currentStreak(records: [record1], goalMinutes: 30, asOf: asOf, calendar: calendar), 1, "today not met preserves streak through yesterday")

    // Goal-on vs Goal-off definitions
    let record2 = sampleRecord(startedAt: yesterday, actualSeconds: 600, completed: true)
    t.checkEqual(ProgressCalculator.currentStreak(records: [record2], goalMinutes: 30, asOf: asOf, calendar: calendar), 0, "600s does not meet 30m goal")
    t.checkEqual(ProgressCalculator.currentStreak(records: [record2], goalMinutes: 0, asOf: asOf, calendar: calendar), 1, "600s meets goal=0 (1 completed session)")

    // 0-second completed session meets goal=0
    let zeroSecondRecord = sampleRecord(startedAt: asOf, actualSeconds: 0, completed: true)
    t.checkEqual(ProgressCalculator.currentStreak(records: [zeroSecondRecord], goalMinutes: 0, asOf: asOf, calendar: calendar), 1, "0-second completed session meets goal=0")

    // Gap-broken streak
    let record3 = sampleRecord(startedAt: twoDaysAgo, actualSeconds: 1800, completed: true)
    // No record for yesterday
    t.checkEqual(ProgressCalculator.currentStreak(records: [record3], goalMinutes: 30, asOf: asOf, calendar: calendar), 0, "gap yesterday breaks streak")

    // goalProgress non-negative
    let negativeRecord = sampleRecord(startedAt: asOf, actualSeconds: -500, completed: true)
    t.checkEqual(ProgressCalculator.goalProgress(records: [negativeRecord], goalMinutes: 30, on: asOf, calendar: calendar), 0, "goalProgress is non-negative even if actualSeconds is negative")

    // bestHours bucketing
    let record4 = sampleRecord(startedAt: asOf.addingTimeInterval(3600 * 9), actualSeconds: 3000, completed: true) // +9h from UTC start
    let buckets = ProgressCalculator.bestHours(records: [record4], calendar: calendar)
    let hour = calendar.component(.hour, from: record4.startedAt)
    t.checkEqual(buckets[hour], 3000, "bestHours correctly buckets actualSeconds by hour")
    t.checkEqual(buckets.reduce(0, +), 3000, "bestHours sums exactly match input records")

    // heatmapCells
    var sundayFirstCal = calendar
    sundayFirstCal.firstWeekday = 1 // Sunday

    var mondayFirstCal = calendar
    mondayFirstCal.firstWeekday = 2 // Monday

    let heatmapEnd = asOf
    let endWeekday = sundayFirstCal.component(.weekday, from: heatmapEnd)
    let offsetToFriday = 6 - endWeekday
    let fridayEnd = sundayFirstCal.date(byAdding: .day, value: offsetToFriday, to: heatmapEnd)!

    let endRecord = sampleRecord(startedAt: fridayEnd, actualSeconds: 1500, completed: true)
    let futureRecord = sampleRecord(startedAt: fridayEnd.addingTimeInterval(86400), actualSeconds: 2000, completed: true)

    let cellsSunday = ProgressCalculator.heatmapCells(records: [endRecord, futureRecord], weeks: 2, endingOn: fridayEnd, calendar: sundayFirstCal)
    let cellsMonday = ProgressCalculator.heatmapCells(records: [endRecord, futureRecord], weeks: 2, endingOn: fridayEnd, calendar: mondayFirstCal)

    t.checkEqual(cellsSunday.count, 7, "heatmap has 7 rows")
    t.checkEqual(cellsSunday[0].count, 2, "heatmap has `weeks` columns")
    t.checkEqual(cellsSunday[5][1], 1500, "Sunday-first: Friday data lands in row 5")
    t.checkEqual(cellsMonday[4][1], 1500, "Monday-first: Friday data lands in row 4")
    t.check(!cellsSunday.flatMap { $0 }.contains(2000), "dates after endingOn remain zero / excluded")

    // tagFocusBuckets tests
    let tag1 = UUID()
    let tag2 = UUID()
    let tag3 = UUID()
    let tag4 = UUID()
    let tag5 = UUID()
    let tag6 = UUID()
    let tag7 = UUID()
    let tag8 = UUID()

    let tagRecords: [SessionRecord] = [
        sampleRecord(tagID: tag1, actualSeconds: 8000, completed: true),
        sampleRecord(tagID: tag2, actualSeconds: 7000, completed: true),
        sampleRecord(tagID: tag3, actualSeconds: 6000, completed: true),
        sampleRecord(tagID: tag4, actualSeconds: 5000, completed: true),
        sampleRecord(tagID: tag5, actualSeconds: 4000, completed: true),
        sampleRecord(tagID: tag6, actualSeconds: 3000, completed: true),
        sampleRecord(tagID: tag7, actualSeconds: 2000, completed: true),
        sampleRecord(tagID: tag8, actualSeconds: 1000, completed: true),
        sampleRecord(tagID: nil, actualSeconds: 9000, completed: true),  // No Tag — highest total
        sampleRecord(tagID: nil, actualSeconds: 500, completed: true),   // more untagged
        sampleRecord(tagID: tag1, actualSeconds: 100, completed: false), // incomplete — exclude
        sampleRecord(phase: .shortBreak, tagID: tag1, actualSeconds: 300, completed: true), // break — exclude
    ]

    let tagBuckets = ProgressCalculator.tagFocusBuckets(records: tagRecords)

    // Named tags: exactly 6 (tags 1-6 by descending seconds)
    let namedBuckets = tagBuckets.filter { $0.label == .named }
    t.checkEqual(namedBuckets.count, 6, "tagFocusBuckets returns exactly 6 named tags")

    // Named buckets sorted descending
    t.checkEqual(namedBuckets[0].seconds, 8000, "top named tag has 8000s")
    t.checkEqual(namedBuckets[5].seconds, 3000, "6th named tag has 3000s")

    // Other bucket: tag7 (2000) + tag8 (1000) = 3000
    let otherBuckets = tagBuckets.filter { $0.label == .other }
    t.checkEqual(otherBuckets.count, 1, "tagFocusBuckets has exactly 1 Other bucket")
    t.checkEqual(otherBuckets.first?.seconds ?? 0, 3000, "Other bucket aggregates tags 7+8 = 3000s")

    // No Tag bucket: 9000 + 500 = 9500 (does NOT consume a named slot)
    let noTagBuckets = tagBuckets.filter { $0.label == .noTag }
    t.checkEqual(noTagBuckets.count, 1, "tagFocusBuckets has exactly 1 No Tag bucket")
    t.checkEqual(noTagBuckets.first?.seconds ?? 0, 9500, "No Tag bucket sums to 9500s")

    // No Tag is separate from named — total named count is still 6
    t.checkEqual(namedBuckets.count, 6, "No Tag does not consume a named tag slot")

    // Incomplete and break records excluded
    let totalBucketSeconds = tagBuckets.reduce(0) { $0 + $1.seconds }
    let expectedTotal = 8000 + 7000 + 6000 + 5000 + 4000 + 3000 + 2000 + 1000 + 9000 + 500
    t.checkEqual(totalBucketSeconds, expectedTotal, "tagFocusBuckets excludes incomplete and break records")

    // Empty records produce no buckets
    let emptyBuckets = ProgressCalculator.tagFocusBuckets(records: [])
    t.checkEqual(emptyBuckets.count, 0, "tagFocusBuckets returns empty for no records")
}

exit(t.summarize())
