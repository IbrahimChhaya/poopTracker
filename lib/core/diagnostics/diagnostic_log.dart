import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../clock.dart';

/// Every event the diagnostic log can hold. The log stores only these
/// codes and when they happened, so no free text (an entry, a note, an
/// error message, a path) can ever reach it.
///
/// Routine journal actions (adding, changing or deleting an entry) are not
/// logged: their times would reveal when entries were made. Only failures
/// and app-level events are.
enum DiagnosticEvent {
  appStarted('app.started', 'App started'),
  journalOpened('journal.opened', 'Journal opened'),
  journalCreated('journal.created', 'New journal set up'),
  journalBlockedStorage(
    'journal.blocked.storage',
    'Journal blocked · secure storage unavailable',
  ),
  journalBlockedKeyMissing(
    'journal.blocked.key_missing',
    'Journal blocked · key missing',
  ),
  journalBlockedKeyRejected(
    'journal.blocked.key_rejected',
    'Journal blocked · key not accepted',
  ),
  journalBlockedNotEncrypted(
    'journal.blocked.not_encrypted',
    'Journal blocked · file not encrypted',
  ),
  journalBlockedNoEncryption(
    'journal.blocked.no_encryption',
    'Journal blocked · encryption unavailable',
  ),
  journalBlockedUnreadable(
    'journal.blocked.unreadable',
    'Journal blocked · file unreadable',
  ),
  journalBlockedSetup(
    'journal.blocked.setup_failed',
    'Journal blocked · setup failed',
  ),
  journalBlockedErase(
    'journal.blocked.erase_failed',
    'Journal blocked · erase failed',
  ),
  startupFailed('startup.failed', 'Startup failed'),
  journalErased('journal.erased', 'Journal erased and started fresh'),
  entryAddFailed('entry.add_failed', 'Couldn’t add an entry'),
  entrySaveFailed('entry.save_failed', 'Couldn’t save changes'),
  entryDetailFailed('entry.detail_failed', 'Couldn’t save a detail'),
  entryDeleteFailed('entry.delete_failed', 'Couldn’t delete an entry'),
  entryUndoFailed('entry.undo_failed', 'Couldn’t undo an entry'),
  lockTurnedOn('lock.on', 'App lock turned on'),
  lockTurnedOff('lock.off', 'App lock turned off'),
  unlockFailed('lock.unlock_failed', 'Couldn’t unlock'),
  unlockLockedOut('lock.locked_out', 'Unlock paused after too many tries'),
  unlockUnavailable('lock.unavailable', 'Unlock not available on this phone'),
  lockSettingFailed(
    'lock.setting_failed',
    'Couldn’t read the app lock setting',
  ),
  reminderScheduled('reminder.scheduled', 'Weekly reminder scheduled'),
  reminderCancelled('reminder.cancelled', 'Weekly reminder turned off'),
  reminderScheduleFailed(
    'reminder.schedule_failed',
    'Couldn’t schedule the weekly reminder',
  ),
  reminderPermissionDenied(
    'reminder.permission_denied',
    'Notifications not allowed',
  ),
  logTurnedOn('log.on', 'Log turned on'),
  logSaved('log.saved', 'Log saved'),
  logShared('log.shared', 'Log shared');

  const DiagnosticEvent(this.code, this.label);

  /// Stable code written to the file.
  final String code;

  /// Plain wording shown on the Diagnostics screen.
  final String label;

  static DiagnosticEvent? fromCode(String code) {
    for (final e in values) {
      if (e.code == code) return e;
    }
    return null;
  }
}

/// One logged event: what happened and the device's local wall-clock time.
final class DiagnosticRecord {
  const DiagnosticRecord(this.event, this.localTime);

  final DiagnosticEvent event;

  /// Local wall-clock fields (UTC-flagged, like `Entry.localWallClock`).
  final DateTime localTime;
}

/// How long and how much the log keeps.
const Duration diagnosticRetention = Duration(days: 30);
const int diagnosticMaxEvents = 500;

/// The on-device diagnostic log (M7.5). Not journal data: it holds only
/// [DiagnosticEvent] codes, so it lives outside the unlocked scope and can
/// record startup problems before the journal opens.
abstract interface class DiagnosticLog {
  /// Records [event]. Never throws and never blocks the caller's action.
  void record(DiagnosticEvent event);

  Future<bool> isEnabled();

  /// Turning the log off deletes it.
  Future<void> setEnabled(bool enabled);

  /// Kept events, newest first.
  Future<List<DiagnosticRecord>> recent();

  /// The whole log as a plain-text file for saving or sharing.
  Future<String> exportText();
}

/// [DiagnosticLog] in app-private storage: `diagnostics/events.log` under
/// Application Support, one `time code` line per event. A marker file
/// `diagnostics/off` means the user turned the log off (on by default).
/// Writes are queued so they never overlap.
class FileDiagnosticLog implements DiagnosticLog {
  FileDiagnosticLog({required this.clock, Future<Directory> Function()? dir})
    : _dir = dir ?? _defaultDir;

  final Clock clock;
  final Future<Directory> Function() _dir;
  Future<void> _queue = Future.value();

  static Future<Directory> _defaultDir() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'diagnostics'),
  );

  Future<File> _file() async => File(p.join((await _dir()).path, 'events.log'));
  Future<File> _offMarker() async => File(p.join((await _dir()).path, 'off'));

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  DateTime _now() => clock.nowLocalWall();

  /// Completes when every queued write has finished (for tests).
  Future<void> get idle => _queue;

  @override
  void record(DiagnosticEvent event) {
    final at = _now();
    unawaited(
      _serial(() async {
        if (!await isEnabled()) return;
        final file = await _file();
        await file.parent.create(recursive: true);
        await file.writeAsString(
          '${_formatTime(at)} ${event.code}\n',
          mode: FileMode.append,
          flush: true,
        );
        await _prune(file, at);
      }).catchError((Object _) {}),
    );
  }

  /// Drops events older than [diagnosticRetention] and keeps at most
  /// [diagnosticMaxEvents], rewriting the file only when something goes.
  Future<void> _prune(File file, DateTime now) async {
    final lines = await file.readAsLines();
    final cutoff = now.subtract(diagnosticRetention);
    final kept = [
      for (final l in lines)
        if (_parse(l) case final r? when !r.localTime.isBefore(cutoff)) l,
    ];
    final trimmed = kept.length > diagnosticMaxEvents
        ? kept.sublist(kept.length - diagnosticMaxEvents)
        : kept;
    if (trimmed.length != lines.length) {
      await file.writeAsString(
        trimmed.isEmpty ? '' : '${trimmed.join('\n')}\n',
        flush: true,
      );
    }
  }

  @override
  Future<bool> isEnabled() async => !await (await _offMarker()).exists();

  @override
  Future<void> setEnabled(bool enabled) =>
      _serial(() async {
        final marker = await _offMarker();
        final file = await _file();
        if (enabled) {
          if (await marker.exists()) await marker.delete();
        } else {
          await marker.parent.create(recursive: true);
          await marker.writeAsString('');
          if (await file.exists()) await file.delete();
        }
      }).then((_) {
        if (enabled) record(DiagnosticEvent.logTurnedOn);
      });

  @override
  Future<List<DiagnosticRecord>> recent() => _serial(() async {
    final file = await _file();
    if (!await isEnabled() || !await file.exists()) return const [];
    final cutoff = _now().subtract(diagnosticRetention);
    final records = [
      for (final l in await file.readAsLines())
        if (_parse(l) case final r? when !r.localTime.isBefore(cutoff)) r,
    ];
    final newest = records.reversed.toList();
    return newest.length > diagnosticMaxEvents
        ? newest.sublist(0, diagnosticMaxEvents)
        : newest;
  });

  @override
  Future<String> exportText() async =>
      formatDiagnosticExport(await recent(), exportedAt: _now());
}

/// "2026-11-06T13:41:05".
String _formatTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}T'
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Parses one stored line; null for anything that is not a known event.
DiagnosticRecord? _parse(String line) {
  final parts = line.trim().split(' ');
  if (parts.length != 2) return null;
  final event = DiagnosticEvent.fromCode(parts[1]);
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$')
      .firstMatch(parts[0]);
  if (event == null || m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  return DiagnosticRecord(
    event,
    DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6)),
  );
}

/// The exported file: a short header, then one line per event, oldest
/// first. Built only from codes, labels and times.
String formatDiagnosticExport(
  List<DiagnosticRecord> newestFirst, {
  required DateTime exportedAt,
}) {
  final b = StringBuffer()
    ..writeln('morrow diagnostics')
    ..writeln('Exported ${_formatTime(exportedAt)} (device local time)')
    ..writeln('App events only. No entries, notes, details or keys.')
    ..writeln();
  for (final r in newestFirst.reversed) {
    b.writeln('${_formatTime(r.localTime)}  ${r.event.code}  ${r.event.label}');
  }
  return b.toString();
}

/// UTF-8 bytes of [text], for saving.
List<int> diagnosticBytes(String text) => utf8.encode(text);
