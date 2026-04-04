import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../globals.dart';

class DailyRewardDialog {
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

  // Schedules a reminder notification 23 hours after claiming, using the same firestore-based reminder system that the Reminders screen uses
  Future<void> setDailyRewardNotification() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final scheduledTime = DateTime.now().add(const Duration(hours: 23));
    final id =
        DateTime.now().millisecondsSinceEpoch; // unique ID for the reminder

    await FirebaseFirestore.instance
        .collection('users-private')
        .doc(uid)
        .collection('reminders')
        .add({
          'message': randomRewardReminderMessage(),
          'dateTime': scheduledTime.toUtc().toIso8601String(),
          'notificationId': id,
        });

    debugPrint('Daily reward reminder scheduled for: $scheduledTime');
  }

  Future<void> showDailyRewardDialog(
    BuildContext context,
    ConfettiController controller,
  ) async {
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
        bool claimed = await userManager
            .claimDailyReward(); // handles the claiming, including any exp updates
        if (claimed) {
          // Set a reminder 23 hours from now
          await setDailyRewardNotification();

          // show the confetti
          controller.play();
        }
      });
    });
  }
}
