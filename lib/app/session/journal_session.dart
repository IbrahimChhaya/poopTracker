import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/bootstrap.dart';
import '../../core/diagnostics/diagnostic_log.dart';
import '../providers.dart';

/// Opens the journal for the current unlocked session.
///
/// Only watched while the session is unlocked. When nothing watches it (the
/// app locks, or the scope is rebuilt) it is disposed, which closes the
/// database. Failures are never retried automatically: a blocked journal
/// waits for the user.
class JournalSessionController extends AsyncNotifier<StartupResult> {
  @override
  Future<StartupResult> build() async {
    final log = ref.read(diagnosticLogProvider);
    final StartupResult result;
    try {
      result = await ref.read(databaseBootstrapProvider).start();
    } on Object {
      log.record(DiagnosticEvent.startupFailed);
      rethrow;
    }
    log.record(switch (result) {
      StartupReady(createdNew: true) => DiagnosticEvent.journalCreated,
      StartupReady() => DiagnosticEvent.journalOpened,
      StartupBlocked(:final reason) => _blockedEvent(reason),
    });
    if (result case StartupReady(:final database)) {
      ref.onDispose(() => unawaited(database.close()));
    }
    return result;
  }

  /// Runs startup again, for "Try again".
  void retry() => ref.invalidateSelf();

  /// Erases the journal and its key, then starts fresh. Call only after the
  /// user has explicitly confirmed. If erasing fails, the journal stays
  /// blocked and erasing can be tried again.
  Future<void> eraseAndStartFresh() async {
    state = const AsyncLoading<StartupResult>();
    try {
      await ref.read(journalResetProvider).eraseAll();
    } on Object {
      state = const AsyncData(StartupBlocked(StartupBlockReason.eraseFailed));
      ref
          .read(diagnosticLogProvider)
          .record(DiagnosticEvent.journalBlockedErase);
      return;
    }
    ref.read(diagnosticLogProvider).record(DiagnosticEvent.journalErased);
    ref.invalidateSelf();
  }
}

DiagnosticEvent _blockedEvent(StartupBlockReason reason) => switch (reason) {
  StartupBlockReason.storageUnavailable =>
    DiagnosticEvent.journalBlockedStorage,
  StartupBlockReason.keyMissing => DiagnosticEvent.journalBlockedKeyMissing,
  StartupBlockReason.keyRejected => DiagnosticEvent.journalBlockedKeyRejected,
  StartupBlockReason.notEncrypted => DiagnosticEvent.journalBlockedNotEncrypted,
  StartupBlockReason.encryptionUnavailable =>
    DiagnosticEvent.journalBlockedNoEncryption,
  StartupBlockReason.databaseUnreadable =>
    DiagnosticEvent.journalBlockedUnreadable,
  StartupBlockReason.setupFailed => DiagnosticEvent.journalBlockedSetup,
  StartupBlockReason.eraseFailed => DiagnosticEvent.journalBlockedErase,
};

final journalSessionProvider =
    AsyncNotifierProvider.autoDispose<JournalSessionController, StartupResult>(
      JournalSessionController.new,
      retry: (_, _) => null,
    );
