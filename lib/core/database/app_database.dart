import 'package:drift/drift.dart';

import 'app_database.steps.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The encrypted journal database. Open it only through
/// `DatabaseBootstrap`, which checks the cipher build and key first.
@DriftDatabase(tables: [Entries, EntryTags, AppSettings, Reminder])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Bump with every schema change and add a migration step. Never delete
  /// and recreate the database to recover from a failed migration.
  @override
  ///
  /// - v1: first schema.
  /// - v2: optional time (`entries.has_time`), symptoms removed (table
  ///   `entry_symptoms` dropped), tags `exercise` removed and `on_period`,
  ///   `feeling_sick` added.
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettings)
          .insert(AppSettingsCompanion.insert(id: const Value(1)));
      await into(reminder).insert(ReminderCompanion.insert(id: const Value(1)));
    },
    // Step-by-step migrations against the exported schemas in drift_schemas/
    // (regenerate with `dart run drift_dev make-migrations`). Drift refuses
    // downgrades.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // Every v1 entry had a time.
        await m.addColumn(schema.entries, schema.entries.hasTime);
        // Symptoms are no longer recorded. Only development builds ever held
        // v1 data, so dropping the table loses no user data.
        await m.deleteTable('entry_symptoms');
        // The tag list changed: rows for a removed tag go, then the table is
        // rebuilt so its CHECK constraint lists the new codes.
        await customStatement("DELETE FROM entry_tags WHERE code = 'exercise'");
        await m.alterTable(TableMigration(schema.entryTags));
      },
    ),
    beforeOpen: (details) async {
      // Also set in the connection setup; repeated here so it holds even if
      // drift reopens the connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
