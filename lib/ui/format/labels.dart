import '../../core/time/local_date.dart';

/// British English labels used across the journal, History and Trends.
/// English only for v1, so no localisation package is needed.

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String weekdayName(LocalDate d) => _weekdays[d.weekday - 1];
String monthName(int month) => _months[month - 1];
String shortMonthName(int month) => _months[month - 1].substring(0, 3);

/// "6 Nov", or "6 Nov 2025" when [withYear].
String formatDayMonth(LocalDate d, {bool withYear = false}) {
  final base = '${d.day} ${shortMonthName(d.month)}';
  return withYear ? '$base ${d.year}' : base;
}

/// "Friday, 6 November 2026".
String formatFullDate(LocalDate d) =>
    '${weekdayName(d)}, ${d.day} ${monthName(d.month)} ${d.year}';

/// "1:35 pm", "12:05 am", "12:00 pm". [wall] holds local wall-clock fields.
String formatTime(DateTime wall) {
  final hour12 = wall.hour % 12 == 0 ? 12 : wall.hour % 12;
  final minute = wall.minute.toString().padLeft(2, '0');
  final suffix = wall.hour < 12 ? 'am' : 'pm';
  return '$hour12:$minute $suffix';
}

/// "Today", "Yesterday", the weekday name for the rest of the past week, or
/// "4 Nov" (with the year if it is not this year) for anything older or in
/// the future.
String relativeDay(LocalDate day, {required LocalDate today}) {
  final ago = day.daysUntil(today);
  if (ago == 0) return 'Today';
  if (ago == 1) return 'Yesterday';
  if (ago > 1 && ago < 7) return weekdayName(day);
  return formatDayMonth(day, withYear: day.year != today.year);
}

/// History day heading: "Today · 6 Nov", "Wednesday · 4 Nov". Older days
/// show only the date, for example "26 Oct" or "26 Oct 2025".
String formatDayHeading(LocalDate day, {required LocalDate today}) {
  final relative = relativeDay(day, today: today);
  final date = formatDayMonth(day, withYear: day.year != today.year);
  return relative == date ? date : '$relative · $date';
}

/// Journal entry title: "Today · 1:35 pm", "Wednesday · 6:20 pm".
String formatEntryTitle(
  LocalDate day,
  DateTime wall, {
  required LocalDate today,
}) => '${relativeDay(day, today: today)} · ${formatTime(wall)}';

/// "24 Oct – 6 Nov", "12 Oct – 8 Nov 2026" when [withYear], and
/// "28 Dec 2026 – 3 Jan 2027" whenever the range spans two years.
String formatDateRange(LocalDate from, LocalDate to, {bool withYear = false}) {
  if (from.year != to.year) {
    return '${formatDayMonth(from, withYear: true)} – '
        '${formatDayMonth(to, withYear: true)}';
  }
  return '${formatDayMonth(from)} – ${formatDayMonth(to, withYear: withYear)}';
}

/// "1 entry", "2 entries", "0 entries".
String formatEntryCount(int n) => n == 1 ? '1 entry' : '$n entries';

/// [numerator] / [denominator] to one decimal place, rounded half up, using
/// whole-number maths so 89 / 20 gives "4.5" (floating point would give
/// 4.4499…). Both must be non-negative and [denominator] positive.
String formatRatioOneDecimal(int numerator, int denominator) {
  if (numerator < 0 || denominator <= 0) {
    throw ArgumentError('Expected numerator >= 0 and denominator > 0');
  }
  final tenths = (numerator * 20 + denominator) ~/ (denominator * 2);
  return '${tenths ~/ 10}.${tenths % 10}';
}
