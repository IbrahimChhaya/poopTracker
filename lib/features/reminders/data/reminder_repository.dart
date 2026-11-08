import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';

/// The reminder the user asked for. Not whether the OS has scheduled it or
/// allows notifications: that is observed separately and never stored.
final class ReminderIntent {
  const ReminderIntent({
    required this.enabled,
    this.weekday,
    this.hour,
    this.minute,
    this.notificationId = reminderNotificationId,
  });

  /// Suggested when the reminder is first switched on (Figma 6.3).
  static const int defaultWeekday = DateTime.sunday;
  static const int defaultHour = 18;
  static const int defaultMinute = 0;

  final bool enabled;

  /// ISO weekday, 1 (Monday) to 7 (Sunday); null until first chosen.
  final int? weekday;
  final int? hour;
  final int? minute;
  final int notificationId;

  int get effectiveWeekday => weekday ?? defaultWeekday;
  int get effectiveHour => hour ?? defaultHour;
  int get effectiveMinute => minute ?? defaultMinute;
}

/// Reads and writes the single reminder row (id 1) in the journal database.
class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;

  Future<ReminderIntent> read() async {
    final row = await (_db.select(
      _db.reminder,
    )..where((r) => r.id.equals(1))).getSingleOrNull();
    if (row == null) return const ReminderIntent(enabled: false);
    return ReminderIntent(
      enabled: row.enabled,
      weekday: row.weekday,
      hour: row.hour,
      minute: row.minute,
      notificationId: row.notificationId,
    );
  }

  /// Stores the whole intent in one write.
  Future<void> save({
    required bool enabled,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    if (weekday < 1 || weekday > 7) throw ArgumentError.value(weekday);
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour);
    if (minute < 0 || minute > 59) throw ArgumentError.value(minute);
    final change = ReminderCompanion(
      enabled: Value(enabled),
      weekday: Value(weekday),
      hour: Value(hour),
      minute: Value(minute),
    );
    await _db.transaction(() async {
      final changed = await (_db.update(
        _db.reminder,
      )..where((r) => r.id.equals(1))).write(change);
      if (changed == 0) {
        await _db
            .into(_db.reminder)
            .insert(change.copyWith(id: const Value(1)));
      }
    });
  }
}
