import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/ids/uid.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_key_store.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late FixedClock clock;
  late EntryRepository repo;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('morrow_repo_');
    final r = await DatabaseBootstrap(
      keyStore: FakeKeyStore(),
      databaseFile: () async => File('${dir.path}/journal.db'),
    ).start();
    db = (r as StartupReady).database;
    clock = FixedClock(DateTime.utc(2026, 11, 6, 13, 41));
    repo = EntryRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
    for (var i = 0; i < 10; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  EntryDraft draft({
    DateTime? at,
    String? comment,
    int? stoolType,
    Ease? ease,
    bool hasTime = true,
    Set<Tag> tags = const {},
  }) => EntryDraft(
    occurredAtUtc: at ?? DateTime.utc(2026, 11, 6, 13, 35),
    originalUtcOffsetMinutes: 0,
    comment: comment,
    stoolType: stoolType,
    ease: ease,
    hasTime: hasTime,
    tags: tags,
  );

  test('saving with only a date and time works', () async {
    final e = await repo.create(draft());
    expect(e.id, greaterThan(0));
    expect(isValidUid(e.uid), isTrue);
    expect(e.comment, isNull);
    expect(e.stoolType, isNull);
    expect(e.hasTime, isTrue);
    expect(e.createdAtUtc, clock.utc);
    expect(e.updatedAtUtc, clock.utc);
  });

  test('every optional detail is stored and read back', () async {
    final e = await repo.create(
      draft(
        comment: '  Felt fine after lunch  ',
        stoolType: 4,
        ease: Ease.someStraining,
        tags: {Tag.afterMeal, Tag.coffee, Tag.feelingSick},
      ),
    );
    final back = await repo.byId(e.id);
    expect(back, e);
    expect(back!.comment, 'Felt fine after lunch');
    expect(back.occurredAtUtc, DateTime.utc(2026, 11, 6, 13, 35));
    expect(back.occurredAtUtc.isUtc, isTrue);
    expect(back.tags, {Tag.afterMeal, Tag.coffee, Tag.feelingSick});
  });

  test('invalid drafts throw and write nothing', () async {
    await expectLater(
      repo.create(draft(at: clock.utc.add(const Duration(hours: 1)))),
      throwsA(
        isA<EntryValidationException>().having((e) => e.errors, 'errors', [
          EntryValidationError.inFuture,
        ]),
      ),
    );
    await expectLater(
      repo.create(draft(stoolType: 0)),
      throwsA(isA<EntryValidationException>()),
    );
    expect(await repo.all(), isEmpty);
  });

  test('an entry without a time is stored and read back as such', () async {
    final e = await repo.create(
      draft(at: DateTime.utc(2026, 11, 5, 12), hasTime: false),
    );
    final back = (await repo.byId(e.id))!;
    expect(back.hasTime, isFalse);
    expect(back.localTime, isNull);
    final timed = await repo.update(
      e.id,
      draft(at: DateTime.utc(2026, 11, 5, 8, 25)),
    );
    expect(timed.hasTime, isTrue);
  });

  test('untimed entries sort after timed ones on the same day', () async {
    final untimed = await repo.create(
      draft(at: DateTime.utc(2026, 11, 5, 12), hasTime: false),
    );
    final evening = await repo.create(draft(at: DateTime.utc(2026, 11, 5, 20)));
    final morning = await repo.create(draft(at: DateTime.utc(2026, 11, 5, 7)));
    final today = await repo.create(draft(at: DateTime.utc(2026, 11, 6, 9)));
    expect((await repo.all()).map((e) => e.id), [
      today.id,
      evening.id,
      morning.id,
      untimed.id,
    ]);
  });

  test('every entry gets its own uid', () async {
    final a = await repo.create(draft());
    final b = await repo.create(draft());
    expect(a.uid, isNot(b.uid));
  });

  test('update replaces details and keeps identity', () async {
    final e = await repo.create(draft(stoolType: 3, tags: {Tag.stress}));
    clock.utc = clock.utc.add(const Duration(minutes: 5));
    final u = await repo.update(
      e.id,
      draft(comment: 'Edited', tags: {Tag.onPeriod}),
    );
    expect(u.id, e.id);
    expect(u.uid, e.uid);
    expect(u.createdAtUtc, e.createdAtUtc);
    expect(u.updatedAtUtc, clock.utc);
    expect(u.comment, 'Edited');
    expect(u.stoolType, isNull);
    expect(u.tags, {Tag.onPeriod});
  });

  test('an invalid update changes nothing', () async {
    final e = await repo.create(draft(comment: 'Original'));
    await expectLater(
      repo.update(e.id, draft(comment: 'a' * 501)),
      throwsA(isA<EntryValidationException>()),
    );
    expect((await repo.byId(e.id))!.comment, 'Original');
  });

  test('updating or deleting a missing entry throws', () async {
    await expectLater(
      repo.update(999, draft()),
      throwsA(isA<EntryNotFoundException>()),
    );
    await expectLater(repo.delete(999), throwsA(isA<EntryNotFoundException>()));
  });

  test('delete removes the entry with its tags', () async {
    final e = await repo.create(draft(tags: {Tag.lowFluids}));
    await repo.delete(e.id);
    expect(await repo.byId(e.id), isNull);
    expect(await db.select(db.entryTags).get(), isEmpty);
  });

  test('all() is newest first and watchAll() follows changes', () async {
    final older = await repo.create(draft(at: DateTime.utc(2026, 11, 4, 8)));
    final newer = await repo.create(draft(at: DateTime.utc(2026, 11, 6, 8)));
    expect((await repo.all()).map((e) => e.id), [newer.id, older.id]);

    final updates = repo.watchAll().map((l) => l.length);
    final expectation = expectLater(updates, emitsInOrder([2, 1]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.delete(older.id);
    await expectation;
  });
}
