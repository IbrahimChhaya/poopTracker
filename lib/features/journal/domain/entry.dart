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

/// Circumstance tags ("Anything to note?"). Stored by [code].
enum Tag {
  afterMeal('after_meal'),
  coffee('coffee'),
  stress('stress'),
  lowFluids('low_fluids'),
  medication('medication'),
  onPeriod('on_period'),
  feelingSick('feeling_sick');

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

/// An entry without a time is stored at this local hour on its day. The hour
/// is never shown; midday keeps the local day stable if the offset shifts a
/// little.
const int dateOnlyHour = 12;

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
  inFuture,
  utcOffsetOutOfRange,
  timeNotUtc,
}

/// The editable fields of an entry, before or after saving. Only the date is
/// required; the time and every other field are optional.
final class EntryDraft {
  EntryDraft({
    required this.occurredAtUtc,
    required this.originalUtcOffsetMinutes,
    this.hasTime = true,
    String? comment,
    this.stoolType,
    this.ease,
    Set<Tag> tags = const {},
  }) : comment = normaliseComment(comment),
       tags = Set.unmodifiable(tags);

  /// For a date-only entry ([hasTime] false), midday on its local day.
  final DateTime occurredAtUtc;
  final int originalUtcOffsetMinutes;

  /// False when the user did not record a time of day.
  final bool hasTime;

  /// Trimmed; null when there is no note.
  final String? comment;
  final int? stoolType;
  final Ease? ease;
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
    if (!occurredAtUtc.isUtc) {
      errors.add(EntryValidationError.timeNotUtc);
    } else if (hasTime) {
      if (occurredAtUtc.isAfter(nowUtc.add(futureTolerance))) {
        errors.add(EntryValidationError.inFuture);
      }
    } else {
      // Without a time only the day matters: today is fine, tomorrow is not.
      final day = LocalDate.fromUtc(
        occurredAtUtc,
        offsetMinutes: originalUtcOffsetMinutes,
      );
      final today = LocalDate.fromUtc(
        nowUtc,
        offsetMinutes: originalUtcOffsetMinutes,
      );
      if (day.isAfter(today)) errors.add(EntryValidationError.inFuture);
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
    this.hasTime = true,
    this.comment,
    this.stoolType,
    this.ease,
    Set<Tag> tags = const {},
  }) : tags = Set.unmodifiable(tags);

  /// Local database key.
  final int id;

  /// Stable identity across devices and backups, used to skip duplicates on
  /// restore.
  final String uid;

  /// For a date-only entry, midday on its local day (never shown).
  final DateTime occurredAtUtc;
  final int originalUtcOffsetMinutes;

  /// False when no time of day was recorded.
  final bool hasTime;
  final String? comment;
  final int? stoolType;
  final Ease? ease;
  final Set<Tag> tags;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// The calendar day the entry belongs to (see [LocalDate]).
  LocalDate get localDate =>
      LocalDate.fromUtc(occurredAtUtc, offsetMinutes: originalUtcOffsetMinutes);

  /// The clock time when the entry happened, where it happened. Meaningless
  /// when [hasTime] is false; use [localTime] for display.
  DateTime get localWallClock =>
      wallClock(occurredAtUtc, offsetMinutes: originalUtcOffsetMinutes);

  /// The recorded wall-clock time, or null for a date-only entry.
  DateTime? get localTime => hasTime ? localWallClock : null;

  EntryDraft toDraft() => EntryDraft(
    occurredAtUtc: occurredAtUtc,
    originalUtcOffsetMinutes: originalUtcOffsetMinutes,
    hasTime: hasTime,
    comment: comment,
    stoolType: stoolType,
    ease: ease,
    tags: tags,
  );

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.id == id &&
      other.uid == uid &&
      other.occurredAtUtc == occurredAtUtc &&
      other.originalUtcOffsetMinutes == originalUtcOffsetMinutes &&
      other.hasTime == hasTime &&
      other.comment == comment &&
      other.stoolType == stoolType &&
      other.ease == ease &&
      other.tags.length == tags.length &&
      other.tags.containsAll(tags) &&
      other.createdAtUtc == createdAtUtc &&
      other.updatedAtUtc == updatedAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    occurredAtUtc,
    originalUtcOffsetMinutes,
    hasTime,
    comment,
    stoolType,
    ease,
    Object.hashAllUnordered(tags),
    createdAtUtc,
    updatedAtUtc,
  );

  // Deliberately omits the note: entries must never appear in logs.
  @override
  String toString() => 'Entry(id: $id)';
}
