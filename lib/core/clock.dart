import 'time/local_date.dart';

/// Source of the current time. Inject it everywhere "now" matters so tests
/// can use a fixed clock.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime nowUtc();

  /// The device's current offset from UTC, in minutes (for example 60 during
  /// British Summer Time).
  int currentUtcOffsetMinutes();

  /// The UTC instant for a local wall-clock time chosen on the device, and
  /// the offset in force at that time (which can differ from now across a
  /// daylight saving change).
  ({DateTime utc, int offsetMinutes}) resolveLocal(
    int year,
    int month,
    int day,
    int hour,
    int minute,
  );
}

extension ClockToday on Clock {
  /// The device's current local calendar date.
  LocalDate today() =>
      LocalDate.fromUtc(nowUtc(), offsetMinutes: currentUtcOffsetMinutes());
}

/// The real device clock.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  int currentUtcOffsetMinutes() => DateTime.now().timeZoneOffset.inMinutes;

  @override
  ({DateTime utc, int offsetMinutes}) resolveLocal(
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) {
    // The OS resolves the zone, including daylight saving. A time skipped by
    // a spring change is moved forward by the OS.
    final local = DateTime(year, month, day, hour, minute);
    return (utc: local.toUtc(), offsetMinutes: local.timeZoneOffset.inMinutes);
  }
}

extension ClockNowLocal on Clock {
  /// The current local wall-clock time (see `wallClock`).
  DateTime nowLocalWall() =>
      nowUtc().add(Duration(minutes: currentUtcOffsetMinutes()));
}
