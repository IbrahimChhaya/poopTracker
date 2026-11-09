import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/backup/backup_file.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/backup_payload.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_key_store.dart';

const KdfParams _fast = KdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);

/// A real encrypted journal in its own temporary folder.
class _Journal {
  _Journal._(this.dir, this.db, this.repo);

  static Future<_Journal> open(FixedClock clock) async {
    final dir = Directory.systemTemp.createTempSync('morrow_backup_');
    final r = await DatabaseBootstrap(
      keyStore: FakeKeyStore(),
      databaseFile: () async => File('${dir.path}/journal.db'),
    ).start();
    final db = (r as StartupReady).database;
    return _Journal._(dir, db, EntryRepository(db, clock));
  }

  final Directory dir;
  final AppDatabase db;
  final EntryRepository repo;

  Future<void> close() async {
    await db.close();
    for (var i = 0; i < 10; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }
}

Future<List<int>> _backupOf(EntryRepository repo) async => sealBackup(
  encodeBackupPayload(
    await repo.all(),
    exportedAtUtc: DateTime.utc(2026, 11, 8, 21, 40),
  ),
  'synthetic passphrase',
  params: _fast,
);

Future<List<BackupEntry>> _read(List<int> file) async =>
    decodeBackupPayload(await openBackup(file, 'synthetic passphrase'));

void main() {
  late FixedClock clock;
  late _Journal source;
  late _Journal target;

  setUp(() async {
    clock = FixedClock(DateTime.utc(2026, 11, 6, 13, 41));
    source = await _Journal.open(clock);
    target = await _Journal.open(clock);
    await source.repo.create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 6, 13, 35),
        originalUtcOffsetMinutes: 60,
        comment: 'Synthetic note with an emoji 🙂',
        stoolType: 4,
        ease: Ease.someStraining,
        tags: {Tag.coffee, Tag.afterMeal},
      ),
    );
    clock.utc = clock.utc.add(const Duration(minutes: 1));
    await source.repo.create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 2, dateOnlyHour),
        originalUtcOffsetMinutes: 0,
        hasTime: false,
      ),
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('payload schema matches the database schema', () {
    expect(backupSchemaVersion, source.db.schemaVersion);
  });

  test('a restore brings back every field, uid and timestamp', () async {
    final result = await target.repo.restore(
      await _read(await _backupOf(source.repo)),
    );
    expect(result, (added: 2, skipped: 0));

    final before = await source.repo.all();
    final after = await target.repo.all();
    expect(after, hasLength(2));
    for (var i = 0; i < before.length; i++) {
      final a = before[i];
      final b = after[i];
      expect(b.uid, a.uid);
      expect(b.occurredAtUtc, a.occurredAtUtc);
      expect(b.originalUtcOffsetMinutes, a.originalUtcOffsetMinutes);
      expect(b.hasTime, a.hasTime);
      expect(b.comment, a.comment);
      expect(b.stoolType, a.stoolType);
      expect(b.ease, a.ease);
      expect(b.tags, a.tags);
      expect(b.createdAtUtc, a.createdAtUtc);
      expect(b.updatedAtUtc, a.updatedAtUtc);
    }
  });

  test('restoring twice adds nothing the second time', () async {
    final file = await _backupOf(source.repo);
    await target.repo.restore(await _read(file));
    final again = await target.repo.restore(await _read(file));
    expect(again, (added: 0, skipped: 2));
    expect(await target.repo.all(), hasLength(2));
  });

  test(
    'restoring into a journal with entries keeps them and adds the rest',
    () async {
      final own = await target.repo.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 11, 5, 8),
          originalUtcOffsetMinutes: 0,
          comment: 'Synthetic entry already here',
        ),
      );
      // One entry from the source is already in the target too.
      final shared = (await source.repo.all()).first;
      await target.repo.restore([BackupEntry.of(shared)]);

      final result = await target.repo.restore(
        await _read(await _backupOf(source.repo)),
      );
      expect(result, (added: 1, skipped: 1));
      final all = await target.repo.all();
      expect(all, hasLength(3));
      expect(
        all.where((e) => e.uid == own.uid).single.comment,
        'Synthetic entry already here',
      );
    },
  );

  test('an existing entry is never overwritten by a backup copy', () async {
    final original = (await source.repo.all()).first;
    await target.repo.restore([BackupEntry.of(original)]);
    final local = (await target.repo.all()).single;
    await target.repo.update(
      local.id,
      local.toDraft().copyWithComment('Edited here'),
    );

    await target.repo.restore(await _read(await _backupOf(source.repo)));
    final kept = (await target.repo.all()).firstWhere(
      (e) => e.uid == original.uid,
    );
    expect(kept.comment, 'Edited here');
  });

  test(
    'an invalid entry fails the whole restore and changes nothing',
    () async {
      final good = BackupEntry.of((await source.repo.all()).first);
      final bad = BackupEntry(
        uid: '3f2b8c1e-9d4a-4f6b-8e2a-1c5d7e9f0a3b',
        draft: EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 11, 1, 9),
          originalUtcOffsetMinutes: 0,
          stoolType: 9,
        ),
        createdAtUtc: DateTime.utc(2026, 11, 1, 9),
        updatedAtUtc: DateTime.utc(2026, 11, 1, 9),
      );
      await expectLater(
        target.repo.restore([good, bad]),
        throwsA(isA<EntryValidationException>()),
      );
      expect(await target.repo.all(), isEmpty);
    },
  );

  group('payload validation', () {
    Map<String, Object?> payload(
      List<Map<String, Object?>> entries, {
      int schema = 2,
      int format = 1,
    }) => {
      'format': format,
      'schemaVersion': schema,
      'exportedAtUtc': '2026-11-08T21:40:00.000Z',
      'entries': entries,
    };
    Map<String, Object?> entry([Map<String, Object?> changes = const {}]) => {
      'uid': '3f2b8c1e-9d4a-4f6b-8e2a-1c5d7e9f0a3b',
      'occurredAtUtc': '2026-11-06T13:35:00.000Z',
      'originalUtcOffsetMinutes': 0,
      'hasTime': true,
      'comment': null,
      'stoolType': null,
      'ease': null,
      'tags': <String>[],
      'createdAtUtc': '2026-11-06T13:35:00.000Z',
      'updatedAtUtc': '2026-11-06T13:35:00.000Z',
      ...changes,
    };
    List<int> bytes(Map<String, Object?> m) => utf8.encode(jsonEncode(m));
    Matcher problem(BackupProblem p) =>
        throwsA(isA<BackupException>().having((e) => e.problem, 'problem', p));

    test('a valid entry decodes', () {
      expect(decodeBackupPayload(bytes(payload([entry()]))), hasLength(1));
    });

    test('a schema 1 backup (no hasTime) restores as timed entries', () async {
      final e = entry()..remove('hasTime');
      final decoded = decodeBackupPayload(bytes(payload([e], schema: 1)));
      expect(decoded.single.draft.hasTime, isTrue);
      expect(await target.repo.restore(decoded), (added: 1, skipped: 0));
    });

    test('a later schema or format is a newer version', () {
      expect(
        () => decodeBackupPayload(bytes(payload([entry()], schema: 3))),
        problem(BackupProblem.newerVersion),
      );
      expect(
        () => decodeBackupPayload(bytes(payload([entry()], format: 2))),
        problem(BackupProblem.newerVersion),
      );
    });

    for (final (name, change) in <(String, Map<String, Object?>)>[
      ('bad uid', {'uid': 'not-a-uid'}),
      ('local time', {'occurredAtUtc': '2026-11-06T13:35:00.000'}),
      ('offset out of range', {'originalUtcOffsetMinutes': 900}),
      ('note too long', {'comment': 'x' * 501}),
      ('stool type out of range', {'stoolType': 8}),
      ('unknown ease', {'ease': 'unknown'}),
      (
        'unknown tag',
        {
          'tags': ['unknown'],
        },
      ),
      ('hasTime missing in schema 2', {'hasTime': null}),
    ]) {
      test('rejects $name', () {
        expect(
          () => decodeBackupPayload(bytes(payload([entry(change)]))),
          problem(BackupProblem.notBackup),
        );
      });
    }

    test('rejects text that is not JSON', () {
      expect(
        () => decodeBackupPayload(utf8.encode('synthetic')),
        problem(BackupProblem.notBackup),
      );
    });
  });
}

extension on EntryDraft {
  EntryDraft copyWithComment(String comment) => EntryDraft(
    occurredAtUtc: occurredAtUtc,
    originalUtcOffsetMinutes: originalUtcOffsetMinutes,
    hasTime: hasTime,
    comment: comment,
    stoolType: stoolType,
    ease: ease,
    tags: tags,
  );
}
