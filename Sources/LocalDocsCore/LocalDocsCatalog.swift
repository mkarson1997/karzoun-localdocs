import Foundation

public actor LocalDocsCatalog {
    public let root: URL
    public let snapshotURL: URL

    private let canonicalRootPath: String
    private let persistence: CatalogPersistence
    private var documentsByPath: [String: DocumentRecord]

    public init(root: URL, snapshotURL: URL) throws {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: canonicalRoot.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw LocalDocsError.rootIsNotDirectory(canonicalRoot.path)
        }

        let persistence = CatalogPersistence(snapshotURL: snapshotURL)
        let loadedSnapshot = try persistence.load()

        if let snapshot = loadedSnapshot,
           snapshot.canonicalRootPath != canonicalRoot.path {
            throw LocalDocsError.catalogRootMismatch(
                expected: canonicalRoot.path,
                found: snapshot.canonicalRootPath
            )
        }

        self.root = canonicalRoot
        self.snapshotURL = snapshotURL
        self.canonicalRootPath = canonicalRoot.path
        self.persistence = persistence
        self.documentsByPath = Dictionary(
            uniqueKeysWithValues: (loadedSnapshot?.documents ?? []).map {
                ($0.relativePath, $0)
            }
        )
    }

    @discardableResult
    public func refresh(now: Date = Date()) throws -> [DocumentRecord] {
        let scanned = try DocumentIndexer.scan(root: root)
        var next: [String: DocumentRecord] = [:]

        for file in scanned {
            if let existing = documentsByPath[file.relativePath] {
                next[file.relativePath] = DocumentRecord(
                    id: existing.id,
                    relativePath: file.relativePath,
                    byteCount: file.byteCount,
                    modifiedAt: file.modifiedAt,
                    sha256: file.sha256,
                    tags: existing.tags,
                    firstIndexedAt: existing.firstIndexedAt,
                    lastIndexedAt: now
                )
            } else {
                next[file.relativePath] = DocumentRecord(
                    id: DocumentID(),
                    relativePath: file.relativePath,
                    byteCount: file.byteCount,
                    modifiedAt: file.modifiedAt,
                    sha256: file.sha256,
                    tags: [],
                    firstIndexedAt: now,
                    lastIndexedAt: now
                )
            }
        }

        documentsByPath = next
        try persist(now: now)
        return sortedDocuments()
    }

    public func allDocuments() -> [DocumentRecord] {
        sortedDocuments()
    }

    public func document(relativePath: String) -> DocumentRecord? {
        documentsByPath[relativePath]
    }

    public func addTag(
        _ tag: String,
        toRelativePath relativePath: String,
        now: Date = Date()
    ) throws {
        let normalized = Self.normalizeTag(tag)
        guard !normalized.isEmpty,
              let existing = documentsByPath[relativePath] else {
            return
        }

        var tags = existing.tags
        tags.insert(normalized)

        documentsByPath[relativePath] = DocumentRecord(
            id: existing.id,
            relativePath: existing.relativePath,
            byteCount: existing.byteCount,
            modifiedAt: existing.modifiedAt,
            sha256: existing.sha256,
            tags: tags,
            firstIndexedAt: existing.firstIndexedAt,
            lastIndexedAt: existing.lastIndexedAt
        )

        try persist(now: now)
    }

    public func removeTag(
        _ tag: String,
        fromRelativePath relativePath: String,
        now: Date = Date()
    ) throws {
        let normalized = Self.normalizeTag(tag)
        guard let existing = documentsByPath[relativePath] else {
            return
        }

        var tags = existing.tags
        tags.remove(normalized)

        documentsByPath[relativePath] = DocumentRecord(
            id: existing.id,
            relativePath: existing.relativePath,
            byteCount: existing.byteCount,
            modifiedAt: existing.modifiedAt,
            sha256: existing.sha256,
            tags: tags,
            firstIndexedAt: existing.firstIndexedAt,
            lastIndexedAt: existing.lastIndexedAt
        )

        try persist(now: now)
    }

    public func search(_ query: String) -> [DocumentRecord] {
        let needle = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !needle.isEmpty else {
            return sortedDocuments()
        }

        return documentsByPath.values
            .filter { record in
                record.relativePath.lowercased().contains(needle) ||
                record.tags.contains(where: { $0.lowercased().contains(needle) })
            }
            .sorted {
                $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
            }
    }

    public func duplicateGroups() -> [[DocumentRecord]] {
        Dictionary(grouping: documentsByPath.values, by: \.sha256)
            .values
            .filter { $0.count > 1 }
            .map { group in
                group.sorted {
                    $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
                }
            }
            .sorted {
                ($0.first?.relativePath ?? "") < ($1.first?.relativePath ?? "")
            }
    }

    private func sortedDocuments() -> [DocumentRecord] {
        documentsByPath.values.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    private func persist(now: Date) throws {
        try persistence.save(
            CatalogSnapshot(
                canonicalRootPath: canonicalRootPath,
                savedAt: now,
                documents: sortedDocuments()
            )
        )
    }

    private static func normalizeTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
