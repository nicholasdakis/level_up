import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// Top-level entry point required by flutter_foreground_task, runs in a separate isolate
// so it has no access to Flutter widgets or providers, only the task handler API
@pragma('vm:entry-point')
void workoutTaskHandler() {
  FlutterForegroundTask.setTaskHandler(_WorkoutTaskHandler());
}

// Handles the foreground service lifecycle in its own isolate
class _WorkoutTaskHandler extends TaskHandler {
  int _startedAtMs = 0;
  String _notificationText = 'Keep it up!';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // read the workout start time saved by the main isolate before the service was started
    _startedAtMs =
        await FlutterForegroundTask.getData<int>(key: 'started_at_ms') ??
        DateTime.now().millisecondsSinceEpoch;
    _notificationText =
        await FlutterForegroundTask.getData<String>(key: 'notification_text') ??
        'Keep it up!';
  }

  @override
  void onNotificationPressed() {
    // tapping the notification body brings the workout screen back to front
    FlutterForegroundTask.sendDataToMain({'button': 'resume'});
  }

  @override
  void onNotificationButtonPressed(String id) {
    // button id is forwarded to the main isolate which handles all workout logic
    FlutterForegroundTask.sendDataToMain({'button': id});
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // use the event timestamp rather than DateTime.now() for slightly more accurate scheduling
    // compute elapsed from the original start time rather than incrementing a counter
    // so the timer stays accurate even if Android delays or skips a callback
    final elapsedSeconds =
        (timestamp.millisecondsSinceEpoch - _startedAtMs) ~/ 1000;
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;
    final timeStr = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    FlutterForegroundTask.updateService(
      notificationTitle: 'Workout in progress · $timeStr',
      notificationText: _notificationText,
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {
    // called when the main isolate sends data via sendDataToTask (e.g. new exercise or set count)
    if (data is Map) {
      final text = data['notification_text'] as String?;
      if (text != null) _notificationText = text;
    }
  }
}

// Static API used by ActiveWorkoutScreen to control the foreground service
class WorkoutForegroundService {
  // must be called once at app start (in main.dart) to configure the notification channel
  // notification channel settings are locked in on Android 8.0+ after first creation
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'workout_channel_2',
        channelName: 'Workout',
        channelDescription: 'Shows your active workout progress',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          1000,
        ), // fires onRepeatEvent every second
        autoRunOnBoot: false,
        allowWakeLock:
            true, // keeps CPU alive so the timer doesn't drift when screen is off
      ),
    );
  }

  static Future<void> start({
    required int startedAtMs,
    required String notificationText,
  }) async {
    if (kIsWeb) return;
    // persist start time before launching the isolate so onStart can read it
    await FlutterForegroundTask.saveData(
      key: 'started_at_ms',
      value: startedAtMs,
    );
    await FlutterForegroundTask.saveData(
      key: 'notification_text',
      value: notificationText,
    );

    if (await FlutterForegroundTask.isRunningService) {
      // restart preserves the callback so the isolate picks up the new start time
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: 'Workout in progress',
      notificationText: notificationText,
      notificationButtons: [
        const NotificationButton(id: 'rest_add', text: '+15s'),
        const NotificationButton(id: 'rest_skip', text: 'Skip Rest'),
      ],
      callback: workoutTaskHandler,
    );
  }

  // sends updated notification body text to the isolate without restarting the service
  static Future<void> update({required String notificationText}) async {
    if (kIsWeb) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    FlutterForegroundTask.sendDataToTask({
      'notification_text': notificationText,
    });
  }

  // called when the workout is finished or discarded to remove the notification
  static Future<void> stop() async {
    if (kIsWeb) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
