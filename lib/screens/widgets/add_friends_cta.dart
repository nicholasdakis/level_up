import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import '../../globals.dart';
import '../../providers/user_data_provider.dart';
import '../../utility/responsive.dart';
import '../social/friends_card.dart' show showAddFriendDialog;

// CTA card shown when the user has no friends, prompts them to add or invite someone
class AddFriendsCta extends ConsumerWidget {
  final Color appColor;
  final VoidCallback? onFriendAdded;

  const AddFriendsCta({super.key, required this.appColor, this.onFriendAdded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = lightenColor(appColor, 0.45);
    final c = cardColors(appColor);

    return frostedGlassCard(
      context,
      color: appColor,
      baseRadius: 16,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Compete with friends',
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 14),
              fontWeight: FontWeight.w700,
              color: primary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Responsive.height(context, 4)),
          Text(
            'Add friends to see how you rank against them.',
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 12),
              color: onTheme(appColor).withAlpha(180),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Responsive.height(context, 14)),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await showAddFriendDialog(context, appColor);
                    onFriendAdded?.call();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 10),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: c.gradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 12),
                      ),
                      border: Border.all(color: c.border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedUserAdd01,
                          color: Colors.white,
                          size: Responsive.scale(context, 14),
                        ),
                        SizedBox(width: Responsive.width(context, 6)),
                        Text(
                          'Add a Friend',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: Responsive.width(context, 10)),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final code = await ref
                        .read(userDataProvider.notifier)
                        .fetchReferralCode();
                    if (code == null) return;
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Join me on Level Up! Use my referral code $code to get bonus XP when you sign up. https://nicholasdakis.com',
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 10),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: c.gradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 12),
                      ),
                      border: Border.all(color: c.border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedShare01,
                          color: Colors.white,
                          size: Responsive.scale(context, 14),
                        ),
                        SizedBox(width: Responsive.width(context, 6)),
                        Text(
                          'Invite',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
