import 'dart:math';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../services/user_data_manager.dart';

class DailyRewardDialog {
  String randomRewardReminderMessage() {
    List<String> reminderMessages = [
      "23 hours have passed, come claim your daily reward!",
      "Come claim your daily reward!",
      "Come claim your free daily XP!",
      "Your free daily XP is waiting for you!",
      "Don't lose your daily reward streak!",
      "Come claim your free daily XP to get ahead on the leaderboard!",
      "Don't forget to claim your free experience points!",
      "Ready to boost your level? Claim your reward now!",
      "Your daily XP is waiting! Don't miss out!",
      "Time to grab today's reward and level up!",
      "Daily reward alert! Claim it before it's gone!",
      "Keep the streak alive! Claim your reward!",
      "Stay ahead! Collect your daily reward now!",
    ];
    final random = Random();
    int randomIndex = random.nextInt(reminderMessages.length);
    return reminderMessages[randomIndex];
  }

  // Schedules a reminder notification 23 hours after claiming via the backend
  Future<void> setDailyRewardNotification() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();

    final scheduledTime = DateTime.now().add(const Duration(hours: 23));
    final id =
        DateTime.now().millisecondsSinceEpoch; // unique ID for the reminder

    await http.post(
      Uri.parse('$backendBaseUrl/set_reminder'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_token': token,
        'message': randomRewardReminderMessage(),
        'scheduled_at': scheduledTime.toUtc().toIso8601String(),
        'notification_id': id,
      }),
    );
  }

  Future<void> showDailyRewardDialog(
    BuildContext context,
    ConfettiController controller,
  ) async {
    // Claim the daily reward from backend first to get the actual XP awarded
    final xpAwarded = await userManager.claimDailyReward();

    // If claim failed or cooldown not met, do nothing
    if (xpAwarded == null) return;

    if (!context.mounted) return;

    // Show claim Dialog after the backend XP is fetched
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Daily Reward!", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Display XP awarded from backend
            Text("You gained $xpAwarded XP!", textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              // just a visual button; the claiming is already done
              onPressed: () => Navigator.pop(context),
              child: Text("CLAIM"),
            ),
          ),
        ],
      ),
    );

    // Update XP bar now that the dialog has been dismissed
    expNotifier.value = currentUserData!.expPoints;

    // Set a reminder 23 hours from now
    if (currentUserData!.notificationsEnabled) {
      await setDailyRewardNotification();
    }
    // Show the confetti celebration
    controller.play();
  }
}
