// notification_setup.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import '../globals.dart'; // For flutterLocalNotificationsPlugin
import 'package:flutter/foundation.dart';

Future<void> initializeNotificationsAndTimezones() async {
  // Initialize timezones
  tz.initializeTimeZones();

  // Set user's local timezone
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneString = timezoneInfo.toString();
    final String timeZoneName =
        timeZoneString // Splits to get the part of the important part of the timezone, e.g "America/New_York"
            .split('(')[1]
            .split(')')[0]
            .split(',')[0];
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    tz.setLocalLocation(
      tz.getLocation('UTC'),
    ); // Default to UTC if there are errors
  }

  // Platform-specific notification settings
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  ); // global notification variable from globals.dart

  // Create channel manually (required for Xiaomi / Android 12+)
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'reminder_channel',
          'Reminders',
          description: 'User reminders',
          importance: Importance.max,
        ),
      );

  await _requestNotificationPermissions();
}

Future<void> _requestNotificationPermissions() async {
  // For Android 13+ notification permission
  if (defaultTargetPlatform == TargetPlatform.android) {
    await Permission.notification.request();

    // Request exact alarm permission for Android 12+
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
    }
  }

  // iOS
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  // macOS
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}
