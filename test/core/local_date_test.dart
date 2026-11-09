import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/clock.dart';
import 'package:poop_tracker/core/time/local_date.dart';

import '../support/fake_clock.dart';

void main() {
  group('LocalDate', () {
    test('rejects dates that do not exist', () {
      expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
      expect(() => LocalDate(2026, 4, 31), throwsArgumentError);
      expect(LocalDate(2028, 2, 29).day, 29);
    });

    test('equality, ordering and ISO string', () {
      expect(LocalDate(2026, 11, 6), LocalDate(2026, 11, 6));
      expect(LocalDate(2026, 11, 6).isBefore(LocalDate(2026, 11, 7)), isTrue);
      expect(LocalDate(2027, 1, 1).isAfter(LocalDate(2026, 12, 31)), isTrue);
      expect(LocalDate(2026, 3, 9).toString(), '2026-03-09');
    });

    test('adds days across month, year and UK clock changes', () {
      expect(LocalDate(2026, 10, 31).addDays(1), LocalDate(2026, 11, 1));
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2026, 3, 28).addDays(2), LocalDate(2026, 3, 30));
      expect(LocalDate(2026, 10, 24).addDays(2), LocalDate(2026, 10, 26));
      expect(LocalDate(2026, 11, 6).addDays(-25 * 7), LocalDate(2026, 5, 15));
    });

    test('daysUntil counts whole calendar days', () {
      expect(LocalDate(2026, 3, 28).daysUntil(LocalDate(2026, 3, 30)), 2);
      expect(LocalDate(2026, 11, 6).daysUntil(LocalDate(2026, 11, 4)), -2);
    });
  });

  group('Monday-to-Sunday weeks', () {
    test('every day maps to its Monday and Sunday', () {
      for (var d = 2; d <= 8; d++) {
        final day = LocalDate(2026, 11, d);
        expect(day.weekStart, LocalDate(2026, 11, 2), reason: '$day');
        expect(day.weekEnd, LocalDate(2026, 11, 8), reason: '$day');
      }
    });

    test('Sunday and the following Monday are in different weeks', () {
      expect(LocalDate(2026, 11, 8).weekStart, LocalDate(2026, 11, 2));
      expect(LocalDate(2026, 11, 9).weekStart, LocalDate(2026, 11, 9));
    });

    test('a week can span the new year', () {
      // 31 December 2026 is a Thursday.
      expect(LocalDate(2026, 12, 31).weekStart, LocalDate(2026, 12, 28));
      expect(LocalDate(2027, 1, 3).weekStart, LocalDate(2026, 12, 28));
      expect(LocalDate(2027, 1, 4).weekStart, LocalDate(2027, 1, 4));
    });
  });

  group('local date from a UTC instant and offset', () {
    test('uses the offset recorded with the entry', () {
      final utc = DateTime.utc(2026, 11, 6, 2);
      expect(LocalDate.fromUtc(utc, offsetMinutes: 0), LocalDate(2026, 11, 6));
      // The same instant recorded in New York (UTC-5) is the evening before.
      expect(
        LocalDate.fromUtc(utc, offsetMinutes: -300),
        LocalDate(2026, 11, 5),
      );
      // And in Auckland (UTC+13) it is later on the 6th.
      expect(
        LocalDate.fromUtc(utc, offsetMinutes: 780),
        LocalDate(2026, 11, 6),
      );
    });

    test('around the UK autumn change (25 October 2026)', () {
      // 23:30 UTC on the 24th is 00:30 BST on the 25th.
      expect(
        LocalDate.fromUtc(
          DateTime.utc(2026, 10, 24, 23, 30),
          offsetMinutes: 60,
        ),
        LocalDate(2026, 10, 25),
      );
      // 23:30 UTC on the 25th is 23:30 GMT on the 25th.
      expect(
        LocalDate.fromUtc(DateTime.utc(2026, 10, 25, 23, 30), offsetMinutes: 0),
        LocalDate(2026, 10, 25),
      );
    });

    test('around the UK spring change (29 March 2026)', () {
      expect(
        LocalDate.fromUtc(DateTime.utc(2026, 3, 28, 23, 30), offsetMinutes: 0),
        LocalDate(2026, 3, 28),
      );
      // 23:30 UTC on the 29th is 00:30 BST on the 30th.
      expect(
        LocalDate.fromUtc(DateTime.utc(2026, 3, 29, 23, 30), offsetMinutes: 60),
        LocalDate(2026, 3, 30),
      );
    });

    test('wallClock keeps local fields', () {
      final w = wallClock(DateTime.utc(2026, 7, 1, 12, 5), offsetMinutes: 60);
      expect((w.hour, w.minute), (13, 5));
    });
  });

  group('Clock', () {
    test('today uses the device offset now', () {
      final clock = FixedClock(DateTime.utc(2026, 11, 6, 23, 30));
      expect(clock.today(), LocalDate(2026, 11, 6));
      clock.offsetMinutes = 60;
      expect(clock.today(), LocalDate(2026, 11, 7));
    });

    test('system clock reports a UTC instant', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });
  });
}
