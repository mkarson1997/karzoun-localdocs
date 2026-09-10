# Karzoun LocalDocs v0.1.0

LocalDocs v0.1.0 is the first public release of a privacy-first, local-only document catalog for Apple applications.

## Highlights

- recursive local document indexing with regular-file-only policy
- streaming SHA-256 fingerprints and exact duplicate detection
- local tags and metadata search
- stable document identities across rescans
- authenticated AES-256-GCM encrypted catalog metadata
- Apple Keychain-backed metadata-key storage
- wrong-key and tamper rejection
- restart-safe encrypted metadata persistence
- safe migration from the legacy plaintext catalog
- Apple security-scoped URL access lease
- macOS security-scoped bookmark support with stale-bookmark reporting
- compiled SwiftPM example target
- deterministic macOS test suite and CodeQL Swift analysis

## Distribution

SwiftPM consumers use the `v0.1.0` Git tag directly. The GitHub Release additionally publishes a reviewed source archive plus `SHA256SUMS.txt` and a provenance attestation.

## Privacy boundary

LocalDocs has no runtime analytics, telemetry, remote storage, cloud sync, or backend dependency. It encrypts its own catalog metadata at rest. Original document files are not copied or re-encrypted by the library.

## Platform boundary

The package declares macOS 13+ and iOS 16+. Current automated build and test evidence runs on macOS. The security-scoped bookmark helper is macOS-specific; host applications remain responsible for Apple permission UI and sandbox entitlements.
