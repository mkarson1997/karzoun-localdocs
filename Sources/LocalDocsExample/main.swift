import Foundation
import LocalDocsCore

@main
struct LocalDocsExample {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            FileHandle.standardError.write(
                Data("Usage: localdocs-example <document-root> <vault-file>\n".utf8)
            )
            Foundation.exit(EXIT_FAILURE)
        }

        let root = URL(
            fileURLWithPath: CommandLine.arguments[1],
            isDirectory: true
        )
        let vault = URL(fileURLWithPath: CommandLine.arguments[2])

        let catalog = try LocalDocsCatalog(root: root, vaultURL: vault)
        let documents = try await catalog.refresh()
        let duplicateGroups = await catalog.duplicateGroups()

        print("Indexed documents: \(documents.count)")
        print("Duplicate groups: \(duplicateGroups.count)")

        for document in documents.prefix(20) {
            print("- \(document.relativePath) [\(document.sha256.prefix(12))…]")
        }
    }
}
