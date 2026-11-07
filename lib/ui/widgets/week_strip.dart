import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';
import '../theme/morrow_typography.dart';

/// One day in the [WeekStrip]. [date] is a local calendar date; only its
/// year, month and day are used.
@immutable
class WeekStripDay {
  const WeekStripDay({
    required this.date,
    required this.hasEntries,
    this.isToday = false,
  });

  final DateTime date;
  final bool hasEntries;
  final bool isToday;
}

/// Monday-to-Sunday row of days, as on the journal home screen.
///
/// Today is outlined, the selected day is filled, and a dot marks days with
/// entries. Each of these is also included in the day's screen reader label.
/// The strip only reports taps; the caller decides what selection means.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.days,
    required this.onSelected,
    this.selected,
    super.key,
  }) : assert(days.length == 7, 'A week strip shows exactly seven days');

  final List<WeekStripDay> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          Expanded(
            child: _DayCell(
              day: day,
              selected: sel != null && _sameDate(sel, day.date),
              onTap: () => onSelected(day.date),
            ),
          ),
      ],
    );
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final WeekStripDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final styles = MorrowTextStyles.of(context);
    final radius = BorderRadius.circular(MorrowRadii.md);

    final weekdayColour = selected ? colors.onPrimaryMuted : colors.mutedText;
    final numberColour = selected ? colors.onPrimary : colors.ink;
    final dotColour = selected ? colors.onPrimary : colors.primary;

    final cell = Material(
      color: selected ? colors.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: day.isToday && !selected
            ? BorderSide(color: colors.primary)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MorrowSizes.dayCellMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Fit(
                  child: Text(
                    _weekdayInitials[day.date.weekday - 1],
                    style: text.labelSmall!.copyWith(color: weekdayColour),
                  ),
                ),
                const SizedBox(height: 6),
                _Fit(
                  child: Text(
                    '${day.date.day}',
                    style: styles.dayNumber.copyWith(color: numberColour),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox.square(
                  dimension: 4,
                  child: day.hasEntries
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: dotColour,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: weekStripDayLabel(day),
      // The whole seventh of the row is tappable (at least 48 px wide on a
      // typical phone), while the visible cell keeps the Figma gap.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _halfGap),
          child: ExcludeSemantics(child: cell),
        ),
      ),
    );
  }
}

/// Shrinks a single line only when the cell is too narrow, for example on a
/// small phone at a very large text size. The full text stays in semantics.
class _Fit extends StatelessWidget {
  const _Fit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: child);
}

/// Half of the 5 px gap between cells in the Figma week strip.
const double _halfGap = 2.5;

const List<String> _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> _monthNames = [
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

/// Screen reader label for a day, for example
/// "Friday 6 November, today, has entries".
String weekStripDayLabel(WeekStripDay day) {
  final d = day.date;
  final parts = <String>[
    '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]}',
    if (day.isToday) 'today',
    day.hasEntries ? 'has entries' : 'no entries',
  ];
  return parts.join(', ');
}
