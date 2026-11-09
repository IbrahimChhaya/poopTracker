import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_store.dart';

/// Whether the welcome (Figma 1.1) has been seen on this phone. Bootstrap
/// metadata, like the app-lock setting: kept in platform secure storage so
/// startup can decide before the journal opens.
abstract interface class WelcomeStore {
  /// Throws [KeyStoreException] if secure storage cannot be read.
  Future<bool> readSeen();

  Future<void> markSeen();
}

class SecureWelcomeStore implements WelcomeStore {
  SecureWelcomeStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: SecureStorageKeyStore.androidOptions,
            iOptions: SecureStorageKeyStore.iosOptions,
          );

  static const String _name = 'morrow.welcome_seen.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> readSeen() async {
    try {
      return await _storage.read(key: _name) == 'yes';
    } on PlatformException {
      throw const KeyStoreException('read welcome');
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await _storage.write(key: _name, value: 'yes');
    } on PlatformException {
      throw const KeyStoreException('write welcome');
    }
  }
}
