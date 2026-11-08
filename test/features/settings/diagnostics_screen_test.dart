import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/platform/file_export.dart';

import '../../support/app_harness.dart';
import '../../support/fake_diagnostics.dart';
import '../../support/harness.dart';

final Finder _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .last;

void main() {
  late TrackingDatabase db;
  late MemoryDiagnosticLog log;
  late FakeFileExport export;

  setUp(() {
    db = TrackingDatabase();
    log = MemoryDiagnosticLog();
    export = FakeFileExport();
  });

  Future<void> openDiagnostics(
    WidgetTester tester, {
    double textScale = 1,
  }) async {
    await pumpMorrowApp(
      tester,
      [StartupReady(db, createdNew: false)],
      log: log,
      fileExport: export,
      textScale: textScale,
      size: textScale > 1 ? smallPhone : figmaPhone,
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Diagnostics'),
      200,
      scrollable: _vertical,
    );
    await tester.ensureVisible(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.bySubtype<ButtonStyleButton>(),
            ),
          )
          .onPressed !=
      null;

  appTest('Settings > Support > Diagnostics shows recent events (10.1, 10.2)', (
    tester,
  ) async {
    await openDiagnostics(tester);
    expect(find.text('Never recorded'), findsOneWidget);
    expect(find.text('Your entries, notes, details or keys'), findsOneWidget);
    // Startup was recorded by the app itself.
    await tester.scrollUntilVisible(
      find.text('Journal opened'),
      200,
      scrollable: _vertical,
    );
    expect(find.text('Journal opened'), findsOneWidget);
    expect(find.text('Kept for 30 days, up to 500 events.'), findsOneWidget);
    expect(enabled(tester, 'Save a copy'), isTrue);
    expect(enabled(tester, 'Share by email'), isTrue);
  });

  appTest('Save a copy hands the file to the save sheet (10.5)', (
    tester,
  ) async {
    await openDiagnostics(tester);
    await tapText(tester, 'Save a copy');
    expect(export.calls.single.name, 'morrow-diagnostics-2026-11-06.txt');
    expect(export.calls.single.text, contains('journal.opened'));
    expect(find.text('Log saved'), findsOneWidget);
    expect(find.text('It’s no longer only on morrow'), findsOneWidget);
    expect(log.events.last, DiagnosticEvent.logSaved);
    await tapText(tester, 'Done');
    expect(find.text('Recent events'), findsOneWidget);
  });

  appTest('a cancelled save shows nothing', (tester) async {
    export.saveResult = false;
    await openDiagnostics(tester);
    await tapText(tester, 'Save a copy');
    expect(find.text('Log saved'), findsNothing);
    expect(log.events, isNot(contains(DiagnosticEvent.logSaved)));
  });

  appTest('Share by email asks first, then opens the share sheet (10.3)', (
    tester,
  ) async {
    await openDiagnostics(tester);
    await tapText(tester, 'Share by email');
    expect(find.text('Share the log?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(export.calls, isEmpty);

    await tapText(tester, 'Share by email');
    await tapText(tester, 'Continue');
    expect(export.calls.single.subject, 'morrow diagnostics');
    expect(find.text('Log shared'), findsOneWidget);
  });

  appTest('a dismissed share sheet says nothing', (tester) async {
    export.shareResult = ShareOutcome.dismissed;
    await openDiagnostics(tester);
    await tapText(tester, 'Share by email');
    await tapText(tester, 'Continue');
    expect(find.text('Log shared'), findsNothing);
  });

  appTest('turning the log off deletes it and disables sharing (10.6)', (
    tester,
  ) async {
    await openDiagnostics(tester);
    await tapText(tester, 'Keep a diagnostic log');
    expect(await log.recent(), isEmpty);
    expect(
      find.text('No events recorded. Turn the log on to keep one.'),
      findsOneWidget,
    );
    expect(enabled(tester, 'Save a copy'), isFalse);
    expect(enabled(tester, 'Share by email'), isFalse);

    await tapText(tester, 'Keep a diagnostic log');
    expect(find.text('Log turned on'), findsOneWidget);
  });

  for (final scale in textScales) {
    appTest('Diagnostics at ${(scale * 100).toInt()}%', (tester) async {
      await openDiagnostics(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Kept for 30 days, up to 500 events.'),
        200,
        scrollable: _vertical,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
