import Foundation
import XCTest
@testable import LocalDocsCore

final class LocalDocsCoreTests: XCTestCase {
    func testRefreshIndexesRegularFilesAndProducesSHA256() async throws {
        let fixture = try Fixture()
        try fixture.write("alpha", to: "docs/a.txt")
        try fixture.write("beta", to: "b.txt")

        let catalog = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        let documents = try await catalog.refresh(now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(documents.map(\.relativePath), ["b.txt", "docs/a.txt"])
        XCTAssertTrue(documents.allSatisfy { $0.sha256.count == 64 })
    }

    func testDuplicateGroupingUsesExactSHA256() async throws {
        let fixture = try Fixture()
        try fixture.write("same", to: "one.txt")
        try fixture.write("same", to: "nested/two.txt")
        try fixture.write("different", to: "three.txt")

        let catalog = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await catalog.refresh()
        let groups = await catalog.duplicateGroups()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].map(\.relativePath)), Set(["one.txt", "nested/two.txt"]))
    }

    func testTagsSurviveRefreshAndRestart() async throws {
        let fixture = try Fixture()
        try fixture.write("report", to: "report.txt")

        let first = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await first.refresh(now: Date(timeIntervalSince1970: 10))
        try await first.addTag(" Finance ", toRelativePath: "report.txt")
        let before = await first.document(relativePath: "report.txt")

        let second = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await second.refresh(now: Date(timeIntervalSince1970: 20))
        let after = await second.document(relativePath: "report.txt")

        XCTAssertEqual(after?.tags, Set(["finance"]))
        XCTAssertEqual(after?.id, before?.id)
    }

    func testContentChangePreservesIdentityAndTags() async throws {
        let fixture = try Fixture()
        try fixture.write("v1", to: "doc.txt")

        let catalog = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await catalog.refresh()
        try await catalog.addTag("important", toRelativePath: "doc.txt")
        let before = await catalog.document(relativePath: "doc.txt")

        try fixture.write("v2 changed", to: "doc.txt")
        _ = try await catalog.refresh()
        let after = await catalog.document(relativePath: "doc.txt")

        XCTAssertEqual(after?.id, before?.id)
        XCTAssertEqual(after?.tags, before?.tags)
        XCTAssertNotEqual(after?.sha256, before?.sha256)
    }

    func testRemovedFileDisappears() async throws {
        let fixture = try Fixture()
        try fixture.write("keep", to: "keep.txt")
        try fixture.write("remove", to: "remove.txt")

        let catalog = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await catalog.refresh()

        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("remove.txt"))
        _ = try await catalog.refresh()

        let documents = await catalog.allDocuments()
        XCTAssertEqual(documents.map(\.relativePath), ["keep.txt"])
    }

    func testSearchMatchesPathAndTagCaseInsensitively() async throws {
        let fixture = try Fixture()
        try fixture.write("x", to: "Invoices/April.pdf")
        try fixture.write("y", to: "notes.txt")

        let catalog = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await catalog.refresh()
        try await catalog.addTag("LEGAL", toRelativePath: "notes.txt")

        let pathResults = await catalog.search("april")
        let tagResults = await catalog.search("legal")

        XCTAssertEqual(pathResults.map(\.relativePath), ["Invoices/April.pdf"])
        XCTAssertEqual(tagResults.map(\.relativePath), ["notes.txt"])
    }

    func testCatalogSnapshotIsBoundToCanonicalRoot() async throws {
        let first = try Fixture()
        let second = try Fixture()
        try first.write("x", to: "doc.txt")

        let firstCatalog = try LocalDocsCatalog(root: first.root, snapshotURL: first.snapshot)
        _ = try await firstCatalog.refresh()

        XCTAssertThrowsError(
            try LocalDocsCatalog(root: second.root, snapshotURL: first.snapshot)
        ) { error in
            guard case LocalDocsError.catalogRootMismatch = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testSymlinkOutsideRootIsSkipped() async throws {
        let fixture = try Fixture()
        let outside = fixture.base.appendingPathComponent("outside-secret.txt")
        try Data("secret".utf8).write(to: outside)

        let link = fixture.root.appendingPathComponent("linked-secret.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        try fixture.write("inside", to: "inside.txt")

        let catalog = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await catalog.refresh()

        let documents = await catalog.allDocuments()
        XCTAssertEqual(documents.map(\.relativePath), ["inside.txt"])
    }

    func testSnapshotIsValidVersionedJSON() async throws {
        let fixture = try Fixture()
        try fixture.write("x", to: "doc.txt")

        let catalog = try LocalDocsCatalog(root: fixture.root, snapshotURL: fixture.snapshot)
        _ = try await catalog.refresh(now: Date(timeIntervalSince1970: 123))

        let snapshot = try CatalogPersistence(snapshotURL: fixture.snapshot).load()
        XCTAssertEqual(snapshot?.version, CatalogSnapshot.currentVersion)
        XCTAssertEqual(snapshot?.documents.count, 1)
        XCTAssertEqual(snapshot?.canonicalRootPath, fixture.root.path)
    }
}

private final class Fixture {
    let base: URL
    let root: URL
    let snapshot: URL

    init() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        root = base.appendingPathComponent("documents", isDirectory: true)
        snapshot = base
            .appendingPathComponent("metadata", isDirectory: true)
            .appendingPathComponent("catalog.json")

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: base)
    }

    func write(_ content: String, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(content.utf8).write(to: url)
    }
}
