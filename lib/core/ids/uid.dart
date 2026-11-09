import 'dart:math';

/// A random (version 4) UUID such as `3f2b8c1e-9d4a-4f6b-8e2a-1c5d7e9f0a3b`.
///
/// Uses a cryptographically secure source by default. Pass [random] only in
/// tests.
String generateUid([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final RegExp _uidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// True for a lower-case version 4 UUID, as produced by [generateUid].
bool isValidUid(String value) => _uidPattern.hasMatch(value);
