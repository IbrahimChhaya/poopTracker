import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/scope.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/page_body.dart';
import '../../../ui/widgets/states.dart';
import '../domain/weekly_summary.dart';
import 'trends_controller.dart';

/// "Your weeks" (5.1–5.7): simple weekly counts over 4, 12 or 26 weeks.
/// Descriptive only: no scores, forecasts or advice.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(trendsViewProvider);
    return PageBody(
      title: 'Your weeks',
      children: switch (view) {
        AsyncData(:final value) when !value.enoughData => const [
          EmptyState(
            title: 'Not enough entries yet',
            message:
                'Weekly trends appear once you have entries from at least two '
                'different weeks.',
          ),
        ],
        AsyncData(:final value) => _content(context, ref, value),
        AsyncError() => const [
          ErrorBanner(
            title: 'Couldn’t load your weeks',
            message: 'Nothing has been changed.',
          ),
        ],
        _ => const [LoadingState(label: 'Loading…')],
      },
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, TrendsView v) {
    final s = v.summary;
    final selection = ref.read(trendsSelectionProvider.notifier);
    final showStool = ref.watch(displayProvider).showStoolForm;
    final weeks = s.weekCount;
    return [
      _RangeTabs(selected: v.selection.range, onSelected: selection.setRange),
      const SizedBox(height: MorrowSpacing.sm),
      _RangePager(
        label: formatDateRange(s.firstDay, s.lastDay, withYear: true),
        onEarlier: v.canGoEarlier ? selection.earlier : null,
        onLater: v.canGoLater ? selection.later : null,
      ),
      const SizedBox(height: MorrowSpacing.lg),
      _StatTiles(
        tiles: [
          (
            value: '${s.totalEntries}',
            title: 'Total entries',
            caption: 'in $weeks weeks',
          ),
          (
            value: formatRatioOneDecimal(s.totalEntries, weeks),
            title: 'Entries / week',
            caption: 'weekly average',
          ),
          (
            value: '${s.weeksLogged} / $weeks',
            title: 'Weeks logged',
            caption: 'with an entry',
          ),
        ],
      ),
      const SizedBox(height: MorrowSpacing.xxl),
      _WeeklyChart(summary: s, lastInProgress: v.includesThisWeek),
      if (showStool) ...[
        const SizedBox(height: MorrowSpacing.xxl),
        _StoolFormCard(summary: s),
      ],
    ];
  }
}

/// 4, 12 or 26 weeks: always one chosen.
class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.selected, required this.onSelected});

  final TrendRange selected;
  final ValueChanged<TrendRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final values = TrendRange.values;
    return Container(
      padding: const EdgeInsets.all(MorrowSpacing.xs),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(MorrowRadii.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: values[i] == selected,
                inMutuallyExclusiveGroup: true,
                label: '${values[i].weeks} weeks, ${i + 1} of ${values.length}',
                excludeSemantics: true,
                child: Material(
                  color: values[i] == selected
                      ? colors.card
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(MorrowRadii.md - 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(MorrowRadii.md - 4),
                    onTap: () => onSelected(values[i]),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: MorrowSizes.minTouchTarget - 8,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MorrowSpacing.xs,
                            vertical: MorrowSpacing.sm,
                          ),
                          child: Text(
                            '${values[i].weeks} weeks',
                            textAlign: TextAlign.center,
                            style: values[i] == selected
                                ? text.labelMedium!.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  )
                                : text.labelMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "‹ 12 Oct – 8 Nov 2026 ›": earlier ranges, never the future.
class _RangePager extends StatelessWidget {
  const _RangePager({
    required this.label,
    required this.onEarlier,
    required this.onLater,
  });

  final String label;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Earlier weeks',
          onPressed: onEarlier,
          icon: const Icon(Icons.chevron_left),
          color: colors.ink,
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: text.labelMedium!.copyWith(color: colors.ink),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Later weeks',
          onPressed: onLater,
          icon: const Icon(Icons.chevron_right),
          color: colors.ink,
        ),
      ],
    );
  }
}

typedef _Tile = ({String value, String title, String caption});

/// Three figures side by side, stacked once text is enlarged.
class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.15;

    Widget tile(_Tile t) => Semantics(
      container: true,
      label: '${t.title}: ${t.value}, ${t.caption}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(MorrowRadii.lg),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // One line; shrinks only when the tile is too narrow.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                t.value,
                maxLines: 1,
                style: text.headlineMedium!.copyWith(color: colors.primary),
              ),
            ),
            const SizedBox(height: MorrowSpacing.sm),
            Text(
              t.title,
              style: text.labelMedium!.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: MorrowSpacing.xxs),
            Text(t.caption, style: text.labelSmall),
          ],
        ),
      ),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: MorrowSpacing.sm),
            tile(tiles[i]),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: MorrowSpacing.sm),
            Expanded(child: tile(tiles[i])),
          ],
        ],
      ),
    );
  }
}

/// A rounded Card Paper panel with a title and a trailing caption.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.trailing,
    required this.children,
  });

  final String title;
  final String trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(MorrowRadii.xxl),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MorrowSpacing.md,
            runSpacing: MorrowSpacing.xs,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: text.titleMedium),
              ),
              Text(trailing, style: text.labelSmall),
            ],
          ),
          const SizedBox(height: MorrowSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// The smallest even number at or above [max] (at least 2), so the axis
/// reads 0, half, top in whole numbers ("0, 3, 6").
int _axisTop(int max) => max <= 2 ? 2 : (max.isEven ? max : max + 1);

/// "Entries each week" (5.1–5.3): one bar per week, the week in progress
/// in Deep Sage. Drawn with plain widgets; each bar has its own label for
/// screen readers.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.summary, required this.lastInProgress});

  final WeeklySummary summary;
  final bool lastInProgress;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    // Grows with the text size so the axis labels always fit.
    final plotHeight = MediaQuery.textScalerOf(context).scale(80);
    final weeks = summary.weeks;
    final top = _axisTop(
      weeks.fold(0, (m, w) => w.entries > m ? w.entries : m),
    );
    final gap = weeks.length <= 4
        ? 18.0
        : weeks.length <= 12
        ? 8.0
        : 3.0;
    final axisStyle = text.labelSmall!;

    Widget bar(int i) {
      final w = weeks[i];
      final current = lastInProgress && i == weeks.length - 1;
      final label =
          'Week of ${formatDayMonth(w.weekStart)}, '
          '${formatEntryCount(w.entries)}${current ? ', in progress' : ''}';
      return Expanded(
        child: Semantics(
          container: true,
          label: label,
          excludeSemantics: true,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: plotHeight * w.entries / top,
              decoration: BoxDecoration(
                color: current ? colors.primary : colors.chartBar,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final List<Widget> xLabels = weeks.length <= 4
        ? [
            for (var i = 0; i < weeks.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: Text(
                  formatDayMonth(weeks[i].weekStart),
                  textAlign: TextAlign.center,
                  style: axisStyle,
                ),
              ),
            ],
          ]
        : [
            Text(formatDayMonth(weeks.first.weekStart), style: axisStyle),
            const Spacer(),
            Text(
              formatDayMonth(weeks[weeks.length ~/ 2].weekStart),
              style: axisStyle,
            ),
            const Spacer(),
            Text(formatDayMonth(weeks.last.weekStart), style: axisStyle),
          ];

    return _ChartCard(
      title: 'Entries each week',
      trailing: 'Entries / week',
      children: [
        SizedBox(
          height: plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final n in [top, top ~/ 2, 0])
                      Text('$n', style: axisStyle),
                  ],
                ),
              ),
              const SizedBox(width: MorrowSpacing.sm),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < weeks.length; i++) ...[
                        if (i > 0) SizedBox(width: gap),
                        bar(i),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MorrowSpacing.sm),
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(children: xLabels),
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        Text(
          lastInProgress
              ? 'Weeks run Monday to Sunday. The latest week is still in '
                    'progress.'
              : 'Weeks run Monday to Sunday.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// "Stool form" (5.4–5.6): how many entries recorded each type. Counts
/// only; no type is presented as better or worse. Shown only when the
/// Stool form setting is on.
class _StoolFormCard extends StatelessWidget {
  const _StoolFormCard({required this.summary});

  final WeeklySummary summary;

  static const double _plotHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final counts = summary.stoolForm.countsByType;
    final withType = summary.stoolForm.entriesWithType;
    final max = counts.values.fold(0, (m, c) => c > m ? c : m);

    Widget column(int type) {
      final n = counts[type] ?? 0;
      return Expanded(
        child: Semantics(
          container: true,
          label: 'Type $type, ${formatEntryCount(n)}',
          excludeSemantics: true,
          child: Column(
            children: [
              Text('$n', style: text.labelSmall),
              const SizedBox(height: MorrowSpacing.xs),
              SizedBox(
                height: _plotHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: n == 0 || max == 0
                        ? 4
                        : 4 + (_plotHeight - 4) * n / max,
                    decoration: BoxDecoration(
                      color: n == 0 ? colors.line : colors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MorrowSpacing.sm),
              Text('$type', style: text.bodySmall),
            ],
          ),
        ),
      );
    }

    return _ChartCard(
      title: 'Stool form',
      trailing: 'Optional · Bristol scale',
      children: [
        Semantics(
          container: true,
          label:
              '$withType of ${formatEntryCount(summary.totalEntries)} in '
              '${summary.weekCount} weeks recorded a stool form',
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$withType',
                style: text.headlineLarge!.copyWith(color: colors.primary),
              ),
              const SizedBox(width: MorrowSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      withType == 1
                          ? 'entry recorded a stool form'
                          : 'entries recorded a stool form',
                      style: text.labelMedium!.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: MorrowSpacing.xxs),
                    Text(
                      'out of ${summary.totalEntries} in '
                      '${summary.weekCount} weeks',
                      style: text.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MorrowSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var t = 1; t <= 7; t++) ...[
              if (t > 1) const SizedBox(width: MorrowSpacing.sm),
              column(t),
            ],
          ],
        ),
        const SizedBox(height: MorrowSpacing.lg),
        Text('Numbers show entries for each type', style: text.bodySmall),
      ],
    );
  }
}
