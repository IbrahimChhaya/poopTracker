import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poop_tracker/app/app.dart';
import 'package:poop_tracker/app/providers.dart';

import '../test/support/fake_diagnostics.dart';
import '../test/support/fake_key_store.dart';
import '../test/support/fake_lock.dart';
import '../test/support/fake_reminders.dart';

/// The welcome and tour on a real phone (M11.1), through the real app on a
/// new encrypted journal in a temporary folder. The phone's own journal,
/// key, app-lock setting, welcome flag, reminder and log are never touched.
///
/// `flutter test integration_test/welcome_test.dart -d DEVICE --no-uninstall`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new journal: welcome, four pages, then the journal', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('morrow_welcome_it_');
    addTearDown(() => dir.delete(recursive: true));
    final welcome = FakeWelcomeStore(seen: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyStoreProvider.overrideWithValue(FakeKeyStore()),
          lockSettingsProvider.overrideWithValue(FakeLockSettings()),
          welcomeStoreProvider.overrideWithValue(welcome),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          diagnosticLogProvider.overrideWithValue(MemoryDiagnosticLog()),
          databaseFileProvider.overrideWithValue(
            () async => File('${dir.path}/journal.db'),
          ),
        ],
        child: const MorrowApp(),
      ),
    );

    // Database work runs on a background isolate in real time.
    Future<void> pumpUntil(Finder finder) async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('Timed out waiting for $finder');
    }

    Future<void> tap(String label) async {
      final f = find.text(label).hitTestable();
      await pumpUntil(f);
      await tester.tap(f.first);
      await tester.pump(const Duration(milliseconds: 600));
    }

    await pumpUntil(find.text('Your quiet journal.'));
    await tap('Get started');
    await pumpUntil(find.text('One tap, and it’s logged.').hitTestable());
    await tap('Next');
    await pumpUntil(find.text('Add more, only if you want.').hitTestable());
    await tap('Stool form');
    await pumpUntil(find.text('Type 4').hitTestable());
    await tap('Next');
    await pumpUntil(find.text('See your trends.').hitTestable());
    await tap('Next');
    await pumpUntil(find.text('Private by design.').hitTestable());
    await tap('Start your journal');
    await pumpUntil(find.text('Your journal'));
    expect(find.text('Start with one tap'), findsOneWidget);
    expect(welcome.seen, isTrue);
  });
}
