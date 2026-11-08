import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminder_planner.dart';

/// Schedules reminders as local notifications on Android.
/// On the web this does nothing; reminders show inside the app instead.
class NotificationService {
  NotificationService();

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _details = AndroidNotificationDetails(
    'cyclesync_reminders',
    'Reminders',
    channelDescription: 'Period, check-in and other reminders you set.',
    icon: 'ic_notification',
    visibility: NotificationVisibility.private,
  );

  AndroidFlutterLocalNotificationsPlugin? _android;
  bool _ready = false;

  Future<AndroidFlutterLocalNotificationsPlugin?> _init() async {
    if (!supported) return null;
    if (_ready) return _android;
    tzdata.initializeTimeZones();
    try {
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      final String name =
          info is String ? info : (info.identifier as String);
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to UTC; one-off reminders still fire at the right moment.
    }
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return null;
    await android.initialize(
      settings: const AndroidInitializationSettings('ic_notification'),
    );
    _android = android;
    _ready = true;
    return android;
  }

  /// Asks for permission to show notifications. Returns false if refused.
  Future<bool> requestPermission() async {
    final android = await _init();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> cancelAll() async {
    final android = await _init();
    await android?.cancelAll();
  }

  /// Replaces all scheduled reminders with [reminders].
  Future<void> apply(List<PlannedReminder> reminders) async {
    final android = await _init();
    if (android == null) return;
    await android.cancelAll();
    for (final r in reminders) {
      final when = tz.TZDateTime.from(r.at, tz.local);
      await android.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: when,
        notificationDetails: _details,
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents:
            r.repeatsDaily ? DateTimeComponents.time : null,
      );
    }
  }
}
