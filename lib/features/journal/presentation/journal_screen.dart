import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paths.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/theme/morrow_typography.dart';
import '../../../ui/widgets/icon_tile.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/states.dart';
import '../../../ui/widgets/week_strip.dart';
import '../domain/entry.dart';
import 'journal_controller.dart';
import 'widgets/entry_card.dart';

/// Journal home (1.4, 2.1, 4.1): this week's journal, or a selected day's.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(journalHomeProvider);
    return SafeArea(
      child: switch (home) {
        AsyncData(:final value) => _JournalBody(view: value),
        AsyncError() => const Padding(
          padding: EdgeInsets.all(24),
          child: ErrorBanner(
            title: 'Couldn’t load your journal',
            message:
                'Nothing has been changed. Try closing and reopening '
                'morrow.',
          ),
        ),
        _ => const LoadingState(label: 'Loading your journal…'),
      },
    );
  }
}

class _JournalBody extends ConsumerWidget {
  const _JournalBody({required this.view});

  final JournalHomeView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final selected = view.selection.day;
    final String heading;
    if (selected != null) {
      heading = selected.weekStart == view.today.weekStart
          ? '${weekdayName(selected)}’s journal'
          : '${weekdayName(selected)} ${formatDayMonth(selected)}';
    } else if (view.selection.weeksBack == 0) {
      heading = 'This week’s journal';
    } else {
      heading = 'Week of ${formatDayMonth(view.shownWeekStart)}';
    }
    // A selected past day becomes the new entry's default date.
    final newEntryDay = selected != null && selected != view.today
        ? selected
        : null;

    void openEntry(Entry e) => context.go(AppPaths.journalEntry, extra: e.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        const _BrandRow(),
        const SizedBox(height: MorrowSpacing.lg),
        Semantics(
          header: true,
          child: Text('Your journal', style: text.headlineLarge),
        ),
        const SizedBox(height: 7),
        Text(formatFullDate(view.today), style: text.bodyMedium),
        const SizedBox(height: MorrowSpacing.xl),
        _WeekPager(view: view),
        const SizedBox(height: MorrowSpacing.md),
        _StatCard(view: view),
        const SizedBox(height: MorrowSpacing.md),
        MorrowButton(
          label: 'Add an entry',
          icon: Icons.add,
          large: true,
          onPressed: () => context.push(AppPaths.newEntry, extra: newEntryDay),
        ),
        const SizedBox(height: MorrowSpacing.xl),
        SectionHeading(
          title: heading,
          trailing: formatEntryCount(view.listed.length),
        ),
        const SizedBox(height: MorrowSpacing.md),
        if (view.listed.isEmpty)
          EmptyState(
            title: 'Nothing here yet',
            message: selected != null
                ? 'No entries on this day.'
                : view.selection.weeksBack == 0
                ? 'Add an entry whenever you’re ready'
                : 'No entries in this week.',
          )
        else
          for (final e in view.listed) ...[
            EntryCard(
              entry: e,
              title: selected != null
                  ? formatTimeOrEntry(e.localTime)
                  : view.selection.weeksBack == 0
                  ? formatEntryTitle(
                      e.localDate,
                      e.localTime,
                      today: view.today,
                    )
                  : [
                      '${weekdayName(e.localDate)} '
                          '${formatDayMonth(e.localDate)}',
                      if (e.hasTime) formatTime(e.localWallClock),
                    ].join(' · '),
              onTap: () => openEntry(e),
            ),
            const SizedBox(height: MorrowSpacing.md),
          ],
        if (view.lastFourWeeks > 0) ...[
          const SizedBox(height: MorrowSpacing.md),
          _TrendPreview(entries: view.lastFourWeeks),
        ],
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(Icons.spa_outlined, color: colors.primary, size: 23),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text('morrow', style: MorrowTextStyles.of(context).wordmark),
        ),
      ],
    );
  }
}

/// The week strip, swipeable back through earlier weeks (never past the
/// current week), with buttons and a label for the same thing so it works
/// without gestures and with screen readers.
class _WeekPager extends ConsumerStatefulWidget {
  const _WeekPager({required this.view});

  final JournalHomeView view;

  @override
  ConsumerState<_WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends ConsumerState<_WeekPager> {
  // Pages run oldest to newest, so the current week is the last page and
  // swiping right goes back in time. (A reversed PageView picked the wrong
  // page when a day was scrolled into view, for example by a screen reader.)
  static int _pageFor(int weeksBack) => maxWeeksBack - weeksBack;
  static int _weeksBackFor(int page) => maxWeeksBack - page;

  late final PageController _pages = PageController(
    initialPage: _pageFor(widget.view.selection.weeksBack),
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  JournalSelectionController get _selection =>
      ref.read(journalSelectionProvider.notifier);

  void _goTo(int weeksBack) {
    _pages.animateToPage(
      _pageFor(weeksBack),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(_WeekPager old) {
    super.didUpdateWidget(old);
    final target = _pageFor(widget.view.selection.weeksBack);
    if (_pages.hasClients && _pages.page?.round() != target) {
      _pages.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final text = Theme.of(context).textTheme;
    final colors = MorrowColors.of(context);
    final weeksBack = view.selection.weeksBack;
    final start = view.shownWeekStart;
    final label = weeksBack == 0
        ? 'This week'
        : weeksBack == 1
        ? 'Last week'
        : formatDateRange(
            start,
            start.weekEnd,
            withYear: start.year != view.today.year,
          );

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              onPressed: weeksBack < maxWeeksBack
                  ? () => _goTo(weeksBack + 1)
                  : null,
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
              tooltip: 'Next week',
              onPressed: weeksBack > 0 ? () => _goTo(weeksBack - 1) : null,
              icon: const Icon(Icons.chevron_right),
              color: colors.ink,
            ),
          ],
        ),
        const SizedBox(height: MorrowSpacing.xs),
        SizedBox(
          height: WeekStrip.heightFor(MediaQuery.textScalerOf(context)),
          child: PageView.builder(
            controller: _pages,
            itemCount: maxWeeksBack + 1,
            onPageChanged: (page) => _selection.showWeek(_weeksBackFor(page)),
            itemBuilder: (context, page) => WeekStrip(
              days: weekDays(
                view.today,
                _weeksBackFor(page),
                view.daysWithEntries,
              ),
              selected: view.selection.day,
              onSelected: _selection.toggleDay,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.view});

  final JournalHomeView view;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final styles = MorrowTextStyles.of(context);
    final recent = view.latestInShownWeek;
    final current = view.selection.weeksBack == 0;
    final start = view.shownWeekStart;
    final loggedLabel = current
        ? 'Logged this week'
        : 'Logged ${formatDateRange(start, start.weekEnd, withYear: start.year != view.today.year)}';
    final recentLabel = recent == null
        ? '—'
        : recent.localDate == view.today && recent.hasTime
        ? formatTime(recent.localWallClock)
        : relativeDay(recent.localDate, today: view.today);

    Widget stat(String value, String label, String semantics) => Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: styles.statValue),
          const SizedBox(height: 3),
          Text(label, style: text.labelSmall),
        ],
      ),
    );

    final count = stat(
      formatEntryCount(view.entriesInShownWeek),
      loggedLabel,
      '${formatEntryCount(view.entriesInShownWeek)} '
      '${loggedLabel.substring(0, 1).toLowerCase()}'
      '${loggedLabel.substring(1)}',
    );
    final latest = stat(
      recentLabel,
      'Most recent entry',
      recent == null
          ? current
                ? 'No entries yet this week'
                : 'No entries that week'
          : 'Most recent entry: $recentLabel',
    );

    // Side by side at normal sizes; stacked once text is enlarged, so a value
    // never wraps away from its unit ("2 / entries").
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.15;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(MorrowRadii.xxl),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                count,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Divider(height: 1, color: colors.tintLine),
                ),
                latest,
              ],
            )
          : IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: count),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: VerticalDivider(width: 1, color: colors.tintLine),
                  ),
                  Expanded(child: latest),
                ],
              ),
            ),
    );
  }
}

class _TrendPreview extends StatelessWidget {
  const _TrendPreview({required this.entries});

  final int entries;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label:
          'See your patterns. ${formatEntryCount(entries)} over the last 4 '
          'weeks. Opens Trends.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(MorrowRadii.sm),
        onTap: () => context.go(AppPaths.trends),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MorrowSpacing.xs),
          child: Row(
            children: [
              const IconTile(
                icon: Icons.insights_outlined,
                tone: IconTileTone.warm,
              ),
              const SizedBox(width: MorrowSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'See your patterns',
                      style: text.titleSmall!.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: MorrowSpacing.xs),
                    Text(
                      '${formatEntryCount(entries)} over the last 4 weeks',
                      style: text.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward, size: 18, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
