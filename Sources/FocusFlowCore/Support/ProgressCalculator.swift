import Foundation

public enum ProgressCalculator {
    public static func dailyFocusTotals(records: [SessionRecord], calendar: Calendar = .current) -> [Date: Int] {
        var totals: [Date: Int] = [:]
        for record in records {
            guard record.completed, record.phase == .focus else { continue }
            let day = calendar.startOfDay(for: record.startedAt)
            totals[day, default: 0] += record.actualSeconds
        }
        return totals
    }

    public static func goalProgress(records: [SessionRecord], goalMinutes: Int, on date: Date, calendar: Calendar = .current) -> Double {
        guard goalMinutes > 0 else { return 0 }
        let totals = dailyFocusTotals(records: records, calendar: calendar)
        let day = calendar.startOfDay(for: date)
        let focusSeconds = totals[day] ?? 0
        return max(0, Double(focusSeconds) / Double(goalMinutes * 60))
    }

    public static func currentStreak(records: [SessionRecord], goalMinutes: Int, asOf: Date, calendar: Calendar = .current) -> Int {
        let totals = dailyFocusTotals(records: records, calendar: calendar)
        let today = calendar.startOfDay(for: asOf)
        var streak = 0

        let goalSeconds = goalMinutes * 60
        let daysWithCompletedSessions = Set(records.filter { $0.completed && $0.phase == .focus }.map { calendar.startOfDay(for: $0.startedAt) })

        func dayCounts(_ day: Date) -> Bool {
            if goalMinutes > 0 {
                let focusSeconds = totals[day] ?? 0
                return focusSeconds >= goalSeconds
            } else {
                return daysWithCompletedSessions.contains(day)
            }
        }

        var currentDay = today
        if !dayCounts(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            currentDay = yesterday
        }

        while dayCounts(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = previousDay
        }

        return streak
    }

    public static func bestHours(records: [SessionRecord], calendar: Calendar = .current) -> [Int] {
        var buckets = Array(repeating: 0, count: 24)
        for record in records {
            guard record.completed, record.phase == .focus else { continue }
            let hour = calendar.component(.hour, from: record.startedAt)
            buckets[hour] += record.actualSeconds
        }
        return buckets
    }

    public static func heatmapCells(records: [SessionRecord], weeks: Int, endingOn: Date, calendar: Calendar = .current) -> [[Int]] {
        var cells = Array(repeating: Array(repeating: 0, count: weeks), count: 7)
        let totals = dailyFocusTotals(records: records, calendar: calendar)

        let endDay = calendar.startOfDay(for: endingOn)
        let endWeekday = calendar.component(.weekday, from: endDay)
        let firstWeekday = calendar.firstWeekday
        let endRow = (endWeekday - firstWeekday + 7) % 7

        let totalDays = (weeks - 1) * 7 + endRow
        guard let startDay = calendar.date(byAdding: .day, value: -totalDays, to: endDay) else {
            return cells
        }

        for i in 0...totalDays {
            guard let day = calendar.date(byAdding: .day, value: i, to: startDay) else { continue }
            let seconds = totals[day] ?? 0
            let row = (calendar.component(.weekday, from: day) - firstWeekday + 7) % 7
            let col = i / 7
            if col >= 0 && col < weeks && row >= 0 && row < 7 {
                cells[row][col] = seconds
            }
        }

        return cells
    }

    /// Buckets completed-focus records by tag ID.
    ///
    /// Returns an array of up to 6 named-tag buckets (sorted by seconds descending),
    /// an optional "Other" bucket aggregating remaining named tags, and a separate
    /// "No Tag" bucket for records with nil tagID. Excludes incomplete and non-focus records.
    public static func tagFocusBuckets(records: [SessionRecord]) -> [TagFocusBucket] {
        var taggedTotals: [UUID: Int] = [:]
        var untaggedSeconds = 0

        for record in records {
            guard record.completed, record.phase == .focus else { continue }
            if let tagID = record.tagID {
                taggedTotals[tagID, default: 0] += record.actualSeconds
            } else {
                untaggedSeconds += record.actualSeconds
            }
        }

        let sorted = taggedTotals.sorted { $0.value > $1.value }
        var result: [TagFocusBucket] = []

        // Top 6 named tags
        for entry in sorted.prefix(6) {
            result.append(TagFocusBucket(tagID: entry.key, seconds: entry.value, label: .named))
        }

        // Other bucket for remaining named tags
        let otherSeconds = sorted.dropFirst(6).reduce(0) { $0 + $1.value }
        if otherSeconds > 0 {
            result.append(TagFocusBucket(tagID: nil, seconds: otherSeconds, label: .other))
        }

        // No Tag bucket
        if untaggedSeconds > 0 {
            result.append(TagFocusBucket(tagID: nil, seconds: untaggedSeconds, label: .noTag))
        }

        return result
    }
}

/// A single bucket in the per-tag focus-time breakdown.
public struct TagFocusBucket: Equatable, Sendable {
    public let tagID: UUID?
    public let seconds: Int
    public let label: Label

    public enum Label: String, Equatable, Sendable {
        case named
        case other = "Other"
        case noTag = "No Tag"
    }

    public init(tagID: UUID?, seconds: Int, label: Label) {
        self.tagID = tagID
        self.seconds = seconds
        self.label = label
    }
}
