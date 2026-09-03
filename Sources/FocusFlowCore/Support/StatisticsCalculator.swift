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
        // Pre-calculate the date interval for O(1) filtering inside the tight loop.
        // Calendar methods (like .component) are extremely expensive to call repeatedly.
        let interval: DateInterval? = {
            switch period {
            case .all: return nil
            case .day: return calendar.dateInterval(of: .day, for: now)
            case .week: return calendar.dateInterval(of: .weekOfYear, for: now)
            case .month: return calendar.dateInterval(of: .month, for: now)
            case .year: return calendar.dateInterval(of: .year, for: now)
            }
        }()

        return records
            .filter { record in
                guard showIncomplete || record.completed else { return false }
                if let tagID, record.tagID != tagID { return false }
                if let interval {
                    return interval.contains(record.startedAt)
                }
                return true
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

}
