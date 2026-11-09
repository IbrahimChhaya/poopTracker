import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/scope.dart';
import '../../../core/clock.dart';
import '../../../core/time/local_date.dart';
import '../domain/weekly_summary.dart';

/// Which weeks Trends shows: a [range], and how many whole ranges before the
/// one ending this week ([rangesBack], never negative). Scoped to the session.
final class TrendsSelection {
  const TrendsSelection({this.range = TrendRange.weeks4, this.rangesBack = 0});

  final TrendRange range;
  final int rangesBack;
}

class TrendsSelectionController extends Notifier<TrendsSelection> {
  @override
  TrendsSelection build() => const TrendsSelection();

  /// Switches range and returns to the weeks ending this week.
  void setRange(TrendRange range) {
    if (range != state.range) state = TrendsSelection(range: range);
  }

  void earlier() => state = TrendsSelection(
    range: state.range,
    rangesBack: state.rangesBack + 1,
  );

  /// Towards this week; never into the future.
  void later() {
    if (state.rangesBack == 0) return;
    state = TrendsSelection(
      range: state.range,
      rangesBack: state.rangesBack - 1,
    );
  }
}

final trendsSelectionProvider =
    NotifierProvider<TrendsSelectionController, TrendsSelection>(
      TrendsSelectionController.new,
      dependencies: [appDatabaseProvider],
    );

/// Everything the Trends screen shows. Figures are computed on the device
/// from the stored entries; nothing is modelled or forecast.
final class TrendsView {
  const TrendsView({
    required this.enoughData,
    required this.selection,
    required this.summary,
    required this.today,
    required this.canGoEarlier,
  });

  /// False until there are entries in at least two different weeks.
  final bool enoughData;
  final TrendsSelection selection;
  final WeeklySummary summary;
  final LocalDate today;
  final bool canGoEarlier;

  bool get canGoLater => selection.rangesBack > 0;

  /// True when the last week shown is the week in progress.
  bool get includesThisWeek => selection.rangesBack == 0;
}

final trendsViewProvider = Provider<AsyncValue<TrendsView>>((ref) {
  final entries = ref.watch(entriesProvider);
  final selection = ref.watch(trendsSelectionProvider);
  final today = ref.watch(clockProvider).today();
  return entries.whenData((all) {
    final weeks = selection.range.weeks;
    final summary = summariseWeeks(
      all,
      lastWeekDay: today.addDays(-7 * weeks * selection.rangesBack),
      weeks: weeks,
    );
    // Entries are newest first, so the last one is the earliest.
    final earliest = all.isEmpty ? null : all.last.localDate;
    return TrendsView(
      enoughData: hasEnoughDataForTrends(all),
      selection: selection,
      summary: summary,
      today: today,
      canGoEarlier: earliest != null && earliest.isBefore(summary.firstDay),
    );
  });
}, dependencies: [entriesProvider, trendsSelectionProvider]);
