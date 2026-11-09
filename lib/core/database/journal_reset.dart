import 'dart:io';

import '../security/key_store.dart';
import 'bootstrap.dart';

/// Permanently erases the journal and its key ("Erase and start fresh").
///
/// Only ever run after the user explicitly confirms. Order matters so an
/// interruption is safe: the database files go first, then the key. If the
/// app stops in between, the next start finds no journal and a stale key,
/// which startup treats as a fresh install. Nothing half-deleted is ever
/// opened.
class JournalReset {
  JournalReset({required this.keyStore, required this.databaseFile});

  final KeyStore keyStore;
  final Future<File> Function() databaseFile;

  /// Throws [FileSystemException] or [KeyStoreException] if something could
  /// not be removed; calling again resumes.
  Future<void> eraseAll() async {
    final file = await databaseFile();
    if (await file.exists()) await file.delete();
    for (final suffix in companionSuffixes) {
      final f = File('${file.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    await keyStore.deleteDatabaseKey();
    await keyStore.deleteSetupMarker();
  }
}
