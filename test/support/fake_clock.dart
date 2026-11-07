import 'package:poop_tracker/core/clock.dart';

/// A clock frozen at [utc], in a zone with offset [offsetMinutes].
class FixedClock implements Clock {
  FixedClock(this.utc, {this.offsetMinutes = 0})
    : assert(utc.isUtc, 'FixedClock needs a UTC instant');

  DateTime utc;
  int offsetMinutes;

  @override
  DateTime nowUtc() => utc;

  @override
  int currentUtcOffsetMinutes() => offsetMinutes;
}

/// UK offsets for 2026: BST (+60) from 29 March 01:00 UTC to 25 October
/// 01:00 UTC, GMT (0) otherwise.
int ukOffsetMinutes2026(DateTime utc) {
  final bstStart = DateTime.utc(2026, 3, 29, 1);
  final bstEnd = DateTime.utc(2026, 10, 25, 1);
  return !utc.isBefore(bstStart) && utc.isBefore(bstEnd) ? 60 : 0;
}

/// "Now" in the Figma designs: Friday 6 November 2026, 1:41 pm in London.
final FixedClock figmaNow = FixedClock(DateTime.utc(2026, 11, 6, 13, 41));
