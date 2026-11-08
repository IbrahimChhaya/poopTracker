import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paths.dart';
import '../../../app/scope.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/overlays.dart';
import '../../../ui/widgets/states.dart';
import 'detail_labels.dart';
import 'history_controller.dart';
import 'widgets/entry_card.dart';

/// "Your history" (4.2–4.6, 4.11).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(historyQueryProvider).search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  HistoryQueryController get _query => ref.read(historyQueryProvider.notifier);

  void _clearSearch() {
    _search.clear();
    _query.clearSearch();
  }

  Future<void> _openFilter(HistoryRange current) async {
    final chosen = await showMorrowSheet<_FilterResult>(
      context,
      title: 'Filter entries',
      builder: (_) => _FilterSheet(current: current),
    );
    switch (chosen) {
      case _FilterApply(:final range):
        _query.setRange(range);
      case _FilterClear():
        _query.clearFilters();
      case null:
        break;
    }
  }

  Future<void> _openTypeFilter(int? current) async {
    final chosen = await showMorrowSheet<_TypeChoice>(
      context,
      title: 'Stool form',
      builder: (_) => _TypeSheet(current: current),
    );
    if (chosen != null) _query.setStoolType(chosen.type);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(historyViewProvider);
    final text = Theme.of(context).textTheme;
    final colors = MorrowColors.of(context);

    final header = <Widget>[
      Semantics(
        header: true,
        child: Text('Your history', style: text.headlineLarge),
      ),
      const SizedBox(height: MorrowSpacing.xxl),
      TextField(
        controller: _search,
        onChanged: _query.setSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search your notes',
          prefixIcon: Icon(Icons.search, color: colors.mutedIcon),
          suffixIcon: ValueListenableBuilder(
            valueListenable: _search,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: _clearSearch,
                  ),
          ),
        ),
      ),
    ];

    final List<Widget> content = switch (view) {
      AsyncData(:final value) => _content(context, value),
      AsyncError() => const [
        ErrorBanner(
          title: 'Couldn’t load your history',
          message: 'Nothing has been changed.',
        ),
      ],
      _ => const [LoadingState(label: 'Loading your history…')],
    };

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [...header, const SizedBox(height: 14), ...content],
      ),
    );
  }

  List<Widget> _content(BuildContext context, HistoryView v) {
    final text = Theme.of(context).textTheme;
    final colors = MorrowColors.of(context);
    final rangeLabel = formatDateRange(v.from!, v.today);

    return [
      Wrap(
        spacing: MorrowSpacing.sm,
        runSpacing: MorrowSpacing.sm,
        children: [
          Semantics(
            button: true,
            label: 'Date range: ${v.query.range.label}, $rangeLabel. Change',
            excludeSemantics: true,
            child: ActionChip(
              onPressed: () => _openFilter(v.query.range),
              backgroundColor: colors.tint,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      rangeLabel,
                      style: text.bodySmall!.copyWith(color: colors.ink),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.expand_more, size: 16, color: colors.mutedIcon),
                ],
              ),
            ),
          ),
          if (ref.watch(displayProvider).showStoolForm)
            _FilterChip(
              label: v.query.stoolType == null
                  ? 'All types'
                  : 'Type ${v.query.stoolType}',
              semantics: v.query.stoolType == null
                  ? 'Stool form filter: all types. Change'
                  : 'Stool form filter: type ${v.query.stoolType}. Change',
              onPressed: () => _openTypeFilter(v.query.stoolType),
            ),
        ],
      ),
      // Only an empty result is counted (4.5, 4.6); lists speak for
      // themselves.
      if (v.matchCount == 0) ...[
        const SizedBox(height: MorrowSpacing.sm),
        Text(formatEntryCount(0), style: text.labelSmall),
      ],
      const SizedBox(height: MorrowSpacing.lg),
      if (v.journalIsEmpty)
        _EmptyJournal(onAdd: () => context.push(AppPaths.newEntry))
      else if (v.matchCount == 0 && v.searching)
        _NoMatches(onClear: _clearSearch)
      else if (v.matchCount == 0)
        const EmptyState(
          title: 'No entries in this period',
          message: 'Choose a longer range or show earlier entries.',
        )
      else
        for (final g in v.groups) ...[
          SectionHeading(
            title: formatDayHeading(g.date, today: v.today),
            trailing: formatEntryCount(g.entries.length),
          ),
          const SizedBox(height: MorrowSpacing.md),
          for (final e in g.entries) ...[
            EntryCard(
              entry: e,
              title: formatTimeOrEntry(e.localTime),
              onTap: () => context.go(AppPaths.historyEntry, extra: e.id),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: MorrowSpacing.md),
        ],
      if (v.hasEarlier)
        Center(
          child: TextButton.icon(
            onPressed: _query.showEarlier,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: const Text('Show earlier entries'),
          ),
        ),
    ];
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EmptyState(
          title: 'Nothing here yet',
          message: 'Entries you add will appear here, newest first.',
        ),
        const SizedBox(height: MorrowSpacing.lg),
        MorrowButton(label: 'Add an entry', icon: Icons.add, onPressed: onAdd),
      ],
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MorrowSpacing.xxl),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(MorrowRadii.xl),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: colors.tint,
              child: Icon(Icons.search, color: colors.primary),
            ),
          ),
          const SizedBox(height: MorrowSpacing.md),
          Text(
            'No matching entries',
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different word, or clear the search.',
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(fontSize: 13),
          ),
          const SizedBox(height: MorrowSpacing.lg),
          IntrinsicWidth(
            child: MorrowButton(
              label: 'Clear search',
              variant: MorrowButtonVariant.secondary,
              onPressed: onClear,
            ),
          ),
        ],
      ),
    );
  }
}

sealed class _FilterResult {
  const _FilterResult();
}

final class _FilterApply extends _FilterResult {
  const _FilterApply(this.range);

  final HistoryRange range;
}

final class _FilterClear extends _FilterResult {
  const _FilterClear();
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current});

  final HistoryRange current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HistoryRange _range = widget.current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Date range', style: text.labelMedium),
        RadioGroup<HistoryRange>(
          groupValue: _range,
          onChanged: (r) => setState(() => _range = r ?? _range),
          child: Column(
            children: [
              for (final r in HistoryRange.values) ...[
                RadioListTile<HistoryRange>(
                  value: r,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(
                    r.label,
                    style: text.bodyLarge!.copyWith(
                      fontWeight: r == _range ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (r != HistoryRange.values.last) const Divider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        MorrowButton(
          label: 'Apply',
          onPressed: () => Navigator.of(context).pop(_FilterApply(_range)),
        ),
        const SizedBox(height: MorrowSpacing.md),
        MorrowButton(
          label: 'Clear filters',
          variant: MorrowButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(const _FilterClear()),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.semantics,
    required this.onPressed,
  });

  final String label;
  final String semantics;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: ActionChip(
        onPressed: onPressed,
        backgroundColor: colors.tint,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: text.bodySmall!.copyWith(color: colors.ink),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 16, color: colors.mutedIcon),
          ],
        ),
      ),
    );
  }
}

final class _TypeChoice {
  const _TypeChoice(this.type);

  final int? type;
}

class _TypeSheet extends StatefulWidget {
  const _TypeSheet({required this.current});

  final int? current;

  @override
  State<_TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends State<_TypeSheet> {
  // 0 means all types.
  late int _value = widget.current ?? 0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RadioGroup<int>(
          groupValue: _value,
          onChanged: (v) => setState(() => _value = v ?? 0),
          child: Column(
            children: [
              for (final t in [0, ...stoolForms.keys]) ...[
                RadioListTile<int>(
                  value: t,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(
                    t == 0 ? 'All types' : stoolFormLabel(t),
                    style: text.bodyLarge!.copyWith(
                      fontWeight: t == _value ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (t != 7) const Divider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        MorrowButton(
          label: 'Apply',
          onPressed: () =>
              Navigator.of(context)
                  .pop(_TypeChoice(_value == 0 ? null : _value)),
        ),
      ],
    );
  }
}
