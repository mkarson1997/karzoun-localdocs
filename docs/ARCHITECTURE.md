# LocalDocs Architecture

## Design goal

LocalDocs keeps document organization logic local to the Apple device and separates filesystem authorization, indexing, metadata persistence, encryption, and host UI concerns.

## Components

### `DocumentIndexer`

Walks the selected root, skips symbolic links, accepts regular files only, computes streaming SHA-256 digests, and returns deterministic relative-path metadata.

### `LocalDocsCatalog`

Actor-isolated catalog state. It reconciles rescans with prior metadata, preserves stable document identity and tags, supports metadata search and duplicate grouping, and delegates persistence to the encrypted catalog store.

### `EncryptedCatalogPersistence`

Serializes the versioned catalog snapshot and seals it with AES-256-GCM before an atomic filesystem write. Loading authenticates the ciphertext before decoding catalog records.

### `MetadataKeyProvider`

Abstracts 256-bit metadata-key storage. Production Apple hosts can use `KeychainMetadataKeyProvider`; deterministic tests use the in-memory provider.

### `SecurityScopedAccessLease`

Wraps Apple security-scoped resource access in an explicitly balanced lifecycle. The host application remains responsible for presenting Apple's folder/document picker and providing the granted URL.

### `SecurityScopedBookmark`

macOS adapter for creating and resolving security-scoped bookmarks. Staleness is reported to the caller instead of silently replacing authorization state.

## Data flow

```text
Apple host UI
   |
   | user grants folder URL
   v
SecurityScopedAccessLease / bookmark adapter
   |
   v
DocumentIndexer
   |
   v
LocalDocsCatalog
   |             \
   |              -> metadata search / duplicate groups / tags
   v
EncryptedCatalogPersistence
   |
AES-256-GCM
   |
   +---- MetadataKeyProvider ----> Apple Keychain
   |
   v
local encrypted vault file
```

## Persistence model

The catalog stores relative paths, content hashes, file metadata, stable IDs, tags, and indexing timestamps. The persisted snapshot is versioned and bound to the canonical selected root. The encrypted envelope is also versioned so future format migrations can be explicit.

The original documents remain where the host filesystem keeps them. LocalDocs does not copy document contents into its metadata vault.

## Concurrency

Catalog state is protected by a Swift actor. Filesystem enumeration and hashing are currently synchronous inside a refresh cycle, which keeps v0.1 semantics deterministic. Incremental change observation and background scheduling are future optimization work rather than hidden behavior in this release.

## Non-goals for v0.1

- cloud synchronization
- remote search or indexing
- document-content encryption
- OCR or semantic embeddings
- Finder replacement UI
- sandbox bypass
- secure erase of flash storage
