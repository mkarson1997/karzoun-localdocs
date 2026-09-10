# Changelog

All notable changes to Karzoun LocalDocs are documented here.

## [0.1.0] - 2026-09-10

### Added

- privacy-first local document catalog written in Swift
- recursive regular-file indexing for a user-selected local root
- streaming SHA-256 fingerprints and exact duplicate grouping
- stable document identity for persistent relative paths
- local tags and metadata search
- removal and content-change detection
- versioned catalog snapshots with atomic writes
- catalog-to-root binding and restart reconstruction
- symbolic-link skipping at the selected-root boundary
- authenticated AES-256-GCM metadata vaults
- 256-bit metadata key abstraction
- Apple Keychain-backed metadata-key storage
- deterministic in-memory key provider for tests
- wrong-key and ciphertext-tamper rejection
- migration from the legacy plaintext catalog only after encrypted-write verification
- Apple security-scoped URL access lease with balanced lifecycle handling
- macOS security-scoped bookmark creation and resolution with stale-bookmark reporting
- compiled `localdocs-example` executable target
- deterministic macOS debug/release test coverage
- CodeQL Swift analysis
- tag-driven GitHub Release validation and publication

### Security and privacy boundaries

- LocalDocs performs no runtime networking, analytics, telemetry, or cloud synchronization.
- LocalDocs encrypts catalog metadata, not the user's original document files.
- Security-scoped access adapters do not request permission or bypass the Apple sandbox.
- Legacy plaintext catalog removal is a logical filesystem deletion, not a secure-erase claim for flash storage.
