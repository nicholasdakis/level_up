import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import '../guest.dart';
import '../services/user_data_manager.dart';
import 'level_up_overlay.dart';
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
    try {
      final scheduledTime = DateTime.now().add(const Duration(hours: 23));
      final id = DateTime.now().millisecondsSinceEpoch;

      await authenticatedPost(
        'set_reminder',
        body: {
          'message': randomRewardReminderMessage(),
          'scheduled_at': scheduledTime.toUtc().toIso8601String(),
          'notification_id': id,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule daily reward notification: $e');
      }
    }
  }

  Future<void> showDailyRewardDialog(
    BuildContext context,
    ConfettiController controller,
  ) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }

    final levelBefore = currentUserData?.level ?? 0;

    // Claim the daily reward from backend first to get the actual XP awarded
    final result = await userManager.claimDailyReward();

    if (result == null) return; // cooldown not met
    if (result.$1 == -1) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Failed to claim reward. Check your connection and try again.",
          ),
          duration: snackBarDuration,
        ),
      );
      return;
    }

    final (xpGained, baseXp, streak, multiplier) = result;

    FirebaseAnalytics.instance.logEvent(
      name: 'daily_reward_claimed',
      parameters: {
        'xp_gained': xpGained,
        'streak': streak,
        'multiplier': multiplier,
      },
    );

    if (!context.mounted) return;

    final color = currentUserData?.appColor ?? appColorNotifier.value;
    final accent = lightenColor(color, 0.45);
    final dim = lightenColor(color, 0.35);
    final faint = lightenColor(color, 0.3);
    const milestones = [(3, 1.1), (10, 1.25), (30, 1.4), (50, 1.5)];
    int? nextDays;
    double? nextMult;
    for (final (days, mult) in milestones) {
      if (streak < days) {
        nextDays = days;
        nextMult = mult;
        break;
      }
    }
    final milestoneProgress = nextDays != null
        ? (streak / nextDays).clamp(0.0, 1.0)
        : 1.0;

    await showFrostedDialog(
      context: context,
      dismissible: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            "Daily Reward",
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 18),
              fontWeight: FontWeight.w700,
              color: dim,
              letterSpacing: 0.5,
            ),
          ),

          SizedBox(height: Responsive.height(context, 20)),

          // XP hero number
          HugeIcon(
            icon: HugeIcons.strokeRoundedGift,
            color: accent,
            size: Responsive.scale(context, 32),
          ),
          SizedBox(height: Responsive.height(context, 10)),
          Text(
            "+$xpGained XP",
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 36),
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.0,
            ),
          ),
          if (multiplier > 1.0) ...[
            SizedBox(height: Responsive.height(context, 6)),
            Text(
              "$baseXp base + ${xpGained - baseXp} streak bonus",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                color: faint,
              ),
            ),
          ],

          SizedBox(height: Responsive.height(context, 16)),

          // Streak row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedFire,
                color: faint,
                size: Responsive.scale(context, 22),
              ),
              SizedBox(width: Responsive.width(context, 8)),
              Flexible(
                child: Text(
                  "$streak day${streak == 1 ? '' : 's'} in a row",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 20),
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: Responsive.height(context, 16)),

          // Milestone progress
          if (nextDays != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
              child: LinearProgressIndicator(
                value: milestoneProgress,
                minHeight: Responsive.height(context, 7),
                backgroundColor: Colors.white.withAlpha(15),
                valueColor: AlwaysStoppedAnimation(faint),
              ),
            ),
            SizedBox(height: Responsive.height(context, 8)),
            Text(
              "${nextDays - streak} day${nextDays - streak == 1 ? '' : 's'} until ${nextMult}x streak bonus",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 12),
                color: dim,
              ),
            ),
          ] else ...[
            Text(
              "Max streak bonus active (${multiplier}x)",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 12),
                color: dim,
              ),
            ),
          ],

          SizedBox(height: Responsive.height(context, 24)),

          // Claim button; the claiming is already done before this dialog shows
          Center(
            child: Builder(
              builder: (dialogContext) => TextButton(
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 24),
                    vertical: Responsive.height(context, 4),
                  ),
                  minimumSize: Size.zero,
                ),
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
                child: Text("CLAIM", style: dialogButtonStyle(confirm: true)),
              ),
            ),
          ),
        ],
      ),
    );

    expNotifier.value = currentUserData!.expPoints;
    if (context.mounted) await handleLevelUpOverlay(context, levelBefore);

    // Set a reminder 23 hours from now
    if (currentUserData!.notificationsEnabled) {
      await setDailyRewardNotification();
    }
    // Show the confetti celebration
    controller.play();
  }
}
