import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/user_data_manager.dart' show trackTrivialAchievement;

class AboutTheDeveloper extends ConsumerStatefulWidget {
  const AboutTheDeveloper({super.key});

  @override
  ConsumerState<AboutTheDeveloper> createState() => _AboutTheDeveloperState();
}

class _AboutTheDeveloperState extends ConsumerState<AboutTheDeveloper> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/settings/developer',
      screenClass: 'AboutTheDeveloper',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: Responsive.centeredHorizontalPadding(context, 24),
                  right: Responsive.centeredHorizontalPadding(context, 24),
                  bottom: Responsive.height(context, 28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: Responsive.height(context, 8),
                        bottom: Responsive.height(context, 12),
                      ),
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 12),
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightenColor(appColor, 0.1).withAlpha(20),
                            border: Border.all(
                              color: lightenColor(appColor, 0.3).withAlpha(180),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: lightenColor(appColor, 0.3).withAlpha(180),
                            size: Responsive.font(context, 13),
                          ),
                        ),
                      ),
                    ),
                    // OVERVIEW
                    sectionHeader("OVERVIEW", context),
                    frostedGlassCard(
                      context,
                      color: appColor,
                      baseRadius: 16,
                      padding: EdgeInsets.all(Responsive.scale(context, 18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "I'm Nicholas Dakis, a Computer Science student.",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              color: lightenColor(appColor, 0.45),
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 10)),
                          Text(
                            "I built Level Up! as a solo project to put my skills into practice. It covers the full stack: Flutter, Python, Supabase, cloud deployment, and everything in between.",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              color: lightenColor(appColor, 0.45),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 24)),

                    // CONNECT
                    sectionHeader("CONNECT", context),
                    frostedGlassCard(
                      context,
                      color: appColor,
                      baseRadius: 16,
                      padding: EdgeInsets.all(Responsive.scale(context, 18)),
                      child: Column(
                        children: [
                          socialLink(
                            assetPath: 'assets/nicholasdakis_website_logo.png',
                            label: 'nicholasdakis.com',
                            url: 'https://nicholasdakis.com',
                            context: context,
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                          socialLink(
                            assetPath: 'assets/linkedin_logo.png',
                            label: 'LinkedIn',
                            url: 'https://www.linkedin.com/in/nicholasdakis',
                            context: context,
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                          socialLink(
                            assetPath: 'assets/github_logo.png',
                            label: 'GitHub',
                            url: 'https://github.com/nicholasdakis',
                            context: context,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 24)),

                    // FEEDBACK
                    sectionHeader("FEEDBACK", context),
                    frostedGlassCard(
                      context,
                      color: appColor,
                      baseRadius: 16,
                      padding: EdgeInsets.all(Responsive.scale(context, 18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Have a suggestion or found a bug? I read every message!",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              color: lightenColor(appColor, 0.45),
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 14)),
                          socialLink(
                            icon: Icons.mail_outline_rounded,
                            label: 'Send feedback',
                            url: '',
                            context: context,
                            onTap: () {
                              trackTrivialAchievement("send_feedback");
                              sendEmail(
                                context,
                                "n1ch0lasd4k1s@gmail.com",
                                "Feedback for Level Up!",
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 24)),

                    // DONATE
                    sectionHeader("DONATE", context),
                    frostedGlassCard(
                      context,
                      color: appColor,
                      baseRadius: 16,
                      padding: EdgeInsets.all(Responsive.scale(context, 18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "If you've been enjoying the app and want to support development, any contribution is appreciated!",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              color: lightenColor(appColor, 0.45),
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 14)),
                          InkWell(
                            splashColor: appColor.withAlpha(60),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 12),
                            ),
                            onTap: () => launchUrl(
                              Uri.parse(
                                "https://www.paypal.com/donate/?business=UR3VZ962M4F4N&item_name=Support+the+developer+of+Level+Up%21&currency_code=USD",
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: frostedGlassCard(
                              context,
                              color: appColor,
                              baseRadius: 12,
                              backgroundColor: appColor.computeLuminance() < 0.2
                                  ? darkenColor(appColor, 0.08).withAlpha(60)
                                  : Colors.white.withAlpha(40),
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 14),
                                vertical: Responsive.height(context, 10),
                              ),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedFavourite,
                                    color: lightenColor(appColor, 0.45),
                                    size: Responsive.scale(context, 20),
                                  ),
                                  SizedBox(
                                    width: Responsive.width(context, 12),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "Donate via PayPal",
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 14),
                                        color: lightenColor(appColor, 0.45),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedArrowRight01,
                                    color: lightenColor(appColor, 0.45),
                                    size: Responsive.scale(context, 20),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 32)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
