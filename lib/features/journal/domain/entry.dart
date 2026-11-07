import 'package:characters/characters.dart';

import '../../../core/time/local_date.dart';

/// How it felt. Stored by [code].
enum Ease {
  easy('easy'),
  someStraining('some_straining'),
  difficult('difficult');

  const Ease(this.code);

  final String code;

  /// Null for an unknown code, for example from a newer backup.
  static Ease? fromCode(String code) => _byCode(values, code, (e) => e.code);
}

/// Predefined symptoms (no free-text symptoms). Stored by [code].
///
/// [none] is an explicit "no symptoms" answer and cannot be combined with any
/// other symptom. In summaries it counts the same as not answering.
enum Symptom {
  none('none'),
  bloating('bloating'),
  cramping('cramping'),
  urgency('urgency'),
  mucus('mucus'),
  blood('blood');

  const Symptom(this.code);

  final String code;

  static Symptom? fromCode(String code) => _byCode(values, code, (e) => e.code);
}

/// Circumstance tags ("Anything to note?"). Stored by [code].
enum Tag {
  afterMeal('after_meal'),
  coffee('coffee'),
  stress('stress'),
  lowFluids('low_fluids'),
  medication('medication'),
  exercise('exercise');

  const Tag(this.code);

  final String code;

  static Tag? fromCode(String code) => _byCode(values, code, (e) => e.code);
}

T? _byCode<T>(List<T> values, String code, String Function(T) codeOf) {
  for (final v in values) {
    if (codeOf(v) == code) return v;
  }
  return null;
}

/// Longest note, counted in user-perceived characters (so an emoji is 1).
const int maxCommentLength = 500;

/// Lowest and highest Bristol stool form types.
const int minStoolType = 1;
const int maxStoolType = 7;

/// Entries may not be later than now. This small allowance covers the time
/// between choosing "now" and pressing save, and minor clock drift.
const Duration futureTolerance = Duration(minutes: 1);

/// Real-world UTC offsets range from -12:00 to +14:00.
const int minUtcOffsetMinutes = -12 * 60;
const int maxUtcOffsetMinutes = 14 * 60;

/// Trims a note. A note that is empty after trimming becomes null.
String? normaliseComment(String? raw) {
  final trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Length of [text] as a person would count it.
int commentLength(String text) => text.characters.length;

enum EntryValidationError {
  commentTooLong,
  stoolTypeOutOfRange,
  noneWithOtherSymptoms,
  inFuture,
  utcOffsetOutOfRange,
  timeNotUtc,
}

/// The editable fields of an entry, before or after saving. Only the date and
/// time are required; every other field is optional.
final class EntryDraft {
  EntryDraft({
    required this.occurredAtUtc,
    required this.originalUtcOffsetMinutes,
    String? comment,
    this.stoolType,
    this.ease,
    Set<Symptom> symptoms = const {},
    Set<Tag> tags = const {},
  }) : comment = normaliseComment(comment),
       symptoms = Set.unmodifiable(symptoms),
       tags = Set.unmodifiable(tags);

  final DateTime occurredAtUtc;
  final int originalUtcOffsetMinutes;

  /// Trimmed; null when there is no note.
  final String? comment;
  final int? stoolType;
  final Ease? ease;
  final Set<Symptom> symptoms;
  final Set<Tag> tags;

  /// Every problem with this draft. Empty means it can be saved.
  List<EntryValidationError> validate({required DateTime nowUtc}) {
    final errors = <EntryValidationError>[];
    final c = comment;
    if (c != null && commentLength(c) > maxCommentLength) {
      errors.add(EntryValidationError.commentTooLong);
    }
    final s = stoolType;
    if (s != null && (s < minStoolType || s > maxStoolType)) {
      errors.add(EntryValidationError.stoolTypeOutOfRange);
    }
    if (symptoms.contains(Symptom.none) && symptoms.length > 1) {
      errors.add(EntryValidationError.noneWithOtherSymptoms);
    }
    if (!occurredAtUtc.isUtc) {
      errors.add(EntryValidationError.timeNotUtc);
    } else if (occurredAtUtc.isAfter(nowUtc.add(futureTolerance))) {
      errors.add(EntryValidationError.inFuture);
    }
    if (originalUtcOffsetMinutes < minUtcOffsetMinutes ||
        originalUtcOffsetMinutes > maxUtcOffsetMinutes) {
      errors.add(EntryValidationError.utcOffsetOutOfRange);
    }
    return errors;
  }
}

/// A saved journal entry.
final class Entry {
  Entry({
    required this.id,
    required this.uid,
    required this.occurredAtUtc,
    required this.originalUtcOffsetMinutes,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.comment,
    this.stoolType,
    this.ease,
    Set<Symptom> symptoms = const {},
    Set<Tag> tags = const {},
  }) : symptoms = Set.unmodifiable(symptoms),
       tags = Set.unmodifiable(tags);

  /// Local database key.
  final int id;

  /// Stable identity across devices and backups, used to skip duplicates on
  /// restore.
  final String uid;
  final DateTime occurredAtUtc;
  final int originalUtcOffsetMinutes;
  final String? comment;
  final int? stoolType;
  final Ease? ease;
  final Set<Symptom> symptoms;
  final Set<Tag> tags;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// The calendar day the entry belongs to (see [LocalDate]).
  LocalDate get localDate =>
      LocalDate.fromUtc(occurredAtUtc, offsetMinutes: originalUtcOffsetMinutes);

  /// The clock time when the entry happened, where it happened.
  DateTime get localWallClock =>
      wallClock(occurredAtUtc, offsetMinutes: originalUtcOffsetMinutes);

  /// True when at least one real symptom was recorded ("None" and no answer
  /// both count as no symptoms).
  bool get hasSymptoms => symptoms.any((s) => s != Symptom.none);

  EntryDraft toDraft() => EntryDraft(
    occurredAtUtc: occurredAtUtc,
    originalUtcOffsetMinutes: originalUtcOffsetMinutes,
    comment: comment,
    stoolType: stoolType,
    ease: ease,
    symptoms: symptoms,
    tags: tags,
  );

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.id == id &&
      other.uid == uid &&
      other.occurredAtUtc == occurredAtUtc &&
      other.originalUtcOffsetMinutes == originalUtcOffsetMinutes &&
      other.comment == comment &&
      other.stoolType == stoolType &&
      other.ease == ease &&
      _sameSet(other.symptoms, symptoms) &&
      _sameSet(other.tags, tags) &&
      other.createdAtUtc == createdAtUtc &&
      other.updatedAtUtc == updatedAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    occurredAtUtc,
    originalUtcOffsetMinutes,
    comment,
    stoolType,
    ease,
    Object.hashAllUnordered(symptoms),
    Object.hashAllUnordered(tags),
    createdAtUtc,
    updatedAtUtc,
  );

  // Deliberately omits the note: entries must never appear in logs.
  @override
  String toString() => 'Entry(id: $id)';
}

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
