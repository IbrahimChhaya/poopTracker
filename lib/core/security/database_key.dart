import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// The per-installation key for the journal database: 32 random bytes.
///
/// Generated on the device with a cryptographically secure source, stored
/// only in platform secure storage, and never logged. Dart cannot reliably
/// wipe memory, so copies may remain in memory until the app exits.
final class DatabaseKey {
  DatabaseKey(List<int> bytes) : bytes = Uint8List.fromList(bytes) {
    if (bytes.length != length) {
      throw ArgumentError('A database key is $length bytes');
    }
  }

  /// A new random key from [Random.secure]. Pass [random] only in tests.
  factory DatabaseKey.generate([Random? random]) {
    final r = random ?? Random.secure();
    return DatabaseKey(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  /// Decodes the form written by [encode]. Throws [FormatException] if the
  /// stored value is damaged.
  factory DatabaseKey.decode(String stored) {
    final bytes = base64.decode(stored);
    if (bytes.length != length) {
      throw const FormatException('Stored database key has the wrong length');
    }
    return DatabaseKey(bytes);
  }

  static const int length = 32;

  final Uint8List bytes;

  /// The form kept in secure storage.
  String encode() => base64.encode(bytes);

  /// Lower-case hex, as used by `PRAGMA hexkey`.
  String toHex() =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  bool sameAs(DatabaseKey other) {
    if (other.bytes.length != bytes.length) return false;
    var diff = 0;
    for (var i = 0; i < bytes.length; i++) {
      diff |= bytes[i] ^ other.bytes[i];
    }
    return diff == 0;
  }

  // Never print key material.
  @override
  String toString() => 'DatabaseKey(redacted)';
}
