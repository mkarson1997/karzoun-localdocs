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

    /// Builds a stable, non-secret Keychain namespace from LocalDocs type identities.
    ///
    /// The service and account values identify the Keychain item; they are not
    /// credentials or cryptographic key material. Deriving them avoids embedding
    /// credential-looking literals in distributed source while remaining stable
    /// across launches of the same LocalDocs module.
    public init() {
        self.service = String(reflecting: KeychainMetadataKeyProvider.self)
        self.account = String(reflecting: CatalogSnapshot.self)
    }

    /// Allows a host application to choose its own non-secret Keychain namespace.
    public init(service: String, account: String) {
        precondition(!service.isEmpty, "Keychain service must not be empty")
        precondition(!account.isEmpty, "Keychain account must not be empty")
        self.service = service
        self.account = account
    }

    public func loadOrCreateKeyData() throws -> Data {
        if let existing = try loadKeyData() {
            return try Self.validate(existing)
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &accessControlError
        ) else {
            throw LocalDocsError.keychainAccessControlCreationFailed
        }

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: keyData,
            kSecAttrAccessControl: accessControl
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
