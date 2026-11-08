import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/settings/data/settings_repository.dart';

import '../../fixtures/figma_trends_fixture.dart';
import '../../support/app_harness.dart';
import '../../support/fake_clock.dart';
import '../../support/harness.dart';

final Finder _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

/// Wording Trends must never use: no scores, judgements or advice.
final RegExp _advice = RegExp(
  r'healthy|unhealthy|normal|abnormal|should|insight|score|streak|risk|'
  'doctor|improv|worse|better',
  caseSensitive: false,
);

void main() {
  late TrackingDatabase db;
  late EntryRepository repo;

  setUp(() {
    db = TrackingDatabase();
    repo = EntryRepository(db, figmaNow);
  });

  Future<void> seedFixture() async {
    for (final e in figmaTrendsFixture()) {
      await repo.create(
        EntryDraft(
          occurredAtUtc: e.occurredAtUtc,
          originalUtcOffsetMinutes: e.originalUtcOffsetMinutes,
          hasTime: e.hasTime,
          comment: e.comment,
          stoolType: e.stoolType,
          ease: e.ease,
          tags: e.tags,
        ),
      );
    }
  }

  Future<void> openTrends(
    WidgetTester tester, {
    double textScale = 1,
    bool stool = false,
  }) async {
    if (stool) await SettingsRepository(db).setShowStoolForm(true);
    await pumpMorrowApp(
      tester,
      [StartupReady(db, createdNew: false)],
      textScale: textScale,
      size: textScale > 1 ? smallPhone : figmaPhone,
    );
    await tester.tap(find.text('Trends').last);
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: _vertical);
    }
    await tester.pumpAndSettle();
  }

  appTest('not enough data (5.7)', (tester) async {
    await repo.create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 6, 9),
        originalUtcOffsetMinutes: 0,
      ),
    );
    await openTrends(tester);
    expect(find.text('Your weeks'), findsOneWidget);
    expect(find.text('Not enough entries yet'), findsOneWidget);
    expect(find.text('Entries each week'), findsNothing);
  });

  appTest('4 weeks matches Figma 5.1', (tester) async {
    await seedFixture();
    await openTrends(tester);
    expect(find.text('12 Oct – 8 Nov 2026'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('in 4 weeks'), findsOneWidget);
    // Each bar has its own label; the latest week is in progress.
    expect(find.bySemanticsLabel('Week of 12 Oct, 4 entries'), findsOneWidget);
    expect(find.bySemanticsLabel('Week of 26 Oct, 5 entries'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Week of 2 Nov, 5 entries, in progress'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Weeks run Monday to Sunday. The latest week is still in progress.',
      ),
      findsOneWidget,
    );
    // Stool form is off by default: no card and no wording.
    expect(
      find.textContaining(RegExp('stool', caseSensitive: false)),
      findsNothing,
    );
    expect(find.textContaining(_advice), findsNothing);
  });

  appTest('12 and 26 weeks match Figma 5.2 and 5.3', (tester) async {
    await seedFixture();
    await openTrends(tester);
    await tester.tap(find.text('12 weeks'));
    await tester.pumpAndSettle();
    expect(find.text('17 Aug – 8 Nov 2026'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('12 / 12'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('12 weeks, 2 of 3')),
      isSemantics(isSelected: true, isButton: true),
    );

    await tester.tap(find.text('26 weeks'));
    await tester.pumpAndSettle();
    expect(find.text('11 May – 8 Nov 2026'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('26 / 26'), findsOneWidget);
    // The range starts with the first entry: nothing earlier to show.
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
  });

  appTest('earlier ranges, never the future', (tester) async {
    await seedFixture();
    await openTrends(tester);
    IconButton later() => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(later().onPressed, isNull);

    await tester.tap(find.byTooltip('Earlier weeks'));
    await tester.pumpAndSettle();
    expect(find.text('14 Sep – 11 Oct 2026'), findsOneWidget);
    expect(later().onPressed, isNotNull);
    // A past range has no week in progress.
    expect(find.text('Weeks run Monday to Sunday.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('in progress')), findsNothing);

    await tester.tap(find.byTooltip('Later weeks'));
    await tester.pumpAndSettle();
    expect(find.text('12 Oct – 8 Nov 2026'), findsOneWidget);

    // Changing range returns to the weeks ending this week.
    await tester.tap(find.byTooltip('Earlier weeks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 weeks'));
    await tester.pumpAndSettle();
    expect(find.text('17 Aug – 8 Nov 2026'), findsOneWidget);
  });

  appTest('stool form card with the setting on (5.4)', (tester) async {
    await seedFixture();
    await openTrends(tester, stool: true);
    await reveal(tester, find.text('Numbers show entries for each type'));
    expect(find.text('Stool form'), findsOneWidget);
    expect(find.text('entries recorded a stool form'), findsOneWidget);
    expect(find.text('out of 18 in 4 weeks'), findsOneWidget);
    expect(find.bySemanticsLabel('Type 4, 10 entries'), findsOneWidget);
    expect(find.bySemanticsLabel('Type 1, 0 entries'), findsOneWidget);
    expect(find.textContaining(_advice), findsNothing);
  });

  group('large text', () {
    for (final scale in textScales) {
      appTest('Trends at ${(scale * 100).toInt()}%', (tester) async {
        await seedFixture();
        await openTrends(tester, textScale: scale, stool: true);
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('Numbers show entries for each type'));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('26 weeks'),
          -200,
          scrollable: _vertical,
        );
        await tester.tap(find.text('26 weeks'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
