import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../features/journal/data/entry_repository.dart';
import '../../features/journal/domain/entry.dart';
import '../clock.dart';
import '../database/bootstrap.dart';
import '../database/encryption.dart';
import '../security/database_key.dart';
import '../security/key_store.dart';

/// Shown only in debug builds or builds made with
/// `--dart-define=MORROW_DIAGNOSTICS=true`.
const bool diagnosticsEnabled = bool.fromEnvironment('MORROW_DIAGNOSTICS');

/// One line of the self-check report. Never contains journal data or keys.
class SelfCheckStep {
  const SelfCheckStep(this.name, {required this.passed, this.detail});

  final String name;
  final bool passed;
  final String? detail;
}

/// Verifies on a real device that the encrypted database works as intended.
///
/// Uses a throwaway folder, a throwaway key and a synthetic marker. It never
/// opens the real journal or reads the real stored key.
Future<List<SelfCheckStep>> runEncryptionSelfCheck() async {
  final steps = <SelfCheckStep>[];
  void step(String name, bool passed, [String? detail]) =>
      steps.add(SelfCheckStep(name, passed: passed, detail: detail));

  final support = await getApplicationSupportDirectory();
  final dir = Directory(p.join(support.path, 'self_check'));
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, 'check.db'));
  const marker = 'SELF-CHECK-MARKER-91d2';
  final key = DatabaseKey.generate();

  try {
    step('SQLite ${sqlite3.version.libVersion} loaded', true);
    try {
      requireCipherBuild();
      step('Encryption build (SQLite3 Multiple Ciphers)', true);
    } on EncryptionUnavailableException {
      step('Encryption build (SQLite3 Multiple Ciphers)', false);
      return steps;
    }

    final db = await const SqliteDatabaseOpener().open(file, key);
    final repo = EntryRepository(db, const SystemClock());
    for (var i = 0; i < 20; i++) {
      await repo.create(
        EntryDraft(
          occurredAtUtc: DateTime.now().toUtc(),
          originalUtcOffsetMinutes: 0,
          comment: '$marker $i',
        ),
      );
    }
    await db.close();

    step('File header is not plain SQLite', !await hasPlaintextHeader(file));
    final bytes = await file.readAsBytes();
    step(
      'Marker text absent from file (${bytes.length} bytes)',
      !_contains(bytes, utf8.encode(marker)),
    );
    final leftovers = [
      for (final s in companionSuffixes)
        if (await File('${file.path}$s').exists()) s,
    ];
    step(
      'No companion files left after closing',
      leftovers.isEmpty,
      leftovers.join(', '),
    );

    final reopened = await checkExistingDatabase(file, key);
    step('Correct key reopens', reopened == DatabaseCheck.ok, reopened.name);
    final again = await const SqliteDatabaseOpener().open(file, key);
    final count = (await EntryRepository(
      again,
      const SystemClock(),
    ).all()).length;
    await again.close();
    step('Data persists after reopening', count == 20, '$count entries');

    final wrong = await checkExistingDatabase(file, DatabaseKey.generate());
    step('Wrong key is rejected', wrong == DatabaseCheck.wrongKey, wrong.name);

    const storage = FlutterSecureStorage(
      aOptions: SecureStorageKeyStore.androidOptions,
      iOptions: SecureStorageKeyStore.iosOptions,
    );
    const probeName = 'morrow.self_check.v1';
    final probe = DatabaseKey.generate();
    await storage.write(key: probeName, value: probe.encode());
    final read = await storage.read(key: probeName);
    await storage.delete(key: probeName);
    final gone = await storage.read(key: probeName);
    step(
      'Secure storage write, read and delete',
      read != null && DatabaseKey.decode(read).sameAs(probe) && gone == null,
    );
  } on Object catch (e) {
    // Type only: messages could in theory echo data.
    step('Unexpected error', false, e.runtimeType.toString());
  } finally {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
  return steps;
}

bool _contains(List<int> hay, List<int> needle) {
  outer:
  for (var i = 0; i <= hay.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
