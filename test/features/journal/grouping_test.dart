import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/features/journal/domain/grouping.dart';

import '../../support/entries.dart';

void main() {
  group('groupByLocalDay', () {
    test('groups by local day, newest day and entry first', () {
      final a = entryAt(2026, 11, 4, 8, 35);
      final b = entryAt(2026, 11, 6, 8, 10);
      final c = entryAt(2026, 11, 4, 18, 20);
      final d = entryAt(2026, 11, 6, 13, 35);
      final e = entryAt(2026, 11, 5, 8, 25);

      final groups = groupByLocalDay([a, b, c, d, e]);

      expect(groups.map((g) => g.date), [
        LocalDate(2026, 11, 6),
        LocalDate(2026, 11, 5),
        LocalDate(2026, 11, 4),
      ]);
      expect(groups[0].entries, [d, b]);
      expect(groups[1].entries, [e]);
      expect(groups[2].entries, [c, a]);
    });

    test('empty input gives no groups', () {
      expect(groupByLocalDay(const []), isEmpty);
    });

    test('entries at the same instant are ordered by id', () {
      final x = entryAt(2026, 11, 6, 8, 0, id: 10);
      final y = entryAt(2026, 11, 6, 8, 0, id: 11);
      expect(groupByLocalDay([x, y]).single.entries, [y, x]);
    });

    test('an entry keeps its original day after a time zone change', () {
      // Recorded at 21:00 in New York; the phone is back in London now.
      final newYork = entryAt(2026, 11, 5, 21, 0, offsetMinutes: -300);
      final london = entryAt(2026, 11, 6, 8, 0, offsetMinutes: 0);
      final groups = groupByLocalDay([newYork, london]);
      expect(groups.map((g) => g.date), [
        LocalDate(2026, 11, 6),
        LocalDate(2026, 11, 5),
      ]);
      expect(groups[1].entries.single, newYork);
    });

    test('UK autumn change: both 1 am hours stay on 25 October', () {
      // Clocks go back at 2 am BST, so 1:30 am happens twice.
      final bst = entryAt(2026, 10, 25, 1, 30, offsetMinutes: 60);
      final gmt = entryAt(2026, 10, 25, 1, 30, offsetMinutes: 0);
      final lateEvening = entryAt(2026, 10, 25, 23, 30, offsetMinutes: 0);
      final groups = groupByLocalDay([bst, gmt, lateEvening]);
      expect(groups.single.date, LocalDate(2026, 10, 25));
      // Ordered by when they really happened.
      expect(groups.single.entries, [lateEvening, gmt, bst]);
    });

    test('UK spring change: just after midnight BST is the next day', () {
      final before = entryAt(2026, 3, 28, 23, 30, offsetMinutes: 0);
      final after = entryAt(2026, 3, 30, 0, 30, offsetMinutes: 60);
      expect(groupByLocalDay([before, after]).map((g) => g.date), [
        LocalDate(2026, 3, 30),
        LocalDate(2026, 3, 28),
      ]);
    });
  });

  group('home journal scope', () {
    final entries = [
      entryAt(2026, 11, 1, 22, 0), // Sunday of the previous week
      entryAt(2026, 11, 2, 0, 0), // Monday 00:00, first moment of the week
      entryAt(2026, 11, 4, 8, 35),
      entryAt(2026, 11, 6, 13, 35),
      entryAt(2026, 11, 8, 23, 59), // Sunday 23:59, last minute of the week
      entryAt(2026, 11, 9, 0, 0), // next Monday
    ];

    test('"This week" is Monday to Sunday inclusive', () {
      final week = entriesInWeek(entries, LocalDate(2026, 11, 6));
      expect(week.map((e) => e.localDate), [
        LocalDate(2026, 11, 8),
        LocalDate(2026, 11, 6),
        LocalDate(2026, 11, 4),
        LocalDate(2026, 11, 2),
      ]);
    });

    test('a selected day shows only that day', () {
      expect(
        entriesOnDay(entries, LocalDate(2026, 11, 4)).single.localDate,
        LocalDate(2026, 11, 4),
      );
      expect(entriesOnDay(entries, LocalDate(2026, 11, 3)), isEmpty);
    });

    test('History range is inclusive at both ends', () {
      final range = entriesBetween(
        entries,
        from: LocalDate(2026, 11, 1),
        to: LocalDate(2026, 11, 4),
      );
      expect(range, hasLength(3));
    });
  });
}
