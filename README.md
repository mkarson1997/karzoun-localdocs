# Karzoun LocalDocs

LocalDocs is a privacy-first, local-only document catalog written in Swift for Apple applications.

It indexes a user-selected local directory, keeps document metadata on the device, detects exact-content duplicates with streaming SHA-256, preserves local tags across rescans, and provides metadata search without a server or network dependency.

## v0.1 core

- recursive regular-file indexing
- symbolic-link skipping at the selected-root boundary
- streaming SHA-256 fingerprints
- deterministic duplicate groups
- stable document IDs for unchanged relative paths
- tag preservation across rescans
- local path/tag search
- removal and content-change detection
- versioned JSON catalog snapshots
- atomic snapshot writes
- catalog-to-root binding
- restart reconstruction
- deterministic temporary-file tests
- macOS CI
- CodeQL Swift

## Architecture

```text
selected local directory
        |
        v
 DocumentIndexer
        |
        v
 LocalDocsCatalog (actor)
      /       \
  search     tags
      \       /
   CatalogPersistence
       |
       v
 local JSON snapshot
```

The core does not use `URLSession`, telemetry, analytics, remote storage, or a backend service.

## Privacy boundary

LocalDocs v0.1 keeps document contents and catalog metadata local. The catalog snapshot is **not yet encrypted at rest**. Encryption and an Apple Keychain-backed key adapter are separate roadmap milestones so the project does not make a privacy claim that the code has not earned yet.

## Safety boundary

Symbolic links are skipped during indexing. This prevents an indexed link from silently walking outside the user-selected root.

## Build

Local development requires a Swift 6 toolchain on macOS:

```bash
swift test --parallel
swift test -c release --parallel
swift build -c release
```

The package declares macOS 13+ and iOS 16+ compatibility. Current CI evidence is macOS-based; Apple-platform adapters are developed separately.

## License

Apache-2.0
