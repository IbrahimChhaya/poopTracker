import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/database/bootstrap.dart';
import '../core/database/database_location.dart';
import '../core/database/journal_reset.dart';
import '../core/diagnostics/diagnostic_log.dart';
import '../core/notifications/reminder_scheduler.dart';
import '../core/platform/file_export.dart';
import '../core/platform/privacy_shield.dart';
import '../core/security/device_auth.dart';
import '../core/security/key_store.dart';
import '../core/security/lock_settings.dart';

// Root (always available) providers. None of these hold journal data; the
// database and everything that reads it live in the unlocked scope (see
// scope.dart). Tests override these with fakes.

final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The on-device diagnostic log (event codes only, never journal data), so
/// it is available before the journal opens.
final diagnosticLogProvider = Provider<DiagnosticLog>(
  (ref) => FileDiagnosticLog(clock: ref.watch(clockProvider)),
);

/// The phone's save and share sheets.
final fileExportProvider = Provider<FileExport>(
  (ref) => const PlatformFileExport(),
);

/// The phone's biometric / passcode prompt (app lock).
final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalDeviceAuthenticator(),
);

/// Whether app lock is on, in secure storage.
final lockSettingsProvider = Provider<LockSettingsStore>(
  (ref) => SecureLockSettings(),
);

/// Hides the recent-apps thumbnail while app lock is on (Android 13+).
final privacyShieldProvider = Provider<PrivacyShield>(
  (ref) => const PlatformPrivacyShield(),
);

/// The OS scheduler for the weekly reminder. Holds no journal data.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => PluginReminderScheduler(),
);

final keyStoreProvider = Provider<KeyStore>((ref) => SecureStorageKeyStore());

final databaseFileProvider = Provider<Future<File> Function()>(
  (ref) => journalDatabaseFile,
);

final databaseOpenerProvider = Provider<EncryptedDatabaseOpener>(
  (ref) => const SqliteDatabaseOpener(),
);

final databaseBootstrapProvider = Provider<DatabaseBootstrap>(
  (ref) => DatabaseBootstrap(
    keyStore: ref.watch(keyStoreProvider),
    databaseFile: ref.watch(databaseFileProvider),
    opener: ref.watch(databaseOpenerProvider),
  ),
);

final journalResetProvider = Provider<JournalReset>(
  (ref) => JournalReset(
    keyStore: ref.watch(keyStoreProvider),
    databaseFile: ref.watch(databaseFileProvider),
  ),
);
