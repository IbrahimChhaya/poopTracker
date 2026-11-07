import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/bootstrap.dart';
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
    final result = await ref.read(databaseBootstrapProvider).start();
    if (result is StartupReady) {
      ref.onDispose(() => unawaited(result.database.close()));
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
      return;
    }
    ref.invalidateSelf();
  }
}

final journalSessionProvider =
    AsyncNotifierProvider.autoDispose<JournalSessionController, StartupResult>(
      JournalSessionController.new,
      retry: (_, _) => null,
    );
