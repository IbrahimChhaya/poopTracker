import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/database/encryption.dart';
import 'package:poop_tracker/core/security/database_key.dart';
import 'package:poop_tracker/core/security/key_store.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../../support/fake_clock.dart';
import '../../support/fake_key_store.dart';

/// A synthetic string that must never appear in any file on disk.
const String marker = 'SYNTHETIC-MARKER-4c7e-ZQX';

/// True if [file] contains [needle] as UTF-8 bytes.
bool fileContains(File file, String needle) {
  if (!file.existsSync()) return false;
  final hay = file.readAsBytesSync();
  final n = utf8.encode(needle);
  outer:
  for (var i = 0; i <= hay.length - n.length; i++) {
    for (var j = 0; j < n.length; j++) {
      if (hay[i + j] != n[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  late Directory dir;
  late File dbFile;
  late FakeKeyStore keys;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('morrow_db_');
    dbFile = File('${dir.path}/journal/journal.db');
    keys = FakeKeyStore();
  });

  tearDown(() async {
    // Give background isolates a moment to release file handles on Windows.
    for (var i = 0; i < 10; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  DatabaseBootstrap bootstrap() =>
      DatabaseBootstrap(keyStore: keys, databaseFile: () async => dbFile);

  Future<AppDatabase> openReady() async {
    final r = await bootstrap().start();
    expect(r, isA<StartupReady>(), reason: '$r');
    return (r as StartupReady).database;
  }

  EntryDraft draft(String comment) => EntryDraft(
    occurredAtUtc: figmaNow.utc.subtract(const Duration(hours: 1)),
    originalUtcOffsetMinutes: 0,
    comment: comment,
  );

  List<int> fileBytes() => dbFile.readAsBytesSync();

  test('the linked SQLite is SQLite3 Multiple Ciphers', () {
    final db = raw.sqlite3.openInMemory();
    addTearDown(db.close);
    expect(
      db.select("SELECT sqlite3mc_config('cipher') AS c").first['c'],
      isNotNull,
    );
  });

  test('a new journal is created encrypted, never as plain SQLite', () async {
    final db = await openReady();
    await db.close();
    expect(dbFile.existsSync(), isTrue);
    expect(await hasPlaintextHeader(dbFile), isFalse);
    expect(keys.marker, SetupMarker.ready);
  });

  test('the correct key reopens the journal and data persists', () async {
    var db = await openReady();
    final repo = EntryRepository(db, figmaNow);
    final saved = await repo.create(draft('Felt fine after lunch'));
    await db.close();

    db = await openReady();
    final again = await EntryRepository(db, figmaNow).all();
    await db.close();
    expect(again.single.uid, saved.uid);
    expect(again.single.comment, 'Felt fine after lunch');
  });

  test('a wrong key is rejected and nothing is replaced', () async {
    final db = await openReady();
    await EntryRepository(db, figmaNow).create(draft('Keep me'));
    await db.close();
    final before = fileBytes();

    keys.key = DatabaseKey.generate(Random(9));
    final r = await bootstrap().start();
    expect(
      r,
      isA<StartupBlocked>().having(
        (b) => b.reason,
        'reason',
        StartupBlockReason.keyRejected,
      ),
    );
    expect(fileBytes(), before);
    expect(keys.keyWrites, 1, reason: 'only the original first-install write');
  });

  test('a missing key is blocked; no new key or database is made', () async {
    final db = await openReady();
    await db.close();
    final before = fileBytes();

    keys.key = null;
    final r = await bootstrap().start();
    expect(
      r,
      isA<StartupBlocked>().having(
        (b) => b.reason,
        'reason',
        StartupBlockReason.keyMissing,
      ),
    );
    expect(keys.key, isNull);
    expect(fileBytes(), before);
  });

  test('checkExistingDatabase never creates a missing file', () async {
    final r = await checkExistingDatabase(dbFile, DatabaseKey.generate());
    expect(r, DatabaseCheck.unreadable);
    expect(dbFile.existsSync(), isFalse);
  });

  test('an unencrypted journal file is refused and left untouched', () {
    dbFile.parent.createSync(recursive: true);
    final plain = raw.sqlite3.open(dbFile.path)
      ..execute('CREATE TABLE t (x TEXT)')
      ..execute("INSERT INTO t VALUES ('$marker')");
    plain.close();
    expect(fileContains(dbFile, marker), isTrue, reason: 'sanity check');
    final before = fileBytes();
    keys.key = DatabaseKey.generate(Random(5));

    return bootstrap().start().then((r) {
      expect(
        r,
        isA<StartupBlocked>().having(
          (b) => b.reason,
          'reason',
          StartupBlockReason.notEncrypted,
        ),
      );
      expect(fileBytes(), before);
    });
  });

  test('a file that is not a database is reported unreadable', () async {
    dbFile.parent.createSync(recursive: true);
    dbFile.writeAsBytesSync(List<int>.generate(4096, (i) => i % 251));
    final r = await checkExistingDatabase(dbFile, DatabaseKey.generate());
    expect(r, anyOf(DatabaseCheck.wrongKey, DatabaseCheck.unreadable));
  });

  group('no plaintext on disk', () {
    test('database file', () async {
      final db = await openReady();
      final repo = EntryRepository(db, figmaNow);
      for (var i = 0; i < 50; i++) {
        await repo.create(draft('$marker $i'));
      }
      await db.close();
      expect(fileContains(dbFile, marker), isFalse);
      for (final s in companionSuffixes) {
        expect(
          fileContains(File('${dbFile.path}$s'), marker),
          isFalse,
          reason: s,
        );
      }
    });

    test('rollback journal while a transaction is open', () async {
      final db = await openReady();
      final repo = EntryRepository(db, figmaNow);
      final e = await repo.create(draft(marker));
      final journal = File('${dbFile.path}-journal');
      var journalSeen = false;
      await db.transaction(() async {
        // Changing the row copies its original page (with the marker) into
        // the rollback journal.
        await (db.update(db.entries)..where((t) => t.id.equals(e.id))).write(
          const EntriesCompanion(comment: Value('changed')),
        );
        journalSeen = journal.existsSync();
        expect(fileContains(journal, marker), isFalse);
        expect(fileContains(dbFile, marker), isFalse);
      });
      await db.close();
      expect(journalSeen, isTrue, reason: 'the journal should exist mid-write');
    });

    test('write-ahead log and shared memory files', () async {
      // The app uses the default rollback journal, but check WAL too in case
      // it is enabled later.
      final key = DatabaseKey.generate(Random(6));
      dbFile.parent.createSync(recursive: true);
      final db = raw.sqlite3.open(dbFile.path);
      applyEncryption(db, key);
      db
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('PRAGMA wal_autocheckpoint = 0')
        ..execute('CREATE TABLE t (x TEXT)');
      final insert = db.prepare('INSERT INTO t VALUES (?)');
      for (var i = 0; i < 50; i++) {
        insert.execute(['$marker $i']);
      }
      insert.close();
      final wal = File('${dbFile.path}-wal');
      expect(wal.existsSync(), isTrue);
      expect(wal.lengthSync(), greaterThan(0));
      expect(fileContains(wal, marker), isFalse);
      expect(fileContains(File('${dbFile.path}-shm'), marker), isFalse);
      expect(fileContains(dbFile, marker), isFalse);
      db.close();
      expect(fileContains(dbFile, marker), isFalse);
    });

    test('no other files are written next to the journal', () async {
      final db = await openReady();
      await EntryRepository(db, figmaNow).create(draft(marker));
      await db.close();
      final names = dbFile.parent
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(names, ['journal.db']);
    });
  });

  group('transactions', () {
    test('a failure rolls back every write in the transaction', () async {
      final db = await openReady();
      await expectLater(
        db.transaction(() async {
          final id = await db
              .into(db.entries)
              .insert(
                EntriesCompanion.insert(
                  uid: 'rollback-test',
                  occurredAtUtcMs: 0,
                  originalUtcOffsetMinutes: 0,
                  createdAtUtcMs: 0,
                  updatedAtUtcMs: 0,
                ),
              );
          await db
              .into(db.entrySymptoms)
              .insert(
                EntrySymptomsCompanion.insert(entryId: id, code: 'bloating'),
              );
          throw StateError('simulated failure');
        }),
        throwsStateError,
      );
      expect(await db.select(db.entries).get(), isEmpty);
      expect(await db.select(db.entrySymptoms).get(), isEmpty);
      await db.close();
    });

    test('a constraint failure inside a write rolls the entry back', () async {
      final db = await openReady();
      await expectLater(
        db.transaction(() async {
          final id = await db
              .into(db.entries)
              .insert(
                EntriesCompanion.insert(
                  uid: 'constraint-test',
                  occurredAtUtcMs: 0,
                  originalUtcOffsetMinutes: 0,
                  createdAtUtcMs: 0,
                  updatedAtUtcMs: 0,
                ),
              );
          // Not an allowed code: the database itself refuses it.
          await db
              .into(db.entrySymptoms)
              .insert(
                EntrySymptomsCompanion.insert(entryId: id, code: 'invented'),
              );
        }),
        throwsA(anything),
      );
      expect(await db.select(db.entries).get(), isEmpty);
      await db.close();
    });
  });

  group('schema v1', () {
    test('creates one settings row and one reminder row, both off', () async {
      final db = await openReady();
      final settings = await db.select(db.appSettings).getSingle();
      expect(settings.showStoolForm, isFalse);
      expect(settings.showContext, isFalse);
      final reminder = await db.select(db.reminder).getSingle();
      expect(reminder.enabled, isFalse);
      expect(reminder.weekday, isNull);
      expect(reminder.tzPolicy, 'follow_device');
      await db.close();
    });

    test('the database refuses out-of-range values', () async {
      final db = await openReady();
      Future<void> insertEntry({int? stool, String? ease, int offset = 0}) => db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              uid: 'u${Random().nextInt(1 << 30)}',
              occurredAtUtcMs: 0,
              originalUtcOffsetMinutes: offset,
              stoolType: Value(stool),
              ease: Value(ease),
              createdAtUtcMs: 0,
              updatedAtUtcMs: 0,
            ),
          );
      await expectLater(insertEntry(stool: 8), throwsA(anything));
      await expectLater(insertEntry(stool: 0), throwsA(anything));
      await expectLater(insertEntry(ease: 'great'), throwsA(anything));
      await expectLater(insertEntry(offset: 900), throwsA(anything));
      await expectLater(
        db
            .into(db.appSettings)
            .insert(AppSettingsCompanion.insert(id: const Value(2))),
        throwsA(anything),
      );
      await insertEntry(stool: 7, ease: 'easy');
      expect(await db.select(db.entries).get(), hasLength(1));
      await db.close();
    });

    test('schema version is 1', () async {
      final db = await openReady();
      expect(db.schemaVersion, 1);
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.data.values.single, 1);
      await db.close();
    });
  });
}
