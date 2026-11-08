import 'package:poop_tracker/features/journal/domain/entry.dart';

int _nextId = 1;

/// Builds a synthetic entry from a local wall-clock time and the UTC offset
/// in force there. [offsetMinutes] defaults to the 2026 UK offset.
Entry entryAt(
  int year,
  int month,
  int day,
  int hour,
  int minute, {
  int? offsetMinutes,
  int? id,
  String? comment,
  int? stoolType,
  Ease? ease,
  Set<Tag> tags = const {},
  bool hasTime = true,
}) {
  final offset = offsetMinutes ?? _ukOffsetForLocal(year, month, day, hour);
  final utc = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
  ).subtract(Duration(minutes: offset));
  final entryId = id ?? _nextId++;
  return Entry(
    id: entryId,
    uid: 'fixture-$entryId',
    occurredAtUtc: utc,
    originalUtcOffsetMinutes: offset,
    comment: comment,
    stoolType: stoolType,
    ease: ease,
    tags: tags,
    hasTime: hasTime,
    createdAtUtc: utc,
    updatedAtUtc: utc,
  );
}

/// UK offset for a local time in 2026 (ambiguous hours resolve to BST).
int _ukOffsetForLocal(int year, int month, int day, int hour) {
  if (year != 2026) return 0;
  final local = DateTime.utc(year, month, day, hour);
  final bstStart = DateTime.utc(2026, 3, 29, 2); // clocks go forward 1→2 am
  final bstEnd = DateTime.utc(2026, 10, 25, 2); // clocks go back 2→1 am
  return !local.isBefore(bstStart) && local.isBefore(bstEnd) ? 60 : 0;
}
