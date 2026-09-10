# Karzoun LocalDocs

LocalDocs is a privacy-first, local-only document catalog written in Swift for Apple applications.

It indexes a user-selected local directory, keeps document metadata on the device, detects exact-content duplicates with streaming SHA-256, preserves local tags across rescans, and provides metadata search without a server or network dependency.

## Current capabilities

- recursive regular-file indexing
- symbolic-link skipping at the selected-root boundary
- streaming SHA-256 fingerprints
- deterministic duplicate groups
- stable document IDs for unchanged relative paths
- tag preservation across rescans
- local path/tag search
- removal and content-change detection
- authenticated AES-256-GCM metadata vaults
- Apple Keychain-backed metadata-key storage
- atomic encrypted vault writes
- wrong-key and tamper rejection
- versioned catalog and encrypted-envelope formats
- catalog-to-root binding
- restart reconstruction
- migration from the legacy plaintext catalog after encrypted-write verification
- security-scoped URL access lease with balanced lifecycle semantics
- macOS security-scoped bookmark creation and resolution
- compiled `localdocs-example` target
- deterministic temporary-file and access-lifecycle tests
- macOS CI
- CodeQL Swift

## Install with Swift Package Manager

Pin the package to the `v0.1.0` release tag:

```swift
dependencies: [
    .package(
        url: "https://github.com/mkarson1997/karzoun-localdocs.git",
        from: "0.1.0"
    )
]
```

Then add `LocalDocsCore` to the target that owns your document workflow.

## Minimal catalog usage

```swift
import Foundation
import LocalDocsCore

let root = URL(fileURLWithPath: "/path/to/documents", isDirectory: true)
let vault = URL(fileURLWithPath: "/path/to/localdocs.vault")

let catalog = try LocalDocsCatalog(root: root, vaultURL: vault)
let documents = try await catalog.refresh()
let duplicateGroups = await catalog.duplicateGroups()

print("Indexed: \(documents.count)")
print("Duplicate groups: \(duplicateGroups.count)")
```

The default metadata key provider stores the 256-bit catalog key in Apple Keychain. Tests or specialized hosts can inject another `MetadataKeyProvider`.

## Compiled example

On macOS with Swift 6:

```bash
swift run localdocs-example /path/to/documents /path/to/localdocs.vault
```

The example performs a local refresh and prints document and duplicate counts. It does not upload data.

## Architecture

```text
Apple host UI
        |
        v
security-scoped access lease / bookmark
        |
        v
 DocumentIndexer
        |
        v
 LocalDocsCatalog (actor)
      /       \
  search     tags
      \       /
EncryptedCatalogPersistence
       |            \
       v             v
AES-256-GCM    MetadataKeyProvider
                     |
              Apple Keychain
```

See `docs/ARCHITECTURE.md` for component and data-flow details and `docs/THREAT_MODEL.md` for trust boundaries, mitigations, and residual risks.

## Metadata encryption

Catalog metadata is serialized locally and sealed with AES-256-GCM. Paths, tags, hashes, timestamps and catalog records are inside authenticated ciphertext. The envelope exposes only its format version, algorithm identifier and sealed bytes.

By default `LocalDocsCatalog` uses `KeychainMetadataKeyProvider`, which keeps the 256-bit metadata key in Apple Keychain. Tests use `InMemoryMetadataKeyProvider` so CI never depends on a user's real Keychain.

The plaintext migration helper writes and verifies the encrypted vault before removing the legacy plaintext file. Removal is a logical filesystem deletion and is not advertised as secure erase on flash storage.

## Apple filesystem integration

`SecurityScopedAccessLease` wraps Apple security-scoped resource access and balances a successful start with exactly one stop, including a deinitialization fallback. The access controller is abstracted so lifecycle behavior is testable without requesting real sandbox permissions in CI.

On macOS, `SecurityScopedBookmark` exposes explicit bookmark creation and resolution with stale-bookmark reporting. Bookmark payloads remain outside the encrypted LocalDocs catalog so host applications can decide where authorization state belongs.

These adapters do not bypass the Apple sandbox and do not request user permission themselves. A host application must obtain a user-selected URL through the appropriate Apple UI and then pass that URL into LocalDocs.

## Privacy boundary

LocalDocs encrypts its own catalog metadata at rest and performs no runtime networking. It does **not** re-encrypt or copy the user's document files themselves; those remain under the host filesystem and Apple platform protections.

## Safety boundary

Symbolic links are skipped during indexing. This prevents an indexed link from silently walking outside the user-selected root.

## Build and verify

Local development requires a Swift 6 toolchain on macOS:

```bash
swift test --parallel
swift test -c release --parallel
swift build -c release
```

The package declares macOS 13+ and iOS 16+ compatibility. Current automated CI evidence is macOS-based. Security-scoped bookmark helpers are intentionally exposed only where the platform API is supported by this package implementation.

## Release integrity

Each tagged GitHub Release publishes a reviewed source archive, `SHA256SUMS.txt`, and a build provenance attestation. SwiftPM consumers use the Git tag directly.

## License

Apache-2.0
