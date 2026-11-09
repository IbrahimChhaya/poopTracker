import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/backup/backup_file.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/platform/file_import.dart';
import 'package:poop_tracker/features/backup/presentation/passphrase_field.dart';
import 'package:poop_tracker/features/backup/presentation/restore_backup_screen.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/backup_payload.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';
import 'package:poop_tracker/ui/widgets/morrow_button.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backup.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_diagnostics.dart';
import '../../support/harness.dart';

const String _pass = 'synthetic passphrase';
const String _create = 'Protect it with a passphrase';
const String _confirm = 'Confirm passphrase';

final Finder _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  late TrackingDatabase db;
  late EntryRepository repo;

  setUp(() async {
    db = TrackingDatabase();
    repo = EntryRepository(db, figmaNow);
    await repo.create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 6, 13, 35),
        originalUtcOffsetMinutes: 0,
        comment: 'Synthetic private note',
      ),
    );
    await repo.create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 4, 8, 10),
        originalUtcOffsetMinutes: 0,
      ),
    );
  });

  Future<AppUnderTest> pump(
    WidgetTester tester, {
    FakeFileExport? export,
    FakeFileImport? import,
    MemoryDiagnosticLog? log,
    double textScale = 1,
  }) => pumpMorrowApp(
    tester,
    [StartupReady(db, createdNew: false)],
    fileExport: export,
    fileImport: import,
    log: log,
    textScale: textScale,
    size: textScale > 1 ? smallPhone : figmaPhone,
  );

  Future<void> open(WidgetTester tester, String row) async {
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Data & privacy'),
      200,
      scrollable: _vertical,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data & privacy'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(row), 200, scrollable: _vertical);
    await tester.ensureVisible(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  /// Types into the passphrase field labelled [label].
  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.scrollUntilVisible(
      find.text(label),
      150,
      scrollable: _vertical,
    );
    final f = find.descendant(
      of: find.widgetWithText(PassphraseField, label),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, value);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(MorrowButton, label));
    await tester.pumpAndSettle();
  }

  /// A backup made elsewhere: one entry already in this journal, one new.
  Future<Uint8List> otherBackup() async {
    final mine = (await repo.all()).first;
    final payload = encodeBackupPayload([
      Entry(
        id: 1,
        uid: mine.uid,
        occurredAtUtc: mine.occurredAtUtc,
        originalUtcOffsetMinutes: 0,
        createdAtUtc: mine.createdAtUtc,
        updatedAtUtc: mine.updatedAtUtc,
        comment: 'Synthetic copy that must not overwrite',
      ),
      Entry(
        id: 2,
        uid: '3f2b8c1e-9d4a-4f6b-8e2a-1c5d7e9f0a3b',
        occurredAtUtc: DateTime.utc(2026, 11, 3, 9, 20),
        originalUtcOffsetMinutes: 0,
        createdAtUtc: DateTime.utc(2026, 11, 3, 9, 20),
        updatedAtUtc: DateTime.utc(2026, 11, 3, 9, 20),
        comment: 'Synthetic restored note',
      ),
    ], exportedAtUtc: DateTime.utc(2026, 11, 5));
    return sealBackup(payload, _pass, deriveKey: fastKeyDeriver);
  }

  group('Data & privacy', () {
    appTest('shows the backup rows and the recovery warning', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Data & privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Export a backup'), findsOneWidget);
      expect(find.text('Restore from a backup'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Only a backup you have exported'),
        200,
        scrollable: _vertical,
      );
      expect(
        find.textContaining('Only a backup you have exported'),
        findsOneWidget,
      );
    });
  });

  group('Export a backup (9.1–9.4)', () {
    appTest('checks the passphrase before doing anything', (tester) async {
      final export = FakeFileExport();
      await pump(tester, export: export);
      await open(tester, 'Export a backup');
      expect(
        find.text('Entries with date, time, note and any optional details'),
        findsOneWidget,
      );
      expect(find.text('Reminders, settings and app lock'), findsOneWidget);
      // The can't-recover warning comes before the passphrase is chosen.
      expect(
        find.text(
          'Choose a passphrase you’ll remember. If you forget it, this '
          'backup can’t be opened, and morrow can’t recover it.',
        ),
        findsOneWidget,
      );
      expect(find.text('At least 8 characters'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Once saved, the file is outside morrow'),
        150,
        scrollable: _vertical,
      );
      expect(
        find.textContaining('Once saved, the file is outside morrow'),
        findsOneWidget,
      );

      await type(tester, _create, 'short');
      await type(tester, _confirm, 'short');
      await press(tester, 'Create backup');
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(export.calls, isEmpty);

      await type(tester, _create, _pass);
      await type(tester, _confirm, 'something else');
      await press(tester, 'Create backup');
      expect(find.text('The passphrases don’t match.'), findsOneWidget);
      expect(export.calls, isEmpty);
    });

    appTest('saves only an encrypted file and confirms (9.4)', (tester) async {
      final export = FakeFileExport();
      final log = MemoryDiagnosticLog();
      await pump(tester, export: export, log: log);
      await open(tester, 'Export a backup');
      await type(tester, _create, _pass);
      await type(tester, _confirm, _pass);
      await press(tester, 'Create backup');

      expect(export.calls, hasLength(1));
      final call = export.calls.single;
      expect(call.name, 'morrow-backup-2026-11-06.morrow');
      expect(call.mimeType, 'application/octet-stream');
      expect(call.bytes.sublist(0, 8), backupMagic);
      expect(latin1.decode(call.bytes).contains('Synthetic'), isFalse);
      final restored = decodeBackupPayload(
        await openBackup(call.bytes, _pass, deriveKey: fastKeyDeriver),
      );
      expect(restored, hasLength(2));

      expect(find.text('Backup saved'), findsOneWidget);
      expect(
        find.text('morrow-backup-2026-11-06 contains 2 entries.'),
        findsOneWidget,
      );
      expect(find.text('Keep your passphrase safe'), findsOneWidget);
      expect(log.events, contains(DiagnosticEvent.backupSaved));

      await press(tester, 'Done');
      expect(find.text('Your local data'), findsOneWidget);
    });

    appTest('cancelling the save sheet goes back with no message', (
      tester,
    ) async {
      final export = FakeFileExport()..saveResult = false;
      final log = MemoryDiagnosticLog();
      await pump(tester, export: export, log: log);
      await open(tester, 'Export a backup');
      await type(tester, _create, _pass);
      await type(tester, _confirm, _pass);
      await press(tester, 'Create backup');
      expect(
        find.widgetWithText(MorrowButton, 'Create backup'),
        findsOneWidget,
      );
      expect(find.text('Backup saved'), findsNothing);
      expect(find.text('Couldn’t create the backup'), findsNothing);
      expect(log.events, isNot(contains(DiagnosticEvent.backupSaved)));
      // The passphrase is not left in the fields.
      expect(find.text(_pass), findsNothing);
    });

    appTest('a failed save says nothing was saved', (tester) async {
      final log = MemoryDiagnosticLog();
      await pump(tester, export: _FailingExport(), log: log);
      await open(tester, 'Export a backup');
      await type(tester, _create, _pass);
      await type(tester, _confirm, _pass);
      await press(tester, 'Create backup');
      expect(find.text('Couldn’t create the backup'), findsOneWidget);
      expect(log.events, contains(DiagnosticEvent.backupFailed));
    });

    appTest('a double tap creates one backup', (tester) async {
      final export = FakeFileExport();
      await pump(tester, export: export);
      await open(tester, 'Export a backup');
      await type(tester, _create, _pass);
      await type(tester, _confirm, _pass);
      final button = find.widgetWithText(MorrowButton, 'Create backup');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(export.calls, hasLength(1));
    });
  });

  group('Restore from a backup (9.5–9.10)', () {
    appTest('adds new entries, keeps existing ones, reports counts', (
      tester,
    ) async {
      final file = await otherBackup();
      final import = FakeFileImport()
        ..next = PickedFile(
          name: 'morrow-backup-2026-11-05.morrow',
          bytes: file,
        );
      final log = MemoryDiagnosticLog();
      await pump(tester, import: import, log: log);
      await open(tester, 'Restore from a backup');
      expect(find.text('Entries already here are kept'), findsOneWidget);

      await press(tester, 'Choose backup file');
      expect(find.text('morrow-backup-2026-11-05'), findsOneWidget);
      expect(find.text('5 Nov 2026 · 1 KB'), findsOneWidget);

      await type(tester, 'Passphrase', _pass);
      await press(tester, 'Restore');
      expect(find.text('Restore complete'), findsOneWidget);
      expect(
        find.text(
          '1 entry added. 1 was already in your journal and was skipped.',
        ),
        findsOneWidget,
      );
      expect(log.events, contains(DiagnosticEvent.restoreDone));

      final all = await repo.all();
      expect(all, hasLength(3));
      expect(all.map((e) => e.comment), contains('Synthetic restored note'));
      expect(
        all.map((e) => e.comment),
        isNot(contains('Synthetic copy that must not overwrite')),
      );

      await press(tester, 'Done');
      expect(find.text('Your local data'), findsOneWidget);
    });

    appTest('a wrong passphrase changes nothing (9.10), then Try again', (
      tester,
    ) async {
      final import = FakeFileImport()
        ..next = PickedFile(
          name: 'morrow-backup-2026-11-05.morrow',
          bytes: await otherBackup(),
        );
      await pump(tester, import: import);
      await open(tester, 'Restore from a backup');
      await press(tester, 'Choose backup file');
      await type(tester, 'Passphrase', 'not the passphrase');
      await press(tester, 'Restore');

      expect(find.text('Couldn’t restore'), findsOneWidget);
      expect(
        find.text(
          'The passphrase didn’t match, or the file isn’t a morrow backup. '
          'Nothing was changed.',
        ),
        findsOneWidget,
      );
      expect(await repo.all(), hasLength(2));

      await type(tester, 'Passphrase', _pass);
      await press(tester, 'Try again');
      expect(find.text('Restore complete'), findsOneWidget);
    });

    appTest('a file that is not a backup is refused before the passphrase', (
      tester,
    ) async {
      final import = FakeFileImport()
        ..next = PickedFile(name: 'notes.txt', bytes: utf8.encode('synthetic'));
      await pump(tester, import: import);
      await open(tester, 'Restore from a backup');
      await press(tester, 'Choose backup file');
      expect(find.text('Couldn’t use that file'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    appTest('a backup from a newer morrow says to update', (tester) async {
      final newer = Uint8List.fromList(await otherBackup());
      ByteData.sublistView(newer).setUint16(8, 2);
      final import = FakeFileImport()
        ..next = PickedFile(
          name: 'morrow-backup-2027-01-01.morrow',
          bytes: newer,
        );
      await pump(tester, import: import);
      await open(tester, 'Restore from a backup');
      await press(tester, 'Choose backup file');
      expect(find.textContaining('newer version of morrow'), findsOneWidget);
    });

    appTest('cancelling the picker changes nothing', (tester) async {
      final import = FakeFileImport();
      await pump(tester, import: import);
      await open(tester, 'Restore from a backup');
      await press(tester, 'Choose backup file');
      expect(import.picks, 1);
      expect(
        find.widgetWithText(MorrowButton, 'Choose backup file'),
        findsOneWidget,
      );
      expect(find.text('Couldn’t use that file'), findsNothing);
    });
  });

  test('restore summary wording', () {
    expect(
      restoreSummary(added: 12, skipped: 6),
      '12 entries added. 6 were already in your journal and were skipped.',
    );
    expect(restoreSummary(added: 1, skipped: 0), '1 entry added.');
    expect(
      restoreSummary(added: 0, skipped: 1),
      '0 entries added. 1 was already in your journal and was skipped.',
    );
    expect(formatFileSize(4000), '4 KB');
    expect(formatFileSize(3 * 1024 * 1024 + 1), '3.0 MB');
  });

  for (final scale in [1.0, 2.0]) {
    appTest('export and restore screens fit at ${scale}x', (tester) async {
      final import = FakeFileImport()
        ..next = PickedFile(
          name: 'morrow-backup-2026-11-05.morrow',
          bytes: await otherBackup(),
        );
      await pump(tester, import: import, textScale: scale);
      await open(tester, 'Export a backup');
      expect(tester.takeException(), isNull);
      await type(tester, _create, _pass);
      await type(tester, _confirm, _pass);
      await press(tester, 'Create backup');
      expect(find.text('Backup saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await press(tester, 'Done');

      await tester.scrollUntilVisible(
        find.text('Restore from a backup'),
        200,
        scrollable: _vertical,
      );
      await tester.ensureVisible(find.text('Restore from a backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();
      await press(tester, 'Choose backup file');
      await type(tester, 'Passphrase', 'not the passphrase');
      await press(tester, 'Restore');
      expect(find.text('Couldn’t restore'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FailingExport extends FakeFileExport {
  @override
  Future<bool> save({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async => throw StateError('simulated');
}
