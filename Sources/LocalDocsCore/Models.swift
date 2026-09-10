import Foundation

public struct DocumentID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID()
    }
}

public struct IndexedFile: Equatable, Sendable {
    public let relativePath: String
    public let byteCount: Int64
    public let modifiedAt: Date
    public let sha256: String
}

public struct DocumentRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: DocumentID
    public let relativePath: String
    public let byteCount: Int64
    public let modifiedAt: Date
    public let sha256: String
    public let tags: Set<String>
    public let firstIndexedAt: Date
    public let lastIndexedAt: Date
}

public struct CatalogSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let canonicalRootPath: String
    public let savedAt: Date
    public let documents: [DocumentRecord]

    public init(
        version: Int = CatalogSnapshot.currentVersion,
        canonicalRootPath: String,
        savedAt: Date,
        documents: [DocumentRecord]
    ) {
        self.version = version
        self.canonicalRootPath = canonicalRootPath
        self.savedAt = savedAt
        self.documents = documents
    }
}

public enum LocalDocsError: Error, Equatable, Sendable {
    case rootIsNotDirectory(String)
    case catalogRootMismatch(expected: String, found: String)
    case unsupportedSnapshotVersion(Int)
    case invalidRelativePath(String)
    case invalidMetadataKeyLength(Int)
    case unsupportedEncryptedEnvelopeVersion(Int)
    case unsupportedEncryptionAlgorithm(String)
    case invalidEncryptedEnvelope
    case metadataAuthenticationFailed
    case keychainFailure(Int32)
    case keychainReturnedInvalidData
}
