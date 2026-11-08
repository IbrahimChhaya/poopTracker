import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/app/scope.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/journal/presentation/entry/entry_page_controller.dart';
import 'package:poop_tracker/features/journal/presentation/entry/quick_add.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_diagnostics.dart';

/// Repository whose writes can be made to fail or to wait.
class ControlledRepository extends EntryRepository {
  ControlledRepository(super.db, super.clock);

  bool failCreate = false;
  bool failUpdate = false;
  bool failDetails = false;
  Completer<void>? createGate;
  int creates = 0;

  @override
  Future<Entry> create(EntryDraft draft) async {
    creates++;
    await createGate?.future;
    if (failCreate) throw StateError('simulated write failure');
    return super.create(draft);
  }

  @override
  Future<Entry> update(int id, EntryDraft draft) {
    if (failUpdate) throw StateError('simulated write failure');
    return super.update(id, draft);
  }

  @override
  Future<Entry> updateDetails(
    int id, {
    required int? stoolType,
    required Ease? ease,
    required Set<Tag> tags,
  }) {
    if (failDetails) throw StateError('simulated write failure');
    return super.updateDetails(
      id,
      stoolType: stoolType,
      ease: ease,
      tags: tags,
    );
  }
}

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ControlledRepository repo;
  late ProviderContainer c;
  late MemoryDiagnosticLog log;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 11, 6, 13, 41));
    repo = ControlledRepository(db, clock);
    log = MemoryDiagnosticLog(clock: clock);
    c = ProviderContainer(
      overrides: [
        diagnosticLogProvider.overrideWithValue(log),
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  QuickAddController quickAdd() => c.read(quickAddProvider.notifier);

  group('one-tap add', () {
    test('today records the exact current instant and offset', () async {
      clock.offsetMinutes = 60;
      final e = (await quickAdd().add())!;
      expect(e.occurredAtUtc, clock.utc);
      expect(e.originalUtcOffsetMinutes, 60);
      expect(e.hasTime, isTrue);
      expect(e.comment, isNull);
      expect(e.stoolType, isNull);
      expect(await repo.all(), hasLength(1));
    });

    test('a past day has no time, stored at midday', () async {
      final e = (await quickAdd().add(day: LocalDate(2026, 11, 4)))!;
      expect(e.localDate, LocalDate(2026, 11, 4));
      expect(e.hasTime, isFalse);
      expect(e.occurredAtUtc, DateTime.utc(2026, 11, 4, 12));
    });

    test('today or a future day means now', () async {
      final today = (await quickAdd().add(day: LocalDate(2026, 11, 6)))!;
      expect(today.hasTime, isTrue);
      final future = (await quickAdd().add(day: LocalDate(2026, 11, 9)))!;
      expect(future.localDate, LocalDate(2026, 11, 6));
      expect(future.hasTime, isTrue);
    });

    test('a second tap while adding is ignored: one entry', () async {
      repo.createGate = Completer<void>();
      final first = quickAdd().add();
      final second = quickAdd().add();
      expect(await second, isNull);
      expect(c.read(quickAddProvider).adding, isTrue);
      repo.createGate!.complete();
      expect(await first, isNotNull);
      expect(repo.creates, 1);
      expect(await repo.all(), hasLength(1));
      expect(c.read(quickAddProvider).adding, isFalse);
      // Successful journal actions are never logged.
      expect(log.events, isEmpty);
    });

    test(
      'a failure saves nothing and is reported, then can be retried',
      () async {
        repo.failCreate = true;
        expect(await quickAdd().add(), isNull);
        expect(c.read(quickAddProvider).failed, isTrue);
        expect(await repo.all(), isEmpty);
        expect(log.events, [DiagnosticEvent.entryAddFailed]);
        repo.failCreate = false;
        expect(await quickAdd().add(), isNotNull);
        expect(c.read(quickAddProvider).failed, isFalse);
      },
    );
  });

  group('entry page', () {
    late Entry entry;

    EntryTarget t({bool isNew = false}) => (entry: entry, isNew: isNew);

    EntryPageController page({bool isNew = false}) {
      // Keep the auto-dispose provider alive for the test.
      c.listen(entryPageProvider(t(isNew: isNew)), (_, _) {});
      return c.read(entryPageProvider(t(isNew: isNew)).notifier);
    }

    EntryPageState state() => c.read(entryPageProvider(t()));

    setUp(() async {
      // Recorded in New York, with details from a "details on" session.
      entry = await repo.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 11, 6, 2),
          originalUtcOffsetMinutes: -300,
          comment: 'Original note',
          stoolType: 4,
          ease: Ease.easy,
          tags: {Tag.coffee},
        ),
      );
    });

    test('starts from the stored values, with nothing to save', () {
      page();
      final s = state();
      expect(s.date, LocalDate(2026, 11, 5));
      expect((s.hour, s.minute), (21, 0));
      expect(s.comment, 'Original note');
      expect(s.hasChanges, isFalse);
    });

    test('Save with nothing changed does nothing', () async {
      expect(await page().save(), SaveOutcome.ignored);
    });

    test('a changed note is unsaved until Save; then stored', () async {
      final p = page()..setComment('Edited note');
      expect(state().hasChanges, isTrue);
      expect((await repo.byId(entry.id))!.comment, 'Original note');
      expect(await p.save(), SaveOutcome.saved);
      final saved = (await repo.byId(entry.id))!;
      expect(saved.comment, 'Edited note');
      // The time, zone and details are kept.
      expect(saved.occurredAtUtc, entry.occurredAtUtc);
      expect(saved.originalUtcOffsetMinutes, -300);
      expect(saved.stoolType, 4);
      expect(saved.tags, {Tag.coffee});
      expect(saved.uid, entry.uid);
      expect(state().hasChanges, isFalse);
    });

    test('typing the stored note back is not a change', () {
      page()
        ..setComment('Changed')
        ..setComment('Original note');
      expect(state().hasChanges, isFalse);
    });

    test('choosing the same time again is not a change', () {
      page().setDateTime(LocalDate(2026, 11, 5), 21, 0);
      expect(state().hasChanges, isFalse);
    });

    test('a changed time is resolved in the current zone', () async {
      final p = page()..setDateTime(LocalDate(2026, 11, 5), 8, 25);
      expect(await p.save(), SaveOutcome.saved);
      final saved = (await repo.byId(entry.id))!;
      expect(saved.localDate, LocalDate(2026, 11, 5));
      expect((saved.localWallClock.hour, saved.localWallClock.minute), (8, 25));
      expect(saved.originalUtcOffsetMinutes, 0);
    });

    test('removing the time', () async {
      final p = page()..setDateTime(entry.localDate, 21, 0, hasTime: false);
      expect(await p.save(), SaveOutcome.saved);
      expect((await repo.byId(entry.id))!.hasTime, isFalse);
    });

    test('future times are refused and nothing is stored', () async {
      final p = page();
      expect(p.isInFuture(LocalDate(2026, 11, 6), 13, 42), isFalse);
      expect(p.isInFuture(LocalDate(2026, 11, 6), 13, 43), isTrue);
      expect(
        p.isInFuture(LocalDate(2026, 11, 6), 23, 0, hasTime: false),
        isFalse,
      );
      p.setDateTime(LocalDate(2026, 11, 6), 20, 0);
      expect(await p.save(), SaveOutcome.invalid);
      expect(state().errors, [EntryValidationError.inFuture]);
      expect((await repo.byId(entry.id))!.occurredAtUtc, entry.occurredAtUtc);
    });

    test('a failed Save keeps the changes for another try', () async {
      repo.failUpdate = true;
      final p = page()..setComment('Edited note');
      expect(await p.save(), SaveOutcome.failed);
      expect(state().saveFailed, isTrue);
      // Only the event code is logged: never the note or the error.
      expect(log.events, [DiagnosticEvent.entrySaveFailed]);
      final text = await log.exportText();
      expect(text, isNot(contains('Edited note')));
      expect(text, isNot(contains('simulated')));
      expect(state().comment, 'Edited note');
      repo.failUpdate = false;
      expect(await p.save(), SaveOutcome.saved);
      expect((await repo.byId(entry.id))!.comment, 'Edited note');
    });

    test('a second Save while one is running is ignored', () async {
      final p = page()..setComment('Once');
      final first = p.save();
      expect(await p.save(), SaveOutcome.ignored);
      expect(await first, SaveOutcome.saved);
    });

    group('details save as chosen', () {
      test('without touching an unsaved note', () async {
        final p = page()..setComment('Not saved yet');
        expect(await p.toggleStoolType(6), isTrue);
        final stored = (await repo.byId(entry.id))!;
        expect(stored.stoolType, 6);
        expect(stored.comment, 'Original note');
        // Details are never an unsaved change.
        expect(state().hasChanges, isTrue, reason: 'the note still is');
        expect(state().details.stoolType, 6);
      });

      test('tapping the chosen ease or type again clears it', () async {
        final p = page();
        await p.toggleEase(Ease.easy);
        await p.toggleStoolType(4);
        final stored = (await repo.byId(entry.id))!;
        expect(stored.ease, isNull);
        expect(stored.stoolType, isNull);
        expect(stored.tags, {Tag.coffee});
      });

      test('tags toggle, and Clear removes ease and tags only', () async {
        final p = page();
        await p.toggleTag(Tag.stress);
        expect((await repo.byId(entry.id))!.tags, {Tag.coffee, Tag.stress});
        await p.clearContext();
        final stored = (await repo.byId(entry.id))!;
        expect(stored.tags, isEmpty);
        expect(stored.ease, isNull);
        expect(stored.stoolType, 4);
        await p.clearStoolForm();
        expect((await repo.byId(entry.id))!.stoolType, isNull);
      });

      test('quick choices are stored in order', () async {
        final p = page();
        unawaited(p.toggleStoolType(1));
        unawaited(p.toggleStoolType(2));
        await p.toggleStoolType(3);
        expect((await repo.byId(entry.id))!.stoolType, 3);
      });

      test('a failed write puts the stored value back', () async {
        repo.failDetails = true;
        expect(await page().toggleStoolType(6), isFalse);
        expect(state().details.stoolType, 4);
        expect(state().detailsFailed, isTrue);
        expect(log.events, [DiagnosticEvent.entryDetailFailed]);
        expect((await repo.byId(entry.id))!.stoolType, 4);
      });

      test('Save keeps details chosen on the page', () async {
        final p = page();
        await p.toggleStoolType(2);
        p.setComment('Edited');
        await p.save();
        final stored = (await repo.byId(entry.id))!;
        expect(stored.stoolType, 2);
        expect(stored.comment, 'Edited');
      });
    });

    group('undo', () {
      test('deletes the entry', () async {
        final p = page(isNew: true);
        expect(p.edited, isFalse);
        expect(await p.undo(), isTrue);
        expect(await repo.all(), isEmpty);
      });

      test('counts a stored detail or an unsaved note as an edit', () async {
        final p = page(isNew: true);
        await p.toggleTag(Tag.stress);
        expect(p.edited, isTrue);
      });
    });
  });
}
