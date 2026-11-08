import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/app_database.dart';

import 'generated/schema.dart';

/// Upgrades from every shipped schema, checked against the exported schemas
/// in drift_schemas/. Add a case here for every new schema version.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('schema matches after upgrading', () {
    const versions = GeneratedHelper.versions;
    for (final (i, from) in versions.indexed) {
      for (final to in versions.skip(i + 1)) {
        test('$from to $to', () async {
          final schema = await verifier.schemaAt(from);
          final db = AppDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, to);
          await db.close();
        });
      }
    }
  });

  test('v1 to v2 keeps entries, marks them timed, drops symptoms and the '
      'removed tag', () async {
    final schema = await verifier.schemaAt(1);
    final raw = schema.rawDatabase
      ..execute(
        'INSERT INTO entries (id, uid, occurred_at_utc_ms, '
        'original_utc_offset_minutes, comment, stool_type, ease, '
        'created_at_utc_ms, updated_at_utc_ms) VALUES '
        "(1, 'u1', 1000, 60, 'Synthetic note', 4, 'easy', 1000, 1000)",
      )
      ..execute(
        "INSERT INTO entry_symptoms (entry_id, code) VALUES (1, 'bloating')",
      )
      ..execute("INSERT INTO entry_tags (entry_id, code) VALUES (1, 'coffee')")
      ..execute(
        "INSERT INTO entry_tags (entry_id, code) VALUES (1, 'exercise')",
      );
    expect(raw.select('SELECT * FROM entry_tags'), hasLength(2));

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final entries = await db.select(db.entries).get();
    expect(entries, hasLength(1));
    final e = entries.single;
    expect(e.uid, 'u1');
    expect(e.hasTime, isTrue);
    expect(e.comment, 'Synthetic note');
    expect(e.stoolType, 4);
    expect(e.ease, 'easy');
    expect(e.originalUtcOffsetMinutes, 60);

    final tags = await db.select(db.entryTags).get();
    expect(tags.map((t) => t.code), ['coffee']);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
      tables.map((r) => r.read<String>('name')),
      isNot(contains('entry_symptoms')),
    );

    // The new tag codes are accepted, the removed one is refused.
    await db
        .into(db.entryTags)
        .insert(EntryTagsCompanion.insert(entryId: 1, code: 'on_period'));
    await expectLater(
      db
          .into(db.entryTags)
          .insert(EntryTagsCompanion.insert(entryId: 1, code: 'exercise')),
      throwsA(anything),
    );
    await db.close();
  });
}
