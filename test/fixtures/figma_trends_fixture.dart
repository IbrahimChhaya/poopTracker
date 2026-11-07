import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';

import '../support/entries.dart';

/// Synthetic journal that reproduces every figure on the Figma Trends screens
/// (5.1 to 5.6) and the current week on the journal (2.1 and 3.4), with
/// "today" as Friday 6 November 2026.
///
/// The 26 weeks run from Monday 11 May to Sunday 8 November 2026 and are
/// built in three segments so each range's totals add up:
/// - weeks 1 to 14: 64 entries (only in the 26-week range)
/// - weeks 15 to 22: 38 entries (12- and 26-week ranges)
/// - weeks 23 to 26: 18 entries (all ranges)
List<Entry> figmaTrendsFixture() {
  final entries = <Entry>[];
  var id = 1;

  void addSegment({
    required LocalDate firstMonday,
    required List<int> perWeek,
    required List<int> stoolCounts,
    required int bloating,
    required int cramping,
    List<Entry> extra = const [],
  }) {
    final types = [
      for (var t = 0; t < 7; t++)
        for (var n = 0; n < stoolCounts[t]; n++) t + 1,
    ];
    var i = 0;
    for (var w = 0; w < perWeek.length; w++) {
      final monday = firstMonday.addDays(7 * w);
      for (var n = 0; n < perWeek[w]; n++) {
        // Spread across the week, including the Sunday, at varied times.
        final day = monday.addDays(const [0, 2, 4, 5, 6][n]);
        final symptoms = i < bloating
            ? {Symptom.bloating}
            : i < bloating + cramping
            ? {Symptom.cramping}
            // "None" and no answer must count the same.
            : (i.isEven ? {Symptom.none} : <Symptom>{});
        entries.add(
          entryAt(
            day.year,
            day.month,
            day.day,
            const [8, 13, 19][n % 3],
            (n * 17) % 60,
            id: id++,
            stoolType: types[i],
            symptoms: symptoms,
          ),
        );
        i++;
      }
    }
    if (i != types.length) {
      throw StateError('Segment counts do not match: $i vs ${types.length}');
    }
    entries.addAll(extra);
  }

  // Weeks 1-14 (11 May to 9 August): 64 entries.
  addSegment(
    firstMonday: LocalDate(2026, 5, 11),
    perWeek: const [5, 5, 5, 4, 5, 4, 5, 4, 5, 4, 5, 4, 5, 4],
    stoolCounts: const [1, 2, 10, 31, 10, 8, 2],
    bloating: 10,
    cramping: 5,
  );

  // Weeks 15-22 (17 August to 11 October): 38 entries.
  addSegment(
    firstMonday: LocalDate(2026, 8, 17),
    perWeek: const [5, 5, 5, 5, 5, 5, 4, 4],
    stoolCounts: const [1, 2, 6, 18, 6, 4, 1],
    bloating: 6,
    cramping: 3,
  );

  // Weeks 23-25 (12 October to 1 November): 13 entries. The week of
  // 19 October includes the UK clock change on Sunday 25 October.
  addSegment(
    firstMonday: LocalDate(2026, 10, 12),
    perWeek: const [4, 4, 5],
    stoolCounts: const [0, 0, 2, 7, 2, 2, 0],
    bloating: 2,
    cramping: 1,
  );

  // Week 26 (2 to 8 November, in progress): the five entries on the
  // journal design.
  entries.addAll([
    entryAt(
      2026,
      11,
      4,
      8,
      35,
      id: id++,
      stoolType: 3,
      ease: Ease.someStraining,
      symptoms: {Symptom.none},
    ),
    entryAt(
      2026,
      11,
      4,
      18,
      20,
      id: id++,
      stoolType: 4,
      ease: Ease.easy,
      comment: 'Quiet evening',
      symptoms: {Symptom.none},
    ),
    entryAt(
      2026,
      11,
      5,
      8,
      25,
      id: id++,
      stoolType: 4,
      ease: Ease.easy,
      symptoms: {Symptom.none},
    ),
    entryAt(
      2026,
      11,
      6,
      8,
      10,
      id: id++,
      stoolType: 4,
      ease: Ease.easy,
      symptoms: {Symptom.none},
    ),
    entryAt(
      2026,
      11,
      6,
      13,
      35,
      id: id++,
      stoolType: 5,
      ease: Ease.easy,
      comment: 'Felt fine after lunch',
      symptoms: {Symptom.bloating},
    ),
  ]);

  return entries;
}
