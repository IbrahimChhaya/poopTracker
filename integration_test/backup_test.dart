import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poop_tracker/core/backup/backup_file.dart';
import 'package:poop_tracker/core/clock.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/backup_payload.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';

import '../test/support/fake_key_store.dart';

/// Backup encryption on a real phone: real Argon2id (19 MiB, 2 passes) in a
/// background isolate, AES-GCM, and a restore into a real encrypted journal
/// in a temporary folder. The phone's own journal and key are never touched.
/// Prints how long sealing and opening take.
///
/// `flutter test integration_test/backup_test.dart -d DEVICE --no-uninstall`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seal, open and restore with the standard settings', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('morrow_backup_it_');
      try {
        Future<EntryRepository> journal(String name) async {
          final r = await DatabaseBootstrap(
            keyStore: FakeKeyStore(),
            databaseFile: () async => File('${dir.path}/$name/journal.db'),
          ).start();
          return EntryRepository(
            (r as StartupReady).database,
            const SystemClock(),
          );
        }

        final source = await journal('a');
        for (var i = 0; i < 200; i++) {
          await source.create(
            EntryDraft(
              occurredAtUtc: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
              originalUtcOffsetMinutes: 0,
              comment: i.isEven ? 'Synthetic note $i' : null,
            ),
          );
        }
        final payload = encodeBackupPayload(
          await source.all(),
          exportedAtUtc: DateTime.now().toUtc(),
        );

        final sealTimer = Stopwatch()..start();
        final file = await sealBackup(payload, 'synthetic passphrase');
        sealTimer.stop();

        final openTimer = Stopwatch()..start();
        final opened = await openBackup(file, 'synthetic passphrase');
        openTimer.stop();

        debugPrint(
          'BACKUP_TIMING seal=${sealTimer.elapsedMilliseconds}ms '
          'open=${openTimer.elapsedMilliseconds}ms '
          'size=${file.length}B entries=200',
        );

        final target = await journal('b');
        final result = await target.restore(decodeBackupPayload(opened));
        expect(result, (added: 200, skipped: 0));
        expect(await target.restore(decodeBackupPayload(opened)), (
          added: 0,
          skipped: 200,
        ));
        await expectLater(
          openBackup(file, 'not the passphrase'),
          throwsA(isA<BackupException>()),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
