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
  }

  Future<void> showDailyRewardDialog(
    BuildContext context,
    ConfettiController controller,
  ) async {
    // Claim the daily reward from backend first to get the actual XP awarded
    final xpAwarded = await userManager.claimDailyReward();

    // If claim failed or cooldown not met, do nothing
    if (xpAwarded == null) return;

    // Show claim Dialog after have the backend XP is fetched
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
              // Display XP awarded from backend
              Text(
                "You gained $xpAwarded XP!",
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                // just a visual button; the claiming is already done
                child: Text("CLAIM", style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ).then((_) async {
        // Set a reminder 23 hours from now
        if (currentUserData!.notificationsEnabled) {
          await setDailyRewardNotification();
        }
        // Show the confetti celebration
        controller.play();
      });
    });
  }
}
