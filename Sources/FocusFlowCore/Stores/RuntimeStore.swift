import Foundation

private struct RuntimeSnapshot: Encodable {
    let engine: TimerEngine
    let phaseEndsAt: Date?
    let isRunning: Bool
    let updatedAt: Date

    func encode(to encoder: Encoder) throws {
        try engine.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phaseEndsAt, forKey: .phaseEndsAt)
        try container.encode(isRunning, forKey: .isRunning)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case phaseEndsAt
        case isRunning
        case updatedAt
    }
}

public final class RuntimeStore {
    private let fileStore: JSONFileStore<TimerEngine>

    public init(url: URL) {
        self.fileStore = JSONFileStore(url: url)
    }

    public convenience init(applicationSupportSubdirectory: String = "FocusFlow") throws {
        let directory = try SessionStore.applicationSupportDirectory().appending(path: applicationSupportSubdirectory)
        self.init(url: directory.appending(path: "runtime.json"))
    }

    public func load(preferences: TimerPreferences) throws -> TimerEngine {
        try fileStore.load(default: TimerEngine(preferences: preferences))
    }

    public func save(_ engine: TimerEngine) throws {
        let snapshot = RuntimeSnapshot(
            engine: engine,
            phaseEndsAt: engine.isRunning ? engine.targetEnd : nil,
            isRunning: engine.isRunning,
            updatedAt: Date()
        )
        let directory = fileStore.url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(snapshot)
        try data.write(to: fileStore.url, options: [.atomic])
    }
}

