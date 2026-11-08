import 'package:drift/drift.dart';

import '../../../core/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ids/uid.dart';
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
