# morrow: data protection

Status: M3, 7 November 2026. Covers the encrypted journal database and its key. App lock (M8), backup exclusions (M10) and encrypted backups (M11) are added later.

## Summary

- The journal is always encrypted, whether or not app lock is on.
- The key is 32 random bytes made on the phone and kept only in the platform's secure storage.
- The app refuses to open a journal it can't verify, and never replaces one automatically.
- This protects a journal file copied off the phone without its key. It doesn't protect against someone who can unlock the phone, a compromised OS, or forensic recovery of memory. Dart can't reliably wipe memory.

## Database

| Item | Choice |
|---|---|
| Library | `sqlite3` 3.9.0 with `hooks: user_defines: sqlite3: source: sqlite3mc` (SQLite3 Multiple Ciphers, MIT licence). The binary is downloaded at build time and checked against sha256 hashes shipped in the package. |
| Cipher | `chacha20` (ChaCha20 with Poly1305 authentication), set explicitly |
| Key | `PRAGMA hexkey` with the 32-byte key as hex. The key is never logged, and `DatabaseKey.toString()` is redacted. |
| Location | `<Application Support>/journal/journal.db`: app-private, not a cache folder, and not shown in the iOS Files app |
| Journal mode | SQLite's default rollback journal. Temporary storage is in memory (`PRAGMA temp_store = MEMORY`, and the build defaults to `SQLITE_TEMP_STORE=2`). |

Every connection runs `applyEncryption` before any other statement, in every build mode:

1. **Cipher build.** `sqlite3mc_config('cipher')` must exist. It's checked on a separate in-memory connection, because on an encrypted file any statement before the key fails.
2. **Cipher and key.** `PRAGMA cipher`, then `PRAGMA hexkey`.
3. **Key proof.** `SELECT count(*) FROM sqlite_master`. `PRAGMA key` reports success even with a wrong key, so only this read proves it. "Not a database" means a wrong key.
4. **Connection settings.** `temp_store = MEMORY` and `foreign_keys = ON`.

When the app opens or creates a journal, it also refuses any file that starts with the plain SQLite header (`SQLite format 3\0`). A newly created file is checked again after it's written. Existing files are opened only in read-write mode, never "create".

## Key storage (flutter_secure_storage 11.2.0)

| Platform | Options | Behaviour |
|---|---|---|
| Android | `resetOnError: false`, `migrateOnAlgorithmChange: false`, RSA-OAEP key wrapping with AES-GCM data (pinned), `storageNamespace: morrow_secure` | Keystore-backed. The plugin's default `resetOnError: true` would silently wipe storage on a read error, so it's off. Uninstalling removes the key. Backup and transfer exclusions are added in M10. |
| iOS | `accessibility: unlocked_this_device`, `synchronizable: false` | Readable only while the phone is unlocked. Never synced to iCloud Keychain and never moved to another device. **Keychain items survive uninstalling the app.** |

Stored items: `morrow.database_key.v1` (base64) and `morrow.setup_marker.v1` (`creating` or `ready`). The key is written, then read back and compared, before any database is created.

## Startup states (`DatabaseBootstrap`)

| Journal file | Stored key | Outcome |
|---|---|---|
| missing | none | First install: mark `creating`, make the key, create the journal, mark `ready` |
| missing | present, `creating` | Interrupted setup: resume with the same key |
| missing | present, `ready` or no marker | Reinstall (for example iOS kept the old key): discard the stale key and start fresh. Nothing exists to lose. *Decision, 7 November 2026.* |
| missing | damaged | Treated as a reinstall |
| present | present | Check, then open. Blocked if the key is wrong, the file is unencrypted, the cipher build is missing, or the file is unreadable |
| present | none or damaged | **Blocked: key missing** (screen 8.8). No new key is made |
| any | secure storage unreadable | **Blocked: storage unavailable.** Never treated as a first install |

Before creating a journal, the app deletes leftover `-journal`, `-wal` and `-shm` files, so SQLite can't replay a stale journal into the new database. A blocked state never changes the file or the key. Recovery is always an explicit user action, added in M10.

## What the tests prove (host, Windows, real SQLite3 Multiple Ciphers 3.54.0)

- The cipher build is loaded, and new journals are not plain SQLite.
- The correct key reopens and data persists. A wrong or missing key is blocked, with the file byte-for-byte unchanged and no key written.
- An unencrypted file is refused and left untouched.
- A synthetic marker string is absent from the database file, the rollback journal mid-transaction, and the `-wal` and `-shm` files in WAL mode. No other files appear next to the journal.
- Transactions roll back. The database's own CHECK constraints refuse out-of-range values.
- A mutation check: skipping `PRAGMA hexkey` makes 13 of these tests fail.

## Device evidence

- **Samsung Galaxy S20 (SM-G980F), Android 13, 7 November 2026.** The encryption self-check passed all 9 checks:
  - in a debug build, via `integration_test/encryption_self_check_test.dart`
  - in a release build made with `--dart-define=MORROW_DIAGNOSTICS=true`, run manually from Settings > Developer
- The release APK bundles `libsqlite3mc.so` for arm64-v8a, armeabi-v7a and x86_64, and requests no `INTERNET` permission.

## Not yet proven (needs a physical device)

- The same checks on an iPhone (needs a Mac to build).
- Secure storage behaviour after reboot, OS backup and restore, device transfer and reinstall (M10).
- Authentication-bound key access is **not** implemented. App lock (M8) is a gate in front of the app, not part of the key.
