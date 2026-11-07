import 'time/local_date.dart';

/// Source of the current time. Inject it everywhere "now" matters so tests
/// can use a fixed clock.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime nowUtc();

  /// The device's current offset from UTC, in minutes (for example 60 during
  /// British Summer Time).
  int currentUtcOffsetMinutes();
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
}
