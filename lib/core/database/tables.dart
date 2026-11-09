import 'package:drift/drift.dart';

// Schema v1. Table and column names are neutral on purpose: the database
// must not spell out what the journal tracks.
//
// Times are whole milliseconds since the Unix epoch, in UTC. The offset that
// applied where an entry happened is stored next to it, so its local day
// never changes (see LocalDate).

/// Journal entries. Only the time is required; every detail is optional.
@DataClassName('EntryRow')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Random v4 UUID. Stable identity used to skip duplicates on restore.
  TextColumn get uid => text().unique()();
  IntColumn get occurredAtUtcMs => integer()();
  IntColumn get originalUtcOffsetMinutes => integer()();

  /// False when no time of day was recorded (schema v2). The stored instant
  /// is then midday on the entry's local day and is never shown.
  BoolColumn get hasTime => boolean().withDefault(const Constant(true))();

  /// Plain text, at most 500 characters (validated in Dart; see Entry).
  TextColumn get comment => text().nullable()();
  IntColumn get stoolType => integer().nullable()();
  TextColumn get ease => text().nullable()();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();

  // Defence in depth: Dart validates first, the database refuses anything
  // that slips through.
  @override
  List<String> get customConstraints => const [
    'CHECK (original_utc_offset_minutes BETWEEN -720 AND 840)',
    'CHECK (stool_type IS NULL OR stool_type BETWEEN 1 AND 7)',
    "CHECK (ease IS NULL OR ease IN ('easy', 'some_straining', 'difficult'))",
  ];
}

/// Circumstance tags chosen for an entry, by code.
@DataClassName('EntryTagRow')
class EntryTags extends Table {
  IntColumn get entryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  TextColumn get code => text()();

  @override
  Set<Column<Object>> get primaryKey => {entryId, code};

  @override
  List<String> get customConstraints => const [
    "CHECK (code IN ('after_meal', 'coffee', 'stress', 'low_fluids', "
        "'medication', 'on_period', 'feeling_sick'))",
  ];
}

/// Ordinary display settings. A single row with id 1.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer()();
  BoolColumn get showStoolForm =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showContext => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const ['CHECK (id = 1)'];
}

/// The reminder the user asked for (not whether the OS has scheduled it). A
/// single row with id 1. Day and time stay null until first chosen.
@DataClassName('ReminderRow')
class Reminder extends Table {
  IntColumn get id => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  /// ISO weekday, 1 (Monday) to 7 (Sunday).
  IntColumn get weekday => integer().nullable()();
  IntColumn get hour => integer().nullable()();
  IntColumn get minute => integer().nullable()();

  /// 'follow_device': the reminder keeps its wall-clock time in whatever
  /// zone the phone is in.
  TextColumn get tzPolicy =>
      text().withDefault(const Constant('follow_device'))();
  IntColumn get notificationId =>
      integer().withDefault(const Constant(reminderNotificationId))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (id = 1)',
    'CHECK (weekday IS NULL OR weekday BETWEEN 1 AND 7)',
    'CHECK (hour IS NULL OR hour BETWEEN 0 AND 23)',
    'CHECK (minute IS NULL OR minute BETWEEN 0 AND 59)',
    "CHECK (tz_policy IN ('follow_device'))",
  ];
}

/// Stable identifier for the single weekly reminder notification.
const int reminderNotificationId = 7001;
