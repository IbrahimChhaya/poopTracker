import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poop_tracker/app/app.dart';
import 'package:poop_tracker/app/providers.dart';

import '../test/support/fake_diagnostics.dart';
import '../test/support/fake_key_store.dart';
import '../test/support/fake_lock.dart';
import '../test/support/fake_reminders.dart';

/// Add (one tap), change, undo and delete entries on a real device, through the real app and
/// the real encrypted database.
///
/// The database lives in a temporary folder and the key in an in-memory key
/// store, so the device's own journal and its stored key are never touched.
/// (Using the real key store with a different database file would look like
/// a reinstall and discard the real key.)
///
/// `flutter test integration_test/journal_flow_test.dart -d DEVICE`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one-tap add, change, undo and delete', (tester) async {
    // Type through Flutter's test keyboard. With the phone's real keyboard
    // also attached, it can send back its own (stale) text when focus moves
    // and overwrite what the test entered.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);

    final dir = await Directory.systemTemp.createTemp('morrow_it_');
    addTearDown(() => dir.delete(recursive: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyStoreProvider.overrideWithValue(FakeKeyStore()),
          // Never read or change the phone's real app-lock setting.
          lockSettingsProvider.overrideWithValue(FakeLockSettings()),
          welcomeStoreProvider.overrideWithValue(FakeWelcomeStore()),
          // Never schedule or cancel the phone's real reminder.
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          // Never write test events into the phone's real diagnostics log.
          diagnosticLogProvider.overrideWithValue(MemoryDiagnosticLog()),
          databaseFileProvider.overrideWithValue(
            () async => File('${dir.path}/journal.db'),
          ),
        ],
        child: const MorrowApp(),
      ),
    );
    // Database work runs on a background isolate in real time, which
    // pumpAndSettle does not wait for.
    Future<void> pumpUntil(Finder finder, {bool gone = false}) async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isEmpty == gone) return;
      }
      final seen = [
        for (final t in [
          'Couldn’t add an entry',
          'Couldn’t save your changes',
          'Today’s entry',
          'Saved',
          'Done',
          'Saving…',
          'Synthetic test note',
        ])
          if (find.text(t).evaluate().isNotEmpty) t,
      ];
      fail(
        'Timed out waiting for $finder${gone ? ' to disappear' : ''}. '
        'On screen: $seen',
      );
    }

    await pumpUntil(find.text('Nothing here yet'));

    Future<void> tap(String text) async {
      await pumpUntil(find.text(text));
      await tester.ensureVisible(find.text(text).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    // One tap adds the entry and opens it, already saved.
    await tap('Add an entry');
    await pumpUntil(find.text('Today’s entry'));
    expect(find.text('Added to today'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    // A note saves by itself; Done returns to the journal.
    await tester.enterText(find.byType(TextField), 'Synthetic test note');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Synthetic test note',
    );
    await tap('Done');
    await pumpUntil(find.text('Synthetic test note'));
    expect(find.text('1 entry'), findsWidgets);

    // Change it on the same page.
    await tap('Synthetic test note');
    await pumpUntil(find.text('Delete this entry'));
    await tester.enterText(find.byType(TextField), 'Synthetic note, edited');
    await tester.pump();
    await tap('Done');
    await pumpUntil(find.text('Changes saved'));
    await pumpUntil(find.text('Synthetic note, edited'));

    // Undo a second, just-added entry.
    await tap('Add an entry');
    await pumpUntil(find.text('Undo'));
    await tap('Undo');
    await pumpUntil(find.text('Today’s entry'), gone: true);
    expect(find.text('1 entry'), findsWidgets);

    // Delete the first.
    await tap('Synthetic note, edited');
    await tap('Delete this entry');
    await tap('Delete entry');
    await pumpUntil(find.text('Today’s entry'), gone: true);
    await pumpUntil(find.text('Nothing here yet'));

    // Leave the app so the database closes before the folder is deleted.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
