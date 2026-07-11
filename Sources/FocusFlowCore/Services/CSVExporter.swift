import Foundation

public enum CSVExporter {
    public static func export(records: [SessionRecord], tags: [Tag]) -> String {
        let tagLookup = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.title) })
        let header = [
            "id",
            "type",
            "title",
            "tag",
            "started_at",
            "ended_at",
            "planned_seconds",
            "actual_seconds",
            "completed",
            "interruptions"
        ].joined(separator: ",")

        // Cache formatter to avoid expensive initialization inside the loop
        let dateFormatter = ISO8601DateFormatter()
        let rows = records.sorted { $0.startedAt < $1.startedAt }.map { record in
            [
                record.id.uuidString,
                record.phase.displayName,
                record.title,
                record.tagID.flatMap { tagLookup[$0] } ?? "",
                dateFormatter.string(from: record.startedAt),
                dateFormatter.string(from: record.endedAt),
                String(record.plannedSeconds),
                String(record.actualSeconds),
                record.completed ? "true" : "false",
                String(record.interruptionCount)
            ].map(escape).joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
