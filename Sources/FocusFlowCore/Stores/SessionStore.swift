import Foundation

public enum SessionStoreError: LocalizedError, Equatable {
    case storeUnavailable
    case recordNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .storeUnavailable:
            "FocusFlow could not access its session store."
        case .recordNotFound:
            "The session record could not be found."
        }
    }
}

public final class SessionStore {
    public private(set) var data: SessionStoreData

    private let fileStore: JSONFileStore<SessionStoreData>

    public init(url: URL) throws {
        self.fileStore = JSONFileStore(url: url)
        self.data = try fileStore.load(default: SessionStoreData())
    }

    public convenience init(applicationSupportSubdirectory: String = "FocusFlow") throws {
        let directory = try Self.applicationSupportDirectory().appending(path: applicationSupportSubdirectory)
        try self.init(url: directory.appending(path: "session-store.json"))
    }

    public func addRecord(_ record: SessionRecord) throws {
        data.records.append(record)
        try save()
    }

    public func deleteRecord(id: UUID) throws {
        data.records.removeAll { $0.id == id }
        try save()
    }

    public func updateRecordQuality(id: UUID, quality: Int?) throws {
        guard let index = data.records.firstIndex(where: { $0.id == id }) else {
            throw SessionStoreError.recordNotFound(id)
        }
        data.records[index].focusQuality = quality
        try save()
    }

    public func resetRecords() throws {
        data.records.removeAll()
        try save()
    }

    public func upsertTag(_ tag: Tag) throws {
        if let index = data.tags.firstIndex(where: { $0.id == tag.id }) {
            data.tags[index] = tag
        } else {
            data.tags.append(tag)
        }
        try save()
    }

    public func deleteTag(id: UUID) throws {
        data.tags.removeAll { $0.id == id }
        for index in data.records.indices where data.records[index].tagID == id {
            data.records[index].tagID = nil
        }
        try save()
    }

    public func save() throws {
        try fileStore.save(data)
    }

    public static func applicationSupportDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}
