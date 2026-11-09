import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poop_tracker/app/app.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/ui/widgets/morrow_navigation_bar.dart';

import '../test/support/fake_diagnostics.dart';
import '../test/support/fake_lock.dart';
import '../test/support/fake_reminders.dart';

/// Real startup on a device: platform secure storage, the encrypted journal
/// in app-private storage, the gate and the shell. On a device that already
/// has a journal from an older build, this also runs its schema migration.
///
/// `flutter test integration_test/startup_test.dart -d DEVICE`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts into the journal, and reopens it on the next start', (
    tester,
  ) async {
    // First start: creates the journal, or opens one from an earlier run.
    var container = ProviderContainer();
    final first = await container.read(databaseBootstrapProvider).start();
    expect(first, isA<StartupReady>(), reason: '$first');
    await (first as StartupReady).database.close();
    container.dispose();

    // Second start, as after a cold start: must open the same journal with
    // the stored key, never create a new one.
    container = ProviderContainer();
    final second = await container.read(databaseBootstrapProvider).start();
    expect(second, isA<StartupReady>(), reason: '$second');
    expect((second as StartupReady).createdNew, isFalse);
    await second.database.close();
    container.dispose();

    // And the real app reaches the shell through the gate. App lock is
    // checked by hand on the device (it needs a real fingerprint or PIN), so
    // the phone's own lock setting is neither read nor changed here.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lockSettingsProvider.overrideWithValue(FakeLockSettings()),
          welcomeStoreProvider.overrideWithValue(FakeWelcomeStore()),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          // Never write test events into the phone's real diagnostics log.
          diagnosticLogProvider.overrideWithValue(MemoryDiagnosticLog()),
        ],
        child: const MorrowApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MorrowNavigationBar), findsOneWidget);
    expect(find.text('Your journal'), findsOneWidget);
  });
}
