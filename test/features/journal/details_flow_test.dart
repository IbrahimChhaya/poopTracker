import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/settings/data/settings_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_clock.dart';
import '../../support/harness.dart';

/// Wording that must not appear in the main flows while both optional-detail
/// settings are off (the default).
final RegExp _detailWording = RegExp(
  r'stool|symptom|bristol|type \d|easy to pass|straining|little context|'
  'on my period|feeling sick',
  caseSensitive: false,
);

final Finder _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

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

      await tapText(tester, 'Add an entry');
      expect(find.text('Optional details'), findsNothing);
      expectNoDetailWording('new entry');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tapText(tester, 'Today · 1:35 pm');
      expect(find.text('Felt fine after lunch'), findsOneWidget);
      expectNoDetailWording('entry detail');
      await tapText(tester, 'Edit');
      expectNoDetailWording('edit entry');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
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
      for (final title in ['Stool form', 'A little context']) {
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
    });
  });

  group('the four combinations', () {
    const combos = [
      (stool: false, context: false, steps: <String>[]),
      (stool: true, context: false, steps: ['Stool form']),
      (stool: false, context: true, steps: ['A little context']),
      (stool: true, context: true, steps: ['Stool form', 'A little context']),
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

        // Editor: one row per enabled step, with an adapting step count.
        await tapText(tester, 'Add an entry');
        expect(
          find.text('Optional details'),
          c.steps.isEmpty ? findsNothing : findsOneWidget,
        );
        for (final row in ['Stool form', 'A little context']) {
          expect(
            find.text(row),
            c.steps.contains(row) ? findsOneWidget : findsNothing,
          );
        }
        if (c.steps.isNotEmpty) {
          await tapText(tester, c.steps.first);
          // The progress bar has one segment per enabled step.
          expect(
            find.bySemanticsLabel('Step 1 of ${c.steps.length}'),
            findsOneWidget,
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        // Entry detail.
        await tapText(tester, 'Today · 1:35 pm');
        expect(
          find.text('Type 5 · Soft blobs'),
          c.stool ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Ease of passage'),
          c.context ? findsOneWidget : findsNothing,
        );
        expect(find.text('Coffee'), c.context ? findsOneWidget : findsNothing);
        expect(find.textContaining('Optional'), findsNothing);
        expect(find.text('Felt fine after lunch'), findsOneWidget);
      });
    }
  });

  group('adding details', () {
    appTest('both steps, then save (3.1–3.4)', (tester) async {
      await configure(stool: true, context: true);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      expect(find.text('Not set'), findsNWidgets(2));

      await tapText(tester, 'Stool form');
      expect(find.bySemanticsLabel('Step 1 of 2'), findsOneWidget);
      expect(find.text('What was the form?'), findsOneWidget);
      expect(find.text('Choose the closest match'), findsOneWidget);
      expect(find.text('Skip and save entry'), findsNothing);
      await tapText(tester, '4 · Smooth and soft');
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Type 4, '))),
        isSemantics(isSelected: true),
      );
      await tapText(tester, 'Continue');

      expect(find.bySemanticsLabel('Step 2 of 2'), findsOneWidget);
      expect(
        find.textContaining(RegExp('optional', caseSensitive: false)),
        findsNothing,
      );
      expect(find.text('Any symptoms?'), findsNothing);
      expect(find.text('Exercise'), findsNothing);
      expect(find.text('On my period'), findsOneWidget);
      expect(find.text('Feeling sick'), findsOneWidget);
      expect(find.text('Type 4 · Smooth and soft'), findsOneWidget);
      await tapText(tester, 'Easy');
      await tapText(tester, 'Coffee');
      await tapText(tester, 'Feeling sick');
      await tester.enterText(find.byType(TextField), 'Synthetic note');
      await tester.pump();
      await tapText(tester, 'Save entry');

      expect(find.text('Entry saved'), findsOneWidget);
      expect(find.text('What was the form?'), findsNothing);
      expect(find.text('New entry'), findsNothing);
      final saved = (await repo.all()).single;
      expect(saved.stoolType, 4);
      expect(saved.ease, Ease.easy);
      expect(saved.tags, {Tag.coffee, Tag.feelingSick});
      expect(saved.comment, 'Synthetic note');

      expect(find.text('TYPE 4'), findsOneWidget);
      expect(find.text('Smooth and soft · Easy to pass'), findsOneWidget);
    });

    appTest('one step only: one progress segment, Done returns to editor', (
      tester,
    ) async {
      await configure(stool: true, context: false);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Stool form');
      expect(find.bySemanticsLabel('Step 1 of 1'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await tapText(tester, '7 · Entirely liquid');
      await tapText(tester, 'Done');
      expect(find.text('Type 7 · Entirely liquid'), findsOneWidget);
      await tapText(tester, 'Save entry');
      expect((await repo.all()).single.stoolType, 7);
    });

    appTest('Skip on the context step returns to the editor', (tester) async {
      await configure(stool: false, context: true);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'A little context');
      await tapText(tester, 'Skip');
      expect(find.text('Optional details'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });

    appTest('every step can be skipped; saving with only a time works', (
      tester,
    ) async {
      await configure(stool: true, context: true);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Stool form');
      await tapText(tester, 'Skip');
      expect(find.text('A little context'), findsWidgets);
      await tapText(tester, 'Save entry');
      final saved = (await repo.all()).single;
      expect(saved.stoolType, isNull);
      expect(saved.ease, isNull);
      expect(saved.tags, isEmpty);
    });

    appTest('tapping a chosen chip again clears it', (tester) async {
      await configure(stool: false, context: true);
      await pump(tester);
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'A little context');
      bool selected(String label) => tester
          .getSemantics(find.text(label))
          .flagsCollection
          .isSelected
          .toBoolOrNull()!;
      await tapText(tester, 'Stress');
      await tapText(tester, 'On my period');
      expect(selected('Stress') && selected('On my period'), isTrue);
      await tapText(tester, 'Stress');
      expect(selected('Stress'), isFalse);
      await tapText(tester, 'Easy');
      await tapText(tester, 'Difficult');
      expect(selected('Easy'), isFalse, reason: 'ease is single choice');
      expect(selected('Difficult'), isTrue);
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

      // Edit only the note while the details are hidden.
      await tapText(tester, 'Today · 1:35 pm');
      await tapText(tester, 'Edit');
      await tester.enterText(find.byType(TextField), 'Edited while hidden');
      await tester.pump();
      await tapText(tester, 'Save changes');
      final saved = (await repo.byId(original.id))!;
      expect(saved.comment, 'Edited while hidden');
      expect(saved.stoolType, 5);
      expect(saved.ease, Ease.easy);
      expect(saved.tags, {Tag.afterMeal, Tag.coffee});
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Turn both on in Settings: the stored details reappear.
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tapText(tester, 'Stool form');
      await tapText(tester, 'A little context');
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
    appTest('steps and detail at 200%', (tester) async {
      await configure(stool: true, context: true);
      await seedDetailed();
      await pump(tester, textScale: 2);
      expect(tester.takeException(), isNull, reason: '');
      await tapText(tester, 'Add an entry');
      await tapText(tester, 'Stool form');
      expect(tester.takeException(), isNull, reason: '');
      await tapText(tester, 'Continue');
      expect(tester.takeException(), isNull, reason: '');
      // At 200% the headers have scrolled away; use the system back action.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapText(tester, 'Soft blobs · Easy to pass');
      expect(tester.takeException(), isNull, reason: '');
    });
  });
}
