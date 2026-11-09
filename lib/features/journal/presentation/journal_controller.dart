import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/scope.dart';
import '../../../core/clock.dart';
import '../../../core/time/local_date.dart';
import '../../../ui/widgets/week_strip.dart';
import '../../trends/domain/weekly_summary.dart';
import '../domain/entry.dart';
import '../domain/grouping.dart';

/// How far back the journal home can page, in weeks (about ten years).
const int maxWeeksBack = 520;

/// What the journal home is showing: a week ([weeksBack] weeks before the
/// current one) and, optionally, one day in it. Scoped to the session.
final class JournalSelection {
  const JournalSelection({this.weeksBack = 0, this.day});

  /// 0 is the current week. Never negative: future weeks are not shown.
  final int weeksBack;

  /// The day picked in the week strip, or null for the whole week.
  final LocalDate? day;
}

class JournalSelectionController extends Notifier<JournalSelection> {
  @override
  JournalSelection build() => const JournalSelection();

  /// Shows the week [weeksBack] weeks ago. Clears the selected day.
  void showWeek(int weeksBack) {
    final w = weeksBack.clamp(0, maxWeeksBack);
    if (w != state.weeksBack) state = JournalSelection(weeksBack: w);
  }

  /// Selects [day], or goes back to the whole week if it is already selected.
  void toggleDay(LocalDate day) => state = JournalSelection(
    weeksBack: state.weeksBack,
    day: state.day == day ? null : day,
  );
}

final journalSelectionProvider =
    NotifierProvider<JournalSelectionController, JournalSelection>(
      JournalSelectionController.new,
      dependencies: [appDatabaseProvider],
    );

/// The seven days of the week [weeksBack] weeks before today's week.
List<WeekStripDay> weekDays(
  LocalDate today,
  int weeksBack,
  Set<LocalDate> daysWithEntries,
) {
  final monday = today.weekStart.addDays(-7 * weeksBack);
  return [
    for (var i = 0; i < 7; i++)
      WeekStripDay(
        date: monday.addDays(i),
        hasEntries: daysWithEntries.contains(monday.addDays(i)),
        isToday: monday.addDays(i) == today,
        isFuture: monday.addDays(i).isAfter(today),
      ),
  ];
}

/// Everything the journal home shows (1.4, 2.1, 4.1).
final class JournalHomeView {
  const JournalHomeView({
    required this.today,
    required this.selection,
    required this.daysWithEntries,
    required this.entriesInShownWeek,
    required this.latestInShownWeek,
    required this.listed,
    required this.lastFourWeeks,
  });

  final LocalDate today;
  final JournalSelection selection;
  final Set<LocalDate> daysWithEntries;

  /// Entries in the week on screen (the current week unless the user has
  /// paged back), and the latest of them.
  final int entriesInShownWeek;
  final Entry? latestInShownWeek;

  /// The shown week's entries, or the selected day's, newest first.
  final List<Entry> listed;
  final int lastFourWeeks;

  LocalDate get shownWeekStart =>
      today.weekStart.addDays(-7 * selection.weeksBack);
}

final journalHomeProvider = Provider<AsyncValue<JournalHomeView>>((ref) {
  final today = ref.watch(clockProvider).today();
  final selection = ref.watch(journalSelectionProvider);
  return ref.watch(entriesProvider).whenData((entries) {
    final shownWeek = today.weekStart.addDays(-7 * selection.weeksBack);
    final inWeek = entriesInWeek(entries, shownWeek);
    final day = selection.day;
    return JournalHomeView(
      today: today,
      selection: selection,
      daysWithEntries: {for (final e in entries) e.localDate},
      entriesInShownWeek: inWeek.length,
      latestInShownWeek: inWeek.isEmpty ? null : inWeek.first,
      listed: day == null ? inWeek : entriesOnDay(entries, day),
      lastFourWeeks: summariseWeeks(
        entries,
        lastWeekDay: today,
        weeks: 4,
      ).totalEntries,
    );
  });
}, dependencies: [entriesProvider, journalSelectionProvider]);
