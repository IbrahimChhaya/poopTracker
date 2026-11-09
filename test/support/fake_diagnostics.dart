import 'package:poop_tracker/core/clock.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/platform/file_export.dart';

import 'fake_clock.dart';

/// In-memory [DiagnosticLog] with the same rules as the file one.
class MemoryDiagnosticLog implements DiagnosticLog {
  MemoryDiagnosticLog({FixedClock? clock}) : clock = clock ?? figmaNow;

  final FixedClock clock;
  bool enabled = true;
  final List<DiagnosticRecord> _events = [];

  List<DiagnosticEvent> get events => [for (final r in _events) r.event];

  @override
  void record(DiagnosticEvent event) {
    if (enabled) _events.add(DiagnosticRecord(event, clock.nowLocalWall()));
  }

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool on) async {
    enabled = on;
    if (on) {
      record(DiagnosticEvent.logTurnedOn);
    } else {
      _events.clear();
    }
  }

  @override
  Future<List<DiagnosticRecord>> recent() async =>
      enabled ? _events.reversed.toList() : const [];

  @override
  Future<void> eraseAll() async {
    enabled = true;
    _events.clear();
  }

  @override
  Future<String> exportText() async =>
      formatDiagnosticExport(await recent(), exportedAt: clock.nowLocalWall());
}

/// Records what would have been handed to the save and share sheets.
class FakeFileExport implements FileExport {
  bool saveResult = true;
  ShareOutcome shareResult = ShareOutcome.shared;
  final List<
    ({
      String name,
      String text,
      List<int> bytes,
      String mimeType,
      String? subject,
    })
  >
  calls = [];

  @override
  Future<bool> save({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    calls.add((
      name: fileName,
      text: String.fromCharCodes(bytes),
      bytes: List.of(bytes),
      mimeType: mimeType,
      subject: null,
    ));
    return saveResult;
  }

  @override
  Future<ShareOutcome> share({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String subject,
  }) async {
    calls.add((
      name: fileName,
      text: String.fromCharCodes(bytes),
      bytes: List.of(bytes),
      mimeType: mimeType,
      subject: subject,
    ));
    return shareResult;
  }
}
