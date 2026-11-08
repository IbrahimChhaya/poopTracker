import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// What the OS says about showing morrow's notifications.
enum NotificationPermission { granted, denied }

/// The reminder's only wording. Generic on purpose: no entries, history or
/// details ever go into a notification or its payload.
const String reminderTitle = 'Weekly check-in';
const String reminderBody = 'Ready to add an entry?';

/// The OS scheduler for the single weekly reminder. No Dart timers,
/// background services or polling: the OS delivers it, and the plugin's
/// boot receiver reschedules it after a reboot from its own stored copy
/// (generic text only), without opening the journal.
abstract interface class ReminderScheduler {
  Future<NotificationPermission> permission();

  /// Shows the OS permission prompt (Android 13+, iOS).
  Future<NotificationPermission> requestPermission();

  /// Schedules (or replaces) notification [id] for every [weekday] (ISO,
  /// 1 = Monday) at [hour]:[minute] local wall-clock time in the phone's
  /// current time zone.
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
  });

  /// Cancels the pending reminder and removes a delivered one.
  Future<void> cancel(int id);

  /// Whether the OS holds a pending reminder with [id].
  Future<bool> isScheduled(int id);

  /// The phone's IANA time zone, for example "Europe/London".
  Future<String> timeZone();

  /// Whether [openSettings] can open morrow's notification settings here.
  bool get canOpenSettings;

  Future<void> openSettings();
}

/// The first [weekday] at [hour]:[minute] strictly after [now], in [now]'s
/// zone.
tz.TZDateTime nextWeekly(
  tz.TZDateTime now, {
  required int weekday,
  required int hour,
  required int minute,
}) {
  var at = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  final ahead = (weekday - at.weekday) % 7;
  at = tz.TZDateTime(
    at.location,
    at.year,
    at.month,
    at.day + ahead,
    hour,
    minute,
  );
  if (!at.isAfter(now)) {
    at = tz.TZDateTime(
      at.location,
      at.year,
      at.month,
      at.day + 7,
      hour,
      minute,
    );
  }
  return at;
}

/// [ReminderScheduler] using flutter_local_notifications 22, timezone and
/// flutter_timezone. Inexact Android scheduling; no exact-alarm permission.
class PluginReminderScheduler implements ReminderScheduler {
  PluginReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const MethodChannel _system = MethodChannel('morrow/privacy');

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'weekly_checkin',
      'Weekly check-in',
      channelDescription: 'One weekly reminder to add an entry.',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ask only when the reminder is switched on, never at startup.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<NotificationPermission> permission() async {
    await _init();
    final bool? on = defaultTargetPlatform == TargetPlatform.iOS
        ? (await _ios?.checkPermissions())?.isEnabled
        : await _android?.areNotificationsEnabled();
    return on ?? false
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    await _init();
    final bool? on = defaultTargetPlatform == TargetPlatform.iOS
        ? await _ios?.requestPermissions(alert: true, sound: true)
        : await _android?.requestNotificationsPermission();
    return on ?? false
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  @override
  Future<String> timeZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    await _init();
    // The phone's current zone, by its IANA name (never guessed from an
    // offset). Read every time, so a reconcile after travel follows it.
    final location = tz.getLocation(await timeZone());
    tz.setLocalLocation(location);
    await _plugin.zonedSchedule(
      id: id,
      title: reminderTitle,
      body: reminderBody,
      scheduledDate: nextWeekly(
        tz.TZDateTime.now(location),
        weekday: weekday,
        hour: hour,
        minute: minute,
      ),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<bool> isScheduled(int id) async {
    await _init();
    return (await _plugin.pendingNotificationRequests()).any((r) => r.id == id);
  }

  @override
  bool get canOpenSettings => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> openSettings() async {
    try {
      await _system.invokeMethod<void>('openNotificationSettings');
    } on MissingPluginException {
      // Not available on this platform.
    } on PlatformException {
      // The settings screen could not be opened.
    }
  }
}
