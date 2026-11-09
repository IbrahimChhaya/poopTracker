import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/app/router.dart';
import 'package:poop_tracker/app/scope.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/journal/presentation/entry/entry_page_controller.dart';
import 'package:poop_tracker/ui/theme/morrow_theme.dart';
import 'package:poop_tracker/ui/theme/morrow_typography.dart';

import '../../support/app_harness.dart';
import '../../support/fake_clock.dart';
import '../../support/harness.dart';

/// Repository whose next creates or updates fail, as if the disk were full.
class FlakyRepository extends EntryRepository {
  FlakyRepository(
    super.db,
    super.clock, {
    this.failCreates = 0,
    this.failUpdates = 0,
  });

  int failCreates;
  int failUpdates;
  int updates = 0;

  @override
  Future<Entry> create(EntryDraft draft) async {
    if (failCreates > 0) {
      failCreates--;
      throw StateError('simulated write failure');
    }
    return super.create(draft);
  }

  @override
  Future<Entry> update(int id, EntryDraft draft) async {
    updates++;
    if (failUpdates > 0) {
      failUpdates--;
      throw StateError('simulated write failure');
    }
    return super.update(id, draft);
  }
}

/// The page's vertical list (not the horizontal week pager).
final Finder _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  late TrackingDatabase db;
  late EntryRepository seed;

  setUp(() {
    db = TrackingDatabase();
    seed = EntryRepository(db, figmaNow);
  });

  Future<Entry> seedAt(int day, int hour, int minute, {String? note}) =>
      seed.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 11, day, hour, minute),
          originalUtcOffsetMinutes: 0,
          comment: note,
        ),
      );

  Future<AppUnderTest> pumpReady(
    WidgetTester tester, {
    double textScale = 1,
    Size size = figmaPhone,
  }) => pumpMorrowApp(
    tester,
    [StartupReady(db, createdNew: false)],
    textScale: textScale,
    size: size,
  );

  /// Scrolls [finder] into the built and visible part of a lazy list.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 200, scrollable: _vertical);
    }
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await reveal(tester, find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Finder noteField() => find.byType(TextField);

  group('journal home', () {
    appTest('stats sit side by side at normal text size', (tester) async {
      await seedAt(6, 13, 35);
      await pumpReady(tester);
      final count = tester.getTopLeft(find.text('1 entry').first);
      final latest = tester.getTopLeft(find.text('1:35 pm').first);
      expect(latest.dy, count.dy);
      expect(latest.dx, greaterThan(count.dx));
    });

    appTest('stats stack at large text, keeping each value whole', (
      tester,
    ) async {
      await seedAt(6, 13, 35);
      await pumpReady(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
      final count = tester.getRect(find.text('1 entry').first);
      final latest = tester.getRect(find.text('1:35 pm').first);
      expect(latest.top, greaterThan(count.bottom));
      expect(latest.left, count.left);
      // One line each: the value never wraps away from its unit.
      final style = Theme.of(tester.element(find.text('1 entry').first))
          .extension<MorrowTextStyles>()!
          .statValue;
      final lineHeight = 1.3 * style.fontSize! * style.height!;
      expect(count.height, lessThan(lineHeight * 1.5));
      expect(latest.height, lessThan(lineHeight * 1.5));
    });

    appTest('empty journal (1.4)', (tester) async {
      await pumpReady(tester);
      expect(find.text('Your journal'), findsOneWidget);
      expect(find.text('Friday, 6 November 2026'), findsOneWidget);
      expect(find.text('This week’s journal'), findsOneWidget);
      expect(find.text('0 entries'), findsNWidgets(2));
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('See your weeks'), findsNothing);
    });

    appTest('this week, then a selected day, then back (2.1, 4.1)', (
      tester,
    ) async {
      await seedAt(4, 8, 35);
      await seedAt(4, 18, 20, note: 'Quiet evening');
      await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await seedAt(1, 9, 0, note: 'Last week'); // Sunday of the previous week
      await pumpReady(tester);

      expect(find.text('3 entries'), findsNWidgets(2));
      expect(find.text('1:35 pm'), findsOneWidget); // most recent
      expect(find.text('Today · 1:35 pm'), findsOneWidget);
      expect(find.text('Wednesday · 6:20 pm'), findsOneWidget);
      expect(find.text('Last week'), findsNothing);
      await reveal(tester, find.text('4 entries over the last 4 weeks'));
      expect(find.text('4 entries over the last 4 weeks'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Wednesday 4 November, has entries'),
        -200,
        scrollable: _vertical,
      );

      await tester.tap(
        find.bySemanticsLabel('Wednesday 4 November, has entries'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wednesday’s journal'), findsOneWidget);
      expect(find.text('2 entries'), findsOneWidget);
      expect(find.text('6:20 pm'), findsOneWidget);
      expect(find.text('Felt fine after lunch'), findsNothing);
      // Weekly counts stay weekly.
      expect(find.text('3 entries'), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel('Wednesday 4 November, has entries'),
      );
      await tester.pumpAndSettle();
      expect(find.text('This week’s journal'), findsOneWidget);
    });

    appTest('future days cannot be opened', (tester) async {
      await pumpReady(tester);
      final saturday = find.bySemanticsLabel(
        'Saturday 7 November, not available yet',
      );
      expect(saturday, findsOneWidget);
      expect(
        tester.getSemantics(saturday),
        isSemantics(isEnabled: false, isButton: true),
      );
      await tester.tap(saturday, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('This week’s journal'), findsOneWidget);
      expect(find.text('Saturday’s journal'), findsNothing);
    });

    appTest('there is no "On-device only" chip', (tester) async {
      await pumpReady(tester);
      expect(find.text('On-device only'), findsNothing);
    });

    appTest('earlier weeks by button and by swipe, never the future', (
      tester,
    ) async {
      await seedAt(6, 13, 35, note: 'Current week note');
      await seed.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 10, 28, 9),
          originalUtcOffsetMinutes: 0,
          comment: 'Last week',
        ),
      ); // Wednesday 28 October, after the clocks went back
      await seed.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 10, 21, 9),
          originalUtcOffsetMinutes: 60,
          comment: 'Two weeks ago',
        ),
      );
      await pumpReady(tester);
      expect(find.text('This week'), findsOneWidget);
      expect(find.byTooltip('Next week'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
        reason: 'no future weeks',
      );

      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      expect(find.text('Last week'), findsWidgets);
      expect(find.text('Week of 26 Oct'), findsOneWidget);
      // The stats follow the week on screen.
      expect(find.text('1 entry'), findsNWidgets(2));
      expect(find.text('Logged 26 Oct – 1 Nov'), findsOneWidget);
      expect(find.text('28 Oct'), findsOneWidget); // latest that week
      expect(find.text('Wednesday 28 Oct · 9:00 am'), findsOneWidget);
      expect(find.text('This week'), findsNothing);

      // Swipe right to go further back.
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Week of 19 Oct'), findsOneWidget);
      expect(find.text('Two weeks ago'), findsOneWidget);

      // Swipe left twice: back to this week, and no further.
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('This week’s journal'), findsOneWidget);
    });

    appTest('a selected past day: one tap adds a date-only entry', (
      tester,
    ) async {
      await pumpReady(tester);
      await tester.tap(
        find.bySemanticsLabel('Wednesday 4 November, no entries'),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Add an entry');
      // Saved straight away, without a time: the current time would be a
      // guess for a past day.
      final saved = (await seed.all()).single;
      expect(saved.localDate.day, 4);
      expect(saved.hasTime, isFalse);
      expect(find.text('Wednesday’s entry'), findsOneWidget);
      expect(find.text('Added to Wednesday'), findsOneWidget);
      expect(find.text('Wednesday · No time'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Wednesday’s journal'), findsOneWidget);
      // The day is the heading, so an untimed card is titled "Entry".
      expect(find.text('Entry'), findsOneWidget);
    });

    appTest('a day with no entries says so', (tester) async {
      await pumpReady(tester);
      await tester.tap(find.bySemanticsLabel('Tuesday 3 November, no entries'));
      await tester.pumpAndSettle();
      expect(find.text('Tuesday’s journal'), findsOneWidget);
      expect(find.text('No entries on this day.'), findsOneWidget);
    });
  });

  group('one-tap entry', () {
    appTest('one tap saves today with the time, then Close (2.1, 2.2)', (
      tester,
    ) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      final saved = (await seed.all()).single;
      expect(saved.hasTime, isTrue);
      expect(saved.localWallClock.hour, 13);
      expect(saved.localWallClock.minute, 41);

      expect(find.text('Today’s entry'), findsOneWidget);
      expect(find.text('Added to today'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Today · 1:41 pm'), findsOneWidget);
      expect(find.text('0 / 500'), findsOneWidget);
      // Already saved: the status says so and Done is ready.
      expect(find.text('Saved'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
            .onPressed,
        isNotNull,
      );
      expect(find.text('Saving…'), findsNothing);
      // A just-added entry has Undo instead of Delete.
      expect(find.text('Delete this entry'), findsNothing);

      // Closing needs no confirmation: the entry is already saved.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Today · 1:41 pm'), findsOneWidget);
      expect(find.text('No note'), findsNothing);
      expect(find.bySemanticsLabel('Today · 1:41 pm'), findsOneWidget);
      expect(await seed.all(), hasLength(1));
    });

    appTest('a double tap on Add an entry creates one entry', (tester) async {
      await pumpReady(tester);
      final add = find.text('Add an entry');
      await tester.tap(add);
      await tester.tap(add, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await seed.all(), hasLength(1));
    });

    appTest('a note saves by itself; Done returns (2.5, 2.8)', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Felt fine after lunch');
      await tester.pump();
      expect(find.text('21 / 500'), findsOneWidget);
      expect(find.text('Saving…'), findsOneWidget);
      // Saved shortly after typing stops, without pressing anything.
      await tester.pump(autosaveDelay);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect((await seed.all()).single.comment, 'Felt fine after lunch');
      // Undo stays until the page is left.
      expect(find.text('Undo'), findsOneWidget);
      await tapText(tester, 'Done');
      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Today’s entry'), findsNothing);
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expect((await seed.all()).single.comment, 'Felt fine after lunch');
    });

    appTest('the note cannot go past 500 characters', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'a' * 600);
      await tester.pump();
      expect(find.text('500 / 500'), findsOneWidget);
      await tapText(tester, 'Done');
      expect((await seed.all()).single.comment, hasLength(500));
    });

    appTest('Undo before any change removes the entry at once', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Undo');
      expect(find.text('Undo this entry?'), findsNothing);
      expect(find.text('Entry removed'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(await seed.all(), isEmpty);
    });

    appTest('Undo after a change asks first (2.11)', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Draft');
      await tester.pump();
      await tapText(tester, 'Undo');
      expect(find.text('Undo this entry?'), findsOneWidget);
      await tapText(tester, 'Keep entry');
      expect(await seed.all(), hasLength(1));
      expect(find.text('Draft'), findsOneWidget);

      await tapText(tester, 'Undo');
      await tapText(tester, 'Undo entry');
      expect(await seed.all(), isEmpty);
      expect(find.text('Your journal'), findsOneWidget);
    });

    appTest('Yesterday can be chosen in the time sheet (2.3, 2.4)', (
      tester,
    ) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'When');
      expect(find.text('When did this happen?'), findsOneWidget);
      expect(
        find.text('Only the date is required. Add a time if you know it.'),
        findsOneWidget,
      );
      await tapText(tester, 'Yesterday');
      expect(find.byType(CupertinoPicker), findsNothing);
      await tapText(tester, 'Done');
      expect(find.text('Yesterday · No time'), findsOneWidget);
      // Saved as soon as the time sheet closed.
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Yesterday’s entry'), findsOneWidget);
      final saved = (await seed.all()).single;
      expect(saved.localDate.day, 5);
      expect(saved.hasTime, isFalse);
      // The card shows just the day.
      await tapText(tester, 'Done');
      expect(find.bySemanticsLabel('Yesterday'), findsOneWidget);
    });

    appTest('a phone on a 24-hour clock gets a 24-hour wheel', (tester) async {
      await pumpMorrowApp(tester, [
        StartupReady(db, createdNew: false),
      ], use24HourClock: true);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'When');
      // Hour and minute only: no am/pm wheel.
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      expect(find.text('am'), findsNothing);
      expect(find.text('13'), findsWidgets);
    });

    appTest('a time can be added back for a past day, and removed for today', (
      tester,
    ) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'When');
      await tapText(tester, 'Yesterday');
      await tapText(tester, 'Record a time');
      expect(find.byType(CupertinoPicker), findsNWidgets(3));
      await tapText(tester, 'Done');
      expect(find.text('Yesterday · 1:41 pm'), findsOneWidget);

      await tapText(tester, 'When');
      await tapText(tester, 'Today');
      await tapText(tester, 'Record a time');
      await tapText(tester, 'Done');
      expect(find.text('Today · No time'), findsOneWidget);
      final saved = (await seed.all()).single;
      expect(saved.hasTime, isFalse);
      expect(saved.localDate.day, 6);
      await tapText(tester, 'Done');
      expect(find.bySemanticsLabel('Today'), findsOneWidget);
    });

    appTest('choosing the stored time again leaves nothing to save', (
      tester,
    ) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'When');
      await tapText(tester, 'Done');
      expect(find.text('Saved'), findsOneWidget);
    });
  });

  group('leaving straight after typing', () {
    appTest('Close saves the note first; there is no discard prompt', (
      tester,
    ) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Draft');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Your journal'), findsOneWidget);
      expect((await seed.all()).single.comment, 'Draft');
    });

    appTest('the system back gesture also saves first', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Draft');
      await tester.pump(); // a frame passes between typing and going back
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Your journal'), findsOneWidget);
      expect((await seed.all()).single.comment, 'Draft');
    });

    appTest('going to the background saves the note at once', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Draft');
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect((await seed.all()).single.comment, 'Draft');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    });
  });

  group('the entry page for an existing entry', () {
    appTest('shows the entry, with Saved and Delete (4.7)', (tester) async {
      await seedAt(4, 18, 20, note: 'Quiet evening');
      await pumpReady(tester);
      await tapText(tester, 'Wednesday · 6:20 pm');
      expect(find.text('Wednesday’s entry'), findsOneWidget);
      expect(find.text('Wednesday · 6:20 pm'), findsOneWidget);
      expect(find.text('Quiet evening'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Delete this entry'), findsOneWidget);
      // No Undo, and no separate view or edit screen.
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Entry details'), findsNothing);
    });

    appTest('an entry older than a week is titled "Entry"', (tester) async {
      await seed.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 10, 28, 9),
          originalUtcOffsetMinutes: 0,
          comment: 'Last week',
        ),
      );
      await pumpReady(tester);
      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Wednesday 28 Oct · 9:00 am');
      expect(find.text('Entry'), findsOneWidget);
      expect(find.text('Wednesday 28 Oct · 9:00 am'), findsOneWidget);
    });

    appTest('changing the note keeps the entry (4.8)', (tester) async {
      final original = await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await pumpReady(tester);
      await tapText(tester, 'Today · 1:35 pm');
      await tester.enterText(noteField(), 'Felt fine after a late lunch');
      await tapText(tester, 'Done');
      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Felt fine after a late lunch'), findsOneWidget);
      final all = await seed.all();
      expect(all.single.id, original.id);
      expect(all.single.uid, original.uid);
    });

    appTest('delete asks, then removes the entry (4.9, 4.10)', (tester) async {
      await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await pumpReady(tester);
      await tapText(tester, 'Today · 1:35 pm');
      await tapText(tester, 'Delete this entry');
      expect(find.text('Delete this entry?'), findsOneWidget);

      await tapText(tester, 'Keep entry');
      expect(await seed.all(), hasLength(1));

      await tapText(tester, 'Delete this entry');
      await tapText(tester, 'Delete entry');
      expect(find.text('Entry deleted'), findsOneWidget);
      expect(find.text('Today’s entry'), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(await seed.all(), isEmpty);
    });
  });

  group('history', () {
    Future<void> openHistory(WidgetTester tester) async {
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
    }

    appTest('empty history (4.6)', (tester) async {
      await pumpReady(tester);
      await openHistory(tester);
      expect(find.text('Your history'), findsOneWidget);
      expect(
        find.text('Entries you add will appear here, newest first.'),
        findsOneWidget,
      );
    });

    appTest('groups by day, newest first (4.2)', (tester) async {
      await seedAt(4, 8, 35);
      await seedAt(4, 18, 20, note: 'Quiet evening');
      await seedAt(5, 8, 25);
      await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await pumpReady(tester);
      await openHistory(tester);
      expect(find.text('24 Oct – 6 Nov'), findsOneWidget);
      expect(find.textContaining('Most recent first'), findsNothing);
      expect(find.text('THE JOURNAL'), findsNothing);
      final headings = [
        'Today · 6 Nov',
        'Yesterday · 5 Nov',
        'Wednesday · 4 Nov',
      ];
      for (final h in headings) {
        expect(find.text(h), findsOneWidget);
      }
      final ys = [for (final h in headings) tester.getTopLeft(find.text(h)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    appTest('search finds notes and says when nothing matches (4.5)', (
      tester,
    ) async {
      await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await seedAt(5, 8, 25, note: 'Quiet morning');
      await seedAt(4, 8, 35);
      await pumpReady(tester);
      await openHistory(tester);

      await tester.enterText(find.byType(TextField), 'LUNCH');
      await tester.pumpAndSettle();
      expect(find.text('Quiet morning'), findsNothing);
      expect(find.text('0 entries'), findsNothing);
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expect(find.text('Quiet morning'), findsNothing);

      await tester.enterText(find.byType(TextField), 'tea');
      await tester.pumpAndSettle();
      expect(find.text('No matching entries'), findsOneWidget);
      await tapText(tester, 'Clear search');
      expect(find.text('Quiet morning'), findsOneWidget);
    });

    appTest('filter and show earlier entries (4.4)', (tester) async {
      await seedAt(6, 13, 35);
      await seed.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 10, 15, 9),
          originalUtcOffsetMinutes: 60,
          comment: 'Three weeks ago',
        ),
      );
      await pumpReady(tester);
      await openHistory(tester);
      expect(find.text('Three weeks ago'), findsNothing);
      expect(find.text('Show earlier entries'), findsOneWidget);

      await tapText(tester, 'Show earlier entries');
      expect(find.text('Three weeks ago'), findsOneWidget);
      expect(find.text('10 Oct – 6 Nov'), findsOneWidget);
      expect(find.text('Show earlier entries'), findsNothing);

      await tester.tap(find.bySemanticsLabel(RegExp('^Date range:')));
      await tester.pumpAndSettle();
      expect(find.text('Filter entries'), findsOneWidget);
      await tapText(tester, 'Clear filters');
      expect(find.text('24 Oct – 6 Nov'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^Date range:')));
      await tester.pumpAndSettle();
      await tapText(tester, 'All time');
      await tapText(tester, 'Apply');
      expect(find.text('Three weeks ago'), findsOneWidget);
    });

    appTest('opening an entry from History and coming back', (tester) async {
      await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await pumpReady(tester);
      await openHistory(tester);
      await tapText(tester, 'Felt fine after lunch');
      expect(find.text('Today’s entry'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Your history'), findsOneWidget);
    });

    appTest('Add an entry on an empty History adds and opens it', (
      tester,
    ) async {
      await pumpReady(tester);
      await openHistory(tester);
      await tapText(tester, 'Add an entry');
      expect(find.text('Today’s entry'), findsOneWidget);
      expect(await seed.all(), hasLength(1));
    });
  });

  group('large text', () {
    for (final scale in textScales) {
      appTest('journal, entry page and history at ${(scale * 100).toInt()}%', (
        tester,
      ) async {
        await seedAt(6, 13, 35, note: 'Felt fine after lunch');
        await seedAt(4, 18, 20, note: 'Quiet evening');
        await pumpReady(tester, textScale: scale, size: smallPhone);
        expect(tester.takeException(), isNull, reason: 'journal');
        await tapText(tester, 'Add an entry');
        expect(tester.takeException(), isNull, reason: 'new entry');
        await reveal(tester, noteField());
        await tester.enterText(noteField(), 'Synthetic note');
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'saving');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'history');
        await tapText(tester, 'Felt fine after lunch');
        expect(tester.takeException(), isNull, reason: 'entry page');
      });
    }
  });

  group('failed saves', () {
    /// The real router inside an unlocked scope, with [repo] in place of the
    /// journal repository.
    Future<void> pumpWithRepository(
      WidgetTester tester,
      EntryRepository repo,
    ) async {
      useScreenSize(tester, figmaPhone);
      final router = buildAppRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWithValue(figmaNow)],
          child: UnlockedScope(
            database: db,
            child: ProviderScope(
              overrides: [entryRepositoryProvider.overrideWithValue(repo)],
              child: MaterialApp.router(
                theme: buildMorrowTheme(),
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    appTest('a failed one-tap add saves nothing and says so (2.10)', (
      tester,
    ) async {
      await pumpWithRepository(
        tester,
        FlakyRepository(db, figmaNow, failCreates: 1),
      );
      await tapText(tester, 'Add an entry');
      expect(find.text('Couldn’t add an entry'), findsOneWidget);
      expect(find.text('Nothing was saved. Try again.'), findsOneWidget);
      expect(find.text('Today’s entry'), findsNothing);
      expect(await seed.all(), isEmpty);

      await tapText(tester, 'Add an entry');
      expect(find.text('Today’s entry'), findsOneWidget);
      expect(await seed.all(), hasLength(1));
    });

    appTest('a failed Save keeps the changes and can be retried (2.6)', (
      tester,
    ) async {
      final flaky = FlakyRepository(db, figmaNow, failUpdates: 1);
      await pumpWithRepository(tester, flaky);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Felt fine after lunch');
      await tapText(tester, 'Done');
      // The page stays, with the note, until it is saved.
      expect(find.text('Couldn’t save your changes'), findsOneWidget);
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expect(find.text('Not saved yet'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Changes saved'), findsNothing);
      expect((await seed.all()).single.comment, isNull);

      await tapText(tester, 'Try again');
      expect(flaky.updates, 2);
      expect(find.text('Saved'), findsOneWidget);
      expect((await seed.all()).single.comment, 'Felt fine after lunch');
      await tapText(tester, 'Done');
      expect(find.text('Your journal'), findsOneWidget);
    });
  });
}
