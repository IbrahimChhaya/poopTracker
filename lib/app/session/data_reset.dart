import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../lock/lock_controller.dart';
import '../providers.dart';

/// Where "Delete all data" is (8.6, 8.7). While not [idle], the app shows
/// only the deleting / deleted / failed screens: the unlocked scope, the
/// router and the database are gone.
enum ResetPhase { idle, deleting, deleted, failed }

class DataResetController extends Notifier<ResetPhase> {
  @override
  ResetPhase build() => ResetPhase.idle;

  /// Deletes everything. [database] is the open journal: it is closed
  /// first, then the files go. Never call without the user's explicit,
  /// confirmed request (and authentication when app lock is on).
  Future<void> deleteEverything(AppDatabase? database) async {
    if (state == ResetPhase.deleting) return;
    state = ResetPhase.deleting;
    try {
      await database?.close();
    } on Object {
      // Already closed.
    }
    try {
      await ref.read(dataEraserProvider).eraseEverything();
    } on Object {
      state = ResetPhase.failed;
      return;
    }
    ref.read(lockControllerProvider.notifier).forgetAfterErase();
    state = ResetPhase.deleted;
  }

  /// "Try again" after a failure: the database is already closed.
  Future<void> retry() => deleteEverything(null);

  /// "Start again" (8.7): back to a fresh, empty journal.
  void startAgain() => state = ResetPhase.idle;
}

final dataResetProvider = NotifierProvider<DataResetController, ResetPhase>(
  DataResetController.new,
);
