import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/scope.dart';
import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/notifications/reminder_scheduler.dart';
import '../data/reminder_repository.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(ref.watch(appDatabaseProvider)),
  dependencies: [appDatabaseProvider],
);

/// What the Weekly reminder screen shows: the reminder the user asked for,
/// kept apart from what the OS allows and whether it is scheduled.
final class ReminderView {
  const ReminderView({
    required this.intent,
    required this.permission,
    required this.scheduled,
    this.turningOn = false,
    this.scheduleFailed = false,
  });

  final ReminderIntent intent;
  final NotificationPermission permission;

  /// The OS holds the pending reminder.
  final bool scheduled;

  /// The permission prompt is showing (6.2).
  final bool turningOn;

  /// The last attempt to schedule failed; the choice is still saved.
  final bool scheduleFailed;

  ReminderView copyWith({
    ReminderIntent? intent,
    NotificationPermission? permission,
    bool? scheduled,
    bool? turningOn,
    bool? scheduleFailed,
  }) => ReminderView(
    intent: intent ?? this.intent,
    permission: permission ?? this.permission,
    scheduled: scheduled ?? this.scheduled,
    turningOn: turningOn ?? this.turningOn,
    scheduleFailed: scheduleFailed ?? this.scheduleFailed,
  );
}

/// View model for the weekly reminder (6.1–6.5).
///
/// The stored intent is the source of truth; [reconcile] makes the OS
/// match it: scheduled when on and allowed, cancelled otherwise. It runs
/// when the journal opens, when the app comes back to the foreground (time
/// zone changes, permission revoked in Settings, Force Stop) and after every
/// change. Scheduling always replaces the one stable notification id, so
/// changes never add duplicates.
class ReminderController extends AsyncNotifier<ReminderView> {
  ReminderRepository get _repo => ref.read(reminderRepositoryProvider);
  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);
  DiagnosticLog get _log => ref.read(diagnosticLogProvider);

  /// What was last handed to the OS (day, time, zone), to skip needless
  /// rescheduling on every resume.
  String? _lastScheduled;

  /// Operations run one at a time, each starting from the latest state.
  /// (The permission prompt sends the app to the background, so a
  /// reconcile-on-resume can arrive while switching on is still running.)
  Future<void> _queue = Future.value();

  Future<void> _serial(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  @override
  Future<ReminderView> build() async {
    final intent = await _repo.read();
    return _reconcile(
      ReminderView(
        intent: intent,
        permission: await _permission(),
        scheduled: false,
      ),
    );
  }

  Future<NotificationPermission> _permission() async {
    try {
      return await _scheduler.permission();
    } on Object {
      return NotificationPermission.denied;
    }
  }

  Future<ReminderView> _reconcile(ReminderView v) async {
    final i = v.intent;
    try {
      if (i.enabled && v.permission == NotificationPermission.granted) {
        final zone = await _scheduler.timeZone();
        final signature =
            '${i.effectiveWeekday} ${i.effectiveHour}:${i.effectiveMinute} '
            '$zone';
        final pending = await _scheduler.isScheduled(i.notificationId);
        if (!pending || signature != _lastScheduled) {
          await _scheduler.scheduleWeekly(
            id: i.notificationId,
            weekday: i.effectiveWeekday,
            hour: i.effectiveHour,
            minute: i.effectiveMinute,
          );
          if (signature != _lastScheduled) {
            _log.record(DiagnosticEvent.reminderScheduled);
          }
          _lastScheduled = signature;
        }
        return v.copyWith(scheduled: true, scheduleFailed: false);
      }
      await _scheduler.cancel(i.notificationId);
      _lastScheduled = null;
      return v.copyWith(scheduled: false, scheduleFailed: false);
    } on Object {
      _log.record(DiagnosticEvent.reminderScheduleFailed);
      return v.copyWith(scheduled: false, scheduleFailed: true);
    }
  }

  /// Re-reads the OS permission and makes the schedule match the intent.
  Future<void> reconcile() => _serial(() async {
    final current = state.value;
    if (current == null || current.turningOn) return;
    final permission = await _permission();
    final next = await _reconcile(current.copyWith(permission: permission));
    if (ref.mounted) state = AsyncData(next);
  });

  Future<void> _save(ReminderIntent intent) => _repo.save(
    enabled: intent.enabled,
    weekday: intent.effectiveWeekday,
    hour: intent.effectiveHour,
    minute: intent.effectiveMinute,
  );

  /// Switching on asks for notification permission (only now, never at
  /// startup). A refusal still saves the reminder (6.4); journalling is
  /// never affected.
  Future<void> setEnabled(bool on) => _serial(() => _setEnabled(on));

  Future<void> _setEnabled(bool on) async {
    final current = state.value;
    if (current == null || current.turningOn) return;
    final intent = ReminderIntent(
      enabled: on,
      weekday: current.intent.effectiveWeekday,
      hour: current.intent.effectiveHour,
      minute: current.intent.effectiveMinute,
      notificationId: current.intent.notificationId,
    );
    var permission = current.permission;
    if (on && permission != NotificationPermission.granted) {
      state = AsyncData(current.copyWith(turningOn: true));
      try {
        permission = await _scheduler.requestPermission();
      } on Object {
        permission = NotificationPermission.denied;
      }
      if (permission != NotificationPermission.granted) {
        _log.record(DiagnosticEvent.reminderPermissionDenied);
      }
    }
    await _save(intent);
    if (!on) _log.record(DiagnosticEvent.reminderCancelled);
    final next = await _reconcile(
      current.copyWith(
        intent: intent,
        permission: permission,
        turningOn: false,
      ),
    );
    if (ref.mounted) state = AsyncData(next);
  }

  Future<void> setDayAndTime({int? weekday, int? hour, int? minute}) =>
      _serial(() => _setDayAndTime(weekday, hour, minute));

  Future<void> _setDayAndTime(int? weekday, int? hour, int? minute) async {
    final current = state.value;
    if (current == null) return;
    final i = current.intent;
    final intent = ReminderIntent(
      enabled: i.enabled,
      weekday: weekday ?? i.effectiveWeekday,
      hour: hour ?? i.effectiveHour,
      minute: minute ?? i.effectiveMinute,
      notificationId: i.notificationId,
    );
    await _save(intent);
    final next = await _reconcile(current.copyWith(intent: intent));
    if (ref.mounted) state = AsyncData(next);
  }

  Future<void> openSettings() => _scheduler.openSettings();
}

/// Lives with the unlocked session: it reads the journal database.
final reminderControllerProvider =
    AsyncNotifierProvider<ReminderController, ReminderView>(
      ReminderController.new,
      dependencies: [reminderRepositoryProvider],
    );
