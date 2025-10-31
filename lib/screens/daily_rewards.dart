import 'dart:math';
import 'package:flutter/material.dart';
import '../globals.dart';

class DailyRewardDialog {
  static void showDailyRewardDialog(BuildContext context) async {
    if (currentUserData == null) return;

    // Check if user can claim
    if (!currentUserData!.canClaimDailyReward) return;

    // Random XP based on level
    final xpGain =
        25 * currentUserData!.level +
        2 * (Random().nextInt(currentUserData!.level) + 1);

    // Show dialog and only claim XP when dialog closes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
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
        // Only after dialog is closed, claim the reward and update XP
        bool claimed = await userManager.claimDailyReward();
        if (claimed) {
          await userManager.updateExpPoints(xpGain);
        }
      });
    });
  }
}
