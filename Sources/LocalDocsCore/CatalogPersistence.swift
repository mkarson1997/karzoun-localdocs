import CryptoKit
import Foundation

public protocol CatalogSnapshotPersistence: Sendable {
    func load() throws -> CatalogSnapshot?
    func save(_ snapshot: CatalogSnapshot) throws
}

public struct EncryptedCatalogPersistence: CatalogSnapshotPersistence, Sendable {
    public static let currentEnvelopeVersion = 1
    public static let algorithm = "AES-256-GCM"

    public let vaultURL: URL
    private let keyProvider: any MetadataKeyProvider

    public init(
        vaultURL: URL,
        keyProvider: any MetadataKeyProvider
    ) {
        self.vaultURL = vaultURL
        self.keyProvider = keyProvider
    }

    public func load() throws -> CatalogSnapshot? {
        guard FileManager.default.fileExists(atPath: vaultURL.path) else {
            return nil
        }

        let envelopeData = try Data(contentsOf: vaultURL)
        let envelope = try JSONDecoder().decode(EncryptedEnvelope.self, from: envelopeData)

        guard envelope.version == Self.currentEnvelopeVersion else {
            throw LocalDocsError.unsupportedEncryptedEnvelopeVersion(envelope.version)
        }

        guard envelope.algorithm == Self.algorithm else {
            throw LocalDocsError.unsupportedEncryptionAlgorithm(envelope.algorithm)
        }

        let keyData = try validatedKeyData()
        let key = SymmetricKey(data: keyData)

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: envelope.combined)
        } catch {
            throw LocalDocsError.invalidEncryptedEnvelope
        }

        let cleartext: Data
        do {
            cleartext = try AES.GCM.open(
                sealedBox,
                using: key,
                authenticating: Self.additionalAuthenticatedData
            )
        } catch {
            throw LocalDocsError.metadataAuthenticationFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(CatalogSnapshot.self, from: cleartext)

        guard snapshot.version == CatalogSnapshot.currentVersion else {
            throw LocalDocsError.unsupportedSnapshotVersion(snapshot.version)
        }

        return snapshot
    }

    public func save(_ snapshot: CatalogSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let cleartext = try encoder.encode(snapshot)

        let keyData = try validatedKeyData()
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(
            cleartext,
            using: key,
            authenticating: Self.additionalAuthenticatedData
        )

        guard let combined = sealed.combined else {
            throw LocalDocsError.invalidEncryptedEnvelope
        }

        let envelope = EncryptedEnvelope(
            version: Self.currentEnvelopeVersion,
            algorithm: Self.algorithm,
            combined: combined
        )

        let envelopeEncoder = JSONEncoder()
        envelopeEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try envelopeEncoder.encode(envelope)

        let directory = vaultURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: vaultURL, options: [.atomic])
    }

    private func validatedKeyData() throws -> Data {
        let keyData = try keyProvider.loadOrCreateKeyData()
        guard keyData.count == 32 else {
            throw LocalDocsError.invalidMetadataKeyLength(keyData.count)
        }
        return keyData
    }

    private static let additionalAuthenticatedData = Data(
        "KarzounLocalDocs|EncryptedCatalog|v1|AES-256-GCM".utf8
    )
}

public enum CatalogMigration {
    /// Migrates the legacy plaintext JSON snapshot into an authenticated encrypted vault.
    /// The plaintext source is removed only after the encrypted vault has been written and verified readable.
    /// This is a logical deletion, not a guarantee of secure erase on flash storage.
    @discardableResult
    public static func migratePlaintextCatalogIfPresent(
        from legacyURL: URL,
        to vaultURL: URL,
        keyProvider: any MetadataKeyProvider
    ) throws -> Bool {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return false
        }

        guard !fileManager.fileExists(atPath: vaultURL.path) else {
            return false
        }

        let plaintext = try Data(contentsOf: legacyURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(CatalogSnapshot.self, from: plaintext)

        guard snapshot.version == CatalogSnapshot.currentVersion else {
            throw LocalDocsError.unsupportedSnapshotVersion(snapshot.version)
        }

        let encrypted = EncryptedCatalogPersistence(
            vaultURL: vaultURL,
            keyProvider: keyProvider
        )

        try encrypted.save(snapshot)

        guard let verified = try encrypted.load(),
              verified.canonicalRootPath == snapshot.canonicalRootPath,
              verified.documents.count == snapshot.documents.count else {
            throw LocalDocsError.invalidEncryptedEnvelope
        }

        try fileManager.removeItem(at: legacyURL)
        return true
    }
}

private struct EncryptedEnvelope: Codable, Sendable {
    let version: Int
    let algorithm: String
    let combined: Data
}
