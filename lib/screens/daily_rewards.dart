import 'dart:math';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../services/user_data_manager.dart';
import '../utility/responsive.dart';

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
    final result = await userManager.claimDailyReward();

    // If claim failed or cooldown not met, do nothing
    if (result == null) return;

    final (xpGained, baseXp, streak, multiplier) = result;

    if (!context.mounted) return;

    // Show claim Dialog after the backend XP is fetched
    await showFrostedAlertDialog(
      context: context,
      title: "Daily Reward!",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: Responsive.height(context, 16),
          ), // vertical spacing scaled to screen height

          Divider(
            indent: 24,
            endIndent: 24,
          ), // horizontal divider with left/right padding

          SizedBox(
            height: Responsive.height(context, 12),
          ), // spacing below divider

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center, // centers icon + text horizontally
            children: [
              Icon(
                Icons.local_fire_department, // fire icon to represent streak
                color: lightenColor(
                  appColorNotifier.value,
                  0.3,
                ), // slightly lighter than theme color
                size: Responsive.font(context, 20), // responsive icon size
              ),
              SizedBox(
                width: Responsive.width(context, 6),
              ), // space between icon and text
              Text(
                "$streak day streak", // dynamic streak value
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.font(
                    context,
                    16,
                  ), // responsive font size
                  fontWeight: FontWeight.w600, // semi-bold for emphasis
                  color: lightenColor(
                    appColorNotifier.value,
                    0.3,
                  ), // matches icon color
                ),
              ),
            ],
          ),

          // only show bonus text if multiplier is actually active (>1)
          if (multiplier > 1.0) ...[
            SizedBox(
              height: Responsive.height(context, 10),
            ), // spacing before bonus text
            Text(
              "${multiplier}x streak bonus (+${xpGained - baseXp} XP)",
              // shows multiplier + extra XP gained beyond base
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.font(
                  context,
                  13,
                ), // slightly smaller than main text
                color: lightenColor(
                  appColorNotifier.value,
                  0.2,
                ), // more subtle color
              ),
            ),
          ],

          Builder(
            builder: (context) {
              // milestone thresholds: (days required, multiplier unlocked)
              const milestones = [(3, 1.1), (10, 1.25), (30, 1.4), (50, 1.5)];

              for (final (days, mult) in milestones) {
                // find the NEXT milestone the user hasn't reached yet
                if (streak < days) {
                  final daysAway =
                      days - streak; // how many days left to reach it
                  return Padding(
                    padding: EdgeInsets.only(
                      top: Responsive.height(context, 6),
                    ), // spacing above hint text
                    child: Text(
                      "$daysAway day${daysAway == 1 ? '' : 's'} away from ${mult}x bonus",
                      // pluralizes "day" correctly + shows next multiplier target
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: Responsive.font(
                          context,
                          12,
                        ), // smallest text in section
                        color: Colors.white38, // low emphasis hint text
                      ),
                    ),
                  );
                }
              }
              // if user passed all milestones, they have the highest possible streak
              return Padding(
                padding: EdgeInsets.only(top: Responsive.height(context, 6)),
                child: Text(
                  "Highest streak bonus unlocked (${multiplier}x)",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.font(context, 12),
                    color: Colors.white38,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          // just a visual button; the claiming is already done
          onPressed: () => Navigator.pop(context),
          child: Text("CLAIM"),
        ),
      ],
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
