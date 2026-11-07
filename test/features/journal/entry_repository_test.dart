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
    Set<Symptom> symptoms = const {},
    Set<Tag> tags = const {},
  }) => EntryDraft(
    occurredAtUtc: at ?? DateTime.utc(2026, 11, 6, 13, 35),
    originalUtcOffsetMinutes: 0,
    comment: comment,
    stoolType: stoolType,
    ease: ease,
    symptoms: symptoms,
    tags: tags,
  );

  test('saving with only a date and time works', () async {
    final e = await repo.create(draft());
    expect(e.id, greaterThan(0));
    expect(isValidUid(e.uid), isTrue);
    expect(e.comment, isNull);
    expect(e.stoolType, isNull);
    expect(e.symptoms, isEmpty);
    expect(e.createdAtUtc, clock.utc);
    expect(e.updatedAtUtc, clock.utc);
  });

  test('every optional detail is stored and read back', () async {
    final e = await repo.create(
      draft(
        comment: '  Felt fine after lunch  ',
        stoolType: 4,
        ease: Ease.someStraining,
        symptoms: {Symptom.bloating, Symptom.cramping},
        tags: {Tag.afterMeal, Tag.coffee},
      ),
    );
    final back = await repo.byId(e.id);
    expect(back, e);
    expect(back!.comment, 'Felt fine after lunch');
    expect(back.occurredAtUtc, DateTime.utc(2026, 11, 6, 13, 35));
    expect(back.occurredAtUtc.isUtc, isTrue);
    expect(back.symptoms, {Symptom.bloating, Symptom.cramping});
    expect(back.tags, {Tag.afterMeal, Tag.coffee});
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
      repo.create(draft(symptoms: {Symptom.none, Symptom.blood})),
      throwsA(isA<EntryValidationException>()),
    );
    expect(await repo.all(), isEmpty);
  });

  test('every entry gets its own uid', () async {
    final a = await repo.create(draft());
    final b = await repo.create(draft());
    expect(a.uid, isNot(b.uid));
  });

  test('update replaces details and keeps identity', () async {
    final e = await repo.create(
      draft(stoolType: 3, symptoms: {Symptom.bloating}, tags: {Tag.stress}),
    );
    clock.utc = clock.utc.add(const Duration(minutes: 5));
    final u = await repo.update(
      e.id,
      draft(comment: 'Edited', symptoms: {Symptom.none}),
    );
    expect(u.id, e.id);
    expect(u.uid, e.uid);
    expect(u.createdAtUtc, e.createdAtUtc);
    expect(u.updatedAtUtc, clock.utc);
    expect(u.comment, 'Edited');
    expect(u.stoolType, isNull);
    expect(u.symptoms, {Symptom.none});
    expect(u.tags, isEmpty);
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

  test('delete removes the entry with its symptoms and tags', () async {
    final e = await repo.create(
      draft(symptoms: {Symptom.urgency}, tags: {Tag.exercise}),
    );
    await repo.delete(e.id);
    expect(await repo.byId(e.id), isNull);
    expect(await db.select(db.entrySymptoms).get(), isEmpty);
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
