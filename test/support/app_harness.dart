import 'dart:collection';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/app.dart';
import 'package:poop_tracker/app/lock/lock_controller.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/core/clock.dart';
import 'package:poop_tracker/core/data/data_eraser.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/database/journal_reset.dart';
import 'package:poop_tracker/core/database/tables.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/notifications/reminder_scheduler.dart';
import 'package:poop_tracker/core/platform/file_export.dart';
import 'package:poop_tracker/core/security/device_auth.dart';
import 'package:poop_tracker/core/security/lock_settings.dart';

import 'fake_clock.dart';
import 'fake_diagnostics.dart';
import 'fake_key_store.dart';
import 'fake_lock.dart';
import 'fake_reminders.dart';
import 'harness.dart';

/// A real (in-memory, unencrypted) database that records when it is closed.
/// For widget tests only; encryption is covered by the database tests.
class TrackingDatabase extends AppDatabase {
  TrackingDatabase() : super(NativeDatabase.memory());

  bool closed = false;

  @override
  Future<void> close() {
    closed = true;
    return super.close();
  }
}

Future<File> _noFile() async => File('unused');

/// Bootstrap that returns scripted results in order (the last repeats).
class ScriptedBootstrap extends DatabaseBootstrap {
  ScriptedBootstrap(List<Object> results)
    : _results = Queue.of(results),
      super(keyStore: FakeKeyStore(), databaseFile: _noFile);

  final Queue<Object> _results;
  int starts = 0;

  @override
  Future<StartupResult> start() async {
    starts++;
    final next = _results.length > 1 ? _results.removeFirst() : _results.first;
    if (next is StartupResult) return next;
    throw next as Error;
  }
}

class FakeReset extends JournalReset {
  FakeReset() : super(keyStore: FakeKeyStore(), databaseFile: _noFile);

  int erases = 0;
  bool fail = false;

  @override
  Future<void> eraseAll() async {
    erases++;
    if (fail) throw const FileSystemException('simulated');
  }
}

/// "Delete all data" without touching files (file behaviour is covered by
/// test/core/data_eraser_test.dart): it runs the same non-file steps on the
/// harness fakes.
class FakeEraser extends DataEraser {
  FakeEraser({
    required super.journalReset,
    required super.lockSettings,
    required super.diagnostics,
    required super.reminders,
  }) : super(markerFile: () async => File('unused'), cacheDirectory: _noDir);

  static Future<Directory> _noDir() async => Directory('unused');

  /// A deletion that did not finish last time.
  bool pendingFromLastTime = false;
  bool fail = false;
  int erases = 0;

  @override
  Future<bool> interrupted() async => pendingFromLastTime;

  @override
  Future<void> eraseEverything() async {
    erases++;
    pendingFromLastTime = true;
    if (fail) throw const FileSystemException('simulated');
    await reminders.cancel(reminderNotificationId);
    await journalReset.eraseAll();
    await lockSettings.writeEnabled(false);
    await diagnostics.eraseAll();
    pendingFromLastTime = false;
  }
}

class TestLock extends LockController {
  @override
  AppLockState build() => AppLockState.unlocked;

  void set(AppLockState s) => state = s;
}

/// Like [testWidgets], but unmounts the app at the end so drift's stream
/// clean-up timers run before the test's pending-timer check.
void appTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}

/// The pumped app and its fakes.
class AppUnderTest {
  AppUnderTest(
    this.container,
    this.bootstrap,
    this.reset,
    this.log,
    this.eraser,
    this.reminders,
  );

  final ProviderContainer container;
  final ScriptedBootstrap bootstrap;
  final FakeReset reset;
  final DiagnosticLog log;
  final FakeEraser eraser;
  final ReminderScheduler reminders;

  TestLock get lock =>
      container.read(lockControllerProvider.notifier) as TestLock;
}

/// Pumps the real [MorrowApp] with scripted startup [results].
Future<AppUnderTest> pumpMorrowApp(
  WidgetTester tester,
  List<Object> results, {
  Clock? clock,
  double textScale = 1,
  Size size = figmaPhone,
  DiagnosticLog? log,
  FileExport? fileExport,
  DeviceAuthenticator? authenticator,
  LockSettingsStore? lockSettings,
  ReminderScheduler? reminders,
  void Function(FakeEraser eraser)? configureEraser,
}) async {
  final bootstrap = ScriptedBootstrap(results);
  final diagnostics = log ?? MemoryDiagnosticLog();
  final reset = FakeReset();
  final scheduler = reminders ?? FakeReminderScheduler();
  final eraser = FakeEraser(
    journalReset: reset,
    lockSettings: lockSettings ?? FakeLockSettings(),
    diagnostics: diagnostics,
    reminders: scheduler,
  );
  configureEraser?.call(eraser);
  useScreenSize(tester, size);
  final container = ProviderContainer(
    overrides: [
      databaseBootstrapProvider.overrideWithValue(bootstrap),
      journalResetProvider.overrideWithValue(reset),
      // With a lock setting, the real lock controller runs (M8 tests);
      // otherwise the session is simply unlocked.
      if (lockSettings == null)
        lockControllerProvider.overrideWith(TestLock.new)
      else
        lockSettingsProvider.overrideWithValue(lockSettings),
      deviceAuthenticatorProvider.overrideWithValue(
        authenticator ?? FakeAuthenticator(),
      ),
      privacyShieldProvider.overrideWithValue(FakePrivacyShield()),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      dataEraserProvider.overrideWithValue(eraser),
      databaseFileProvider.overrideWithValue(
        () async => File('/test-support/journal/morrow.db'),
      ),
      clockProvider.overrideWithValue(clock ?? figmaNow),
      diagnosticLogProvider.overrideWithValue(diagnostics),
      fileExportProvider.overrideWithValue(fileExport ?? FakeFileExport()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const MorrowApp(),
      ),
    ),
  );
  if (lockSettings == null) {
    await tester.pumpAndSettle();
  } else {
    // A prompt may be showing, with a busy spinner that never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return AppUnderTest(
    container,
    bootstrap,
    reset,
    diagnostics,
    eraser,
    scheduler,
  );
}
