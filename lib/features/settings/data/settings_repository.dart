import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Which optional details are shown. Both default to off.
final class DisplaySettings {
  const DisplaySettings({
    required this.showStoolForm,
    required this.showContext,
  });

  static const DisplaySettings defaults = DisplaySettings(
    showStoolForm: false,
    showContext: false,
  );

  final bool showStoolForm;
  final bool showContext;

  bool get anyDetails => showStoolForm || showContext;
}

/// Ordinary settings, stored in the encrypted database (single row, id 1).
///
/// Turning a setting off only hides its details; stored values are kept.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$AppSettingsTable, AppSettingsRow> get _row =>
      _db.select(_db.appSettings)..where((s) => s.id.equals(1));

  Stream<DisplaySettings> watchDisplay() => _row.watch().map(
    (rows) => rows.isEmpty
        ? DisplaySettings.defaults
        : DisplaySettings(
            showStoolForm: rows.single.showStoolForm,
            showContext: rows.single.showContext,
          ),
  );

  Future<void> setShowStoolForm(bool value) =>
      _write(AppSettingsCompanion(showStoolForm: Value(value)));

  Future<void> setShowContext(bool value) =>
      _write(AppSettingsCompanion(showContext: Value(value)));

  Future<void> _write(AppSettingsCompanion change) async {
    final changed = await (_db.update(
      _db.appSettings,
    )..where((s) => s.id.equals(1))).write(change);
    if (changed == 0) {
      // The row is created with the schema; recreate it if it is missing.
      await _db
          .into(_db.appSettings)
          .insert(change.copyWith(id: const Value(1)));
    }
  }
}
