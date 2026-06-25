import Foundation

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
        try fileStore.save(engine)
    }
}
