/// A calendar date with no time and no time zone, for example 6 November
/// 2026.
///
/// Date grouping rule: an entry's local date is its UTC instant plus the UTC
/// offset that was in force when it was recorded. It never moves when the
/// device changes time zone later. Arithmetic uses UTC internally, so it is
/// not affected by daylight saving changes.
final class LocalDate implements Comparable<LocalDate> {
  /// Throws [ArgumentError] for a date that does not exist (for example
  /// 31 April).
  factory LocalDate(int year, int month, int day) {
    final d = DateTime.utc(year, month, day);
    if (d.year != year || d.month != month || d.day != day) {
      throw ArgumentError('Not a real date: $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  /// The local date of [utc] at a UTC offset of [offsetMinutes].
  factory LocalDate.fromUtc(DateTime utc, {required int offsetMinutes}) {
    final wall = wallClock(utc, offsetMinutes: offsetMinutes);
    return LocalDate._(wall.year, wall.month, wall.day);
  }

  factory LocalDate._fromUtcMidnight(DateTime d) =>
      LocalDate._(d.year, d.month, d.day);

  final int year;
  final int month;
  final int day;

  DateTime get _utcMidnight => DateTime.utc(year, month, day);

  /// ISO weekday: 1 is Monday, 7 is Sunday.
  int get weekday => _utcMidnight.weekday;

  LocalDate addDays(int days) =>
      LocalDate._fromUtcMidnight(_utcMidnight.add(Duration(days: days)));

  /// The Monday that starts this date's week. Weeks run Monday to Sunday
  /// everywhere in the app, whatever the device locale.
  LocalDate get weekStart => addDays(1 - weekday);

  /// The Sunday that ends this date's week.
  LocalDate get weekEnd => addDays(7 - weekday);

  /// Whole days from this date to [other] (negative if [other] is earlier).
  int daysUntil(LocalDate other) =>
      other._utcMidnight.difference(_utcMidnight).inDays;

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// The local wall-clock time of [utc] at [offsetMinutes], as a [DateTime]
/// whose fields read as local time. It is flagged UTC only so that Dart does
/// not apply the device's own zone; never treat it as a real UTC instant.
DateTime wallClock(DateTime utc, {required int offsetMinutes}) {
  assert(utc.isUtc, 'wallClock expects a UTC instant');
  return utc.add(Duration(minutes: offsetMinutes));
}
