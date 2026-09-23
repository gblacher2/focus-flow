import Foundation

public struct Tag: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var colorName: String

    public init(id: UUID = UUID(), title: String, colorName: String) {
        self.id = id
        self.title = title
        self.colorName = colorName
    }
}

public struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var phase: TimerPhase
    public var title: String
    public var tagID: UUID?
    public var startedAt: Date
    public var endedAt: Date
    public var plannedSeconds: Int
    public var actualSeconds: Int
    public var completed: Bool
    public var interruptionCount: Int
    /// Semantic values 1 (distracted), 2 (okay), 3 (deep); nil = not reviewed.
    public var focusQuality: Int?

    public init(
        id: UUID = UUID(),
        phase: TimerPhase,
        title: String,
        tagID: UUID?,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        actualSeconds: Int,
        completed: Bool,
        interruptionCount: Int,
        focusQuality: Int? = nil
    ) {
        self.id = id
        self.phase = phase
        self.title = title
        self.tagID = tagID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.completed = completed
        self.interruptionCount = interruptionCount
        self.focusQuality = focusQuality
    }
}

public struct SessionStoreData: Codable, Equatable, Sendable {
    public var tags: [Tag]
    public var records: [SessionRecord]

    public init(tags: [Tag] = Self.defaultTags, records: [SessionRecord] = []) {
        self.tags = tags
        self.records = records
    }

    public static let defaultTags: [Tag] = [
        Tag(title: "Work", colorName: "blue"),
        Tag(title: "Study", colorName: "green"),
        Tag(title: "Personal", colorName: "orange")
    ]
}

public struct StatisticsSummary: Equatable, Sendable {
    public var completedFocusCount: Int
    public var completedBreakCount: Int
    public var totalFocusSeconds: Int
    public var totalBreakSeconds: Int
    public var interruptionCount: Int

    public init(
        completedFocusCount: Int = 0,
        completedBreakCount: Int = 0,
        totalFocusSeconds: Int = 0,
        totalBreakSeconds: Int = 0,
        interruptionCount: Int = 0
    ) {
        self.completedFocusCount = completedFocusCount
        self.completedBreakCount = completedBreakCount
        self.totalFocusSeconds = totalFocusSeconds
        self.totalBreakSeconds = totalBreakSeconds
        self.interruptionCount = interruptionCount
    }
}
