import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/database/tables.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/security/device_auth.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/ui/widgets/morrow_button.dart';

import '../../support/app_harness.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_diagnostics.dart';
import '../../support/fake_lock.dart';
import '../../support/fake_reminders.dart';
import '../../support/harness.dart';

final Finder _deleteButton = find.widgetWithText(
  MorrowButton,
  'Delete all data',
);

void main() {
  late TrackingDatabase db;
  late TrackingDatabase fresh;

  setUp(() async {
    db = TrackingDatabase();
    fresh = TrackingDatabase();
    await EntryRepository(db, figmaNow).create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 10, 24, 9, 10),
        originalUtcOffsetMinutes: 60,
        comment: 'Synthetic private note',
      ),
    );
    await EntryRepository(db, figmaNow).create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 6, 13, 35),
        originalUtcOffsetMinutes: 0,
      ),
    );
  });

  Future<void> openSettingsRow(WidgetTester tester, String row) async {
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(row),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  Future<void> tick(WidgetTester tester) async {
    const label = 'I understand this can’t be undone';
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  appTest('Data & privacy (8.3) shows the local data and the data rows', (
    tester,
  ) async {
    await pumpMorrowApp(tester, [StartupReady(db, createdNew: false)]);
    await openSettingsRow(tester, 'Local data and privacy');

    expect(find.text('Private by design.'), findsOneWidget);
    expect(find.text('Works entirely offline'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('Journal started 24 October 2026'), findsOneWidget);
    expect(find.text('Export a backup'), findsOneWidget);
    expect(find.text('Restore from a backup'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Delete all data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete everything?'), findsOneWidget);

    // Cancel goes back to Data & privacy, not to Settings.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Your local data'), findsOneWidget);
  });

  appTest('nothing is deleted until "I understand" is ticked (8.4)', (
    tester,
  ) async {
    final app = await pumpMorrowApp(tester, [
      StartupReady(db, createdNew: false),
    ]);
    await openSettingsRow(tester, 'Delete all data');
    expect(
      find.textContaining('Export a backup first if you want to keep a copy.'),
      findsOneWidget,
    );

    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(app.eraser.erases, 0);
    expect(find.text('Delete everything?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(app.eraser.erases, 0);
    expect(db.closed, isFalse);
  });

  appTest('deleting closes the journal, removes everything, then Start '
      'again opens an empty one (8.6, 8.7)', (tester) async {
    final reminders = FakeReminderScheduler(allowed: true);
    await reminders.scheduleWeekly(
      id: reminderNotificationId,
      weekday: DateTime.sunday,
      hour: 18,
      minute: 0,
    );
    final log = MemoryDiagnosticLog()..record(DiagnosticEvent.lockTurnedOn);
    final app = await pumpMorrowApp(
      tester,
      [
        StartupReady(db, createdNew: false),
        StartupReady(fresh, createdNew: true),
      ],
      reminders: reminders,
      log: log,
    );
    await openSettingsRow(tester, 'Delete all data');
    await tick(tester);
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('All data deleted'), findsOneWidget);
    expect(find.text('Synthetic private note'), findsNothing);
    expect(db.closed, isTrue);
    expect(app.eraser.erases, 1);
    expect(app.reset.erases, 1);
    expect(reminders.pending, isEmpty);
    expect(log.events, isEmpty);

    await tester.tap(find.text('Start again'));
    await tester.pumpAndSettle();
    expect(app.bootstrap.starts, 2);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  appTest('with app lock on, the person confirms it is them first (8.5)', (
    tester,
  ) async {
    final auth = FakeAuthenticator();
    final settings = FakeLockSettings(enabled: true);
    final app = await pumpMorrowApp(
      tester,
      [StartupReady(db, createdNew: false)],
      authenticator: auth,
      lockSettings: settings,
    );
    await tester.pumpAndSettle();
    await openSettingsRow(tester, 'Delete all data');
    await tick(tester);

    auth.next = AuthOutcome.cancelled;
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(auth.reasons.last, 'Confirm to delete all data');
    expect(app.eraser.erases, 0);
    expect(find.text('Delete everything?'), findsOneWidget);

    auth.next = AuthOutcome.lockedOut;
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(app.eraser.erases, 0);
    expect(
      find.text('Too many tries. Wait a moment, then try again.'),
      findsOneWidget,
    );

    auth.next = AuthOutcome.success;
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(app.eraser.erases, 1);
    expect(settings.enabled, isFalse);
    expect(find.text('All data deleted'), findsOneWidget);
  });

  appTest('a failed deletion says so and Try again finishes it', (
    tester,
  ) async {
    final app = await pumpMorrowApp(tester, [
      StartupReady(db, createdNew: false),
    ], configureEraser: (e) => e.fail = true);
    await openSettingsRow(tester, 'Delete all data');
    await tick(tester);
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t finish deleting'), findsOneWidget);
    expect(find.text('Synthetic private note'), findsNothing);

    app.eraser.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('All data deleted'), findsOneWidget);
    expect(app.eraser.erases, 2);
  });

  appTest('an interrupted deletion is finished before the journal opens', (
    tester,
  ) async {
    final app = await pumpMorrowApp(tester, [
      StartupReady(fresh, createdNew: true),
    ], configureEraser: (e) => e.pendingFromLastTime = true);

    expect(app.eraser.erases, 1);
    expect(app.reset.erases, 1);
    expect(
      (app.log as MemoryDiagnosticLog).events,
      contains(DiagnosticEvent.dataDeletionResumed),
    );
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  appTest('if an interrupted deletion still cannot finish, nothing opens', (
    tester,
  ) async {
    final app = await pumpMorrowApp(
      tester,
      [StartupReady(db, createdNew: false)],
      configureEraser: (e) => e
        ..pendingFromLastTime = true
        ..fail = true,
    );
    expect(app.bootstrap.starts, 0);
    expect(find.text('Synthetic private note'), findsNothing);
    expect(find.text('Nothing here yet'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    appTest('Delete all data and the result screens fit at ${scale}x', (
      tester,
    ) async {
      await pumpMorrowApp(
        tester,
        [
          StartupReady(db, createdNew: false),
          StartupReady(fresh, createdNew: true),
        ],
        textScale: scale,
        size: scale > 1 ? smallPhone : figmaPhone,
      );
      await openSettingsRow(tester, 'Delete all data');
      expect(tester.takeException(), isNull);
      await tick(tester);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('All data deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
