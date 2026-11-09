import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/database/tables.dart';

import '../../support/app_harness.dart';
import '../../support/fake_reminders.dart';
import '../../support/harness.dart';

void main() {
  late TrackingDatabase db;
  late FakeReminderScheduler os;

  setUp(() {
    db = TrackingDatabase();
    os = FakeReminderScheduler();
  });

  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
    await pumpMorrowApp(
      tester,
      [StartupReady(db, createdNew: false)],
      reminders: os,
      textScale: textScale,
      size: textScale > 1 ? smallPhone : figmaPhone,
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly reminder'));
    await tester.pumpAndSettle();
  }

  /// Scrolls the lazy list until [text] is built and visible.
  Future<void> reveal(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  appTest('off (6.1): no permission asked just by looking', (tester) async {
    await open(tester);
    expect(find.text('Remind me weekly'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(
      find.text(
        'One weekly check-in to add an entry. You choose the day and time.',
      ),
      findsOneWidget,
    );
    expect(os.requests, 0);
  });

  appTest('switching on (6.3): Sunday 6 pm, preview and status', (
    tester,
  ) async {
    await open(tester);
    await tapText(tester, 'Remind me weekly');
    expect(os.requests, 1);
    expect(find.text('Every Sunday at 6:00 pm'), findsOneWidget);
    expect(find.text('6:00 pm'), findsOneWidget);
    expect(find.text('Weekly check-in'), findsOneWidget);
    expect(find.text('Ready to add an entry?'), findsOneWidget);
    await reveal(tester, 'Scheduled on this phone');
    expect(find.text('Scheduled on this phone'), findsOneWidget);
    expect(
      find.text('Your phone will show it every Sunday at 6:00 pm.'),
      findsOneWidget,
    );
    expect(os.pending, hasLength(1));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Sunday')),
      isSemantics(isSelected: true, isButton: true),
    );
    // The seven days sit in one row.
    final monday = tester.getRect(find.bySemanticsLabel('Monday'));
    final sunday = tester.getRect(find.bySemanticsLabel('Sunday'));
    expect(sunday.top, monday.top);
    expect(sunday.left, greaterThan(monday.right));

    await tester.scrollUntilVisible(
      find.text('M'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tapText(tester, 'M');
    expect(find.text('Every Monday at 6:00 pm'), findsOneWidget);
    expect(os.pending[reminderNotificationId]!.weekday, DateTime.monday);
    expect(os.pending, hasLength(1));

    // Back in Settings, the row shows the reminder.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Every Monday at 6:00 pm'), findsOneWidget);
  });

  appTest(
    'notifications refused (6.4): saved, explained, Open phone settings',
    (tester) async {
      os.grantOnRequest = false;
      await open(tester);
      await tapText(tester, 'Remind me weekly');
      expect(find.text('Notifications are turned off'), findsOneWidget);
      // The saved choice is shown, but never as if it will arrive.
      expect(
        find.text('Every Sunday at 6:00 pm · Notifications off'),
        findsOneWidget,
      );
      expect(find.text('Scheduled on this phone'), findsNothing);
      expect(os.pending, isEmpty);
      await tapText(tester, 'Open phone settings');
      expect(os.settingsOpened, 1);

      // Settings says the same, so the summary there never misleads.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text('Every Sunday at 6:00 pm · Notifications off'),
        findsOneWidget,
      );
    },
  );

  appTest('allowed later in Settings: picked up on return', (tester) async {
    os.grantOnRequest = false;
    await open(tester);
    await tapText(tester, 'Remind me weekly');
    expect(find.text('Notifications are turned off'), findsOneWidget);

    os.allowed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await reveal(tester, 'Scheduled on this phone');
    expect(find.text('Scheduled on this phone'), findsOneWidget);
    expect(os.pending, hasLength(1));
  });

  appTest('switching off cancels it', (tester) async {
    os.allowed = true;
    await open(tester);
    await tapText(tester, 'Remind me weekly');
    expect(os.pending, hasLength(1));
    await tapText(tester, 'Remind me weekly');
    expect(os.pending, isEmpty);
    expect(find.text('Off'), findsOneWidget);
  });

  for (final scale in textScales) {
    appTest('Weekly reminder at ${(scale * 100).toInt()}%', (tester) async {
      os.allowed = true;
      await open(tester, textScale: scale);
      await tapText(tester, 'Remind me weekly');
      expect(tester.takeException(), isNull);
      // Every day is at least a 48 px target, at any text size.
      for (final day in ['Monday', 'Sunday']) {
        final r = tester.getRect(find.bySemanticsLabel(day));
        expect(r.height, greaterThanOrEqualTo(48), reason: day);
        expect(r.width, greaterThanOrEqualTo(scale > 1.4 ? 48 : 40));
      }
    });
  }
}
