import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/app/scope.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/database/tables.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/notifications/reminder_scheduler.dart';
import 'package:poop_tracker/features/reminders/presentation/reminder_controller.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/fake_diagnostics.dart';
import '../../support/fake_reminders.dart';

void main() {
  late AppDatabase db;
  late FakeReminderScheduler os;
  late MemoryDiagnosticLog log;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    os = FakeReminderScheduler();
    log = MemoryDiagnosticLog();
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        reminderSchedulerProvider.overrideWithValue(os),
        diagnosticLogProvider.overrideWithValue(log),
      ],
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<ReminderView> view() => c.read(reminderControllerProvider.future);
  ReminderController reminder() => c.read(reminderControllerProvider.notifier);

  test('off by default: nothing scheduled, no permission asked', () async {
    final v = await view();
    expect(v.intent.enabled, isFalse);
    expect(v.scheduled, isFalse);
    expect(os.requests, 0);
    expect(os.pending, isEmpty);
  });

  test(
    'switching on asks for permission, saves Sunday 6 pm and schedules',
    () async {
      await view();
      await reminder().setEnabled(true);
      final v = c.read(reminderControllerProvider).value!;
      expect(os.requests, 1);
      expect(v.permission, NotificationPermission.granted);
      expect(v.scheduled, isTrue);
      expect(os.pending, {
        reminderNotificationId: (
          weekday: DateTime.sunday,
          hour: 18,
          minute: 0,
          zone: 'Europe/London',
        ),
      });
      final row = await db.select(db.reminder).getSingle();
      expect(
        (row.enabled, row.weekday, row.hour, row.minute),
        (true, 7, 18, 0),
      );
      expect(log.events, [DiagnosticEvent.reminderScheduled]);
    },
  );

  test(
    'a refusal still saves the reminder and schedules nothing (6.4)',
    () async {
      os.grantOnRequest = false;
      await view();
      await reminder().setEnabled(true);
      final v = c.read(reminderControllerProvider).value!;
      expect(v.intent.enabled, isTrue);
      expect(v.permission, NotificationPermission.denied);
      expect(v.scheduled, isFalse);
      expect(os.pending, isEmpty);
      expect((await db.select(db.reminder).getSingle()).enabled, isTrue);
      expect(log.events, [DiagnosticEvent.reminderPermissionDenied]);

      // Allowed later in system Settings: the next reconcile schedules it.
      os.allowed = true;
      await reminder().reconcile();
      expect(os.pending, hasLength(1));
    },
  );

  test(
    'a resume while the permission prompt is open does not undo it',
    () async {
      // Found on the S20: the prompt backgrounds the app, and the
      // reconcile-on-resume used to overwrite the result with "Turning on".
      os
        ..grantOnRequest = false
        ..promptOpen = Completer<void>();
      await view();
      final switching = reminder().setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(reminderControllerProvider).value!.turningOn, isTrue);
      final resumed = reminder().reconcile();
      os.promptOpen!.complete();
      await switching;
      await resumed;
      final v = c.read(reminderControllerProvider).value!;
      expect(v.turningOn, isFalse);
      expect(v.intent.enabled, isTrue);
      expect(v.permission, NotificationPermission.denied);
    },
  );

  test('changing the day or time replaces the one reminder', () async {
    os.allowed = true;
    await view();
    await reminder().setEnabled(true);
    await reminder().setDayAndTime(weekday: DateTime.monday);
    await reminder().setDayAndTime(hour: 8, minute: 30);
    expect(os.pending, hasLength(1));
    expect(os.pending[reminderNotificationId], (
      weekday: DateTime.monday,
      hour: 8,
      minute: 30,
      zone: 'Europe/London',
    ));
    expect(os.requests, 0, reason: 'already allowed: no prompt');
  });

  test('switching off cancels it and keeps the chosen day and time', () async {
    os.allowed = true;
    await view();
    await reminder().setEnabled(true);
    await reminder().setDayAndTime(weekday: DateTime.wednesday);
    await reminder().setEnabled(false);
    expect(os.pending, isEmpty);
    final row = await db.select(db.reminder).getSingle();
    expect(row.enabled, isFalse);
    expect(row.weekday, DateTime.wednesday);
    expect(log.events.last, DiagnosticEvent.reminderCancelled);
  });

  group('reconcile', () {
    Future<void> scheduled() async {
      os.allowed = true;
      await view();
      await reminder().setEnabled(true);
    }

    test('nothing changed: the OS schedule is left alone', () async {
      await scheduled();
      final before = os.schedules;
      await reminder().reconcile();
      await reminder().reconcile();
      expect(os.schedules, before);
    });

    test('permission revoked in Settings: cancelled and reported', () async {
      await scheduled();
      os.allowed = false;
      await reminder().reconcile();
      final v = c.read(reminderControllerProvider).value!;
      expect(v.permission, NotificationPermission.denied);
      expect(v.scheduled, isFalse);
      expect(v.intent.enabled, isTrue, reason: 'the choice is kept');
      expect(os.pending, isEmpty);
    });

    test('a time-zone change reschedules in the new zone', () async {
      await scheduled();
      os.zone = 'America/New_York';
      await reminder().reconcile();
      expect(os.pending[reminderNotificationId]!.zone, 'America/New_York');
      expect(os.pending[reminderNotificationId]!.hour, 18);
    });

    test('a schedule cleared by the OS (Force Stop) is put back', () async {
      await scheduled();
      os.pending.clear();
      await reminder().reconcile();
      expect(os.pending, hasLength(1));
    });

    test('a scheduling failure is reported and the choice kept', () async {
      os
        ..allowed = true
        ..failSchedule = true;
      await view();
      await reminder().setEnabled(true);
      final v = c.read(reminderControllerProvider).value!;
      expect(v.scheduleFailed, isTrue);
      expect(v.intent.enabled, isTrue);
      expect(log.events, contains(DiagnosticEvent.reminderScheduleFailed));
    });

    test('the stored reminder is restored on the next start', () async {
      await scheduled();
      c.dispose();
      os.pending.clear();
      c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          reminderSchedulerProvider.overrideWithValue(os),
          diagnosticLogProvider.overrideWithValue(log),
        ],
      );
      final v = await view();
      expect(v.intent.enabled, isTrue);
      expect(v.scheduled, isTrue);
      expect(os.pending, hasLength(1));
    });
  });

  group('next weekly date', () {
    setUpAll(tz_data.initializeTimeZones);

    tz.TZDateTime at(String zone, int y, int m, int d, int h, [int min = 0]) =>
        tz.TZDateTime(tz.getLocation(zone), y, m, d, h, min);

    test('later this week', () {
      // Friday 6 November 2026, 1:41 pm.
      final next = nextWeekly(
        at('Europe/London', 2026, 11, 6, 13, 41),
        weekday: DateTime.sunday,
        hour: 18,
        minute: 0,
      );
      expect(next, at('Europe/London', 2026, 11, 8, 18));
    });

    test('today, still to come, and already past', () {
      final now = at('Europe/London', 2026, 11, 8, 12);
      expect(
        nextWeekly(now, weekday: DateTime.sunday, hour: 18, minute: 0),
        at('Europe/London', 2026, 11, 8, 18),
      );
      expect(
        nextWeekly(now, weekday: DateTime.sunday, hour: 9, minute: 0),
        at('Europe/London', 2026, 11, 15, 9),
      );
    });

    test('keeps the wall-clock time across the clocks going back', () {
      // Friday 23 October 2026; UK clocks go back on Sunday 25 October.
      final next = nextWeekly(
        at('Europe/London', 2026, 10, 23, 12),
        weekday: DateTime.sunday,
        hour: 18,
        minute: 0,
      );
      expect((next.day, next.hour, next.minute), (25, 18, 0));
      expect(next.timeZoneOffset, Duration.zero);
    });
  });
}
