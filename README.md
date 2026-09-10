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
- deterministic temporary-file and access-lifecycle tests
- macOS CI
- CodeQL Swift

## Architecture

```text
selected local directory
        |
        v
security-scoped access lease
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

The core does not use `URLSession`, telemetry, analytics, remote storage, or a backend service.

## Metadata encryption

Catalog metadata is serialized locally and sealed with AES-256-GCM. Paths, tags, hashes, timestamps and catalog records are inside the authenticated ciphertext. The envelope exposes only its format version, algorithm identifier and sealed bytes.

By default `LocalDocsCatalog` uses `KeychainMetadataKeyProvider`, which keeps the 256-bit metadata key in the Apple Keychain. Tests use `InMemoryMetadataKeyProvider` so CI never depends on a user's Keychain.

The plaintext migration helper writes and verifies the encrypted vault before removing the legacy plaintext file. Removal is a logical filesystem deletion and is not advertised as secure erase on flash storage.

## Apple filesystem integration

`SecurityScopedAccessLease` wraps `startAccessingSecurityScopedResource()` and guarantees a balanced stop operation, including deinitialization fallback. The access controller is abstracted so lifecycle behavior is testable without requesting real sandbox permissions in CI.

On macOS, `SecurityScopedBookmark` exposes explicit bookmark creation and resolution with stale-bookmark reporting. Bookmark payloads remain outside the encrypted LocalDocs catalog, so host applications can decide where bookmark authorization state belongs.

These adapters do not bypass the Apple sandbox and do not request user permission themselves. A host application must obtain a user-selected URL through the appropriate Apple UI and then pass that URL into LocalDocs.

## Privacy boundary

LocalDocs encrypts its own catalog metadata at rest and performs no networking. It does **not** re-encrypt or copy the user's document files themselves; those remain under the host filesystem and Apple platform protections.

## Safety boundary

Symbolic links are skipped during indexing. This prevents an indexed link from silently walking outside the user-selected root.

## Build

Local development requires a Swift 6 toolchain on macOS:

```bash
swift test --parallel
swift test -c release --parallel
swift build -c release
```

The package declares macOS 13+ and iOS 16+ compatibility. Current CI evidence is macOS-based. Security-scoped bookmark helpers are intentionally exposed only where the platform API is supported by this package implementation.

## License

Apache-2.0
