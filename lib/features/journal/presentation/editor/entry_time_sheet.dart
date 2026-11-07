import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/time/local_date.dart';
import '../../../../ui/format/labels.dart';
import '../../../../ui/theme/morrow_colors.dart';
import '../../../../ui/theme/morrow_tokens.dart';
import '../../../../ui/widgets/morrow_button.dart';
import '../../../../ui/widgets/morrow_chip.dart';
import '../../../../ui/widgets/overlays.dart';

typedef EntryTime = ({LocalDate date, int hour, int minute});

/// "When did this happen?" (screen 2.3). Completes with the chosen local date
/// and time, or null if dismissed. Times that have not happened yet cannot
/// be chosen.
Future<EntryTime?> showEntryTimeSheet(
  BuildContext context, {
  required EntryTime initial,
  required LocalDate today,
  required bool Function(LocalDate date, int hour, int minute) isInFuture,
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
  final bool Function(LocalDate date, int hour, int minute) isInFuture;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late LocalDate _date = widget.initial.date;
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;

  late final _hourCtl = FixedExtentScrollController(
    initialItem: (_hour % 12 == 0 ? 12 : _hour % 12) - 1,
  );
  late final _minuteCtl = FixedExtentScrollController(initialItem: _minute);
  late final _periodCtl = FixedExtentScrollController(
    initialItem: _hour < 12 ? 0 : 1,
  );

  @override
  void dispose() {
    _hourCtl.dispose();
    _minuteCtl.dispose();
    _periodCtl.dispose();
    super.dispose();
  }

  LocalDate get _yesterday => widget.today.addDays(-1);

  void _setHour12(int index, {bool? pm}) {
    final h12 = index + 1; // 1..12
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
      setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final isToday = _date == widget.today;
    final isYesterday = _date == _yesterday;
    final future = widget.isInFuture(_date, _hour, _minute);

    Widget wheel({
      required String label,
      required FixedExtentScrollController controller,
      required int count,
      required String Function(int) itemLabel,
      required ValueChanged<int> onChanged,
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
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: colors.tint,
                  borderRadius: BorderRadius.circular(MorrowRadii.sm),
                ),
              ),
              CupertinoPicker(
                scrollController: controller,
                itemExtent: 44,
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
              onSelected: (_) => setState(() => _date = widget.today),
            ),
            MorrowChip(
              label: 'Yesterday',
              selected: isYesterday,
              onSelected: (_) => setState(() => _date = _yesterday),
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
        const SizedBox(height: MorrowSpacing.lg),
        Container(
          height: 150,
          padding: const EdgeInsets.symmetric(horizontal: MorrowSpacing.md),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(MorrowRadii.lg),
          ),
          child: Row(
            children: [
              wheel(
                label: 'Hour',
                controller: _hourCtl,
                count: 12,
                itemLabel: (i) => '${i + 1}',
                onChanged: _setHour12,
              ),
              wheel(
                label: 'Minute',
                controller: _minuteCtl,
                count: 60,
                itemLabel: (i) => i.toString().padLeft(2, '0'),
                onChanged: (i) => setState(() => _minute = i),
              ),
              wheel(
                label: 'am or pm',
                controller: _periodCtl,
                count: 2,
                itemLabel: (i) => i == 0 ? 'am' : 'pm',
                onChanged: (i) => _setHour12(_hourCtl.selectedItem, pm: i == 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: MorrowSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            future
                ? 'That time hasn’t happened yet. Choose an earlier time.'
                : 'Date and time are the only required parts of an entry.',
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
              : () => Navigator.of(
                  context,
                ).pop<EntryTime>((date: _date, hour: _hour, minute: _minute)),
        ),
      ],
    );
  }
}
