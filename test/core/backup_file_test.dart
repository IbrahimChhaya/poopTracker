import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/backup/backup_file.dart';

/// Small Argon2id settings so the tests run quickly; the real ones are
/// covered once below.
const KdfParams _fast = KdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);

const String _pass = 'synthetic passphrase';
final List<int> _payload = utf8.encode('{"synthetic":"payload text"}');

Matcher _problem(BackupProblem p) =>
    throwsA(isA<BackupException>().having((e) => e.problem, 'problem', p));

/// Offsets in the format-1 header.
const int _formatAt = 8;
const int _memoryAt = 11;
const int _saltAt = 21;

void main() {
  late Uint8List sealed;

  setUpAll(() async {
    sealed = await sealBackup(_payload, _pass, params: _fast);
  });

  test('round trip returns the payload', () async {
    expect(await openBackup(sealed, _pass), _payload);
  });

  test('starts with the magic and never contains the payload in plain', () {
    expect(sealed.sublist(0, 8), backupMagic);
    expect(ascii.decode(sealed.sublist(0, 8)), 'MORROWBK');
    final text = latin1.decode(sealed);
    expect(text.contains('synthetic'), isFalse);
    expect(text.contains('payload'), isFalse);
  });

  test(
    'the same input seals differently each time (fresh salt and nonce)',
    () async {
      final again = await sealBackup(_payload, _pass, params: _fast);
      expect(again, isNot(sealed));
    },
  );

  test('the header records format 1 and the settings used', () {
    final h = BackupHeader.parse(sealed);
    expect(h.params.memoryKiB, 64);
    expect(h.params.iterations, 1);
    expect(h.params.parallelism, 1);
    expect(h.salt, hasLength(16));
    expect(h.nonce, hasLength(12));
    expect(ByteData.sublistView(sealed).getUint16(_formatAt), 1);
  });

  test('a wrong passphrase cannot open it', () async {
    await expectLater(
      openBackup(sealed, 'not the passphrase'),
      _problem(BackupProblem.cannotOpen),
    );
  });

  test(
    'a changed header byte cannot open it (the header is authenticated)',
    () async {
      final tampered = Uint8List.fromList(sealed);
      tampered[_saltAt] ^= 0x01;
      await expectLater(
        openBackup(tampered, _pass),
        _problem(BackupProblem.cannotOpen),
      );
    },
  );

  test('a changed body byte cannot open it', () async {
    final tampered = Uint8List.fromList(sealed);
    tampered[tampered.length - 20] ^= 0x01;
    await expectLater(
      openBackup(tampered, _pass),
      _problem(BackupProblem.cannotOpen),
    );
  });

  test('a cut-short file is not a backup', () async {
    for (final n in [0, 5, 10, 30, 50]) {
      await expectLater(
        openBackup(sealed.sublist(0, n), _pass),
        _problem(BackupProblem.notBackup),
        reason: 'length $n',
      );
    }
  });

  test('another file is not a backup', () async {
    final other = Uint8List.fromList(
      List.generate(200, (_) => Random(1).nextInt(256)),
    );
    await expectLater(
      openBackup(other, _pass),
      _problem(BackupProblem.notBackup),
    );
    await expectLater(
      openBackup(utf8.encode('{"entries": []}'), _pass),
      _problem(BackupProblem.notBackup),
    );
  });

  test('a later format is refused as a newer version', () async {
    final later = Uint8List.fromList(sealed);
    ByteData.sublistView(later).setUint16(_formatAt, 2);
    await expectLater(
      openBackup(later, _pass),
      _problem(BackupProblem.newerVersion),
    );
  });

  test('settings beyond the read limits are refused before any work', () async {
    var derived = 0;
    final huge = Uint8List.fromList(sealed);
    ByteData.sublistView(huge).setUint32(_memoryAt, 4 * 1024 * 1024);
    await expectLater(
      openBackup(
        huge,
        _pass,
        deriveKey: (_, _, _) async {
          derived++;
          return List.filled(32, 0);
        },
      ),
      _problem(BackupProblem.notBackup),
    );
    expect(derived, 0);
  });

  test('a file over the size limit is refused', () {
    expect(
      () => BackupHeader.parse(Uint8List(maxBackupBytes + 1)),
      _problem(BackupProblem.notBackup),
    );
  });

  test('standard settings (19 MiB, 2 passes) work end to end', () async {
    expect(KdfParams.standard.withinReadLimits, isTrue);
    final file = await sealBackup(_payload, _pass);
    expect(BackupHeader.parse(file).params.memoryKiB, 19 * 1024);
    expect(await openBackup(file, _pass), _payload);
  });
}
