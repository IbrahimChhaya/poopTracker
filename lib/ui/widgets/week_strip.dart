import 'package:flutter/material.dart';

import '../../core/time/local_date.dart';
import '../format/labels.dart';
import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';
import '../theme/morrow_typography.dart';

/// One day in the [WeekStrip].
@immutable
class WeekStripDay {
  const WeekStripDay({
    required this.date,
    required this.hasEntries,
    this.isToday = false,
    this.isFuture = false,
  });

  final LocalDate date;
  final bool hasEntries;
  final bool isToday;

  /// Days after today cannot be opened: there is nothing to see yet.
  final bool isFuture;
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
  final LocalDate? selected;
  final ValueChanged<LocalDate> onSelected;

  /// The strip's height at [scaler], for hosts that need a fixed height (such
  /// as a swipeable page of weeks).
  static double heightFor(TextScaler scaler) {
    final content =
        20 + 6 + 8 + 4 + scaler.scale(11) * 1.2 + scaler.scale(16) * 1.2;
    return content > MorrowSizes.dayCellMinHeight
        ? content + 1
        : MorrowSizes.dayCellMinHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          Expanded(
            child: _DayCell(
              day: day,
              selected: selected == day.date,
              onTap: day.isFuture ? null : () => onSelected(day.date),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final WeekStripDay day;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final styles = MorrowTextStyles.of(context);
    final radius = BorderRadius.circular(MorrowRadii.md);

    final weekdayColour = selected ? colors.onPrimaryMuted : colors.mutedText;
    // Future days use the muted colour with no dot, and are not tappable.
    final numberColour = selected
        ? colors.onPrimary
        : day.isFuture
        ? colors.mutedText
        : colors.ink;
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
      enabled: !day.isFuture,
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

/// Screen reader label for a day, for example
/// "Friday 6 November, today, has entries".
String weekStripDayLabel(WeekStripDay day) {
  final d = day.date;
  final parts = <String>[
    '${weekdayName(d)} ${d.day} ${monthName(d.month)}',
    if (day.isToday) 'today',
    if (day.isFuture)
      'not available yet'
    else
      day.hasEntries ? 'has entries' : 'no entries',
  ];
  return parts.join(', ');
}
