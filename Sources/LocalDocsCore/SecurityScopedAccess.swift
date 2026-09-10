import Foundation

public enum SecurityScopedAccessError: Error, Equatable, Sendable {
    case accessDenied(String)
    case staleBookmark
}

public protocol SecurityScopedURLControlling: Sendable {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

public struct FoundationSecurityScopedURLController: SecurityScopedURLControlling {
    public init() {}

    public func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

public final class SecurityScopedAccessLease: @unchecked Sendable {
    public let url: URL

    private let controller: any SecurityScopedURLControlling
    private let lock = NSLock()
    private var active: Bool

    public init(
        url: URL,
        controller: any SecurityScopedURLControlling = FoundationSecurityScopedURLController()
    ) throws {
        self.url = url
        self.controller = controller

        guard controller.startAccessing(url) else {
            self.active = false
            throw SecurityScopedAccessError.accessDenied(url.path)
        }

        self.active = true
    }

    deinit {
        stop()
    }

    public func withAccess<T>(_ operation: (URL) throws -> T) rethrows -> T {
        try operation(url)
    }

    public func stop() {
        lock.lock()
        let shouldStop = active
        active = false
        lock.unlock()

        if shouldStop {
            controller.stopAccessing(url)
        }
    }
}

#if os(macOS)
public struct SecurityScopedBookmarkResolution: Equatable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

public enum SecurityScopedBookmark {
    public static func create(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public static func resolve(_ data: Data) throws -> SecurityScopedBookmarkResolution {
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )

        return SecurityScopedBookmarkResolution(url: url, isStale: stale)
    }
}
#endif
