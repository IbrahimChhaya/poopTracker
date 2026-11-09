import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ids/uid.dart';
import '../domain/backup_payload.dart';
import '../domain/entry.dart';
import '../domain/grouping.dart';

/// A draft failed validation. Nothing was written.
class EntryValidationException implements Exception {
  EntryValidationException(List<EntryValidationError> errors)
    : errors = List.unmodifiable(errors);

  final List<EntryValidationError> errors;

  @override
  String toString() => 'EntryValidationException($errors)';
}

/// No entry has this id (for example it was deleted elsewhere).
class EntryNotFoundException implements Exception {
  const EntryNotFoundException();

  @override
  String toString() => 'EntryNotFoundException';
}

/// The only way the app reads or writes journal entries.
///
/// Every write validates first, uses one transaction for the entry and its
/// tags, and completes only after the commit. Queries use
/// drift's bound parameters; nothing is logged.
class EntryRepository {
  EntryRepository(this._db, this._clock, {String Function()? newUid})
    : _newUid = newUid ?? generateUid;

  final AppDatabase _db;
  final Clock _clock;
  final String Function() _newUid;

  Future<Entry> create(EntryDraft draft) async {
    final now = _clock.nowUtc();
    _validate(draft, now);
    final nowMs = now.millisecondsSinceEpoch;
    final id = await _db.transaction(() async {
      final id = await _db
          .into(_db.entries)
          .insert(
            EntriesCompanion.insert(
              uid: _newUid(),
              occurredAtUtcMs: draft.occurredAtUtc.millisecondsSinceEpoch,
              originalUtcOffsetMinutes: draft.originalUtcOffsetMinutes,
              hasTime: Value(draft.hasTime),
              comment: Value(draft.comment),
              stoolType: Value(draft.stoolType),
              ease: Value(draft.ease?.code),
              createdAtUtcMs: nowMs,
              updatedAtUtcMs: nowMs,
            ),
          );
      await _writeDetails(id, draft);
      return id;
    });
    return (await byId(id))!;
  }

  Future<Entry> update(int id, EntryDraft draft) async {
    final now = _clock.nowUtc();
    _validate(draft, now);
    await _db.transaction(() async {
      final changed =
          await (_db.update(_db.entries)..where((e) => e.id.equals(id))).write(
            EntriesCompanion(
              occurredAtUtcMs: Value(
                draft.occurredAtUtc.millisecondsSinceEpoch,
              ),
              originalUtcOffsetMinutes: Value(draft.originalUtcOffsetMinutes),
              hasTime: Value(draft.hasTime),
              comment: Value(draft.comment),
              stoolType: Value(draft.stoolType),
              ease: Value(draft.ease?.code),
              updatedAtUtcMs: Value(now.millisecondsSinceEpoch),
            ),
          );
      if (changed == 0) throw const EntryNotFoundException();
      await (_db.delete(
        _db.entryTags,
      )..where((t) => t.entryId.equals(id))).go();
      await _writeDetails(id, draft);
    });
    return (await byId(id))!;
  }

  /// Replaces only the optional details (stool form, ease and tags), leaving
  /// the time and note as stored. The entry page saves details the moment
  /// they are chosen, separately from unsaved time or note changes.
  Future<Entry> updateDetails(
    int id, {
    required int? stoolType,
    required Ease? ease,
    required Set<Tag> tags,
  }) async {
    if (stoolType != null && (stoolType < 1 || stoolType > 7)) {
      throw EntryValidationException(const [
        EntryValidationError.stoolTypeOutOfRange,
      ]);
    }
    final now = _clock.nowUtc();
    await _db.transaction(() async {
      final changed =
          await (_db.update(_db.entries)..where((e) => e.id.equals(id))).write(
            EntriesCompanion(
              stoolType: Value(stoolType),
              ease: Value(ease?.code),
              updatedAtUtcMs: Value(now.millisecondsSinceEpoch),
            ),
          );
      if (changed == 0) throw const EntryNotFoundException();
      await (_db.delete(
        _db.entryTags,
      )..where((t) => t.entryId.equals(id))).go();
      await _db.batch((b) {
        b.insertAll(_db.entryTags, [
          for (final t in tags)
            EntryTagsCompanion.insert(entryId: id, code: t.code),
        ]);
      });
    });
    return (await byId(id))!;
  }

  /// Adds the entries from a backup in one transaction. An entry whose uid
  /// is already in the journal (or earlier in the same backup) is skipped;
  /// nothing is ever overwritten or deleted. Original created and updated
  /// times are kept. Any invalid entry rolls the whole restore back.
  Future<({int added, int skipped})> restore(List<BackupEntry> entries) {
    return _db.transaction(() async {
      final uidColumn = _db.entries.uid;
      final known = {
        for (final row in await (_db.selectOnly(
          _db.entries,
        )..addColumns([uidColumn])).get())
          row.read(uidColumn)!,
      };
      var added = 0;
      var skipped = 0;
      for (final b in entries) {
        if (!known.add(b.uid)) {
          skipped++;
          continue;
        }
        // A backup from a phone whose clock was ahead is still restored;
        // every other rule applies.
        final errors = b.draft.validate(nowUtc: _clock.nowUtc())
          ..remove(EntryValidationError.inFuture);
        if (errors.isNotEmpty) throw EntryValidationException(errors);
        final id = await _db
            .into(_db.entries)
            .insert(
              EntriesCompanion.insert(
                uid: b.uid,
                occurredAtUtcMs: b.draft.occurredAtUtc.millisecondsSinceEpoch,
                originalUtcOffsetMinutes: b.draft.originalUtcOffsetMinutes,
                hasTime: Value(b.draft.hasTime),
                comment: Value(b.draft.comment),
                stoolType: Value(b.draft.stoolType),
                ease: Value(b.draft.ease?.code),
                createdAtUtcMs: b.createdAtUtc.millisecondsSinceEpoch,
                updatedAtUtcMs: b.updatedAtUtc.millisecondsSinceEpoch,
              ),
            );
        await _writeDetails(id, b.draft);
        added++;
      }
      return (added: added, skipped: skipped);
    });
  }

  /// Deletes the entry with its tags.
  Future<void> delete(int id) async {
    final removed = await (_db.delete(
      _db.entries,
    )..where((e) => e.id.equals(id))).go();
    if (removed == 0) throw const EntryNotFoundException();
  }

  Future<Entry?> byId(int id) async {
    final row = await (_db.select(
      _db.entries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (await _withDetails([row])).single;
  }

  /// Every entry, newest first (see [compareNewestFirst]).
  Future<List<Entry>> all() async =>
      _sorted(await _withDetails(await _allQuery().get()));

  /// Every entry, newest first, updated after each change.
  Stream<List<Entry>> watchAll() => _allQuery().watch().asyncMap(
    (rows) async => _sorted(await _withDetails(rows)),
  );

  static List<Entry> _sorted(List<Entry> entries) =>
      [...entries]..sort(compareNewestFirst);

  SimpleSelectStatement<$EntriesTable, EntryRow> _allQuery() =>
      _db.select(_db.entries)..orderBy([
        (e) => OrderingTerm.desc(e.occurredAtUtcMs),
        (e) => OrderingTerm.desc(e.id),
      ]);

  void _validate(EntryDraft draft, DateTime nowUtc) {
    final errors = draft.validate(nowUtc: nowUtc);
    if (errors.isNotEmpty) throw EntryValidationException(errors);
  }

  Future<void> _writeDetails(int id, EntryDraft draft) async {
    await _db.batch((b) {
      b.insertAll(_db.entryTags, [
        for (final t in draft.tags)
          EntryTagsCompanion.insert(entryId: id, code: t.code),
      ]);
    });
  }

  Future<List<Entry>> _withDetails(List<EntryRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r.id];
    final tags = <int, Set<Tag>>{};
    for (final t in await (_db.select(
      _db.entryTags,
    )..where((t) => t.entryId.isIn(ids))).get()) {
      final tag = Tag.fromCode(t.code);
      if (tag != null) tags.putIfAbsent(t.entryId, () => {}).add(tag);
    }
    return [
      for (final r in rows)
        Entry(
          id: r.id,
          uid: r.uid,
          occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(
            r.occurredAtUtcMs,
            isUtc: true,
          ),
          originalUtcOffsetMinutes: r.originalUtcOffsetMinutes,
          hasTime: r.hasTime,
          comment: r.comment,
          stoolType: r.stoolType,
          ease: r.ease == null ? null : Ease.fromCode(r.ease!),
          tags: tags[r.id] ?? const {},
          createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
            r.createdAtUtcMs,
            isUtc: true,
          ),
          updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
            r.updatedAtUtcMs,
            isUtc: true,
          ),
        ),
    ];
  }
}
