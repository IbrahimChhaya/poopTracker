import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/database/bootstrap.dart';
import '../core/database/database_location.dart';
import '../core/database/journal_reset.dart';
import '../core/security/key_store.dart';

// Root (always available) providers. None of these hold journal data; the
// database and everything that reads it live in the unlocked scope (see
// scope.dart). Tests override these with fakes.

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final keyStoreProvider = Provider<KeyStore>((ref) => SecureStorageKeyStore());

final databaseFileProvider = Provider<Future<File> Function()>(
  (ref) => journalDatabaseFile,
);

final databaseOpenerProvider = Provider<EncryptedDatabaseOpener>(
  (ref) => const SqliteDatabaseOpener(),
);

final databaseBootstrapProvider = Provider<DatabaseBootstrap>(
  (ref) => DatabaseBootstrap(
    keyStore: ref.watch(keyStoreProvider),
    databaseFile: ref.watch(databaseFileProvider),
    opener: ref.watch(databaseOpenerProvider),
  ),
);

final journalResetProvider = Provider<JournalReset>(
  (ref) => JournalReset(
    keyStore: ref.watch(keyStoreProvider),
    databaseFile: ref.watch(databaseFileProvider),
  ),
);
