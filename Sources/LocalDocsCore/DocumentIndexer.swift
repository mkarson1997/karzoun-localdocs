import CryptoKit
import Foundation

public enum DocumentIndexer {
    public static func scan(root: URL) throws -> [IndexedFile] {
        let fileManager = FileManager.default
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: canonicalRoot.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LocalDocsError.rootIsNotDirectory(canonicalRoot.path)
        }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: canonicalRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        let rootPrefix = canonicalRoot.path.hasSuffix("/")
            ? canonicalRoot.path
            : canonicalRoot.path + "/"

        var results: [IndexedFile] = []

        while let item = enumerator.nextObject() as? URL {
            let values = try item.resourceValues(forKeys: Set(keys))

            if values.isSymbolicLink == true {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true else {
                continue
            }

            let standardized = item.standardizedFileURL
            guard standardized.path.hasPrefix(rootPrefix) else {
                continue
            }

            let relativePath = String(standardized.path.dropFirst(rootPrefix.count))
            guard !relativePath.isEmpty,
                  !relativePath.hasPrefix("../"),
                  relativePath != ".." else {
                throw LocalDocsError.invalidRelativePath(relativePath)
            }

            results.append(
                IndexedFile(
                    relativePath: relativePath,
                    byteCount: Int64(values.fileSize ?? 0),
                    modifiedAt: values.contentModificationDate ?? .distantPast,
                    sha256: try sha256(url: standardized)
                )
            )
        }

        return results.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    private static func sha256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
