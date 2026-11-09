import 'dart:async';

import 'package:poop_tracker/core/notifications/reminder_scheduler.dart';

/// A pending OS reminder, as the fake scheduler holds it.
typedef PendingReminder = ({int weekday, int hour, int minute, String zone});

/// In-memory stand-in for the OS scheduler.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({
    this.allowed = false,
    this.grantOnRequest = true,
    this.zone = 'Europe/London',
  });

  bool allowed;
  bool grantOnRequest;
  String zone;
  bool failSchedule = false;
  bool canOpen = true;

  /// When set, the permission prompt stays open until it completes.
  Completer<void>? promptOpen;

  final Map<int, PendingReminder> pending = {};
  int requests = 0;
  int schedules = 0;
  int cancels = 0;
  int settingsOpened = 0;

  @override
  Future<NotificationPermission> permission() async =>
      allowed ? NotificationPermission.granted : NotificationPermission.denied;

  @override
  Future<NotificationPermission> requestPermission() async {
    requests++;
    await promptOpen?.future;
    if (grantOnRequest) allowed = true;
    return permission();
  }

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    if (failSchedule) throw StateError('simulated scheduling failure');
    schedules++;
    pending[id] = (weekday: weekday, hour: hour, minute: minute, zone: zone);
  }

  @override
  Future<void> cancel(int id) async {
    cancels++;
    pending.remove(id);
  }

  @override
  Future<bool> isScheduled(int id) async => pending.containsKey(id);

  @override
  Future<String> timeZone() async => zone;

  @override
  bool get canOpenSettings => canOpen;

  @override
  Future<void> openSettings() async => settingsOpened++;
}
