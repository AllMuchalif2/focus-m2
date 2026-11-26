import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? notificationsPlugin})
      : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _isInitialized = true;
  }

  Future<void> scheduleTimerNotification({
    required DateTime endAt,
    required String title,
    required String body,
    int id = 1001,
  }) async {
    await initialize();

    final scheduledDate = tz.TZDateTime.from(endAt, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'timer_channel',
        'Timer Notifications',
        channelDescription: 'Pemberitahuan saat sesi Pomodoro selesai',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelTimerNotification({int id = 1001}) async {
    await initialize();
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _notificationsPlugin.cancelAll();
  }
}
