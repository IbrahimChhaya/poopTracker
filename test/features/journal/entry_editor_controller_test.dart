import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/app/scope.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/journal/presentation/editor/entry_editor_controller.dart';

import '../../support/fake_clock.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer c;
  late EntryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 11, 6, 13, 41));
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
    );
    repo = c.read(entryRepositoryProvider);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  EditorTarget t(Entry? original, [LocalDate? day]) =>
      (original: original, initialDate: day);

  EntryEditorController editor(Entry? original, [LocalDate? day]) {
    // Keep the auto-dispose provider alive for the test.
    c.listen(entryEditorProvider(t(original, day)), (_, _) {});
    return c.read(entryEditorProvider(t(original, day)).notifier);
  }

  EntryEditorState stateOf(Entry? original, [LocalDate? day]) =>
      c.read(entryEditorProvider(t(original, day)));

  test('a new entry defaults to now and has no changes', () {
    editor(null);
    final s = stateOf(null);
    expect(s.date, LocalDate(2026, 11, 6));
    expect((s.hour, s.minute), (13, 41));
    expect(s.hasChanges, isFalse);
  });

  test('saving untouched uses the exact current instant and offset', () async {
    clock.offsetMinutes = 60;
    final e = editor(null);
    expect(await e.save(), SaveOutcome.saved);
    final saved = (await repo.all()).single;
    expect(saved.occurredAtUtc, clock.utc);
    expect(saved.originalUtcOffsetMinutes, 60);
  });

  test('a selected past day is the default, with no changes', () async {
    final day = LocalDate(2026, 11, 4);
    final e = editor(null, day);
    final s = stateOf(null, day);
    expect(s.date, day);
    expect((s.hour, s.minute), (13, 41));
    expect(s.hasChanges, isFalse);
    expect(await e.save(), SaveOutcome.saved);
    final saved = (await repo.all()).single;
    expect(saved.localDate, day);
    expect(saved.occurredAtUtc, DateTime.utc(2026, 11, 4, 13, 41));
  });

  test('today or a future day as the default means now', () {
    editor(null, LocalDate(2026, 11, 6));
    expect(stateOf(null, LocalDate(2026, 11, 6)).date, LocalDate(2026, 11, 6));
    editor(null, LocalDate(2026, 11, 9));
    expect(stateOf(null, LocalDate(2026, 11, 9)).date, LocalDate(2026, 11, 6));
  });

  test('a chosen time is resolved in the current zone', () async {
    final e = editor(null)..setDateTime(LocalDate(2026, 11, 5), 8, 25);
    expect(stateOf(null).hasChanges, isTrue);
    await e.save();
    final saved = (await repo.all()).single;
    expect(saved.localDate, LocalDate(2026, 11, 5));
    expect((saved.localWallClock.hour, saved.localWallClock.minute), (8, 25));
  });

  test('future times are detected and refused', () async {
    final e = editor(null);
    expect(e.isInFuture(LocalDate(2026, 11, 6), 13, 42), isFalse); // 1 min
    expect(e.isInFuture(LocalDate(2026, 11, 6), 13, 43), isTrue);
    expect(e.isInFuture(LocalDate(2026, 11, 7), 9, 0), isTrue);
    e.setDateTime(LocalDate(2026, 11, 6), 20, 0);
    expect(await e.save(), SaveOutcome.invalid);
    expect(stateOf(null).errors, [EntryValidationError.inFuture]);
    expect(await repo.all(), isEmpty);
  });

  test('a second save while one is running is ignored', () async {
    final e = editor(null)..setComment('Once only');
    final first = e.save();
    final second = e.save();
    expect(await second, SaveOutcome.ignored);
    expect(await first, SaveOutcome.saved);
    expect(await repo.all(), hasLength(1));
  });

  group('optional details', () {
    test('choosing and clearing a stool type', () {
      final e = editor(null)..toggleStoolType(4);
      expect(stateOf(null).details.stoolType, 4);
      expect(stateOf(null).hasChanges, isTrue);
      e.toggleStoolType(4);
      expect(stateOf(null).details.stoolType, isNull);
      expect(stateOf(null).hasChanges, isFalse);
    });

    test('"None" and other symptoms exclude each other', () {
      final e = editor(null)
        ..toggleSymptom(Symptom.bloating)
        ..toggleSymptom(Symptom.cramping);
      expect(stateOf(null).details.symptoms, {
        Symptom.bloating,
        Symptom.cramping,
      });
      e.toggleSymptom(Symptom.none);
      expect(stateOf(null).details.symptoms, {Symptom.none});
      e.toggleSymptom(Symptom.urgency);
      expect(stateOf(null).details.symptoms, {Symptom.urgency});
    });

    test('ease is single choice and clears on a second tap', () {
      final e = editor(null)
        ..toggleEase(Ease.easy)
        ..toggleEase(Ease.difficult);
      expect(stateOf(null).details.ease, Ease.difficult);
      e.toggleEase(Ease.difficult);
      expect(stateOf(null).details.ease, isNull);
    });

    test('details are saved', () async {
      final e = editor(null)
        ..toggleStoolType(3)
        ..toggleEase(Ease.someStraining)
        ..toggleSymptom(Symptom.mucus)
        ..toggleTag(Tag.stress)
        ..toggleTag(Tag.exercise);
      expect(await e.save(), SaveOutcome.saved);
      final saved = (await repo.all()).single;
      expect(saved.stoolType, 3);
      expect(saved.ease, Ease.someStraining);
      expect(saved.symptoms, {Symptom.mucus});
      expect(saved.tags, {Tag.stress, Tag.exercise});
    });
  });

  group('editing', () {
    late Entry original;

    setUp(() async {
      // Recorded in New York, with optional details from a "details on"
      // session.
      original = await repo.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 11, 6, 2),
          originalUtcOffsetMinutes: -300,
          comment: 'Original note',
          stoolType: 4,
          ease: Ease.easy,
          symptoms: {Symptom.bloating},
          tags: {Tag.coffee},
        ),
      );
    });

    test('starts from the saved values, with no changes', () {
      editor(original);
      final s = stateOf(original);
      expect(s.date, LocalDate(2026, 11, 5));
      expect((s.hour, s.minute), (21, 0));
      expect(s.comment, 'Original note');
      expect(s.hasChanges, isFalse);
    });

    test(
      'changing only the note keeps the time, zone and hidden details',
      () async {
        final e = editor(original)..setComment('Edited note');
        expect(await e.save(), SaveOutcome.saved);
        final saved = (await repo.byId(original.id))!;
        expect(saved.comment, 'Edited note');
        expect(saved.occurredAtUtc, original.occurredAtUtc);
        expect(saved.originalUtcOffsetMinutes, -300);
        expect(saved.stoolType, 4);
        expect(saved.ease, Ease.easy);
        expect(saved.symptoms, {Symptom.bloating});
        expect(saved.tags, {Tag.coffee});
        expect(saved.uid, original.uid);
      },
    );

    test('choosing the same time again is not a change', () {
      editor(original).setDateTime(LocalDate(2026, 11, 5), 21, 0);
      expect(stateOf(original).hasChanges, isFalse);
    });

    test('clearing the note removes it', () async {
      final e = editor(original)..setComment('   ');
      await e.save();
      expect((await repo.byId(original.id))!.comment, isNull);
    });
  });
}
