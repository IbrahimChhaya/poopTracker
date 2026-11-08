import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/notifications/reminder_scheduler.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/icon_tile.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/setting_row.dart';
import '../../../ui/widgets/states.dart';
import '../data/reminder_repository.dart';
import 'reminder_controller.dart';

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "6:00 pm" for an hour and minute.
String reminderTime(int hour, int minute) =>
    formatTime(DateTime.utc(2000, 1, 1, hour, minute));

/// "Every Sunday at 6:00 pm".
String reminderSummary(ReminderIntent i) =>
    'Every ${_weekdayNames[i.effectiveWeekday - 1]} at '
    '${reminderTime(i.effectiveHour, i.effectiveMinute)}';

/// "Weekly reminder" (6.1–6.4).
class ReminderScreen extends ConsumerWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final view = ref.watch(reminderControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    side: BorderSide(color: colors.line),
                    backgroundColor: colors.card,
                    foregroundColor: colors.ink,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                const SizedBox(width: MorrowSpacing.md),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Weekly reminder', style: text.headlineSmall),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MorrowSpacing.xxl),
            ...switch (view) {
              AsyncData(:final value) => _content(context, ref, value),
              AsyncError() => const [
                ErrorBanner(
                  title: 'Couldn’t load your reminder',
                  message: 'Nothing has been changed.',
                ),
              ],
              _ => const [LoadingState(label: 'Loading…')],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, ReminderView v) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final controller = ref.read(reminderControllerProvider.notifier);
    final i = v.intent;
    final on = i.enabled;

    Future<void> chooseTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: i.effectiveHour,
          minute: i.effectiveMinute,
        ),
        helpText: 'Reminder time',
      );
      if (picked != null) {
        await controller.setDayAndTime(
          hour: picked.hour,
          minute: picked.minute,
        );
      }
    }

    return [
      CardGroup(
        children: [
          SettingRow.toggle(
            icon: Icons.notifications_none,
            title: 'Remind me weekly',
            subtitle: v.turningOn
                ? 'Turning on…'
                : on
                ? 'On'
                : 'Off',
            value: on || v.turningOn,
            onChanged: v.turningOn ? null : controller.setEnabled,
          ),
        ],
      ),
      if (!on) ...[
        const SizedBox(height: MorrowSpacing.lg),
        Text(
          'Get one gentle nudge a week to add an entry. You choose the day '
          'and time.',
          style: text.bodySmall,
        ),
      ] else ...[
        const SizedBox(height: MorrowSpacing.xxl),
        Semantics(header: true, child: Text('Day', style: text.labelMedium)),
        const SizedBox(height: MorrowSpacing.sm),
        _DayPicker(
          selected: i.effectiveWeekday,
          onSelected: (d) => controller.setDayAndTime(weekday: d),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        CardGroup(
          children: [
            SettingRow.navigation(
              icon: Icons.schedule_outlined,
              title: 'Time',
              subtitle: 'Follows your phone’s local time',
              actionLabel: reminderTime(i.effectiveHour, i.effectiveMinute),
              onTap: chooseTime,
            ),
          ],
        ),
        const SizedBox(height: MorrowSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(
            reminderSummary(i),
            style: text.bodyMedium!.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(height: MorrowSpacing.xxl),
        if (v.permission == NotificationPermission.denied)
          _NotificationsOff(
            canOpenSettings: ref
                .read(reminderSchedulerProvider)
                .canOpenSettings,
            onOpenSettings: controller.openSettings,
          )
        else if (v.scheduleFailed)
          const ErrorBanner(
            title: 'Couldn’t schedule your reminder',
            message:
                'Your choice is saved. morrow will try again next time you '
                'open it.',
          )
        else ...[
          Text('How it will look', style: text.labelMedium),
          const SizedBox(height: MorrowSpacing.sm),
          const _Preview(),
          const SizedBox(height: MorrowSpacing.xxl),
          Text('Status', style: text.labelMedium),
          const SizedBox(height: MorrowSpacing.sm),
          const CardGroup(
            children: [
              _StatusRow(
                title: 'Notifications are allowed',
                subtitle: 'morrow can show your reminder',
              ),
            ],
          ),
        ],
        const SizedBox(height: MorrowSpacing.xxl),
        Text(
          'Reminders use your phone’s scheduling and may arrive a little '
          'late, for example when battery saver is on. They never include '
          'your entries.',
          style: text.labelSmall,
        ),
      ],
    ];
  }
}

/// M T W T F S S, one choice.
class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    // Seven equal circles in one row, as large as fit (up to 48 px).
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = MorrowSpacing.xs;
        final size = ((constraints.maxWidth - 6 * gap) / 7).clamp(
          32.0,
          MorrowSizes.minTouchTarget,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var d = 1; d <= 7; d++)
              Semantics(
                button: true,
                selected: d == selected,
                inMutuallyExclusiveGroup: true,
                label: _weekdayNames[d - 1],
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: size,
                  child: Material(
                    color: d == selected ? colors.primary : colors.card,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: d == selected ? colors.primary : colors.line,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onSelected(d),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _weekdayNames[d - 1].substring(0, 1),
                            style: text.labelLarge!.copyWith(
                              fontSize: 14,
                              color: d == selected
                                  ? colors.onPrimary
                                  : colors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// What the notification will look like (generic wording only).
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Preview: $reminderTitle. $reminderBody',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MorrowSpacing.lg),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(MorrowRadii.lg),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa_outlined, size: 14, color: colors.primary),
                const SizedBox(width: MorrowSpacing.xs),
                Text('morrow · now', style: text.labelSmall),
              ],
            ),
            const SizedBox(height: MorrowSpacing.xs),
            Text(reminderTitle, style: text.titleSmall),
            const SizedBox(height: MorrowSpacing.xxs),
            Text(reminderBody, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MorrowSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            const IconTile(icon: Icons.check),
            const SizedBox(width: MorrowSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: MorrowSpacing.xxs),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Notifications are turned off" (6.4). The reminder stays saved.
class _NotificationsOff extends StatelessWidget {
  const _NotificationsOff({
    required this.canOpenSettings,
    required this.onOpenSettings,
  });

  final bool canOpenSettings;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErrorBanner(
          title: 'Notifications are turned off',
          message: canOpenSettings
              ? 'Your reminder is saved, but nothing will be sent until you '
                    'allow notifications for morrow in your phone’s settings. '
                    'You can still add entries as usual.'
              : 'Your reminder is saved, but nothing will be sent until you '
                    'allow notifications for morrow in Settings > '
                    'Notifications. You can still add entries as usual.',
        ),
        if (canOpenSettings) ...[
          const SizedBox(height: MorrowSpacing.md),
          MorrowButton(
            label: 'Open phone settings',
            variant: MorrowButtonVariant.secondary,
            onPressed: onOpenSettings,
          ),
        ],
      ],
    );
  }
}
