import FocusFlowCore
import Testing
import Foundation

@Test func groupedBucketsRecordsByDayMostRecentFirst() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let day1 = Date(timeIntervalSince1970: 1_000_000)           // earlier day
    let day2 = day1.addingTimeInterval(60 * 60 * 24 * 3)        // 3 days later

    // Caller passes newest-first; two records share day2.
    let records = [
        record(startedAt: day2.addingTimeInterval(7_200)),     // day2, later
        record(startedAt: day2),                                // day2, earlier
        record(startedAt: day1)                                 // day1
    ]

    let groups = StatisticsCalculator.grouped(records: records, calendar: calendar)

    #expect(groups.count == 2)
    // Most-recent day first.
    #expect(groups[0].day == calendar.startOfDay(for: day2))
    #expect(groups[1].day == calendar.startOfDay(for: day1))
    // Two records in the recent bucket, input order preserved.
    #expect(groups[0].records.count == 2)
    #expect(groups[0].records[0].startedAt == day2.addingTimeInterval(7_200))
    #expect(groups[1].records.count == 1)
}

@Test func groupedReturnsEmptyForNoRecords() {
    #expect(StatisticsCalculator.grouped(records: []).isEmpty)
}

private func record(startedAt: Date) -> SessionRecord {
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
