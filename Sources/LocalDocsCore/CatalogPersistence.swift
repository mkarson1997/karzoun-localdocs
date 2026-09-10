import Foundation

public struct CatalogPersistence: Sendable {
    public let snapshotURL: URL

    public init(snapshotURL: URL) {
        self.snapshotURL = snapshotURL
    }

    public func load() throws -> CatalogSnapshot? {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: snapshotURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(CatalogSnapshot.self, from: data)

        guard snapshot.version == CatalogSnapshot.currentVersion else {
            throw LocalDocsError.unsupportedSnapshotVersion(snapshot.version)
        }

        return snapshot
    }

    public func save(_ snapshot: CatalogSnapshot) throws {
        let directory = snapshotURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
    }
}
