import '../../../core/time/local_date.dart';
import '../../journal/domain/entry.dart';

/// The ranges offered on Trends.
enum TrendRange {
  weeks4(4),
  weeks12(12),
  weeks26(26);

  const TrendRange(this.weeks);

  final int weeks;
}

/// Entries in one Monday-to-Sunday week.
final class WeekCount {
  const WeekCount(this.weekStart, this.entries);

  final LocalDate weekStart;
  final int entries;
}

/// How many entries recorded each stool form type. Counts only: no type is
/// treated as better or worse than another.
final class StoolFormSummary {
  StoolFormSummary(Map<int, int> countsByType)
    : countsByType = Map.unmodifiable(countsByType);

  /// Every type from 1 to 7, including those with no entries.
  final Map<int, int> countsByType;

  int get entriesWithType => countsByType.values.fold(0, (a, b) => a + b);
}

/// Symptom counts. "None" and "not answered" both count as no symptoms.
final class SymptomSummary {
  SymptomSummary({
    required List<MapEntry<Symptom, int>> counts,
    required this.entriesWithSymptoms,
    required this.entriesWithoutSymptoms,
  }) : counts = List.unmodifiable(counts);

  /// Symptoms recorded at least once, most frequent first. An entry with two
  /// symptoms counts once for each.
  final List<MapEntry<Symptom, int>> counts;

  /// Entries with at least one real symptom.
  final int entriesWithSymptoms;

  /// Entries with "None" or no symptom answer.
  final int entriesWithoutSymptoms;
}

/// Simple, descriptive figures for a run of whole weeks.
final class WeeklySummary {
  WeeklySummary({
    required List<WeekCount> weeks,
    required this.stoolForm,
    required this.symptoms,
  }) : weeks = List.unmodifiable(weeks);

  /// Oldest week first.
  final List<WeekCount> weeks;
  final StoolFormSummary stoolForm;
  final SymptomSummary symptoms;

  LocalDate get firstDay => weeks.first.weekStart;
  LocalDate get lastDay => weeks.last.weekStart.weekEnd;
  int get weekCount => weeks.length;
  int get totalEntries => weeks.fold(0, (sum, w) => sum + w.entries);

  /// Weeks with at least one entry.
  int get weeksLogged => weeks.where((w) => w.entries > 0).length;

  /// Total entries divided by every week in the range, including empty weeks
  /// and the week in progress.
  double get averagePerWeek => totalEntries / weekCount;
}

/// Summarises the [weeks] weeks that end with the week containing
/// [lastWeekDay]. Entries are placed by their own local day.
WeeklySummary summariseWeeks(
  Iterable<Entry> entries, {
  required LocalDate lastWeekDay,
  required int weeks,
}) {
  if (weeks < 1) throw ArgumentError.value(weeks, 'weeks', 'must be >= 1');
  final lastStart = lastWeekDay.weekStart;
  final firstStart = lastStart.addDays(-7 * (weeks - 1));
  final lastEnd = lastStart.weekEnd;

  final perWeek = List<int>.filled(weeks, 0);
  final stool = {for (var t = minStoolType; t <= maxStoolType; t++) t: 0};
  final symptomCounts = <Symptom, int>{};
  var withSymptoms = 0;
  var total = 0;

  for (final e in entries) {
    final day = e.localDate;
    if (day.isBefore(firstStart) || day.isAfter(lastEnd)) continue;
    total++;
    perWeek[firstStart.daysUntil(day.weekStart) ~/ 7]++;
    final type = e.stoolType;
    if (type != null && stool.containsKey(type)) {
      stool[type] = stool[type]! + 1;
    }
    if (e.hasSymptoms) {
      withSymptoms++;
      for (final s in e.symptoms) {
        if (s == Symptom.none) continue;
        symptomCounts[s] = (symptomCounts[s] ?? 0) + 1;
      }
    }
  }

  final sortedSymptoms = symptomCounts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.index.compareTo(b.key.index);
    });

  return WeeklySummary(
    weeks: [
      for (var i = 0; i < weeks; i++)
        WeekCount(firstStart.addDays(7 * i), perWeek[i]),
    ],
    stoolForm: StoolFormSummary(stool),
    symptoms: SymptomSummary(
      counts: sortedSymptoms,
      entriesWithSymptoms: withSymptoms,
      entriesWithoutSymptoms: total - withSymptoms,
    ),
  );
}

/// Trends need entries from at least two different weeks; otherwise the
/// screen shows "Not enough entries yet".
bool hasEnoughDataForTrends(Iterable<Entry> entries) {
  LocalDate? firstWeek;
  for (final e in entries) {
    final w = e.localDate.weekStart;
    if (firstWeek == null) {
      firstWeek = w;
    } else if (w != firstWeek) {
      return true;
    }
  }
  return false;
}
