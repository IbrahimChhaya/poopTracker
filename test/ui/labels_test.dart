import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/ui/format/labels.dart';

void main() {
  final today = LocalDate(2026, 11, 6); // Friday, as in the Figma designs

  test('full date', () {
    expect(formatFullDate(today), 'Friday, 6 November 2026');
  });

  test('times use a 12-hour clock with am/pm', () {
    DateTime t(int h, int m) => DateTime.utc(2026, 11, 6, h, m);
    expect(formatTime(t(13, 35)), '1:35 pm');
    expect(formatTime(t(8, 10)), '8:10 am');
    expect(formatTime(t(0, 5)), '12:05 am');
    expect(formatTime(t(12, 0)), '12:00 pm');
    expect(formatTime(t(23, 59)), '11:59 pm');
  });

  group('relative days', () {
    test('match the journal designs', () {
      expect(relativeDay(today, today: today), 'Today');
      expect(relativeDay(LocalDate(2026, 11, 5), today: today), 'Yesterday');
      expect(relativeDay(LocalDate(2026, 11, 4), today: today), 'Wednesday');
      expect(relativeDay(LocalDate(2026, 10, 31), today: today), 'Saturday');
    });

    test('a week or more ago shows the date', () {
      expect(relativeDay(LocalDate(2026, 10, 30), today: today), '30 Oct');
      expect(relativeDay(LocalDate(2025, 12, 1), today: today), '1 Dec 2025');
    });

    test('future dates show the date, never "Today"', () {
      expect(relativeDay(LocalDate(2026, 11, 7), today: today), '7 Nov');
    });
  });

  test('History day headings match the designs', () {
    expect(formatDayHeading(today, today: today), 'Today · 6 Nov');
    expect(
      formatDayHeading(LocalDate(2026, 11, 5), today: today),
      'Yesterday · 5 Nov',
    );
    expect(
      formatDayHeading(LocalDate(2026, 11, 4), today: today),
      'Wednesday · 4 Nov',
    );
    expect(formatDayHeading(LocalDate(2026, 10, 26), today: today), '26 Oct');
    expect(
      formatDayHeading(LocalDate(2025, 10, 26), today: today),
      '26 Oct 2025',
    );
  });

  test('journal entry titles match the designs', () {
    expect(
      formatEntryTitle(
        LocalDate(2026, 11, 4),
        DateTime.utc(2026, 11, 4, 18, 20),
        today: today,
      ),
      'Wednesday · 6:20 pm',
    );
    expect(
      formatEntryTitle(today, DateTime.utc(2026, 11, 6, 13, 35), today: today),
      'Today · 1:35 pm',
    );
  });

  test('date ranges', () {
    expect(
      formatDateRange(LocalDate(2026, 10, 24), LocalDate(2026, 11, 6)),
      '24 Oct – 6 Nov',
    );
    expect(
      formatDateRange(
        LocalDate(2026, 10, 12),
        LocalDate(2026, 11, 8),
        withYear: true,
      ),
      '12 Oct – 8 Nov 2026',
    );
    expect(
      formatDateRange(LocalDate(2026, 12, 28), LocalDate(2027, 1, 3)),
      '28 Dec 2026 – 3 Jan 2027',
    );
  });

  test('entry counts', () {
    expect(formatEntryCount(0), '0 entries');
    expect(formatEntryCount(1), '1 entry');
    expect(formatEntryCount(18), '18 entries');
  });

  group('one-decimal ratios', () {
    test('match the Trends designs', () {
      expect(formatRatioOneDecimal(18, 4), '4.5');
      expect(formatRatioOneDecimal(56, 12), '4.7');
      expect(formatRatioOneDecimal(120, 26), '4.6');
    });

    test('round half up exactly', () {
      expect(formatRatioOneDecimal(89, 20), '4.5'); // 4.45
      expect(formatRatioOneDecimal(81, 20), '4.1'); // 4.05
      expect(formatRatioOneDecimal(8, 2), '4.0');
      expect(formatRatioOneDecimal(0, 4), '0.0');
      expect(formatRatioOneDecimal(1, 3), '0.3');
      expect(formatRatioOneDecimal(2, 3), '0.7');
    });

    test('reject impossible input', () {
      expect(() => formatRatioOneDecimal(1, 0), throwsArgumentError);
      expect(() => formatRatioOneDecimal(-1, 2), throwsArgumentError);
    });
  });
}
