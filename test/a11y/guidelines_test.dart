import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/features/settings/data/settings_repository.dart';

import '../support/app_harness.dart';
import '../support/fake_clock.dart';
import '../support/fake_lock.dart';

/// Flutter's own accessibility guidelines (M12) on every main screen:
/// 48 px tap targets (Android) and 44 pt (iOS), every tap target labelled,
/// and text contrast. Screen-reader behaviour itself still needs TalkBack
/// and VoiceOver on a device.
void main() {
  late TrackingDatabase db;

  setUp(() async {
    db = TrackingDatabase();
    final repo = EntryRepository(db, figmaNow);
    await repo.create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 6, 13, 35),
        originalUtcOffsetMinutes: 0,
        comment: 'Synthetic note',
        stoolType: 4,
        ease: Ease.easy,
        tags: {Tag.coffee},
      ),
    );
    await repo.create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 10, 28, 9),
        originalUtcOffsetMinutes: 0,
      ),
    );
    final settings = SettingsRepository(db);
    await settings.setShowStoolForm(true);
    await settings.setShowContext(true);
  });

  Future<void> checkAll(WidgetTester tester, String screen) async {
    final handle = tester.ensureSemantics();
    await expectLater(
      tester,
      meetsGuideline(androidTapTargetGuideline),
      reason: '$screen: Android tap targets',
    );
    await expectLater(
      tester,
      meetsGuideline(iOSTapTargetGuideline),
      reason: '$screen: iOS tap targets',
    );
    await expectLater(
      tester,
      meetsGuideline(labeledTapTargetGuideline),
      reason: '$screen: labelled tap targets',
    );
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '$screen: text contrast',
    );
    handle.dispose();
  }

  Future<void> go(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  appTest('journal, entry page and details sheet', (tester) async {
    await pumpMorrowApp(tester, [StartupReady(db, createdNew: false)]);
    await checkAll(tester, 'journal');
    await go(tester, 'Today · 1:35 pm');
    await checkAll(tester, 'entry page');
    await go(tester, 'Context');
    await checkAll(tester, 'details sheet');
  });

  appTest('history and trends', (tester) async {
    await pumpMorrowApp(tester, [StartupReady(db, createdNew: false)]);
    await go(tester, 'History');
    await checkAll(tester, 'history');
    await go(tester, 'Trends');
    await checkAll(tester, 'trends');
  });

  appTest('settings and its pages', (tester) async {
    await pumpMorrowApp(tester, [StartupReady(db, createdNew: false)]);
    await go(tester, 'Settings');
    await checkAll(tester, 'settings');
    for (final page in ['Weekly reminder', 'App lock', 'Data & privacy']) {
      await go(tester, page);
      await checkAll(tester, page);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  appTest('welcome and tour', (tester) async {
    await pumpMorrowApp(tester, [
      StartupReady(db, createdNew: true),
    ], welcome: FakeWelcomeStore(seen: false));
    await tester.pumpAndSettle();
    await checkAll(tester, 'welcome');
    await go(tester, 'Get started');
    for (var i = 1; i <= 4; i++) {
      await checkAll(tester, 'tour page $i');
      if (i < 4) {
        await tester.tap(find.text('Next').hitTestable());
        await tester.pumpAndSettle();
      }
    }
  });
}
