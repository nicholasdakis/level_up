import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart';
import '../guest.dart';
import '../providers/user_data_provider.dart';
import '../services/user_data_manager.dart';
import 'level_up_overlay.dart';
import '../utility/responsive.dart';
import '../utility/shared_preferences/shared_prefs_async.dart';
import 'premium_sheet.dart' show showPremiumSheet;
import '../services/fcm/notification_service.dart'
    show requestNotificationPermissionIfNeeded;
import 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging, AuthorizationStatus;

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
    Color appColor,
    WidgetRef ref,
  ) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }

    // Check locally if the streak broke before claiming to intercept with the shield dialog first
    final userData = ref.read(userDataProvider).value;
    final lastClaim = userData?.lastDailyClaim;
    final currentStreak = userData?.dailyClaimStreak ?? 0;
    final streakBroke =
        lastClaim != null &&
        DateTime.now().toUtc().difference(lastClaim).inSeconds >= 172800 &&
        currentStreak > 0;

    final isFirstClaim = lastClaim == null;

    if (streakBroke && context.mounted) {
      final isPremium = userData?.isPremium ?? false;
      final shieldCount = userData?.shieldCount ?? 0;
      if (isPremium && shieldCount > 0) {
        // Premium with shields: offer restore before claiming
        final used = await _showShieldDialog(
          context,
          appColor,
          ref,
          shieldCount,
        );
        if (used) {
          return; // shield was used, streak restored, skip the normal claim
        }
      } else if (!isPremium) {
        final dismissed =
            await SharedPrefsService().getBool(
              SharedPreferencesKey.streakShieldDialogDismissed,
            ) ??
            false;
        if (!dismissed && context.mounted) {
          final shouldClaim = await _showShieldUpsellDialog(
            context,
            appColor,
            ref,
          );
          if (!shouldClaim) return;
        }
        // if dismissed previously or user chose to claim, fall through to claimDailyReward
      }
    }

    if (!context.mounted) return;

    // Claim the daily reward
    final result = await ref.read(userDataProvider.notifier).claimDailyReward();

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

    final (xpGained, baseXp, streak, multiplier, levelBefore) = result;
    final isPremium = userData?.isPremium ?? false;
    final preProXp = isPremium ? (xpGained / 1.2).round() : xpGained;
    final premiumBonus = xpGained - preProXp;
    final streakBonus = preProXp - baseXp;

    logAnalyticsEvent(
      'daily_reward_claimed',
      parameters: {
        'xp_gained': xpGained,
        'streak': streak,
        'multiplier': multiplier,
      },
    );

    if (!context.mounted) return;

    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final faint = lightenColor(appColor, 0.3);
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
      appColor: appColor,
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
          if (multiplier > 1.0 || premiumBonus > 0) ...[
            SizedBox(height: Responsive.height(context, 6)),
            Text(
              [
                '$baseXp base',
                if (streakBonus > 0) '+ $streakBonus streak bonus',
                if (premiumBonus > 0) '+ $premiumBonus premium bonus',
              ].join(' '),
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

    final updatedData = ref.read(userDataProvider).value;
    if (context.mounted) {
      await handleLevelUpOverlay(context, levelBefore, appColor, ref);
    }

    // On first ever claim, ask for notification permission before scheduling
    if (isFirstClaim && context.mounted) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (context.mounted) {
          await _showFirstClaimNotificationPrompt(context, appColor, ref);
        }
      }
    }

    // Set a reminder 23 hours from now
    if (updatedData?.notificationsEnabled ?? false) {
      await setDailyRewardNotification();
    }
    // Show the confetti celebration
    controller.play();
  }
}

Future<bool> _showShieldDialog(
  BuildContext context,
  Color appColor,
  WidgetRef ref,
  int shieldCount,
) async {
  final accent = lightenColor(appColor, 0.45);
  final dim = lightenColor(appColor, 0.35);
  final used = await showFrostedDialog<bool>(
    context: context,
    appColor: appColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedShield01,
          color: accent,
          size: 36,
        ),
        SizedBox(height: Responsive.height(context, 12)),
        Text(
          'Your streak broke.',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.height(context, 6)),
        Text(
          'Use a streak shield to restore it?\n$shieldCount shield${shieldCount == 1 ? '' : 's'} remaining this month.',
          style: GoogleFonts.manrope(
            color: dim,
            fontSize: Responsive.font(context, 13),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.height(context, 20)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
              child: Text('Skip', style: dialogButtonStyle()),
            ),
            TextButton(
              onPressed: () async {
                logAnalyticsEvent('shield_used');
                final result = await ref
                    .read(userDataProvider.notifier)
                    .useStreakShield();
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pop(result != null);
                if (result == null) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Streak restored to ${result.$2} days. ${result.$1} shield${result.$1 == 1 ? '' : 's'} left this month.',
                      style: GoogleFonts.manrope(),
                    ),
                    duration: snackBarDurationImportant,
                  ),
                );
              },
              child: Text(
                'Use Shield',
                style: dialogButtonStyle(confirm: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return used == true;
}

// Returns true if the user dismissed (should proceed to claim), false if they tapped Learn More (bail out)
Future<bool> _showShieldUpsellDialog(
  BuildContext context,
  Color appColor,
  WidgetRef ref,
) async {
  logAnalyticsEvent('shield_upsell_shown');
  final accent = lightenColor(appColor, 0.45);
  final dim = lightenColor(appColor, 0.35);
  final shouldClaim = await showFrostedDialog<bool>(
    context: context,
    appColor: appColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedShield01,
          color: accent,
          size: 36,
        ),
        SizedBox(height: Responsive.height(context, 12)),
        Text(
          'Your streak broke.',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.height(context, 6)),
        Text(
          'Next time, go Pro before this happens. Pro members get 3 shields a month to restore broken streaks instantly.',
          style: GoogleFonts.manrope(
            color: dim,
            fontSize: Responsive.font(context, 13),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.height(context, 20)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
              child: Text('Dismiss', style: dialogButtonStyle()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop(false);
                logAnalyticsEvent('shield_upsell_learn_more');
                showPremiumSheet(context, ref);
              },
              child: Text(
                'Learn More',
                style: dialogButtonStyle(confirm: true),
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.height(context, 4)),
        TextButton(
          onPressed: () async {
            await SharedPrefsService().setBool(
              SharedPreferencesKey.streakShieldDialogDismissed,
              true,
            );
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(true);
            }
          },
          child: Text(
            "Don't show again",
            style: GoogleFonts.manrope(
              color: Colors.white.withAlpha(60),
              fontSize: Responsive.font(context, 10),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
  return shouldClaim == true;
}

Future<void> _showFirstClaimNotificationPrompt(
  BuildContext context,
  Color appColor,
  WidgetRef ref,
) async {
  final accent = lightenColor(appColor, 0.45);
  final dim = lightenColor(appColor, 0.35);
  final confirmed = await showFrostedDialog<bool>(
    context: context,
    appColor: appColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedNotification01,
          color: accent,
          size: 36,
        ),
        SizedBox(height: Responsive.height(context, 12)),
        Text(
          'Never miss a reward',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.height(context, 6)),
        Text(
          'Enable notifications to get daily reminders, protect your streak, and never miss out on free XP.',
          style: GoogleFonts.manrope(
            color: dim,
            fontSize: Responsive.font(context, 13),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.height(context, 20)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
              child: Text('No thanks', style: dialogButtonStyle()),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
              child: Text(
                'Yes, remind me',
                style: dialogButtonStyle(confirm: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await requestNotificationPermissionIfNeeded(
      context,
      ref.read(userDataProvider.notifier),
      appColor: appColor,
      skipIfDenied: true,
    );
  }
}
