import 'package:flutter/material.dart';

import '../theme/morrow_tokens.dart';
import '../theme/morrow_typography.dart';
import '../widgets/card_group.dart';
import '../widgets/morrow_button.dart';
import '../widgets/morrow_chip.dart';
import '../widgets/overlays.dart';
import '../widgets/setting_row.dart';
import '../widgets/states.dart';
import '../widgets/week_strip.dart';

/// Every shared widget on one screen, with synthetic content. Reachable only
/// in debug builds (see the placeholder Settings tab) and used by the
/// accessibility tests.
class UiKitGallery extends StatefulWidget {
  const UiKitGallery({super.key});

  @override
  State<UiKitGallery> createState() => _UiKitGalleryState();
}

class _UiKitGalleryState extends State<UiKitGallery> {
  bool _toggle = false;
  bool _busy = false;
  final Set<String> _chips = {'Easy'};
  DateTime? _selectedDay;

  static final List<WeekStripDay> _week = [
    for (var d = 2; d <= 8; d++)
      WeekStripDay(
        date: DateTime(2026, 11, d),
        hasEntries: d <= 6,
        isToday: d == 6,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final styles = MorrowTextStyles.of(context);
    const gap = SizedBox(height: MorrowSpacing.xxl);

    return Scaffold(
      appBar: AppBar(title: const Text('UI kit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
        children: [
          Text('UI KIT', style: styles.eyebrow),
          const SizedBox(height: MorrowSpacing.sm),
          Text('A little clarity.', style: text.headlineLarge),
          const SizedBox(height: MorrowSpacing.xs),
          Text('Synthetic content only', style: text.bodyMedium),
          gap,
          WeekStrip(
            days: _week,
            selected: _selectedDay,
            onSelected: (d) =>
                setState(() => _selectedDay = _selectedDay == d ? null : d),
          ),
          gap,
          MorrowButton(
            label: 'Add an entry',
            icon: Icons.add,
            large: true,
            onPressed: () {},
          ),
          const SizedBox(height: MorrowSpacing.md),
          MorrowButton(
            label: 'Save entry',
            busyLabel: 'Saving…',
            busy: _busy,
            onPressed: () => setState(() => _busy = true),
          ),
          const SizedBox(height: MorrowSpacing.md),
          MorrowButton(
            label: 'Clear filters',
            variant: MorrowButtonVariant.secondary,
            onPressed: () => setState(() => _busy = false),
          ),
          const SizedBox(height: MorrowSpacing.md),
          MorrowButton(
            label: 'Discard',
            variant: MorrowButtonVariant.dangerOutline,
            onPressed: () {},
          ),
          const SizedBox(height: MorrowSpacing.md),
          MorrowButton(
            label: 'Delete everything',
            variant: MorrowButtonVariant.danger,
            onPressed: () {},
          ),
          gap,
          CardGroup(
            label: 'Privacy',
            children: [
              SettingRow.navigation(
                icon: Icons.lock_outline,
                title: 'App lock',
                subtitle: 'Off',
                onTap: () {},
              ),
              SettingRow.toggle(
                icon: Icons.notes,
                title: 'Example setting',
                subtitle: 'Shows an optional step when adding an entry.',
                value: _toggle,
                onChanged: (v) => setState(() => _toggle = v),
              ),
            ],
          ),
          const SizedBox(height: MorrowSpacing.lg),
          CardGroup(
            label: 'Data',
            children: [
              SettingRow.navigation(
                icon: Icons.delete_outline,
                title: 'Delete all data',
                subtitle: 'Removes every entry from this phone',
                destructive: true,
                onTap: () {},
              ),
            ],
          ),
          gap,
          Text('How did it feel?', style: text.titleMedium),
          const SizedBox(height: MorrowSpacing.md),
          ChipWrap(
            children: [
              for (final label in const ['Easy', 'Some effort', 'Difficult'])
                MorrowChip(
                  label: label,
                  selected: _chips.contains(label),
                  onSelected: (on) => setState(
                    () => on ? _chips.add(label) : _chips.remove(label),
                  ),
                ),
            ],
          ),
          gap,
          const EmptyState(
            title: 'Nothing here yet',
            message:
                'Add an entry whenever you’re ready. It stays on this phone.',
          ),
          const SizedBox(height: MorrowSpacing.lg),
          const ErrorBanner(
            title: 'Couldn’t save your entry',
            message:
                'Your draft is still here. Nothing has been lost. Try again.',
          ),
          const SizedBox(height: MorrowSpacing.lg),
          const LoadingState(label: 'Loading…'),
          gap,
          Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MorrowButton(
                  label: 'Show dialog',
                  variant: MorrowButtonVariant.secondary,
                  onPressed: () => showMorrowConfirmDialog(
                    context,
                    title: 'Discard this entry?',
                    message:
                        'You haven’t saved it yet. If you leave now, what '
                        'you’ve entered will be lost.',
                    confirmLabel: 'Discard',
                    cancelLabel: 'Keep editing',
                    destructive: true,
                  ),
                ),
                const SizedBox(height: MorrowSpacing.md),
                MorrowButton(
                  label: 'Show sheet',
                  variant: MorrowButtonVariant.secondary,
                  onPressed: () => showMorrowSheet<void>(
                    context,
                    title: 'Filter entries',
                    builder: (context) => MorrowButton(
                      label: 'Apply',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const SizedBox(height: MorrowSpacing.md),
                MorrowButton(
                  label: 'Show toast',
                  variant: MorrowButtonVariant.secondary,
                  onPressed: () => showMorrowToast(context, 'Entry saved'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
