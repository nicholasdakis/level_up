import 'dart:math';
import 'package:flutter/material.dart';
import '../globals.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DailyRewardDialog {
  // Method for scheduling a reminder notification 23 hours after claiming the Daily Reward
  String randomRewardReminderMessage() {
    List<String> reminderMessages = [
      "Come claim your daily reward!",
      "Don't forget to claim your free experience points!",
      "Ready to boost your level? Claim your reward now!",
      "Your daily XP is waiting! Don't miss out!",
      "Time to grab today's reward and level up!",
      "Daily reward alert! Claim it before it's gone!",
      "Keep the streak alive! Claim your reward!",
      "Unlock new achievements with your daily reward!",
      "Your adventure continues—claim your daily XP!",
      "Stay ahead! Collect your daily reward now!",
    ];
    final random = Random();
    int randomIndex = random.nextInt(reminderMessages.length);
    return reminderMessages[randomIndex];
  }

  Future<void> setDailyRewardNotification() async {
    const int notificationId = 1; // Unique ID for notification
    final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(hours: 23));
    debugPrint('Notification scheduled for: $scheduledTime');

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'User reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Daily Reward Available!',
      randomRewardReminderMessage(),
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showDailyRewardDialog(BuildContext context) async {
    // Random XP based on level
    final xpGain =
        25 * currentUserData!.level +
        2 * (Random().nextInt(currentUserData!.level) + 1);

    // Show claim Dialog and only claim XP when Dialog closes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: appColorNotifier.value.withAlpha(200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Daily Reward!",
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "You gained $xpGain XP!",
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                // just a visual button, the claiming is done when the dialog box closes
                child: Text("CLAIM", style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ).then((_) async {
        bool claimed = await userManager.claimDailyReward();
        if (claimed) {
          // update experience on Firebase
          await userManager.updateExpPoints(xpGain);
          await setDailyRewardNotification();
        }
      });
    });
  }
}
