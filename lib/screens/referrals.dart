import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../services/user_data_manager.dart'
    show authenticatedGet, authenticatedPost;

// Checks for a pending referral reward and shows the claim dialog if one exists
Future<void> checkPendingReferralReward(
  BuildContext context,
  StateSetter setState,
) async {
  final res = await authenticatedGet('pending_referral_reward');
  if (!context.mounted) return;
  if (res.statusCode != 200) return;
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (data['pending'] != true) return;

  final refereeUid = data['referee_uid'] as String;
  final refereeUsername = data['referee_username'] as String;

  await showFrostedAlertDialog(
    context: context,
    title: "Referral Reward!",
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedUserAdd01,
          color: lightenColor(appColorNotifier.value, 0.45),
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
                final claimRes = await authenticatedPost(
                  'claim_referral_reward',
                  body: {'referee_uid': refereeUid},
                );
                if (!context.mounted) return;
                if (claimRes.statusCode == 200) {
                  final claimData =
                      jsonDecode(claimRes.body) as Map<String, dynamic>;
                  currentUserData?.level = claimData['new_level'];
                  currentUserData?.expPoints = claimData['new_exp'];
                  expNotifier.value = claimData['new_exp'];
                  if (currentUserData != null) {
                    currentUserData!.referralCount =
                        currentUserData!.referralCount + 1;
                  }
                  userDataNotifier.notifyListeners();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("+${claimData['xp_awarded']} XP claimed!"),
                      duration: snackBarDuration,
                    ),
                  );
                }
              },
              child: const Text("Claim XP"),
            ),
          ),
        ),
      ),
    ],
  );
}

// Referrals card widget for the home dashboard
Widget buildReferralsCard(BuildContext context) {
  final accent = lightenColor(appColorNotifier.value, 0.45);
  final accentDim = lightenColor(appColorNotifier.value, 0.3);
  return GestureDetector(
    onTap: () async {
      final codeInputController = TextEditingController();
      // Use cached code or fetch/generate one
      String? code = currentUserData?.referralCode;
      if (code == null) {
        final getRes = await authenticatedGet('referral_code');
        if (getRes.statusCode == 200) {
          code =
              (jsonDecode(getRes.body) as Map<String, dynamic>)['referral_code']
                  as String;
        } else if (getRes.statusCode == 404) {
          final postRes = await authenticatedPost('referral_code');
          if (postRes.statusCode == 201) {
            code =
                (jsonDecode(postRes.body)
                        as Map<String, dynamic>)['referral_code']
                    as String;
          }
        }
        if (code != null) currentUserData?.referralCode = code;
      }
      if (!context.mounted) return;
      showFrostedAlertDialog(
        context: context,
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
                padding: EdgeInsets.only(bottom: Responsive.height(context, 8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: Responsive.scale(context, 22),
                      height: Responsive.scale(context, 22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: appColorNotifier.value.withAlpha(80),
                        border: Border.all(
                          color: lightenColor(
                            appColorNotifier.value,
                            0.3,
                          ).withAlpha(160),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          step.$1,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: accent,
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
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: Responsive.height(context, 8)),
            Center(
              child: GestureDetector(
                onTap: () {
                  if (code != null) {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Referral code copied!"),
                        duration: snackBarDuration,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 20),
                    vertical: Responsive.height(context, 10),
                  ),
                  decoration: BoxDecoration(
                    color: appColorNotifier.value.withAlpha(60),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    border: Border.all(
                      color: lightenColor(
                        appColorNotifier.value,
                        0.3,
                      ).withAlpha(160),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        code ?? "—",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 18),
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: Responsive.width(context, 10)),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCopy01,
                        color: accentDim,
                        size: Responsive.scale(context, 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: Responsive.height(context, 12)),
            Center(
              child: Text(
                "${currentUserData?.referralCount ?? 0} friend${(currentUserData?.referralCount ?? 0) == 1 ? '' : 's'} referred",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 12),
                  color: accentDim,
                ),
              ),
            ),
            Divider(
              color: Colors.white12,
              height: Responsive.height(context, 32),
            ),
            if (currentUserData?.referralUsed == true) ...[
              Text(
                "You've already entered a referral code.",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: Colors.white38,
                ),
              ),
            ] else ...[
              Text(
                "Have a referral code?",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: Colors.white60,
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
              TextField(
                controller: codeInputController,
                style: GoogleFonts.manrope(color: Colors.white),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  hintText: "Enter code",
                  hintStyle: GoogleFonts.manrope(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.check,
                      color: lightenColor(appColorNotifier.value, 0.45),
                    ),
                    onPressed: () async {
                      final entered = codeInputController.text
                          .trim()
                          .toUpperCase();
                      if (entered.isEmpty) return;
                      final res = await authenticatedPost(
                        'use_referral',
                        body: {'referral_code': entered},
                      );
                      if (!context.mounted) return;
                      if (res.statusCode == 200) {
                        final data =
                            jsonDecode(res.body) as Map<String, dynamic>;
                        currentUserData?.level = data['new_level'];
                        currentUserData?.expPoints = data['new_exp'];
                        currentUserData?.referralUsed = true;
                        expNotifier.value = data['new_exp'];
                        userDataNotifier.notifyListeners();
                        Navigator.of(context, rootNavigator: true).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Referral code applied! +${data['xp_awarded']} XP",
                            ),
                            duration: snackBarDuration,
                          ),
                        );
                      } else {
                        String error = 'Something went wrong';
                        try {
                          error =
                              (jsonDecode(res.body)
                                  as Map<String, dynamic>)['error'] ??
                              error;
                        } catch (_) {}
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
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
          Expanded(
            child: Center(
              child: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                  child: const Text("Close"),
                ),
              ),
            ),
          ),
        ],
      );
    },
    child: frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 14),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUserAdd01,
            color: accentDim,
            size: Responsive.scale(context, 28),
          ),
          SizedBox(width: Responsive.width(context, 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Refer a Friend",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${currentUserData?.referralCount ?? 0}",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 22),
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "referred",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 10),
                  color: accentDim,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
