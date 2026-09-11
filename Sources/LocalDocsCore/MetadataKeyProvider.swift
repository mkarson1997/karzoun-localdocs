import CryptoKit
import Foundation
import Security

public protocol MetadataKeyProvider: Sendable {
    func loadOrCreateKeyData() throws -> Data
}

public struct InMemoryMetadataKeyProvider: MetadataKeyProvider, Sendable {
    private let keyData: Data

    public init(keyData: Data? = nil) {
        if let keyData {
            precondition(keyData.count == 32, "LocalDocs metadata keys must be exactly 256 bits")
            self.keyData = keyData
        } else {
            let key = SymmetricKey(size: .bits256)
            self.keyData = key.withUnsafeBytes { Data($0) }
        }
    }

    public func loadOrCreateKeyData() throws -> Data {
        keyData
    }
}

public struct KeychainMetadataKeyProvider: MetadataKeyProvider, Sendable {
    public let service: String
    public let account: String

    public init(
        service: String = "dev.karzoun.localdocs.metadata",
        account: String = "catalog-key"
    ) {
        self.service = service
        self.account = account
    }

    public func loadOrCreateKeyData() throws -> Data {
        if let existing = try loadKeyData() {
            return try Self.validate(existing)
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: keyData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status == errSecSuccess {
            return keyData
        }

        if status == errSecDuplicateItem,
           let racedValue = try loadKeyData() {
            return try Self.validate(racedValue)
        }

        throw LocalDocsError.keychainFailure(status)
    }

    private func loadKeyData() throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw LocalDocsError.keychainReturnedInvalidData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw LocalDocsError.keychainFailure(status)
        }
    }

    private static func validate(_ data: Data) throws -> Data {
        guard data.count == 32 else {
            throw LocalDocsError.invalidMetadataKeyLength(data.count)
        }
        return data
    }
}
