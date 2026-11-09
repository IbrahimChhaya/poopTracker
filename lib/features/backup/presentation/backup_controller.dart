import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lock/lock_controller.dart';
import '../../../app/providers.dart';
import '../../../app/scope.dart';
import '../../../core/backup/backup_file.dart';
import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/time/local_date.dart';
import '../../journal/data/entry_repository.dart';
import '../../journal/domain/backup_payload.dart';

/// "Export a backup" (9.1–9.4).
sealed class ExportState {
  const ExportState();
}

/// 9.1. [failed] after an error; cancelling the save sheet shows nothing.
final class ExportReady extends ExportState {
  const ExportReady({this.failed = false});

  final bool failed;
}

/// 9.2 "Creating your backup…".
final class ExportWorking extends ExportState {
  const ExportWorking(this.entryCount);

  final int entryCount;
}

/// 9.4 "Backup saved".
final class ExportSaved extends ExportState {
  const ExportSaved({required this.fileName, required this.entryCount});

  final String fileName;
  final int entryCount;
}

/// `morrow-backup-2026-11-08.morrow`, from the local date.
String backupFileName(LocalDate day) =>
    'morrow-backup-${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}.morrow';

/// Builds the encrypted file in memory and hands it to the phone's save
/// sheet. Only the encrypted bytes ever leave this class; morrow keeps no
/// copy.
class ExportController extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportReady();

  EntryRepository get _repo => ref.read(entryRepositoryProvider);
  DiagnosticLog get _log => ref.read(diagnosticLogProvider);

  /// [passphrase] is already checked by the screen (length, match).
  Future<void> create(String passphrase) async {
    if (state is ExportWorking) return;
    state = const ExportWorking(0);
    try {
      final entries = await _repo.all();
      if (!ref.mounted) return;
      state = ExportWorking(entries.length);
      final clock = ref.read(clockProvider);
      final now = clock.nowUtc();
      final payload = encodeBackupPayload(entries, exportedAtUtc: now);
      final file = await sealBackup(
        payload,
        passphrase,
        deriveKey: ref.read(backupKeyDeriverProvider),
      );
      // Best effort: the plain JSON is not kept around.
      payload.fillRange(0, payload.length, 0);
      if (!ref.mounted) return;
      final name = backupFileName(
        LocalDate.fromUtc(now, offsetMinutes: clock.currentUtcOffsetMinutes()),
      );
      final saved = await ref
          .read(lockControllerProvider.notifier)
          .whileSystemSheet(
            () => ref
                .read(fileExportProvider)
                .save(
                  fileName: name,
                  bytes: file,
                  mimeType: 'application/octet-stream',
                ),
          );
      if (!ref.mounted) return;
      if (saved) {
        _log.record(DiagnosticEvent.backupSaved);
        state = ExportSaved(fileName: name, entryCount: entries.length);
      } else {
        state = const ExportReady();
      }
    } on Object {
      _log.record(DiagnosticEvent.backupFailed);
      if (ref.mounted) state = const ExportReady(failed: true);
    }
  }
}

final exportControllerProvider =
    NotifierProvider.autoDispose<ExportController, ExportState>(
      ExportController.new,
      dependencies: [entryRepositoryProvider],
    );

/// "Restore from a backup" (9.5–9.10).
sealed class RestoreState {
  const RestoreState();
}

/// 9.5. [problem] after picking a file that can't be restored:
/// [BackupProblem.notBackup] or [BackupProblem.newerVersion].
final class RestoreChoose extends RestoreState {
  const RestoreChoose({this.problem});

  final BackupProblem? problem;
}

/// Why the last attempt changed nothing (9.10).
enum RestoreError { cannotOpen, newerVersion, failed }

/// 9.7, or 9.10 when [error] is set.
final class RestorePassphrase extends RestoreState {
  const RestorePassphrase({
    required this.fileName,
    required this.sizeBytes,
    this.error,
  });

  final String fileName;
  final int sizeBytes;
  final RestoreError? error;
}

/// 9.8 "Restoring your entries…".
final class RestoreWorking extends RestoreState {
  const RestoreWorking();
}

/// 9.9 "Restore complete".
final class RestoreDone extends RestoreState {
  const RestoreDone({required this.added, required this.skipped});

  final int added;
  final int skipped;
}

/// Picks a file, opens it with the passphrase, validates every entry, then
/// adds the new ones in one transaction. Nothing is replaced or deleted.
class RestoreController extends Notifier<RestoreState> {
  @override
  RestoreState build() => const RestoreChoose();

  /// The picked file, still encrypted. Gone when the screen closes or the
  /// app locks.
  List<int>? _file;

  DiagnosticLog get _log => ref.read(diagnosticLogProvider);

  Future<void> choose() async {
    try {
      final picked = await ref
          .read(lockControllerProvider.notifier)
          .whileSystemSheet(() => ref.read(fileImportProvider).pickBackup());
      if (!ref.mounted || picked == null) return;
      BackupHeader.parse(picked.bytes);
      _file = picked.bytes;
      state = RestorePassphrase(
        fileName: picked.name,
        sizeBytes: picked.bytes.length,
      );
    } on BackupException catch (e) {
      _log.record(DiagnosticEvent.restoreRefused);
      if (!ref.mounted) return;
      state = RestoreChoose(problem: e.problem);
    } on Object {
      _log.record(DiagnosticEvent.restoreFailed);
      if (ref.mounted) {
        state = const RestoreChoose(problem: BackupProblem.notBackup);
      }
    }
  }

  Future<void> restore(String passphrase) async {
    final current = state;
    final file = _file;
    if (current is! RestorePassphrase || file == null) return;
    state = const RestoreWorking();
    RestoreError error;
    try {
      final payload = await openBackup(
        file,
        passphrase,
        deriveKey: ref.read(backupKeyDeriverProvider),
      );
      final entries = decodeBackupPayload(payload);
      payload.fillRange(0, payload.length, 0);
      if (!ref.mounted) return;
      final result = await ref.read(entryRepositoryProvider).restore(entries);
      _log.record(DiagnosticEvent.restoreDone);
      _file = null;
      if (ref.mounted) {
        state = RestoreDone(added: result.added, skipped: result.skipped);
      }
      return;
    } on BackupException catch (e) {
      _log.record(DiagnosticEvent.restoreRefused);
      error = e.problem == BackupProblem.newerVersion
          ? RestoreError.newerVersion
          : RestoreError.cannotOpen;
    } on Object {
      _log.record(DiagnosticEvent.restoreFailed);
      error = RestoreError.failed;
    }
    if (ref.mounted) {
      state = RestorePassphrase(
        fileName: current.fileName,
        sizeBytes: current.sizeBytes,
        error: error,
      );
    }
  }

  /// Back to 9.5 to pick another file.
  void chooseAnother() {
    _file = null;
    state = const RestoreChoose();
  }
}

final restoreControllerProvider =
    NotifierProvider.autoDispose<RestoreController, RestoreState>(
      RestoreController.new,
      dependencies: [entryRepositoryProvider],
    );
