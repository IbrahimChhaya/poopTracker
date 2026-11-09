import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/journal/presentation/entry/entry_page_controller.dart';
import 'package:poop_tracker/features/settings/data/settings_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_clock.dart';
import '../../support/harness.dart';

/// Wording that must not appear in the main flows while both optional-detail
/// settings are off (the default).
final RegExp _detailWording = RegExp(
  r'stool|symptom|bristol|type \d|easy to pass|straining|context|'
  'on my period|feeling sick',
  caseSensitive: false,
);

final Finder _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

/// The details sheet's own Done (the entry page's footer also says Done).
final Finder sheetDone = find.descendant(
  of: find.byType(BottomSheet),
  matching: find.text('Done'),
);

void main() {
  late TrackingDatabase db;
  late EntryRepository repo;
  late SettingsRepository settings;

  setUp(() {
    db = TrackingDatabase();
    repo = EntryRepository(db, figmaNow);
    settings = SettingsRepository(db);
  });

  Future<Entry> seedDetailed() => repo.create(
    EntryDraft(
      occurredAtUtc: DateTime.utc(2026, 11, 6, 13, 35),
      originalUtcOffsetMinutes: 0,
      comment: 'Felt fine after lunch',
      stoolType: 5,
      ease: Ease.easy,
      tags: {Tag.afterMeal, Tag.coffee},
    ),
  );

  Future<void> configure({required bool stool, required bool context}) async {
    await settings.setShowStoolForm(stool);
    await settings.setShowContext(context);
  }

  Future<void> pump(WidgetTester tester, {double textScale = 1}) =>
      pumpMorrowApp(
        tester,
        [StartupReady(db, createdNew: false)],
        textScale: textScale,
        size: textScale > 1 ? smallPhone : figmaPhone,
      ).then((_) {});

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 200, scrollable: _vertical);
    }
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await reveal(tester, find.text(text));
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  /// Closes the details sheet by tapping the dimmed page above it.
  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, Finder f) =>
      tester.getSemantics(f).flagsCollection.isSelected.toBoolOrNull()!;

  void expectNoDetailWording(String where) {
    expect(find.textContaining(_detailWording), findsNothing, reason: where);
    expect(
      find.bySemanticsLabel(_detailWording),
      findsNothing,
      reason: '$where (screen reader)',
    );
  }

  group('default: both settings off', () {
    appTest('no stool or context wording in the main flows', (tester) async {
      await seedDetailed();
      await pump(tester);
      expectNoDetailWording('journal');

      await tapText(tester, 'Today · 1:35 pm');
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expectNoDetailWording('entry page');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tapText(tester, 'Add an entry');
      expectNoDetailWording('new entry');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('All types'), findsNothing);
      expectNoDetailWording('history');
    });

    appTest('Settings shows both switches, off', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      for (final title in ['Stool form', 'Context']) {
        final row = find.ancestor(
          of: find.text(title),
          matching: find.byType(MergeSemantics),
        );
        expect(
          tester.getSemantics(row),
          isSemantics(hasToggledState: true, isToggled: false),
          reason: title,
        );
      }
      expect(find.text('A little context'), findsNothing);
    });
  });

  group('the four combinations', () {
    const combos = [
      (stool: false, context: false, pages: <String>[]),
      (stool: true, context: false, pages: ['Stool form']),
      (stool: false, context: true, pages: ['Context']),
      (stool: true, context: true, pages: ['Context', 'Stool form']),
    ];

    for (final c in combos) {
      appTest('stool ${c.stool}, context ${c.context}', (tester) async {
        await configure(stool: c.stool, context: c.context);
        await seedDetailed();
        await pump(tester);

        // Journal card.
        expect(find.text('TYPE 5'), c.stool ? findsOneWidget : findsNothing);
        expect(
          find.textContaining('Easy to pass'),
          c.context ? findsOneWidget : findsNothing,
        );

        // Entry page: one card per enabled detail, Context first.
        await tapText(tester, 'Today · 1:35 pm');
        expect(
          find.text('Easy · After a meal, Coffee'),
          c.context ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Type 5 · Soft blobs'),
          c.stool ? findsOneWidget : findsNothing,
        );
        if (c.stool && c.context) {
          expect(
            tester.getTopLeft(find.text('Context')).dy,
            lessThan(tester.getTopLeft(find.text('Stool form')).dy),
          );
        }
        expect(find.textContaining('Optional'), findsNothing);
        expect(find.text('Felt fine after lunch'), findsOneWidget);

        if (c.pages.isNotEmpty) {
          await tapText(tester, c.pages.first);
          // A position bar only when there is more than one page.
          expect(
            find.bySemanticsLabel('Page 1 of 2'),
            c.pages.length > 1 ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Next'),
            c.pages.length > 1 ? findsOneWidget : findsNothing,
          );
          expect(sheetDone, c.pages.length > 1 ? findsNothing : findsOneWidget);
        }
      });
    }
  });

  group('the details sheet', () {
    appTest('Context, Next, Stool form, Done: all saved as chosen', (
      tester,
    ) async {
      await configure(stool: true, context: true);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      expect(find.text('Not added'), findsNWidgets(2));

      await tapText(tester, 'Context');
      expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);
      expect(find.text('Saved as you choose'), findsOneWidget);
      expect(find.text('How did it feel?'), findsOneWidget);
      expect(find.text('Anything going on?'), findsOneWidget);
      expect(find.text('Anything to note?'), findsNothing);
      expect(find.text('On my period'), findsOneWidget);
      await tapText(tester, 'Easy');
      await tapText(tester, 'Coffee');
      await tapText(tester, 'Feeling sick');
      // Stored straight away, before Next or Done.
      final afterContext = (await repo.all()).single;
      expect(afterContext.ease, Ease.easy);
      expect(afterContext.tags, {Tag.coffee, Tag.feelingSick});

      await tapText(tester, 'Next');
      expect(find.bySemanticsLabel('Page 2 of 2'), findsOneWidget);
      expect(find.text('Choose the closest match'), findsOneWidget);
      await tapText(tester, '4 · Smooth and soft');
      expect(
        selected(tester, find.bySemanticsLabel(RegExp('^Type 4, '))),
        isTrue,
      );
      await tapText(tester, 'Done');

      // Back on the entry page: the cards summarise, nothing to save.
      expect(find.text('Easy · Coffee, Feeling sick'), findsOneWidget);
      expect(find.text('Type 4 · Smooth and soft'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      final saved = (await repo.all()).single;
      expect(saved.stoolType, 4);
      expect(saved.ease, Ease.easy);
      expect(saved.tags, {Tag.coffee, Tag.feelingSick});

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('TYPE 4'), findsOneWidget);
      expect(find.text('Smooth and soft · Easy to pass'), findsOneWidget);
    });

    appTest('the Stool form card opens on its page; swipe back to Context', (
      tester,
    ) async {
      await configure(stool: true, context: true);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Stool form');
      expect(find.bySemanticsLabel('Page 2 of 2'), findsOneWidget);
      expect(sheetDone, findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 2 of 2'), findsOneWidget);
    });

    appTest('closing without Done keeps the choices', (tester) async {
      await configure(stool: true, context: false);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Stool form');
      await tapText(tester, '7 · Entirely liquid');
      await dismissSheet(tester);
      expect(find.text('Type 7 · Entirely liquid'), findsOneWidget);
      expect((await repo.all()).single.stoolType, 7);
    });

    appTest('Clear empties the page; tapping a choice again clears it', (
      tester,
    ) async {
      await configure(stool: false, context: true);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Context');
      await tapText(tester, 'Stress');
      await tapText(tester, 'On my period');
      expect(
        selected(tester, find.text('Stress')) &&
            selected(tester, find.text('On my period')),
        isTrue,
      );
      await tapText(tester, 'Stress');
      expect(selected(tester, find.text('Stress')), isFalse);

      // Ease is a single choice.
      await tapText(tester, 'Easy');
      await tapText(tester, 'Difficult');
      expect(selected(tester, find.bySemanticsLabel('Easy, 1 of 3')), isFalse);
      expect(
        selected(tester, find.bySemanticsLabel('Difficult, 3 of 3')),
        isTrue,
      );
      await tapText(tester, 'Difficult');
      expect(
        selected(tester, find.bySemanticsLabel('Difficult, 3 of 3')),
        isFalse,
      );

      await tapText(tester, 'Easy');
      await tapText(tester, 'Clear');
      final saved = (await repo.all()).single;
      expect(saved.ease, isNull);
      expect(saved.tags, isEmpty);
      await tapText(tester, 'Done');
      expect(find.text('Not added'), findsOneWidget);
    });

    appTest('details and the note both save by themselves', (tester) async {
      await configure(stool: true, context: false);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tester.enterText(find.byType(TextField), 'Synthetic note');
      await tester.pump();
      await tapText(tester, 'Stool form');
      await tapText(tester, '3 · Cracked surface');
      await tapText(tester, 'Done');
      // The type was stored when chosen; the note saves by itself too.
      expect((await repo.all()).single.stoolType, 3);
      await tester.pump(autosaveDelay);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      final saved = (await repo.all()).single;
      expect(saved.stoolType, 3);
      expect(saved.comment, 'Synthetic note');
    });
  });

  group('turning a setting off keeps the values', () {
    appTest('hidden while off, kept through an edit, back when on', (
      tester,
    ) async {
      await configure(stool: false, context: false);
      final original = await seedDetailed();
      await pump(tester);
      expect(find.text('TYPE 5'), findsNothing);

      // Change only the note while the details are hidden.
      await tapText(tester, 'Today · 1:35 pm');
      await tester.enterText(find.byType(TextField), 'Edited while hidden');
      await tester.pump();
      await tapText(tester, 'Done');
      final saved = (await repo.byId(original.id))!;
      expect(saved.comment, 'Edited while hidden');
      expect(saved.stoolType, 5);
      expect(saved.ease, Ease.easy);
      expect(saved.tags, {Tag.afterMeal, Tag.coffee});

      // Turn both on in Settings: the stored details reappear.
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Stool form');
      await tapText(tester, 'Context');
      final row = await db.select(db.appSettings).getSingle();
      expect(row.showStoolForm && row.showContext, isTrue);
      await tester.tap(find.text('Journal').last);
      await tester.pumpAndSettle();
      expect(find.text('TYPE 5'), findsOneWidget);
      expect(find.text('Soft blobs · Easy to pass'), findsOneWidget);
    });
  });

  group('history', () {
    appTest('type filter appears with stool form on, and filters', (
      tester,
    ) async {
      await configure(stool: true, context: false);
      await seedDetailed();
      await repo.create(
        EntryDraft(
          occurredAtUtc: DateTime.utc(2026, 11, 5, 8, 25),
          originalUtcOffsetMinutes: 0,
          comment: 'Type four entry',
          stoolType: 4,
        ),
      );
      await pump(tester);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('All types'), findsOneWidget);
      expect(find.text('TYPE 5'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^Stool form filter')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Type 4 · Smooth and soft');
      await tapText(tester, 'Apply');
      expect(find.text('Type 4'), findsOneWidget);
      expect(find.text('TYPE 4'), findsOneWidget);
      expect(find.text('TYPE 5'), findsNothing);
    });
  });

  group('large text', () {
    appTest('entry page and both sheet pages at 200%', (tester) async {
      await configure(stool: true, context: true);
      await seedDetailed();
      await pump(tester, textScale: 2);
      expect(tester.takeException(), isNull, reason: 'journal');
      await tapText(tester, 'Soft blobs · Easy to pass');
      expect(tester.takeException(), isNull, reason: 'entry page');
      await tapText(tester, 'Easy · After a meal, Coffee');
      expect(tester.takeException(), isNull, reason: 'context page');
      // The three choices stay in one row, even at 200%.
      final easy = tester.getRect(find.bySemanticsLabel('Easy, 1 of 3'));
      final some = tester.getRect(
        find.bySemanticsLabel('Some straining, 2 of 3'),
      );
      expect(some.top, easy.top);
      expect(some.left, greaterThan(easy.left));
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'stool form page');
    });
  });
}
