import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/database_key.dart';

/// The cipher used for every journal database: ChaCha20 with Poly1305
/// authentication (SQLite3 Multiple Ciphers' "chacha20" scheme).
const String journalCipher = 'chacha20';

/// The first 16 bytes of every unencrypted SQLite database file.
const List<int> plaintextSqliteHeader = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, // "SQLite f"
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, // "ormat 3\0"
];

/// Raised when the linked SQLite has no encryption support. Opening must
/// stop: carrying on would write an unencrypted journal.
class EncryptionUnavailableException implements Exception {
  const EncryptionUnavailableException();

  @override
  String toString() => 'EncryptionUnavailableException';
}

/// Raised when the key does not open the database.
class WrongKeyException implements Exception {
  const WrongKeyException();

  @override
  String toString() => 'WrongKeyException';
}

/// Applies the key and safe connection settings to a newly opened SQLite
/// connection. Runs before any other statement, in every build mode, and
/// throws instead of continuing if anything is wrong.
///
/// Used as drift's `setup` callback, so it may run in a background isolate.
void applyEncryption(Database db, DatabaseKey key) {
  // 1. The cipher build must be loaded. Plain SQLite has no such function.
  // Checked on a separate in-memory connection: on an encrypted file, any
  // statement before the key would fail because the schema is unreadable.
  requireCipherBuild();

  // 2. Choose the cipher, then the key. PRAGMA values cannot be bound as
  // parameters; the key is a validated 64-character hex string, so there is
  // nothing to escape.
  db
    ..execute("PRAGMA cipher = '$journalCipher'")
    ..execute("PRAGMA hexkey = '${key.toHex()}'");

  // 3. PRAGMA key always reports success. Only reading the schema proves the
  // key is right.
  try {
    db.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException catch (e) {
    if (e.resultCode == _sqliteNotADb) throw const WrongKeyException();
    rethrow;
  }

  // 4. Keep temporary tables and indices in memory, never in temp files.
  db
    ..execute('PRAGMA temp_store = MEMORY')
    ..execute('PRAGMA foreign_keys = ON');
}

const int _sqliteNotADb = 26;

/// Throws [EncryptionUnavailableException] unless the process is using the
/// SQLite3 Multiple Ciphers build.
void requireCipherBuild() {
  final probe = sqlite3.openInMemory();
  try {
    final rows = probe.select("SELECT sqlite3mc_config('cipher') AS c");
    if (rows.isEmpty || rows.first['c'] == null) {
      throw const EncryptionUnavailableException();
    }
  } on SqliteException {
    throw const EncryptionUnavailableException();
  } finally {
    probe.close();
  }
}

/// Outcome of checking an existing database file without changing it.
enum DatabaseCheck {
  ok,
  wrongKey,

  /// The file is a plain, unencrypted SQLite database.
  notEncrypted,
  encryptionUnavailable,

  /// The file exists but cannot be read (for example truncated or not a
  /// database at all). Distinct from [wrongKey] only when SQLite can tell.
  unreadable,
}

/// True when [file] starts with the plaintext SQLite header.
Future<bool> hasPlaintextHeader(File file) async {
  if (!await file.exists()) return false;
  final raf = await file.open();
  try {
    final head = await raf.read(plaintextSqliteHeader.length);
    if (head.length < plaintextSqliteHeader.length) return false;
    for (var i = 0; i < head.length; i++) {
      if (head[i] != plaintextSqliteHeader[i]) return false;
    }
    return true;
  } finally {
    await raf.close();
  }
}

/// Checks that [file] is an encrypted journal that [key] opens. Never
/// creates or modifies the file. Runs in a short-lived isolate.
Future<DatabaseCheck> checkExistingDatabase(File file, DatabaseKey key) async {
  if (!await file.exists()) return DatabaseCheck.unreadable;
  if (await hasPlaintextHeader(file)) return DatabaseCheck.notEncrypted;
  final path = file.path;
  final keyBytes = key.bytes;
  return Isolate.run(() {
    final Database db;
    try {
      // readWrite (not readWriteCreate): a missing file is an error.
      db = sqlite3.open(path, mode: OpenMode.readWrite);
    } on SqliteException {
      return DatabaseCheck.unreadable;
    }
    try {
      applyEncryption(db, DatabaseKey(keyBytes));
      return DatabaseCheck.ok;
    } on EncryptionUnavailableException {
      return DatabaseCheck.encryptionUnavailable;
    } on WrongKeyException {
      return DatabaseCheck.wrongKey;
    } on SqliteException {
      return DatabaseCheck.unreadable;
    } finally {
      db.close();
    }
  });
}

/// A drift executor for the encrypted journal at [file], running on a
/// background isolate. Statements are never logged.
QueryExecutor openEncryptedExecutor(File file, DatabaseKey key) {
  final keyBytes = key.bytes;
  return NativeDatabase.createInBackground(
    file,
    setup: (db) => applyEncryption(db, DatabaseKey(keyBytes)),
  );
}
