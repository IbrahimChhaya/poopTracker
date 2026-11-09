import '../../../core/time/local_date.dart';
import 'entry.dart';

/// Entries that share a local day, newest first.
final class DayGroup {
  DayGroup(this.date, List<Entry> entries)
    : entries = List.unmodifiable(entries);

  final LocalDate date;
  final List<Entry> entries;
}

/// Newest first: by local day, then entries with a time (latest first), then
/// entries without a time (most recently added first), then by id.
///
/// Within a day this follows when entries actually happened. After a time zone
/// change the clock times shown can then look out of order, which is rare
/// and truthful. Date-only entries go last in their day rather than at the
/// hidden midday placeholder.
int compareNewestFirst(Entry a, Entry b) {
  final byDay = b.localDate.compareTo(a.localDate);
  if (byDay != 0) return byDay;
  if (a.hasTime != b.hasTime) return a.hasTime ? -1 : 1;
  final byTime = a.hasTime
      ? b.occurredAtUtc.compareTo(a.occurredAtUtc)
      : b.createdAtUtc.compareTo(a.createdAtUtc);
  return byTime != 0 ? byTime : b.id.compareTo(a.id);
}

/// Groups [entries] by their local day (see [Entry.localDate]). Days are
/// newest first, and so are the entries within each day.
List<DayGroup> groupByLocalDay(Iterable<Entry> entries) {
  final byDay = <LocalDate, List<Entry>>{};
  for (final e in entries) {
    byDay.putIfAbsent(e.localDate, () => []).add(e);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days) DayGroup(d, byDay[d]!..sort(compareNewestFirst)),
  ];
}

/// Entries whose local day falls in the Monday-to-Sunday week containing
/// [anyDayInWeek], newest first. This is "This week's journal".
List<Entry> entriesInWeek(Iterable<Entry> entries, LocalDate anyDayInWeek) {
  final start = anyDayInWeek.weekStart;
  final end = anyDayInWeek.weekEnd;
  return entries
      .where((e) => !e.localDate.isBefore(start) && !e.localDate.isAfter(end))
      .toList()
    ..sort(compareNewestFirst);
}

/// Entries on [day], newest first. This is the journal for a selected day.
List<Entry> entriesOnDay(Iterable<Entry> entries, LocalDate day) =>
    entries.where((e) => e.localDate == day).toList()..sort(compareNewestFirst);

/// Entries whose local day is between [from] and [to] inclusive, newest
/// first. Used by the History date-range filter.
List<Entry> entriesBetween(
  Iterable<Entry> entries, {
  required LocalDate from,
  required LocalDate to,
}) {
  return entries
      .where((e) => !e.localDate.isBefore(from) && !e.localDate.isAfter(to))
      .toList()
    ..sort(compareNewestFirst);
}
