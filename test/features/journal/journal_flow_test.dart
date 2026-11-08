import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/app/scope.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/journal/presentation/editor/entry_editor_screen.dart';
import 'package:poop_tracker/ui/theme/morrow_theme.dart';
import 'package:poop_tracker/ui/theme/morrow_typography.dart';

import '../../support/app_harness.dart';
import '../../support/fake_clock.dart';
import '../../support/harness.dart';

/// Repository whose next N creates fail, as if the disk were full.
class FlakyRepository extends EntryRepository {
  FlakyRepository(super.db, super.clock, {this.failures = 1});

  int failures;
  int attempts = 0;

  @override
  Future<Entry> create(EntryDraft draft) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw StateError('simulated write failure');
    }
    return super.create(draft);
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
      expect(find.text('See your patterns'), findsNothing);
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

    appTest('a selected past day is the date of a new entry', (tester) async {
      await pumpReady(tester);
      await tester.tap(
        find.bySemanticsLabel('Wednesday 4 November, no entries'),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Add an entry');
      // A past day starts without a time: the current time would be a guess.
      expect(find.text('Wednesday · No time'), findsOneWidget);
      // Opening on a chosen day is not an edit: closing needs no confirmation.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this entry?'), findsNothing);

      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Save entry');
      final saved = (await seed.all()).single;
      expect(saved.localDate.day, 4);
      expect(saved.hasTime, isFalse);
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

  group('adding an entry', () {
    appTest('saves with only a date and time (2.2, 2.7)', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      expect(find.text('New entry'), findsOneWidget);
      expect(find.text('Today, 1:41 pm'), findsOneWidget);
      expect(find.text('0 / 500'), findsOneWidget);

      await tapText(tester, 'Save entry');
      expect(find.text('Entry saved'), findsOneWidget);
      expect(find.text('New entry'), findsNothing);
      expect(find.text('Today · 1:41 pm'), findsOneWidget);
      // A card without a note is a single line; no "No note".
      expect(find.text('No note'), findsNothing);
      expect(find.bySemanticsLabel('Today · 1:41 pm'), findsOneWidget);
      expect(await seed.all(), hasLength(1));
    });

    appTest('saves a note and counts its characters', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Felt fine after lunch');
      await tester.pump();
      expect(find.text('21 / 500'), findsOneWidget);
      await tapText(tester, 'Save entry');
      expect(find.text('Felt fine after lunch'), findsOneWidget);
    });

    appTest('the note cannot go past 500 characters', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'a' * 600);
      await tester.pump();
      expect(find.text('500 / 500'), findsOneWidget);
      await tapText(tester, 'Save entry');
      expect((await seed.all()).single.comment, hasLength(500));
    });

    appTest('a double tap on save creates one entry', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      final save = find.text('Save entry');
      await tester.tap(save);
      await tester.tap(save, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await seed.all(), hasLength(1));
    });

    appTest('Yesterday can be chosen in the time sheet (2.3)', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'When');
      expect(find.text('When did this happen?'), findsOneWidget);
      expect(
        find.text('Only the date is required. Add a time if you know it.'),
        findsOneWidget,
      );
      // Today starts with a time; picking a past day turns it off.
      expect(find.text('Hour'), findsNothing);
      await tapText(tester, 'Yesterday');
      expect(find.byType(CupertinoPicker), findsNothing);
      await tapText(tester, 'Done');
      expect(find.text('Yesterday · No time'), findsOneWidget);
      await tapText(tester, 'Save entry');
      final saved = (await seed.all()).single;
      expect(saved.localDate.day, 5);
      expect(saved.hasTime, isFalse);
      // The card shows just the day.
      expect(find.bySemanticsLabel('Yesterday'), findsOneWidget);
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
      expect(find.text('Yesterday, 1:41 pm'), findsOneWidget);

      await tapText(tester, 'When');
      await tapText(tester, 'Today');
      await tapText(tester, 'Record a time');
      await tapText(tester, 'Done');
      expect(find.text('Today · No time'), findsOneWidget);
      await tapText(tester, 'Save entry');
      final saved = (await seed.all()).single;
      expect(saved.hasTime, isFalse);
      expect(saved.localDate.day, 6);
      // Untimed entries show just the day.
      expect(find.bySemanticsLabel('Today'), findsOneWidget);
    });
  });

  group('discarding', () {
    appTest('closing with no changes needs no confirmation', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this entry?'), findsNothing);
      expect(find.text('Your journal'), findsOneWidget);
    });

    appTest('a typed note asks first; Keep editing keeps it (2.6)', (
      tester,
    ) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Draft');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this entry?'), findsOneWidget);
      await tapText(tester, 'Keep editing');
      expect(find.text('Draft'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Discard');
      expect(find.text('Your journal'), findsOneWidget);
      expect(await seed.all(), isEmpty);
    });

    appTest('the system back gesture also asks first', (tester) async {
      await pumpReady(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(noteField(), 'Draft');
      await tester.pump(); // a frame passes between typing and going back
      // The Android back button / back gesture.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard this entry?'), findsOneWidget);
      expect(find.text('New entry'), findsOneWidget);
      await tapText(tester, 'Keep editing');
      expect(find.text('Draft'), findsOneWidget);
    });
  });

  group('detail, edit and delete', () {
    appTest('shows an entry (4.7)', (tester) async {
      await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await pumpReady(tester);
      await tapText(tester, 'Today · 1:35 pm');
      expect(find.text('Entry details'), findsOneWidget);
      expect(find.text('Friday, 6 November 2026'), findsOneWidget);
      expect(find.text('1:35 pm'), findsOneWidget);
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expect(
        find.text('Saved on this device · Not shared anywhere'),
        findsNothing,
      );
    });

    appTest('edit changes the note and keeps the entry (4.9)', (tester) async {
      final original = await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await pumpReady(tester);
      await tapText(tester, 'Today · 1:35 pm');
      await tapText(tester, 'Edit');
      expect(find.text('Edit entry'), findsOneWidget);
      await tester.enterText(noteField(), 'Felt fine after a late lunch');
      await tapText(tester, 'Save changes');
      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Felt fine after a late lunch'), findsOneWidget);
      final all = await seed.all();
      expect(all.single.id, original.id);
      expect(all.single.uid, original.uid);
    });

    appTest('Cancel on edit with changes asks first', (tester) async {
      await seedAt(6, 13, 35, note: 'Felt fine after lunch');
      await pumpReady(tester);
      await tapText(tester, 'Today · 1:35 pm');
      await tapText(tester, 'Edit');
      await tester.enterText(noteField(), 'Changed');
      await tapText(tester, 'Cancel');
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tapText(tester, 'Discard changes');
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expect((await seed.all()).single.comment, 'Felt fine after lunch');
    });

    appTest('delete asks, then removes the entry (4.10, 4.11)', (tester) async {
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
      expect(find.text('Entry details'), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(await seed.all(), isEmpty);
    });

    appTest('delete from the edit screen', (tester) async {
      await seedAt(6, 13, 35);
      await pumpReady(tester);
      await tapText(tester, 'Today · 1:35 pm');
      await tapText(tester, 'Edit');
      await tapText(tester, 'Delete this entry');
      await tapText(tester, 'Delete entry');
      expect(find.text('Edit entry'), findsNothing);
      expect(find.text('Entry details'), findsNothing);
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
      expect(find.text('Entry details'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Your history'), findsOneWidget);
    });
  });

  group('large text', () {
    for (final scale in textScales) {
      appTest('journal, editor and history at ${(scale * 100).toInt()}%', (
        tester,
      ) async {
        await seedAt(6, 13, 35, note: 'Felt fine after lunch');
        await seedAt(4, 18, 20, note: 'Quiet evening');
        await pumpReady(tester, textScale: scale, size: smallPhone);
        expect(tester.takeException(), isNull, reason: 'journal');
        await tapText(tester, 'Add an entry');
        expect(tester.takeException(), isNull, reason: 'editor');
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'history');
        await tapText(tester, 'Felt fine after lunch');
        expect(tester.takeException(), isNull, reason: 'detail');
      });
    }
  });

  group('failed save', () {
    appTest('keeps the draft and can be retried (2.5)', (tester) async {
      final flaky = FlakyRepository(db, figmaNow);
      useScreenSize(tester, figmaPhone);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/entry/new',
            builder: (_, _) => const NewEntryScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWithValue(figmaNow)],
          child: UnlockedScope(
            database: db,
            child: ProviderScope(
              overrides: [entryRepositoryProvider.overrideWithValue(flaky)],
              child: MaterialApp.router(
                theme: buildMorrowTheme(),
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(router.push('/entry/new'));
      await tester.pumpAndSettle();

      await tester.enterText(noteField(), 'Felt fine after lunch');
      await tapText(tester, 'Save entry');
      expect(find.text('Couldn’t save your entry'), findsOneWidget);
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Entry saved'), findsNothing);
      expect(await seed.all(), isEmpty);

      await tapText(tester, 'Try again');
      expect(flaky.attempts, 2);
      expect(find.text('Home'), findsOneWidget);
      expect((await seed.all()).single.comment, 'Felt fine after lunch');
    });
  });
}
