import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poop_tracker/app/app.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/app/scope.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/journal/presentation/journal_screen.dart';

import '../test/fixtures/figma_trends_fixture.dart';
import '../test/support/fake_clock.dart';
import '../test/support/fake_key_store.dart';

/// Trends on a real device with the synthetic Figma journal, through the
/// real app and an encrypted database in a temporary folder (the device's
/// own journal is never touched). Set `MORROW_HOLD=1` to keep each screen up
/// for a few seconds so it can be looked at.
///
/// `flutter test integration_test/trends_test.dart -d DEVICE`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const hold = bool.fromEnvironment('MORROW_HOLD');

  testWidgets('Trends with the Figma journal', (tester) async {
    final dir = await Directory.systemTemp.createTemp('morrow_trends_');
    addTearDown(() => dir.delete(recursive: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyStoreProvider.overrideWithValue(FakeKeyStore()),
          databaseFileProvider.overrideWithValue(
            () async => File('${dir.path}/journal.db'),
          ),
          clockProvider.overrideWithValue(figmaNow),
        ],
        child: const MorrowApp(),
      ),
    );

    Future<void> pumpUntil(Finder f) async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
        if (f.evaluate().isNotEmpty) return;
      }
      fail('Timed out waiting for $f');
    }

    Future<void> look() async {
      if (!hold) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 6)),
      );
    }

    await pumpUntil(find.byType(JournalScreen));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(JournalScreen)),
    );
    final repo = container.read(entryRepositoryProvider);
    await tester.runAsync(() async {
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
      await container.read(settingsRepositoryProvider).setShowStoolForm(true);
    });

    await tester.tap(find.text('Trends').last);
    await pumpUntil(find.text('12 Oct – 8 Nov 2026'));
    await tester.pumpAndSettle();
    expect(find.text('4.5'), findsOneWidget);
    await look();

    await tester.tap(find.text('26 weeks'));
    await pumpUntil(find.text('11 May – 8 Nov 2026'));
    await tester.pumpAndSettle();
    expect(find.text('120'), findsWidgets);
    await look();

    await tester.scrollUntilVisible(
      find.text('Numbers show entries for each type'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    await look();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
