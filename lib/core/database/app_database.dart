import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The encrypted journal database. Open it only through
/// `DatabaseBootstrap`, which checks the cipher build and key first.
@DriftDatabase(
  tables: [Entries, EntrySymptoms, EntryTags, AppSettings, Reminder],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Bump with every schema change and add a migration step. Never delete
  /// and recreate the database to recover from a failed migration.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettings)
          .insert(AppSettingsCompanion.insert(id: const Value(1)));
      await into(reminder).insert(ReminderCompanion.insert(id: const Value(1)));
    },
    onUpgrade: (m, from, to) async {
      throw StateError('No migration from schema $from to $to');
    },
    beforeOpen: (details) async {
      // Also set in the connection setup; repeated here so it holds even if
      // drift reopens the connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
