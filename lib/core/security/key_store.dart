import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database_key.dart';

/// Progress of first-time setup, kept next to the key so startup can tell a
/// genuine first install from an interrupted one or a reinstall.
enum SetupMarker {
  /// Setup started; the key may or may not have been written yet.
  creating('creating'),

  /// The database was created and verified with the stored key.
  ready('ready');

  const SetupMarker(this.code);

  final String code;
}

/// Secure storage could not be read or written.
class KeyStoreException implements Exception {
  const KeyStoreException(this.operation);

  /// What failed, for example 'read key'. Never includes values.
  final String operation;

  @override
  String toString() => 'KeyStoreException($operation)';
}

/// A stored value exists but cannot be decoded.
class KeyStoreCorruptException implements Exception {
  const KeyStoreCorruptException();

  @override
  String toString() => 'KeyStoreCorruptException';
}

/// Platform secure storage for the database key and setup marker. Lives
/// outside the database so startup can decide what to do before opening it.
abstract interface class KeyStore {
  /// Null when no key is stored. Throws [KeyStoreException] if storage cannot
  /// be read and [KeyStoreCorruptException] if the value is damaged.
  Future<DatabaseKey?> readDatabaseKey();
  Future<void> writeDatabaseKey(DatabaseKey key);
  Future<void> deleteDatabaseKey();

  /// Null when no marker is stored or it is not recognised.
  Future<SetupMarker?> readSetupMarker();
  Future<void> writeSetupMarker(SetupMarker marker);
  Future<void> deleteSetupMarker();
}

/// [KeyStore] backed by the Android Keystore and the iOS Keychain.
class SecureStorageKeyStore implements KeyStore {
  SecureStorageKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: androidOptions,
            iOptions: iosOptions,
          );

  /// Android (flutter_secure_storage 11):
  /// - Never wipe storage on a read error (the plugin default is to reset,
  ///   which would silently destroy the key).
  /// - Pin the default ciphers (RSA-OAEP key wrapping, AES-GCM data) so a
  ///   future plugin default cannot trigger a migration.
  /// - A fixed storage name, so backup rules can exclude it (M10).
  static const AndroidOptions androidOptions = AndroidOptions(
    resetOnError: false,
    migrateOnAlgorithmChange: false,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    storageNamespace: 'morrow_secure',
  );

  /// iOS: readable only while the device is unlocked, never synchronised
  /// to iCloud Keychain and never moved to another device. Note that
  /// Keychain items survive uninstalling the app (handled at startup).
  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );

  static const String _keyName = 'morrow.database_key.v1';
  static const String _markerName = 'morrow.setup_marker.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<DatabaseKey?> readDatabaseKey() async {
    final String? stored;
    try {
      stored = await _storage.read(key: _keyName);
    } on PlatformException {
      throw const KeyStoreException('read key');
    }
    if (stored == null) return null;
    try {
      return DatabaseKey.decode(stored);
    } on FormatException {
      throw const KeyStoreCorruptException();
    }
  }

  @override
  Future<void> writeDatabaseKey(DatabaseKey key) => _guard(
    'write key',
    () => _storage.write(key: _keyName, value: key.encode()),
  );

  @override
  Future<void> deleteDatabaseKey() =>
      _guard('delete key', () => _storage.delete(key: _keyName));

  @override
  Future<SetupMarker?> readSetupMarker() async {
    final String? stored;
    try {
      stored = await _storage.read(key: _markerName);
    } on PlatformException {
      throw const KeyStoreException('read marker');
    }
    for (final m in SetupMarker.values) {
      if (m.code == stored) return m;
    }
    return null;
  }

  @override
  Future<void> writeSetupMarker(SetupMarker marker) => _guard(
    'write marker',
    () => _storage.write(key: _markerName, value: marker.code),
  );

  @override
  Future<void> deleteSetupMarker() =>
      _guard('delete marker', () => _storage.delete(key: _markerName));

  Future<void> _guard(String operation, Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException {
      throw KeyStoreException(operation);
    }
  }
}
