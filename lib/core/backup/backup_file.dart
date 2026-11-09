import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// The encrypted backup file, format version 1 (decided 8 November 2026).
///
/// ```
/// header (authenticated as AAD, readable without the passphrase):
///   magic        8 bytes  "MORROWBK"
///   format       uint16   1
///   kdf          uint8    1 = Argon2id
///   memoryKiB    uint32
///   iterations   uint32
///   parallelism  uint8
///   saltLength   uint8    16, then the salt
///   nonceLength  uint8    12, then the nonce
/// body:
///   AES-256-GCM ciphertext of the payload, then its 16-byte tag
/// ```
///
/// All integers are big-endian. The header holds no journal data. The
/// payload (JSON, see backup_payload.dart) exists only in memory.
///
/// The cryptography is the maintained `cryptography` package (Argon2id key
/// derivation, AES-GCM); nothing here designs its own.

const List<int> backupMagic = [0x4d, 0x4f, 0x52, 0x52, 0x4f, 0x57, 0x42, 0x4b];

/// The file format this version writes and reads.
const int backupFormatVersion = 1;

const int _kdfArgon2id = 1;
const int _saltLength = 16;
const int _nonceLength = 12;
const int _macLength = 16;

/// A passphrase needs at least this many characters (decision 1).
const int minPassphraseLength = 8;

/// Larger files are refused before they are read into memory.
const int maxBackupBytes = 32 * 1024 * 1024;

/// Argon2id settings, stored in each file so they can be raised later
/// without breaking older backups.
final class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// What new backups use: 19 MiB, 2 passes, 1 lane.
  static const KdfParams standard = KdfParams(
    memoryKiB: 19 * 1024,
    iterations: 2,
    parallelism: 1,
  );

  /// Limits for reading. A file asking for more is refused, so a crafted
  /// file cannot make the phone run out of memory or spin for minutes.
  bool get withinReadLimits =>
      memoryKiB >= 8 * parallelism &&
      memoryKiB <= 256 * 1024 &&
      iterations >= 1 &&
      iterations <= 16 &&
      parallelism >= 1 &&
      parallelism <= 8;
}

/// Why a file could not be opened.
enum BackupProblem {
  /// Not a morrow backup (wrong magic, too short, too large, malformed).
  notBackup,

  /// A later format or schema than this version understands.
  newerVersion,

  /// The passphrase didn't match or the file was changed. AES-GCM cannot
  /// tell these apart, so neither can the person.
  cannotOpen,
}

class BackupException implements Exception {
  const BackupException(this.problem);

  final BackupProblem problem;

  @override
  String toString() => 'BackupException(${problem.name})';
}

/// Turns a passphrase into a 32-byte key. Swappable so widget tests (which
/// run in a fake-async zone) need not run Argon2id.
typedef KeyDeriver = Future<List<int>> Function(
  String passphrase,
  List<int> salt,
  KdfParams params,
);

/// Argon2id in a background isolate, so the screen keeps drawing.
Future<List<int>> argon2idInIsolate(
  String passphrase,
  List<int> salt,
  KdfParams params,
) {
  final password = utf8.encode(passphrase);
  final saltCopy = List<int>.of(salt);
  final memory = params.memoryKiB;
  final iterations = params.iterations;
  final parallelism = params.parallelism;
  return Isolate.run(() async {
    final key = await DartArgon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: 32,
      maxIsolates: 1,
    ).deriveKey(secretKey: SecretKey(password), nonce: saltCopy);
    return key.extractBytes();
  });
}

/// What the header says, read before asking for the passphrase.
final class BackupHeader {
  const BackupHeader._(this.params, this.salt, this.nonce, this.length);

  final KdfParams params;
  final List<int> salt;
  final List<int> nonce;

  /// Header length in bytes; the header is the AAD.
  final int length;

  /// Checks the magic, version and settings. Throws [BackupException].
  static BackupHeader parse(List<int> file) {
    if (file.length > maxBackupBytes) {
      throw const BackupException(BackupProblem.notBackup);
    }
    final bytes = file is Uint8List ? file : Uint8List.fromList(file);
    final data = ByteData.sublistView(bytes);
    var at = 0;
    bool has(int n) => at + n <= bytes.length;

    if (!has(backupMagic.length)) {
      throw const BackupException(BackupProblem.notBackup);
    }
    for (var i = 0; i < backupMagic.length; i++) {
      if (bytes[i] != backupMagic[i]) {
        throw const BackupException(BackupProblem.notBackup);
      }
    }
    at = backupMagic.length;
    if (!has(2)) throw const BackupException(BackupProblem.notBackup);
    final format = data.getUint16(at);
    at += 2;
    if (format > backupFormatVersion) {
      throw const BackupException(BackupProblem.newerVersion);
    }
    if (format != backupFormatVersion) {
      throw const BackupException(BackupProblem.notBackup);
    }
    if (!has(1 + 4 + 4 + 1 + 1)) {
      throw const BackupException(BackupProblem.notBackup);
    }
    final kdf = data.getUint8(at++);
    final memory = data.getUint32(at);
    at += 4;
    final iterations = data.getUint32(at);
    at += 4;
    final parallelism = data.getUint8(at++);
    final params = KdfParams(
      memoryKiB: memory,
      iterations: iterations,
      parallelism: parallelism,
    );
    if (kdf != _kdfArgon2id || !params.withinReadLimits) {
      throw const BackupException(BackupProblem.notBackup);
    }
    final saltLength = data.getUint8(at++);
    if (saltLength != _saltLength || !has(saltLength + 1)) {
      throw const BackupException(BackupProblem.notBackup);
    }
    final salt = bytes.sublist(at, at + saltLength);
    at += saltLength;
    final nonceLength = data.getUint8(at++);
    if (nonceLength != _nonceLength || !has(nonceLength + _macLength)) {
      throw const BackupException(BackupProblem.notBackup);
    }
    final nonce = bytes.sublist(at, at + nonceLength);
    at += nonceLength;
    return BackupHeader._(params, salt, nonce, at);
  }
}

/// Encrypts [payload] with a key derived from [passphrase].
Future<Uint8List> sealBackup(
  List<int> payload,
  String passphrase, {
  KdfParams params = KdfParams.standard,
  KeyDeriver deriveKey = argon2idInIsolate,
  Random? random,
}) async {
  final rng = random ?? Random.secure();
  final salt = List<int>.generate(_saltLength, (_) => rng.nextInt(256));
  final nonce = List<int>.generate(_nonceLength, (_) => rng.nextInt(256));

  final header = BytesBuilder()
    ..add(backupMagic)
    ..add(_u16(backupFormatVersion))
    ..addByte(_kdfArgon2id)
    ..add(_u32(params.memoryKiB))
    ..add(_u32(params.iterations))
    ..addByte(params.parallelism)
    ..addByte(_saltLength)
    ..add(salt)
    ..addByte(_nonceLength)
    ..add(nonce);
  final aad = header.toBytes();

  final keyBytes = await deriveKey(passphrase, salt, params);
  final box = await AesGcm.with256bits().encrypt(
    payload,
    secretKey: SecretKey(keyBytes),
    nonce: nonce,
    aad: aad,
  );
  return (BytesBuilder(copy: false)
        ..add(aad)
        ..add(box.cipherText)
        ..add(box.mac.bytes))
      .toBytes();
}

/// Decrypts a backup. Throws [BackupException]; never returns partial data.
Future<List<int>> openBackup(
  List<int> file,
  String passphrase, {
  KeyDeriver deriveKey = argon2idInIsolate,
}) async {
  final header = BackupHeader.parse(file);
  final bytes = file is Uint8List ? file : Uint8List.fromList(file);
  final aad = bytes.sublist(0, header.length);
  final body = bytes.sublist(header.length, bytes.length - _macLength);
  final mac = bytes.sublist(bytes.length - _macLength);

  final keyBytes = await deriveKey(passphrase, header.salt, header.params);
  try {
    return await AesGcm.with256bits().decrypt(
      SecretBox(body, nonce: header.nonce, mac: Mac(mac)),
      secretKey: SecretKey(keyBytes),
      aad: aad,
    );
  } on SecretBoxAuthenticationError {
    throw const BackupException(BackupProblem.cannotOpen);
  }
}

List<int> _u16(int v) => (ByteData(2)..setUint16(0, v)).buffer.asUint8List();
List<int> _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
