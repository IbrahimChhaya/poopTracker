import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/journal_reset.dart';
import '../database/tables.dart';
import '../diagnostics/diagnostic_log.dart';
import '../notifications/reminder_scheduler.dart';
import '../security/lock_settings.dart';

/// "Delete all data" (8.4–8.7): removes everything morrow keeps on this
/// phone, in an order that is safe to interrupt.
///
/// 1. An "erasing" marker file is written first. If the app stops part
///    way, the next start sees it and finishes the job before opening
///    anything ([resumeIfInterrupted]), so a half-deleted journal is never
///    shown or reused.
/// 2. The reminder is cancelled and a delivered one removed.
/// 3. The journal files, then its key and setup marker ([JournalReset]).
/// 4. The app-lock setting, the diagnostics log and the cache folder.
/// 5. The marker last.
///
/// The caller closes the database first. Every step can run again safely.
class DataEraser {
  DataEraser({
    required this.journalReset,
    required this.lockSettings,
    required this.diagnostics,
    required this.reminders,
    required this.markerFile,
    required this.cacheDirectory,
  });

  final JournalReset journalReset;
  final LockSettingsStore lockSettings;
  final DiagnosticLog diagnostics;
  final ReminderScheduler reminders;

  /// Where the "erasing" marker lives (app-private storage).
  final Future<File> Function() markerFile;

  /// Temporary files (for example share-sheet copies); emptied, not
  /// removed.
  final Future<Directory> Function() cacheDirectory;

  /// True when a previous deletion did not finish.
  Future<bool> interrupted() async => (await markerFile()).exists();

  /// Finishes an interrupted deletion. Throws if it still cannot finish.
  Future<bool> resumeIfInterrupted() async {
    if (!await interrupted()) return false;
    await eraseEverything();
    return true;
  }

  /// Throws [FileSystemException] or a key-store error if something could
  /// not be removed; calling again resumes.
  Future<void> eraseEverything() async {
    final marker = await markerFile();
    await marker.parent.create(recursive: true);
    await marker.writeAsString('', flush: true);

    try {
      await reminders.cancel(reminderNotificationId);
    } on Object {
      // The OS schedule holds no journal data; a reminder that cannot be
      // cancelled now finds no journal and is cancelled again on resume.
    }
    await journalReset.eraseAll();
    await lockSettings.writeEnabled(false);
    await diagnostics.eraseAll();
    final cache = await cacheDirectory();
    if (await cache.exists()) {
      await for (final entry in cache.list()) {
        await entry.delete(recursive: true);
      }
    }
    await marker.delete();
  }
}

/// The marker's place: next to the journal folder, never inside it (the
/// journal folder is deleted by [JournalReset]).
Future<File> erasingMarkerFor(Future<File> Function() databaseFile) async {
  final journalDir = (await databaseFile()).parent;
  return File(p.join(journalDir.parent.path, 'erasing'));
}
