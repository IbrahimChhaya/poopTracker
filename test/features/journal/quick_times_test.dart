import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/time/local_date.dart';
import 'package:poop_tracker/features/journal/domain/quick_times.dart';

void main() {
  final today = LocalDate(2026, 11, 13);
  final yesterday = LocalDate(2026, 11, 12);

  List<String> labels(int hour, [int minute = 0]) => [
    for (final q in quickTimes(today: today, hour: hour, minute: minute))
      q.label,
  ];

  group('which chips show (the Figma examples)', () {
    test('at 12 pm: the hours, then Last night and This morning', () {
      expect(labels(12), [
        '1 hour ago',
        '2 hours ago',
        'Last night',
        'This morning',
      ]);
    });

    test('at 5 pm: This morning and This afternoon', () {
      expect(labels(17), [
        '1 hour ago',
        '2 hours ago',
        'This morning',
        'This afternoon',
      ]);
    });

    test('at 8 pm: This afternoon and This evening', () {
      expect(labels(20), [
        '1 hour ago',
        '2 hours ago',
        'This afternoon',
        'This evening',
      ]);
    });

    test('before 8 am only Last night has happened', () {
      expect(labels(7, 59), ['1 hour ago', '2 hours ago', 'Last night']);
    });

    test('a moment counts from its exact time', () {
      expect(labels(8), contains('This morning'));
      expect(labels(13, 59), isNot(contains('This afternoon')));
      expect(labels(14), contains('This afternoon'));
    });
  });

  test('moments carry their day and time', () {
    final noon = quickTimes(today: today, hour: 12, minute: 0);
    final lastNight = noon.firstWhere((q) => q.label == 'Last night');
    expect(
      (lastNight.date, lastNight.hour, lastNight.minute),
      (yesterday, 21, 0),
    );
    final morning = noon.firstWhere((q) => q.label == 'This morning');
    expect((morning.date, morning.hour, morning.minute), (today, 8, 0));
  });

  test('the hours ago keep the minutes', () {
    final q = quickTimes(today: today, hour: 13, minute: 41);
    expect((q[0].date, q[0].hour, q[0].minute), (today, 12, 41));
    expect((q[1].date, q[1].hour, q[1].minute), (today, 11, 41));
  });

  test('just after midnight the hours ago fall on yesterday', () {
    final q = quickTimes(today: today, hour: 0, minute: 30);
    expect((q[0].date, q[0].hour, q[0].minute), (yesterday, 23, 30));
    expect((q[1].date, q[1].hour, q[1].minute), (yesterday, 22, 30));
    expect(q.last.label, 'Last night');
  });

  test('across a month boundary', () {
    final q = quickTimes(today: LocalDate(2026, 3, 1), hour: 1, minute: 0);
    expect(q[1].date, LocalDate(2026, 2, 28));
    expect(q[1].hour, 23);
    expect(q.last.date, LocalDate(2026, 2, 28));
  });

  test('never more than four chips, never one in the future', () {
    for (var h = 0; h < 24; h++) {
      for (final m in [0, 30, 59]) {
        final q = quickTimes(today: today, hour: h, minute: m);
        expect(q.length, inInclusiveRange(3, 4));
        final now = DateTime.utc(2026, 11, 13, h, m);
        for (final c in q) {
          final t = DateTime.utc(
            c.date.year,
            c.date.month,
            c.date.day,
            c.hour,
            c.minute,
          );
          expect(t.isAfter(now), isFalse, reason: '${c.label} at $h:$m');
        }
      }
    }
  });
}
