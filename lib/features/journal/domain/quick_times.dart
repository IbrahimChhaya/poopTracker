import '../../../core/time/local_date.dart';

/// A one-tap time on the "When did this happen?" sheet (Figma 2.3–2.3c).
typedef QuickTime = ({String label, LocalDate date, int hour, int minute});

/// The moments that follow the time of day, in time order. "Last night" is
/// yesterday; the rest are today.
const _moments = <({String label, int dayOffset, int hour})>[
  (label: 'Last night', dayOffset: -1, hour: 21),
  (label: 'This morning', dayOffset: 0, hour: 8),
  (label: 'This afternoon', dayOffset: 0, hour: 14),
  (label: 'This evening', dayOffset: 0, hour: 19),
];

/// The quick times for a sheet opened at [hour]:[minute] on [today] (local
/// wall-clock time):
///
/// - "1 hour ago" and "2 hours ago", always: the wall-clock time minus one
///   or two hours, falling on yesterday shortly after midnight.
/// - Then the two most recent moments that have already happened (a moment
///   counts from its exact time), earlier first. Before 8:00 am only
///   "Last night" has happened, so there are three chips.
///
/// Never more than four, and never a time that hasn't happened yet.
List<QuickTime> quickTimes({
  required LocalDate today,
  required int hour,
  required int minute,
}) {
  final now = DateTime.utc(today.year, today.month, today.day, hour, minute);
  QuickTime ago(int hours, String label) {
    final t = now.subtract(Duration(hours: hours));
    return (
      label: label,
      date: LocalDate(t.year, t.month, t.day),
      hour: t.hour,
      minute: t.minute,
    );
  }

  final passed = [
    for (final m in _moments)
      if (m.dayOffset < 0 || hour >= m.hour)
        (
          label: m.label,
          date: today.addDays(m.dayOffset),
          hour: m.hour,
          minute: 0,
        ),
  ];
  return [
    ago(1, '1 hour ago'),
    ago(2, '2 hours ago'),
    ...passed.skip(passed.length > 2 ? passed.length - 2 : 0),
  ];
}
