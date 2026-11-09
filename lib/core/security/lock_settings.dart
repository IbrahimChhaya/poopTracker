import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_store.dart';

/// Whether app lock is on. Security bootstrap metadata: kept in platform
/// secure storage (not the journal database) so startup can decide whether
/// to ask before the journal opens.
abstract interface class LockSettingsStore {
  /// Throws [KeyStoreException] if secure storage cannot be read.
  Future<bool> readEnabled();

  Future<void> writeEnabled(bool enabled);
}

class SecureLockSettings implements LockSettingsStore {
  SecureLockSettings([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: SecureStorageKeyStore.androidOptions,
            iOptions: SecureStorageKeyStore.iosOptions,
          );

  static const String _name = 'morrow.app_lock.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> readEnabled() async {
    try {
      return await _storage.read(key: _name) == 'on';
    } on PlatformException {
      throw const KeyStoreException('read app lock');
    }
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    try {
      if (enabled) {
        await _storage.write(key: _name, value: 'on');
      } else {
        await _storage.delete(key: _name);
      }
    } on PlatformException {
      throw const KeyStoreException('write app lock');
    }
  }
}
