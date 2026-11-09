import 'package:poop_tracker/core/security/database_key.dart';
import 'package:poop_tracker/core/security/key_store.dart';

/// In-memory [KeyStore] with switchable failures.
class FakeKeyStore implements KeyStore {
  FakeKeyStore({this.key, this.marker});

  DatabaseKey? key;
  SetupMarker? marker;

  /// The stored key is damaged and cannot be decoded.
  bool keyCorrupt = false;

  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  /// Reads after a write return a different key (storage silently lost it).
  bool loseWrites = false;

  int keyWrites = 0;
  int keyDeletes = 0;

  @override
  Future<DatabaseKey?> readDatabaseKey() async {
    if (failReads) throw const KeyStoreException('read key');
    if (keyCorrupt) throw const KeyStoreCorruptException();
    return key;
  }

  @override
  Future<void> writeDatabaseKey(DatabaseKey value) async {
    if (failWrites) throw const KeyStoreException('write key');
    keyWrites++;
    keyCorrupt = false;
    key = loseWrites ? null : value;
  }

  @override
  Future<void> deleteDatabaseKey() async {
    if (failDeletes) throw const KeyStoreException('delete key');
    keyDeletes++;
    keyCorrupt = false;
    key = null;
  }

  @override
  Future<SetupMarker?> readSetupMarker() async {
    if (failReads) throw const KeyStoreException('read marker');
    return marker;
  }

  @override
  Future<void> writeSetupMarker(SetupMarker value) async {
    if (failWrites) throw const KeyStoreException('write marker');
    marker = value;
  }

  @override
  Future<void> deleteSetupMarker() async {
    if (failDeletes) throw const KeyStoreException('delete marker');
    marker = null;
  }
}
