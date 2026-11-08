import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/clock.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/features/journal/domain/grouping.dart';
import 'package:poop_tracker/features/trends/domain/weekly_summary.dart';
import 'package:poop_tracker/ui/format/labels.dart';

import '../../fixtures/figma_trends_fixture.dart';
import '../../support/entries.dart';
import '../../support/fake_clock.dart';

/// Expected figures, read from the Figma Trends screens (5.1 to 5.6).
typedef _Expected = ({
  TrendRange range,
  String rangeLabel,
  int total,
  String average,
  int weeksLogged,
  List<int> stool,
});

const List<_Expected> _figma = [
  (
    range: TrendRange.weeks4,
    rangeLabel: '12 Oct – 8 Nov 2026',
    total: 18,
    average: '4.5',
    weeksLogged: 4,
    stool: [0, 0, 3, 10, 3, 2, 0],
  ),
  (
    range: TrendRange.weeks12,
    rangeLabel: '17 Aug – 8 Nov 2026',
    total: 56,
    average: '4.7',
    weeksLogged: 12,
    stool: [1, 2, 9, 28, 9, 6, 1],
  ),
  (
    range: TrendRange.weeks26,
    rangeLabel: '11 May – 8 Nov 2026',
    total: 120,
    average: '4.6',
    weeksLogged: 26,
    stool: [2, 4, 19, 59, 19, 14, 3],
  ),
];

void main() {
  final fixture = figmaTrendsFixture();
  final today = figmaNow.today();

  test('fixture "today" is Friday 6 November 2026', () {
    expect(today, LocalDate(2026, 11, 6));
  });

  group('reproduces the Figma Trends screens', () {
    for (final x in _figma) {
      group('${x.range.weeks} weeks', () {
        final s = summariseWeeks(
          fixture,
          lastWeekDay: today,
          weeks: x.range.weeks,
        );

        test('range label', () {
          expect(
            formatDateRange(s.firstDay, s.lastDay, withYear: true),
            x.rangeLabel,
          );
        });

        test('total, average and weeks logged', () {
          expect(s.totalEntries, x.total);
          expect(formatRatioOneDecimal(s.totalEntries, s.weekCount), x.average);
          expect(
            '${s.weeksLogged} / ${s.weekCount}',
            '${x.weeksLogged} / '
                '${x.range.weeks}',
          );
        });

        test('stool form counts', () {
          expect([
            for (var t = 1; t <= 7; t++) s.stoolForm.countsByType[t],
          ], x.stool);
          expect(s.stoolForm.entriesWithType, x.total);
        });
      });
    }

    test('4-week bars are 4, 4, 5, 5 with the latest week in progress', () {
      final s = summariseWeeks(fixture, lastWeekDay: today, weeks: 4);
      expect(s.weeks.map((w) => w.entries), [4, 4, 5, 5]);
      expect(s.weeks.map((w) => formatDayMonth(w.weekStart)), [
        '12 Oct',
        '19 Oct',
        '26 Oct',
        '2 Nov',
      ]);
    });

    test('journal: this week has 5 entries, most recent at 1:35 pm', () {
      final week = entriesInWeek(fixture, today);
      expect(formatEntryCount(week.length), '5 entries');
      expect(formatTime(week.first.localWallClock), '1:35 pm');
      expect(
        week.map(
          (e) => formatEntryTitle(e.localDate, e.localWallClock, today: today),
        ),
        [
          'Today · 1:35 pm',
          'Today · 8:10 am',
          'Yesterday · 8:25 am',
          'Wednesday · 6:20 pm',
          'Wednesday · 8:35 am',
        ],
      );
    });

    test('journal footer: 18 entries over the last 4 weeks', () {
      final s = summariseWeeks(fixture, lastWeekDay: today, weeks: 4);
      expect(
        '${s.totalEntries} entries over the last 4 weeks',
        '18 entries over the last 4 weeks',
      );
    });
  });

  group('summariseWeeks rules', () {
    test('empty weeks count towards the average but not weeks logged', () {
      final entries = [
        entryAt(2026, 10, 12, 9, 0),
        entryAt(2026, 10, 13, 9, 0),
        entryAt(2026, 11, 6, 9, 0),
      ];
      final s = summariseWeeks(entries, lastWeekDay: today, weeks: 4);
      expect(s.weeks.map((w) => w.entries), [2, 0, 0, 1]);
      expect(s.weeksLogged, 2);
      expect(s.averagePerWeek, closeTo(0.75, 1e-9));
      expect(formatRatioOneDecimal(s.totalEntries, s.weekCount), '0.8');
    });

    test('entries outside the range are ignored', () {
      final entries = [
        entryAt(2026, 10, 11, 23, 59), // Sunday before the range
        entryAt(2026, 10, 12, 0, 0), // first minute of the range
        entryAt(2026, 11, 8, 23, 59), // last minute of the range
        entryAt(2026, 11, 9, 0, 0), // Monday after
      ];
      final s = summariseWeeks(entries, lastWeekDay: today, weeks: 4);
      expect(s.totalEntries, 2);
      expect(s.weeks.first.entries, 1);
      expect(s.weeks.last.entries, 1);
    });

    test('an earlier range can be viewed', () {
      final s = summariseWeeks(
        figmaTrendsFixture(),
        lastWeekDay: LocalDate(2026, 10, 11),
        weeks: 4,
      );
      expect(
        formatDateRange(s.firstDay, s.lastDay, withYear: true),
        '14 Sep – 11 Oct 2026',
      );
      expect(s.weeks.map((w) => w.entries), [5, 5, 4, 4]);
    });

    test('entries without a stool type are left out of the stool counts', () {
      final entries = [
        entryAt(2026, 11, 2, 9, 0, stoolType: 4),
        entryAt(2026, 11, 3, 9, 0),
      ];
      final s = summariseWeeks(entries, lastWeekDay: today, weeks: 4);
      expect(s.stoolForm.entriesWithType, 1);
      expect(s.stoolForm.countsByType.keys, [1, 2, 3, 4, 5, 6, 7]);
    });

    test('entries are placed by their own local day, not the phone zone', () {
      // 23:30 on Sunday 8 November in New York is Monday 04:30 UTC.
      final e = entryAt(2026, 11, 8, 23, 30, offsetMinutes: -300);
      final s = summariseWeeks([e], lastWeekDay: today, weeks: 1);
      expect(s.totalEntries, 1);
    });

    test('rejects a range of zero weeks', () {
      expect(
        () => summariseWeeks(const [], lastWeekDay: today, weeks: 0),
        throwsArgumentError,
      );
    });
  });

  group('not enough data', () {
    test('no entries is not enough', () {
      expect(hasEnoughDataForTrends(const []), isFalse);
    });

    test('many entries in one week is not enough', () {
      expect(
        hasEnoughDataForTrends([
          entryAt(2026, 11, 2, 0, 0),
          entryAt(2026, 11, 5, 9, 0),
          entryAt(2026, 11, 8, 23, 59),
        ]),
        isFalse,
      );
    });

    test('Sunday and the next Monday are two weeks, which is enough', () {
      expect(
        hasEnoughDataForTrends([
          entryAt(2026, 11, 8, 23, 59),
          entryAt(2026, 11, 9, 0, 0),
        ]),
        isTrue,
      );
    });

    test('the Figma fixture has enough', () {
      expect(hasEnoughDataForTrends(fixture), isTrue);
    });
  });
}
