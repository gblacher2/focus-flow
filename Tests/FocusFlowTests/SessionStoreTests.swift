import FocusFlowCore
import Testing
import Foundation

@Test func storePersistsRecordsAndTags() throws {
    let url = temporaryURL().appending(path: "sessions.json")
    let store = try SessionStore(url: url)
    let tag = Tag(title: "Deep Work", colorName: "blue")
    let record = sampleRecord(tagID: tag.id)

    try store.upsertTag(tag)
    try store.addRecord(record)

    let reloaded = try SessionStore(url: url)
    #expect(reloaded.data.tags.contains(tag))
    #expect(reloaded.data.records.contains(record))
}

@Test func deletingTagClearsRecordAssignments() throws {
    let url = temporaryURL().appending(path: "sessions.json")
    let store = try SessionStore(url: url)
    let tag = Tag(title: "Study", colorName: "green")

    try store.upsertTag(tag)
    try store.addRecord(sampleRecord(tagID: tag.id))
    try store.deleteTag(id: tag.id)

    #expect(!store.data.tags.contains(tag))
    #expect(store.data.records.first?.tagID == nil)
}

@Test func statisticsFilterAndSummary() {
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

    #expect(filtered.count == 2)
    #expect(summary.completedFocusCount == 1)
    #expect(summary.completedBreakCount == 1)
    #expect(summary.totalFocusSeconds == 1_500)
    #expect(summary.totalBreakSeconds == 300)
}

@Test func csvExporterEscapesCommasAndQuotes() {
    let tag = Tag(title: "Study, CFA", colorName: "green")
    let record = sampleRecord(title: "Read \"Ethics\"", tagID: tag.id)

    let csv = CSVExporter.export(records: [record], tags: [tag])

    #expect(csv.contains("\"Read \"\"Ethics\"\"\""))
    #expect(csv.contains("\"Study, CFA\""))
}

private func sampleRecord(
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
