import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/scope.dart';
import '../../../core/clock.dart';
import '../../../core/time/local_date.dart';
import '../domain/entry.dart';
import '../domain/grouping.dart';

/// Date ranges offered by "Filter entries" (4.4), narrowest first.
enum HistoryRange {
  last2Weeks('Last 2 weeks'),
  last4Weeks('Last 4 weeks'),
  last3Months('Last 3 months'),
  allTime('All time');

  const HistoryRange(this.label);

  final String label;

  /// First day included, or null for all time. Ranges end today.
  LocalDate? firstDay(LocalDate today) => switch (this) {
    last2Weeks => today.addDays(-13),
    last4Weeks => today.addDays(-27),
    last3Months => _monthsBefore(today, 3).addDays(1),
    allTime => null,
  };

  /// The next wider range, for "Show earlier entries".
  HistoryRange? get wider =>
      index + 1 < values.length ? values[index + 1] : null;

  static const HistoryRange initial = last2Weeks;
}

LocalDate _monthsBefore(LocalDate d, int months) {
  var y = d.year;
  var m = d.month - months;
  while (m < 1) {
    m += 12;
    y--;
  }
  final lastDay = DateTime.utc(y, m + 1, 0).day;
  return LocalDate(y, m, d.day > lastDay ? lastDay : d.day);
}

final class HistoryQuery {
  const HistoryQuery({
    this.search = '',
    this.range = HistoryRange.initial,
    this.stoolType,
  });

  final String search;
  final HistoryRange range;

  /// Only entries of this stool form type; null for all types. Ignored while
  /// the stool form setting is off.
  final int? stoolType;

  HistoryQuery copyWith({String? search, HistoryRange? range}) => HistoryQuery(
    search: search ?? this.search,
    range: range ?? this.range,
    stoolType: stoolType,
  );

  HistoryQuery withStoolType(int? type) =>
      HistoryQuery(search: search, range: range, stoolType: type);
}

/// Search text and date range for History. Scoped to the session, so the
/// search is forgotten when the app locks.
class HistoryQueryController extends Notifier<HistoryQuery> {
  @override
  HistoryQuery build() => const HistoryQuery();

  void setSearch(String text) => state = state.copyWith(search: text);
  void clearSearch() => state = state.copyWith(search: '');
  void setRange(HistoryRange range) => state = state.copyWith(range: range);
  void clearFilters() => state = HistoryQuery(search: state.search);
  void setStoolType(int? type) => state = state.withStoolType(type);

  void showEarlier() {
    final wider = state.range.wider;
    if (wider != null) state = state.copyWith(range: wider);
  }
}

final historyQueryProvider =
    NotifierProvider<HistoryQueryController, HistoryQuery>(
      HistoryQueryController.new,
      dependencies: [appDatabaseProvider],
    );

final class HistoryView {
  const HistoryView({
    required this.today,
    required this.query,
    required this.from,
    required this.groups,
    required this.matchCount,
    required this.journalIsEmpty,
    required this.hasEarlier,
  });

  final LocalDate today;
  final HistoryQuery query;

  /// First day shown, or null for all time (then the oldest entry's day).
  final LocalDate? from;
  final List<DayGroup> groups;
  final int matchCount;

  /// No entries at all, regardless of filters.
  final bool journalIsEmpty;

  /// Entries exist before the current range (offer "Show earlier entries").
  final bool hasEarlier;

  /// Searching or filtering by type, so an empty result means "no match".
  bool get searching =>
      query.search.trim().isNotEmpty || query.stoolType != null;
}

/// Case-insensitive match of [search] inside the note. Entries without a
/// note never match a search.
bool noteMatches(Entry e, String search) {
  final needle = search.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return e.comment?.toLowerCase().contains(needle) ?? false;
}

final historyViewProvider = Provider<AsyncValue<HistoryView>>((ref) {
  final today = ref.watch(clockProvider).today();
  final query = ref.watch(historyQueryProvider);
  final showStool = ref.watch(displayProvider).showStoolForm;
  final type = showStool ? query.stoolType : null;
  bool matches(Entry e) =>
      noteMatches(e, query.search) && (type == null || e.stoolType == type);
  return ref.watch(entriesProvider).whenData((entries) {
    final from = query.range.firstDay(today);
    final inRange = from == null
        ? entries
        : entriesBetween(entries, from: from, to: today);
    final found = inRange.where(matches).toList();
    final hasEarlier =
        from != null &&
        entries.any((e) => e.localDate.isBefore(from) && matches(e));
    return HistoryView(
      today: today,
      query: query,
      from: from ?? (entries.isEmpty ? today : entries.last.localDate),
      groups: groupByLocalDay(found),
      matchCount: found.length,
      journalIsEmpty: entries.isEmpty,
      hasEarlier: hasEarlier,
    );
  });
}, dependencies: [entriesProvider, historyQueryProvider, displayProvider]);
