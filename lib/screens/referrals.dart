import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import '../guest.dart';
import '../providers/user_data_provider.dart';
import '../utility/responsive.dart';
import 'package:share_plus/share_plus.dart';
import '../services/user_data_manager.dart'
    show authenticatedGet, defaultAppColor;
import 'level_up_overlay.dart';

// Checks for a pending referral reward and shows the claim dialog if one exists
Future<void> checkPendingReferralReward(
  BuildContext context,
  StateSetter setState,
  Color appColor,
  WidgetRef ref,
) async {
  final res = await authenticatedGet('pending_referral_reward');
  if (!context.mounted) return;
  if (res.statusCode != 200) return;
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (data['pending'] != true) return;

  final appColor = ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );
  final refereeUid = data['referee_uid'] as String;
  final refereeUsername = data['referee_username'] as String;

  await showFrostedAlertDialog(
    context: context,
    appColor: appColor,
    title: "Referral Reward!",
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedUserAdd01,
          color: Colors.white,
          size: Responsive.scale(context, 40),
        ),
        SizedBox(height: Responsive.height(context, 12)),
        Text(
          "$refereeUsername used your referral code!",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 15),
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: Responsive.height(context, 8)),
        Text(
          "Claim your XP reward below.",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            color: Colors.white38,
          ),
        ),
      ],
    ),
    actions: [
      Expanded(
        child: Center(
          child: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                final prevLevel = ref.read(userDataProvider).value?.level ?? 0;
                final claimData = await ref
                    .read(userDataProvider.notifier)
                    .claimReferralReward(refereeUid);
                if (!context.mounted) return;
                if (claimData != null) {
                  if (prevLevel < 3 &&
                      (ref.read(userDataProvider).value?.level ?? 0) >= 3) {
                    logAnalyticsEvent('reached_level_3');
                  }
                  if (context.mounted) {
                    await handleLevelUpOverlay(
                      context,
                      prevLevel,
                      appColor,
                      ref,
                    );
                  }
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("+${claimData['xp_awarded']} XP claimed!"),
                      duration: snackBarDuration,
                    ),
                  );
                }
              },
              child: Text("Claim XP", style: dialogButtonStyle(confirm: true)),
            ),
          ),
        ),
      ),
    ],
  );
}

// Referrals card widget for the home dashboard
Widget buildReferralsCard(BuildContext context, Color appColor, WidgetRef ref) {
  // Square action tile matching the Watch an Ad card layout
  return Builder(
    builder: (context) {
      final base = appColor;
      final radius = BorderRadius.circular(Responsive.scale(context, 16));
      final referralCount =
          ref.read(userDataProvider).value?.referralCount ?? 0;
      final c = cardColors(base);
      final accent = c.onCard;
      final accentDim = onTheme(appColor);

      final card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c.gradient,
          ),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: c.splashColor,
              highlightColor: c.highlightColor,
              onTap: () async {
                logAnalyticsEvent('tap_referral_card');
                final codeInputController = TextEditingController();
                // Use cached code or fetch/generate one
                final code = await ref
                    .read(userDataProvider.notifier)
                    .fetchReferralCode();
                if (!context.mounted) return;
                if (code == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Failed to load referral code. Check your connection and try again.",
                      ),
                      duration: snackBarDuration,
                    ),
                  );
                  return;
                }
                showFrostedAlertDialog(
                  context: context,
                  appColor: appColor,
                  title: "Refer a Friend",
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...[
                        ("1", "Share your code with a friend"),
                        ("2", "They sign up and enter your code"),
                        ("3", "Once they reach level 3, you both earn XP"),
                      ].map(
                        (step) => Padding(
                          padding: EdgeInsets.only(
                            bottom: Responsive.height(context, 8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: Responsive.scale(context, 22),
                                height: Responsive.scale(context, 22),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: appColor.withAlpha(80),
                                  border: Border.all(color: Colors.white),
                                ),
                                child: Center(
                                  child: Text(
                                    step.$1,
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 11),
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: Responsive.width(context, 10)),
                              Expanded(
                                child: Text(
                                  step.$2,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 13),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 8)),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Referral code copied!"),
                              duration: snackBarDuration,
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 20),
                            vertical: Responsive.height(context, 10),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 12),
                            ),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                code,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 18),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              SizedBox(width: Responsive.width(context, 10)),
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedCopy01,
                                color: Colors.white,
                                size: Responsive.scale(context, 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 12)),
                      Center(
                        child: Text(
                          "${ref.read(userDataProvider).value?.referralCount ?? 0} friend${(ref.read(userDataProvider).value?.referralCount ?? 0) == 1 ? '' : 's'} referred",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Divider(
                        color: onTheme(appColor).withAlpha(120),
                        height: Responsive.height(context, 32),
                      ),
                      if (ref.read(userDataProvider).value?.referralUsed ==
                          true) ...[
                        Center(
                          child: Text(
                            "Each account can only enter a referral code once, but you can refer as many friends as you'd like.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 13),
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          "Have a referral code?",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 8)),
                        TextField(
                          controller: codeInputController,
                          style: GoogleFonts.manrope(color: Colors.white),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(8),
                          ],
                          decoration: InputDecoration(
                            hintText: "Enter code",
                            hintStyle: GoogleFonts.manrope(
                              color: Colors.white38,
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            suffixIcon: IconButton(
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                color: Colors.white,
                                size: Responsive.scale(context, 20),
                              ),
                              onPressed: () async {
                                final entered = codeInputController.text
                                    .trim()
                                    .toUpperCase();
                                if (entered.isEmpty) return;
                                final prevLevel2 =
                                    ref.read(userDataProvider).value?.level ??
                                    0;
                                final data = await ref
                                    .read(userDataProvider.notifier)
                                    .useReferralCode(entered);
                                if (!context.mounted) return;
                                if (data != null) {
                                  if (prevLevel2 < 3 &&
                                      (ref
                                                  .read(userDataProvider)
                                                  .value
                                                  ?.level ??
                                              0) >=
                                          3) {
                                    logAnalyticsEvent('reached_level_3');
                                  }
                                  if (context.mounted) {
                                    await handleLevelUpOverlay(
                                      context,
                                      prevLevel2,
                                      appColor,
                                      ref,
                                    );
                                  }
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Referral code applied! +${data['xp_awarded']} XP",
                                      ),
                                      duration: snackBarDuration,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Something went wrong'),
                                      duration: snackBarDuration,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: Text("Close", style: dialogButtonStyle()),
                    ),
                    TextButton(
                      onPressed: () async {
                        logAnalyticsEvent('tap_invite_friend');
                        final message =
                            "I've been using Level Up to track my health and it's actually fun. Join me and we both get XP bonuses!\n\nDownload it here: https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup\n\nUse my referral code: $code";
                        if (kIsWeb) {
                          await Clipboard.setData(ClipboardData(text: message));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Invite message copied!"),
                                duration: snackBarDuration,
                              ),
                            );
                          }
                          return;
                        }
                        SharePlus.instance.share(ShareParams(text: message));
                      },
                      child: Text(
                        "Invite a Friend",
                        style: dialogButtonStyle(confirm: true),
                      ),
                    ),
                  ],
                );
              },
              child: Padding(
                padding: EdgeInsets.all(Responsive.scale(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Icon at the top of the tile
                    themedIconBox(
                      context,
                      icon: HugeIcons.strokeRoundedUserAdd01,
                      color: base,
                      iconSize: 22,
                      padding: 8,
                      radius: 10,
                      hugeIcon: true,
                    ),
                    SizedBox(height: Responsive.height(context, 8)),
                    Text(
                      "Refer a Friend",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 14),
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      referralCount == 1
                          ? '1 referred'
                          : '$referralCount referred',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        color: accentDim,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (!isGuest) return card;

      return GestureDetector(
        onTap: () => Guest.block(
          context,
          title: 'Sign up to refer friends',
          description:
              'Create a free account to invite friends and earn bonus XP for every referral.',
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(child: Opacity(opacity: 0.35, child: card)),
            guestLockOverlay(context, appColor),
          ],
        ),
      );
    },
  );
}
