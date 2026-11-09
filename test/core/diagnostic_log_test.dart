import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';

import '../support/fake_clock.dart';

void main() {
  late Directory dir;
  late FixedClock clock;
  late FileDiagnosticLog log;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('morrow_diag_');
    clock = FixedClock(DateTime.utc(2026, 11, 6, 13, 41));
    log = FileDiagnosticLog(clock: clock, dir: () async => dir);
  });

  tearDown(() => dir.delete(recursive: true));

  File file() => File('${dir.path}/events.log');

  test('on by default; records events newest first', () async {
    expect(await log.isEnabled(), isTrue);
    log
      ..record(DiagnosticEvent.appStarted)
      ..record(DiagnosticEvent.journalOpened);
    await log.idle;
    final recent = await log.recent();
    expect(
      [for (final r in recent) r.event],
      [DiagnosticEvent.journalOpened, DiagnosticEvent.appStarted],
    );
    expect(recent.first.localTime, DateTime.utc(2026, 11, 6, 13, 41));
  });

  test('each line is only a time and a known code', () async {
    log.record(DiagnosticEvent.entrySaveFailed);
    await log.idle;
    final lines = await file().readAsLines();
    expect(lines, ['2026-11-06T13:41:00 entry.save_failed']);
  });

  test('turning it off deletes the log and stops recording', () async {
    log.record(DiagnosticEvent.appStarted);
    await log.idle;
    await log.setEnabled(false);
    expect(await file().exists(), isFalse);
    log.record(DiagnosticEvent.journalOpened);
    await log.idle;
    expect(await log.recent(), isEmpty);
    expect(await file().exists(), isFalse);

    await log.setEnabled(true);
    await log.idle;
    expect(
      [for (final r in await log.recent()) r.event],
      [DiagnosticEvent.logTurnedOn],
    );
  });

  test('keeps at most 500 events', () async {
    for (var i = 0; i < 510; i++) {
      log.record(DiagnosticEvent.appStarted);
    }
    log.record(DiagnosticEvent.journalOpened);
    await log.idle;
    final recent = await log.recent();
    expect(recent, hasLength(diagnosticMaxEvents));
    expect(recent.first.event, DiagnosticEvent.journalOpened);
    expect(await file().readAsLines(), hasLength(diagnosticMaxEvents));
  });

  test('drops events older than 30 days', () async {
    log.record(DiagnosticEvent.appStarted);
    await log.idle;
    clock.utc = clock.utc.add(const Duration(days: 31));
    log.record(DiagnosticEvent.journalOpened);
    await log.idle;
    expect(
      [for (final r in await log.recent()) r.event],
      [DiagnosticEvent.journalOpened],
    );
    expect(await file().readAsLines(), hasLength(1));
  });

  test('lines that are not known events are ignored', () async {
    await file().writeAsString(
      'not a line\n2026-11-06T09:00:00 made.up\n'
      '2026-11-06T09:00:00 app.started extra text\n'
      '2026-11-06T10:00:00 journal.opened\n',
    );
    expect(
      [for (final r in await log.recent()) r.event],
      [DiagnosticEvent.journalOpened],
    );
  });

  test('recording never throws, even when storage fails', () async {
    final broken = FileDiagnosticLog(
      clock: clock,
      dir: () async => throw const FileSystemException('simulated'),
    )..record(DiagnosticEvent.appStarted);
    await broken.idle;
  });

  test(
    'the export has a header and one line per event, oldest first',
    () async {
      log
        ..record(DiagnosticEvent.appStarted)
        ..record(DiagnosticEvent.entryAddFailed);
      await log.idle;
      final text = await log.exportText();
      expect(text, startsWith('morrow diagnostics\n'));
      expect(
        text,
        contains('App events only. No entries, notes, details or keys.'),
      );
      expect(text.trim().split('\n').skip(4).toList(), [
        '2026-11-06T13:41:00  app.started  App started',
        '2026-11-06T13:41:00  entry.add_failed  Couldn’t add an entry',
      ]);
    },
  );
}
