import Foundation

public enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    public var id: String { rawValue }
}

public enum StatisticsCalculator {
    public static func records(
        from records: [SessionRecord],
        period: StatisticsPeriod,
        tagID: UUID?,
        showIncomplete: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SessionRecord] {
        records
            .filter { record in
                guard showIncomplete || record.completed else { return false }
                if let tagID, record.tagID != tagID { return false }
                return contains(record.startedAt, in: period, now: now, calendar: calendar)
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Groups records by calendar day, most-recent day first. Records within each
    /// group preserve the input order (callers pass newest-first records).
    public static func grouped(
        records: [SessionRecord],
        calendar: Calendar = .current
    ) -> [(day: Date, records: [SessionRecord])] {
        var order: [Date] = []
        var buckets: [Date: [SessionRecord]] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.startedAt)
            if buckets[day] == nil {
                buckets[day] = []
                order.append(day)
            }
            buckets[day]?.append(record)
        }
        return order
            .sorted(by: >)
            .map { (day: $0, records: buckets[$0] ?? []) }
    }

    public static func summary(for records: [SessionRecord]) -> StatisticsSummary {
        records.reduce(into: StatisticsSummary()) { summary, record in
            guard record.completed else { return }
            if record.phase == .focus {
                summary.completedFocusCount += 1
                summary.totalFocusSeconds += record.actualSeconds
            } else if record.phase.isBreak {
                summary.completedBreakCount += 1
                summary.totalBreakSeconds += record.actualSeconds
            }
            summary.interruptionCount += record.interruptionCount
        }
    }

    private static func contains(
        _ date: Date,
        in period: StatisticsPeriod,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        switch period {
        case .all:
            true
        case .day:
            calendar.isDate(date, inSameDayAs: now)
        case .week:
            calendar.component(.weekOfYear, from: date) == calendar.component(.weekOfYear, from: now) &&
                calendar.component(.yearForWeekOfYear, from: date) == calendar.component(.yearForWeekOfYear, from: now)
        case .month:
            calendar.component(.month, from: date) == calendar.component(.month, from: now) &&
                calendar.component(.year, from: date) == calendar.component(.year, from: now)
        case .year:
            calendar.component(.year, from: date) == calendar.component(.year, from: now)
        }
    }
}
