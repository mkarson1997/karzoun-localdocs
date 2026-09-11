# LocalDocs Threat Model

## Assets

- document catalog metadata: relative paths, tags, hashes, timestamps, stable IDs
- metadata encryption key
- persisted security-scoped bookmark data
- user-selected local filesystem root

## Trust boundaries

### Host application

The host owns permission prompts, sandbox entitlements, UI, backup policy, and the lifecycle around user-selected URLs. LocalDocs is distributed as a library and does not expose a CLI that turns arbitrary command-line strings into filesystem read/write targets.

### LocalDocs core

The core indexes only the selected local root, maintains metadata, and encrypts its catalog. It performs no runtime networking.

### Apple Keychain

The default metadata key provider stores the 256-bit catalog key in the Apple Keychain using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The encrypted catalog does not persist the raw key.

### Filesystem

Original user documents remain in the host filesystem. LocalDocs does not claim to encrypt those files.

## Threats and mitigations

### Plaintext metadata disclosure

**Threat:** a copied catalog file reveals sensitive filenames, tags, hashes, or timestamps.

**Mitigation:** catalog snapshots are sealed with AES-256-GCM before persistence; tests verify representative metadata strings are absent from persisted ciphertext.

### Catalog tampering

**Threat:** an attacker alters the encrypted metadata vault.

**Mitigation:** AES-GCM authentication rejects modified ciphertext before catalog decoding.

### Wrong-key use

**Threat:** a vault is opened with unrelated key material.

**Mitigation:** authenticated decryption fails rather than returning partially decoded state.

### Metadata-key exposure while locked

**Threat:** a background process attempts to retrieve the catalog key while the device is locked.

**Mitigation:** the default Keychain item uses the this-device-only, when-unlocked accessibility class.

### Symlink escape

**Threat:** indexing follows a symbolic link outside the user-selected root.

**Mitigation:** symbolic links are skipped by the indexer and are covered by deterministic tests.

### Catalog/root confusion

**Threat:** metadata for one selected directory is accidentally reused with another.

**Mitigation:** catalog snapshots persist the canonical root path and reject root mismatches after authenticated decryption.

### Untrusted path injection

**Threat:** a convenience executable accepts arbitrary external path strings and turns them directly into filesystem read/write targets.

**Mitigation:** v0.1 ships only the Swift library. Host applications obtain filesystem URLs through their own Apple permission UI and security-scoped access flow.

### Leaked security-scoped access

**Threat:** a host starts Apple security-scoped access but fails to stop it.

**Mitigation:** `SecurityScopedAccessLease` balances successful start/stop calls and includes a deinitialization fallback.

### Stale bookmark confusion

**Threat:** a stale security-scoped bookmark is silently treated as current authorization.

**Mitigation:** bookmark resolution reports staleness explicitly to the caller.

### Plaintext migration loss

**Threat:** a legacy plaintext catalog is deleted before the encrypted replacement is valid.

**Mitigation:** migration writes and verifies the encrypted vault before removing the legacy file.

### Release artifact path manipulation

**Threat:** an unexpected tag-derived version string influences archive paths in release automation.

**Mitigation:** the release workflow validates the derived version against a constrained version pattern before using it in artifact paths.

## Residual risks and non-claims

- Compromise of the unlocked host process or device can expose data in memory.
- LocalDocs does not encrypt the user's original document contents.
- Logical file deletion is not secure erase on flash storage.
- Keychain protection depends on the Apple device and host application's security configuration.
- v0.1 uses full refresh scans rather than a filesystem event stream.
- LocalDocs does not provide malware scanning, DLP, OCR, or remote backup.
