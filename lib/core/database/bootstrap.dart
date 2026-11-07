import 'dart:io';

import '../security/database_key.dart';
import '../security/key_store.dart';
import 'app_database.dart';
import 'encryption.dart';

/// Files SQLite may keep next to the database.
const List<String> companionSuffixes = ['-journal', '-wal', '-shm'];

/// Opens encrypted journal databases. An interface so startup logic can be
/// tested without native SQLite.
abstract interface class EncryptedDatabaseOpener {
  /// Checks an existing file without creating or changing it.
  Future<DatabaseCheck> check(File file, DatabaseKey key);

  /// Opens [file] with [key], creating it if it does not exist, and returns
  /// only once the key, schema and on-disk encryption are verified.
  Future<AppDatabase> open(File file, DatabaseKey key);
}

class SqliteDatabaseOpener implements EncryptedDatabaseOpener {
  const SqliteDatabaseOpener();

  @override
  Future<DatabaseCheck> check(File file, DatabaseKey key) =>
      checkExistingDatabase(file, key);

  @override
  Future<AppDatabase> open(File file, DatabaseKey key) async {
    final db = AppDatabase(openEncryptedExecutor(file, key));
    try {
      // Forces the connection setup (cipher check, key) and migrations.
      await db.customSelect('SELECT 1').get();
      // Belt and braces: the file on disk must not be plain SQLite.
      if (await file.exists() && await hasPlaintextHeader(file)) {
        throw const EncryptionUnavailableException();
      }
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }
}

/// Why the journal cannot be opened. Every case keeps existing files and
/// keys untouched; recovery is always an explicit user action.
enum StartupBlockReason {
  /// Secure storage could not be read or written. May work on retry.
  storageUnavailable,

  /// A journal exists but its key is gone (screen 8.8).
  keyMissing,

  /// A journal exists but the stored key does not open it.
  keyRejected,

  /// A journal file exists but is not encrypted. It is never used.
  notEncrypted,

  /// This build has no encryption support. Nothing is opened or created.
  encryptionUnavailable,

  /// A journal file exists but cannot be read.
  databaseUnreadable,

  /// Creating a new journal failed. Setup resumes on the next start.
  setupFailed,
}

sealed class StartupResult {
  const StartupResult();
}

final class StartupReady extends StartupResult {
  const StartupReady(this.database, {required this.createdNew});

  final AppDatabase database;

  /// True on a first install (or a reinstall that found no journal).
  final bool createdNew;
}

final class StartupBlocked extends StartupResult {
  const StartupBlocked(this.reason);

  final StartupBlockReason reason;

  @override
  String toString() => 'StartupBlocked($reason)';
}

/// Decides, at every launch, whether to create, open or refuse the journal.
///
/// | Journal file | Stored key            | Outcome                          |
/// |--------------|-----------------------|----------------------------------|
/// | missing      | none                  | first install: create            |
/// | missing      | present, "creating"   | interrupted setup: resume        |
/// | missing      | present, "ready"/none | reinstall: discard key, create   |
/// | missing      | unreadable/damaged    | blocked / reinstall (see below)  |
/// | present      | present               | open if the key checks out       |
/// | present      | none or damaged       | blocked: key missing             |
/// | any          | storage read fails    | blocked: storage unavailable     |
///
/// A missing journal means there is nothing to lose, so a stale key left by
/// a previous install (iOS keeps Keychain items after uninstall) is replaced.
/// An existing journal is never replaced, re-keyed or deleted here.
class DatabaseBootstrap {
  DatabaseBootstrap({
    required this.keyStore,
    required this.databaseFile,
    this.opener = const SqliteDatabaseOpener(),
    DatabaseKey Function()? generateKey,
  }) : _generateKey = generateKey ?? DatabaseKey.generate;

  final KeyStore keyStore;
  final Future<File> Function() databaseFile;
  final EncryptedDatabaseOpener opener;
  final DatabaseKey Function() _generateKey;

  Future<StartupResult> start() async {
    final file = await databaseFile();
    final exists = await file.exists();

    DatabaseKey? key;
    var keyDamaged = false;
    SetupMarker? marker;
    try {
      marker = await keyStore.readSetupMarker();
      key = await keyStore.readDatabaseKey();
    } on KeyStoreCorruptException {
      keyDamaged = true;
    } on KeyStoreException {
      return const StartupBlocked(StartupBlockReason.storageUnavailable);
    }

    if (exists) {
      if (key == null) {
        return const StartupBlocked(StartupBlockReason.keyMissing);
      }
      return _openExisting(file, key, marker);
    }

    // No journal on disk. Reuse a key only if setup was interrupted before
    // the database was created; otherwise start clean.
    final resume = key != null && !keyDamaged && marker == SetupMarker.creating;
    if (!resume && (key != null || keyDamaged || marker != null)) {
      try {
        await keyStore.deleteDatabaseKey();
        await keyStore.deleteSetupMarker();
      } on KeyStoreException {
        return const StartupBlocked(StartupBlockReason.storageUnavailable);
      }
      key = null;
    }
    return _create(file, resume ? key : null);
  }

  Future<StartupResult> _openExisting(
    File file,
    DatabaseKey key,
    SetupMarker? marker,
  ) async {
    switch (await opener.check(file, key)) {
      case DatabaseCheck.ok:
        break;
      case DatabaseCheck.wrongKey:
        return const StartupBlocked(StartupBlockReason.keyRejected);
      case DatabaseCheck.notEncrypted:
        return const StartupBlocked(StartupBlockReason.notEncrypted);
      case DatabaseCheck.encryptionUnavailable:
        return const StartupBlocked(StartupBlockReason.encryptionUnavailable);
      case DatabaseCheck.unreadable:
        return const StartupBlocked(StartupBlockReason.databaseUnreadable);
    }

    final AppDatabase db;
    try {
      db = await opener.open(file, key);
    } on EncryptionUnavailableException {
      return const StartupBlocked(StartupBlockReason.encryptionUnavailable);
    } on Object {
      return const StartupBlocked(StartupBlockReason.databaseUnreadable);
    }

    if (marker != SetupMarker.ready) {
      // Finishes an interrupted setup. If this write fails the journal still
      // opens; the marker only matters when no database file exists.
      try {
        await keyStore.writeSetupMarker(SetupMarker.ready);
      } on KeyStoreException {
        // Ignored on purpose, see above.
      }
    }
    return StartupReady(db, createdNew: false);
  }

  Future<StartupResult> _create(File file, DatabaseKey? existingKey) async {
    final DatabaseKey key;
    try {
      await keyStore.writeSetupMarker(SetupMarker.creating);
      if (existingKey != null) {
        key = existingKey;
      } else {
        key = _generateKey();
        await keyStore.writeDatabaseKey(key);
      }
      // Read the key back before creating anything that depends on it.
      final stored = await keyStore.readDatabaseKey();
      if (stored == null || !stored.sameAs(key)) {
        return const StartupBlocked(StartupBlockReason.storageUnavailable);
      }
    } on KeyStoreException {
      return const StartupBlocked(StartupBlockReason.storageUnavailable);
    } on KeyStoreCorruptException {
      return const StartupBlocked(StartupBlockReason.storageUnavailable);
    }

    // Leftover journal files from an old database must not be replayed into
    // the new one.
    await _deleteCompanions(file);
    await file.parent.create(recursive: true);

    final AppDatabase db;
    try {
      db = await opener.open(file, key);
    } on EncryptionUnavailableException {
      // Whatever was written is not safely encrypted and holds no entries.
      await _deleteDatabaseFiles(file);
      return const StartupBlocked(StartupBlockReason.encryptionUnavailable);
    } on Object {
      return const StartupBlocked(StartupBlockReason.setupFailed);
    }

    try {
      await keyStore.writeSetupMarker(SetupMarker.ready);
    } on KeyStoreException {
      // The journal works. A missing "ready" marker only means a later start
      // re-confirms it, which is harmless while the file exists.
    }
    return StartupReady(db, createdNew: true);
  }

  static Future<void> _deleteCompanions(File file) async {
    for (final suffix in companionSuffixes) {
      final f = File('${file.path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  static Future<void> _deleteDatabaseFiles(File file) async {
    if (await file.exists()) await file.delete();
    await _deleteCompanions(file);
  }
}
