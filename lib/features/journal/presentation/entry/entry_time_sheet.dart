import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/time/local_date.dart';
import '../../../../ui/format/labels.dart';
import '../../../../ui/theme/morrow_colors.dart';
import '../../../../ui/theme/morrow_tokens.dart';
import '../../../../ui/widgets/morrow_button.dart';
import '../../../../ui/widgets/morrow_chip.dart';
import '../../../../ui/widgets/overlays.dart';

typedef EntryTime = ({LocalDate date, int hour, int minute, bool hasTime});

/// "When did this happen?" (2.3, 2.8). Completes with the chosen local date
/// and, if "Record a time" is on, the time; null if dismissed. Times that have
/// not happened yet cannot be chosen.
Future<EntryTime?> showEntryTimeSheet(
  BuildContext context, {
  required EntryTime initial,
  required LocalDate today,
  required bool Function(LocalDate date, int hour, int minute, {bool hasTime})
  isInFuture,
}) {
  return showMorrowSheet<EntryTime>(
    context,
    title: 'When did this happen?',
    builder: (context) =>
        _TimeSheet(initial: initial, today: today, isInFuture: isInFuture),
  );
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.initial,
    required this.today,
    required this.isInFuture,
  });

  final EntryTime initial;
  final LocalDate today;
  final bool Function(LocalDate date, int hour, int minute, {bool hasTime})
  isInFuture;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late LocalDate _date = widget.initial.date;
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;
  late bool _hasTime = widget.initial.hasTime;

  /// Until the user flips "Record a time" themselves, picking today turns it
  /// on and picking a past day turns it off.
  bool _timeTouched = false;

  void _setHasTime(bool v) => setState(() {
    _hasTime = v;
    _timeTouched = true;
  });

  void _pickDate(LocalDate d) => setState(() {
    _date = d;
    if (!_timeTouched) _hasTime = d == widget.today;
  });

  late final _hourCtl = FixedExtentScrollController(
    initialItem: (_hour % 12 == 0 ? 12 : _hour % 12) - 1,
  );

  /// Used instead of the 12-hour wheel when the phone uses a 24-hour clock.
  late final _hour24Ctl = FixedExtentScrollController(initialItem: _hour);
  late final _minuteCtl = FixedExtentScrollController(initialItem: _minute);
  late final _periodCtl = FixedExtentScrollController(
    initialItem: _hour < 12 ? 0 : 1,
  );

  @override
  void dispose() {
    _hourCtl.dispose();
    _hour24Ctl.dispose();
    _minuteCtl.dispose();
    _periodCtl.dispose();
    super.dispose();
  }

  LocalDate get _yesterday => widget.today.addDays(-1);

  void _setHour12(int index, {bool? pm}) {
    // Looping wheels report positions past the ends; wrap them.
    final h12 = index % 12 + 1; // 1..12
    final isPm = pm ?? _hour >= 12;
    setState(() => _hour = (h12 % 12) + (isPm ? 12 : 0));
  }

  Future<void> _pickOtherDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(
        widget.today.year,
        widget.today.month,
        widget.today.day,
      ),
    );
    if (picked != null) {
      _pickDate(LocalDate(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final isToday = _date == widget.today;
    final isYesterday = _date == _yesterday;
    final future = widget.isInFuture(_date, _hour, _minute, hasTime: _hasTime);
    // Follows the phone's clock setting, and grows with the text size (up
    // to a point, so the sheet still fits).
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final grow = (MediaQuery.textScalerOf(context).scale(10) / 10).clamp(
      1.0,
      1.6,
    );
    final itemExtent = 44 * grow;

    Widget wheel({
      required String label,
      required FixedExtentScrollController controller,
      required int count,
      required String Function(int) itemLabel,
      required ValueChanged<int> onChanged,
      bool looping = false,
    }) {
      // The highlight sits behind the wheel. CupertinoPicker paints its
      // selection overlay on top of the items, which hid the chosen value.
      return Expanded(
        child: Semantics(
          label: label,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: itemExtent,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: colors.tint,
                  borderRadius: BorderRadius.circular(MorrowRadii.sm),
                ),
              ),
              CupertinoPicker(
                scrollController: controller,
                itemExtent: itemExtent,
                looping: looping,
                onSelectedItemChanged: onChanged,
                selectionOverlay: null,
                children: [
                  for (var i = 0; i < count; i++)
                    Center(
                      child: Text(
                        itemLabel(i),
                        style: text.headlineSmall!.copyWith(color: colors.ink),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChipWrap(
          children: [
            MorrowChip(
              label: 'Today',
              selected: isToday,
              onSelected: (_) => _pickDate(widget.today),
            ),
            MorrowChip(
              label: 'Yesterday',
              selected: isYesterday,
              onSelected: (_) => _pickDate(_yesterday),
            ),
            MorrowChip(
              label: isToday || isYesterday
                  ? 'Other date'
                  : formatDayMonth(
                      _date,
                      withYear: _date.year != widget.today.year,
                    ),
              selected: !isToday && !isYesterday,
              onSelected: (_) => _pickOtherDate(),
            ),
          ],
        ),
        const SizedBox(height: MorrowSpacing.md),
        // The whole row toggles the switch, not just the switch itself.
        MergeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(MorrowRadii.sm),
            onTap: () => _setHasTime(!_hasTime),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Record a time',
                    style: text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(value: _hasTime, onChanged: _setHasTime),
              ],
            ),
          ),
        ),
        if (_hasTime) ...[
          const SizedBox(height: MorrowSpacing.sm),
          Container(
            height: 150 * grow,
            padding: const EdgeInsets.symmetric(horizontal: MorrowSpacing.md),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(MorrowRadii.lg),
            ),
            child: Row(
              children: [
                if (use24)
                  wheel(
                    label: 'Hour',
                    controller: _hour24Ctl,
                    count: 24,
                    itemLabel: (i) => i.toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _hour = i % 24),
                    looping: true,
                  )
                else
                  wheel(
                    label: 'Hour',
                    controller: _hourCtl,
                    count: 12,
                    itemLabel: (i) => '${i + 1}',
                    onChanged: _setHour12,
                    looping: true,
                  ),
                wheel(
                  label: 'Minute',
                  controller: _minuteCtl,
                  count: 60,
                  itemLabel: (i) => i.toString().padLeft(2, '0'),
                  onChanged: (i) => setState(() => _minute = i % 60),
                  looping: true,
                ),
                if (!use24)
                  wheel(
                    label: 'am or pm',
                    controller: _periodCtl,
                    count: 2,
                    itemLabel: (i) => i == 0 ? 'am' : 'pm',
                    onChanged: (i) =>
                        _setHour12(_hourCtl.selectedItem, pm: i == 1),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: MorrowSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            future
                ? 'That time hasn’t happened yet. Choose an earlier time.'
                : 'Only the date is required. Add a time if you know it.',
            style: text.bodySmall!.copyWith(
              color: future ? colors.danger : colors.mutedText,
            ),
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        MorrowButton(
          label: 'Done',
          onPressed: future
              ? null
              : () => Navigator.of(context).pop<EntryTime>((
                  date: _date,
                  hour: _hour,
                  minute: _minute,
                  hasTime: _hasTime,
                )),
        ),
      ],
    );
  }
}
