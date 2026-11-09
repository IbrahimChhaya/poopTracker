import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:poop_tracker/core/data/data_eraser.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/database/journal_reset.dart';
import 'package:poop_tracker/core/database/tables.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/security/database_key.dart';
import 'package:poop_tracker/core/security/key_store.dart';

import '../support/fake_clock.dart';
import '../support/fake_key_store.dart';
import '../support/fake_lock.dart';
import '../support/fake_reminders.dart';

/// Every file under [dir], relative to it, sorted.
List<String> filesUnder(Directory dir) => [
  for (final e in dir.listSync(recursive: true))
    if (e is File) p.relative(e.path, from: dir.path).replaceAll(r'\', '/'),
]..sort();

void main() {
  late Directory root;
  late Directory support;
  late Directory cache;
  late File databaseFile;
  late FakeKeyStore keys;
  late FakeLockSettings lockSettings;
  late FakeReminderScheduler reminders;
  late FileDiagnosticLog log;
  late DataEraser eraser;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('morrow_erase_');
    support = Directory(p.join(root.path, 'support'));
    cache = Directory(p.join(root.path, 'cache'));
    databaseFile = File(p.join(support.path, 'journal', 'morrow.db'));

    // Synthetic stand-ins for everything morrow writes.
    await databaseFile.create(recursive: true);
    await databaseFile.writeAsString('synthetic');
    for (final suffix in companionSuffixes) {
      await File('${databaseFile.path}$suffix').writeAsString('synthetic');
    }
    await File(p.join(support.path, 'diagnostics', 'events.log'))
        .create(recursive: true);
    await File(p.join(cache.path, 'share', 'morrow-diagnostics.txt'))
        .create(recursive: true);

    keys = FakeKeyStore(key: DatabaseKey.generate(), marker: SetupMarker.ready);
    lockSettings = FakeLockSettings(enabled: true);
    reminders = FakeReminderScheduler(allowed: true);
    await reminders.scheduleWeekly(
      id: reminderNotificationId,
      weekday: DateTime.sunday,
      hour: 18,
      minute: 0,
    );
    log = FileDiagnosticLog(
      clock: figmaNow,
      dir: () async => Directory(p.join(support.path, 'diagnostics')),
    );
    eraser = DataEraser(
      journalReset: JournalReset(
        keyStore: keys,
        databaseFile: () async => databaseFile,
      ),
      lockSettings: lockSettings,
      diagnostics: log,
      reminders: reminders,
      markerFile: () => erasingMarkerFor(() async => databaseFile),
      cacheDirectory: () async => cache,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('removes every file, the key, app lock and the reminder', () async {
    expect(filesUnder(support), isNotEmpty);
    await eraser.eraseEverything();

    expect(filesUnder(support), isEmpty);
    expect(filesUnder(cache), isEmpty);
    expect(await cache.exists(), isTrue, reason: 'emptied, not removed');
    expect(keys.key, isNull);
    expect(keys.marker, isNull);
    expect(lockSettings.enabled, isFalse);
    expect(reminders.pending, isEmpty);
    expect(await eraser.interrupted(), isFalse);
  });

  test('the marker sits outside the journal folder', () async {
    final marker = await erasingMarkerFor(() async => databaseFile);
    expect(p.isWithin(databaseFile.parent.path, marker.path), isFalse);
    expect(p.isWithin(support.path, marker.path), isTrue);
  });

  test(
    'a failure part way leaves the marker so the next start resumes',
    () async {
      keys.failDeletes = true;
      await expectLater(eraser.eraseEverything(), throwsA(anything));

      expect(await eraser.interrupted(), isTrue);
      // The journal files were already gone before the key step failed.
      expect(await databaseFile.exists(), isFalse);
      expect(keys.key, isNotNull);

      keys.failDeletes = false;
      expect(await eraser.resumeIfInterrupted(), isTrue);
      expect(keys.key, isNull);
      expect(lockSettings.enabled, isFalse);
      expect(filesUnder(support), isEmpty);
      expect(await eraser.interrupted(), isFalse);
    },
  );

  test('resume does nothing when no deletion was interrupted', () async {
    expect(await eraser.resumeIfInterrupted(), isFalse);
    expect(await databaseFile.exists(), isTrue);
    expect(keys.key, isNotNull);
  });

  test('a reminder that cannot be cancelled does not stop deletion', () async {
    final failing = _FailingCancel();
    final e = DataEraser(
      journalReset: JournalReset(
        keyStore: keys,
        databaseFile: () async => databaseFile,
      ),
      lockSettings: lockSettings,
      diagnostics: log,
      reminders: failing,
      markerFile: () => erasingMarkerFor(() async => databaseFile),
      cacheDirectory: () async => cache,
    );
    await e.eraseEverything();
    expect(filesUnder(support), isEmpty);
  });

  test('running twice is safe', () async {
    await eraser.eraseEverything();
    await eraser.eraseEverything();
    expect(filesUnder(support), isEmpty);
    expect(await eraser.interrupted(), isFalse);
  });
}

class _FailingCancel extends FakeReminderScheduler {
  @override
  Future<void> cancel(int id) async => throw StateError('simulated');
}
