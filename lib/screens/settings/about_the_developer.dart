import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/user_data_manager.dart' show trackTrivialAchievement;

class AboutTheDeveloper extends StatefulWidget {
  const AboutTheDeveloper({super.key});

  @override
  State<AboutTheDeveloper> createState() => _AboutTheDeveloperState();
}

class _AboutTheDeveloperState extends State<AboutTheDeveloper> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(Responsive.scale(context, 12)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightenColor(
                    appColorNotifier.value,
                    0.1,
                  ).withAlpha(20),
                  border: Border.all(
                    color: lightenColor(
                      appColorNotifier.value,
                      0.3,
                    ).withAlpha(180),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: lightenColor(
                    appColorNotifier.value,
                    0.3,
                  ).withAlpha(180),
                  size: Responsive.font(context, 13),
                ),
              ),
            ),
          ),
          title: createTitle("About the Developer", context),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 3)),
            child: Container(
              height: Responsive.height(context, 3),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        body: ScrollConfiguration(
          behavior: NoGlowScrollBehavior(),
          child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.centeredHorizontalPadding(context, 24),
              vertical: Responsive.height(context, 28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // OVERVIEW
                sectionHeader("OVERVIEW", context),
                frostedGlassCard(
                  context,
                  baseRadius: 16,
                  padding: EdgeInsets.all(Responsive.scale(context, 18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hi, I'm Nicholas Dakis — a Computer Science student at Queens College.",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 14),
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 10)),
                      Text(
                        "I built Level Up! to get experience working on a real project end to end. It taught me a lot: Flutter, Python, backend development, databases, deployment, and all the tools and decisions that come with shipping something real.",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 14),
                          color: Colors.white70,
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
                  baseRadius: 16,
                  padding: EdgeInsets.all(Responsive.scale(context, 18)),
                  child: Column(
                    children: [
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
                  baseRadius: 16,
                  padding: EdgeInsets.all(Responsive.scale(context, 18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Have a suggestion or found a bug? I read every message.",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 14),
                          color: Colors.white54,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 14)),
                      InkWell(
                        splashColor: appColorNotifier.value.withAlpha(60),
                        borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
                        onTap: () {
                          trackTrivialAchievement("send_feedback");
                          sendEmail(
                            context,
                            "n1ch0lasd4k1s@gmail.com",
                            "Feedback for Level Up!",
                          );
                        },
                        child: frostedGlassCard(
                          context,
                          baseRadius: 12,
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 14),
                            vertical: Responsive.height(context, 10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mail_outline,
                                color: Colors.white70,
                                size: Responsive.scale(context, 20),
                              ),
                              SizedBox(width: Responsive.width(context, 12)),
                              Expanded(
                                child: Text(
                                  "Send feedback",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 14),
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white38,
                                size: Responsive.scale(context, 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: Responsive.height(context, 24)),

                // DONATE
                sectionHeader("DONATE", context),
                frostedGlassCard(
                  context,
                  baseRadius: 16,
                  padding: EdgeInsets.all(Responsive.scale(context, 18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "If you've been enjoying the app and want to support it, any contribution is appreciated.",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 14),
                          color: Colors.white54,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 14)),
                      InkWell(
                        splashColor: appColorNotifier.value.withAlpha(60),
                        borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
                        onTap: () => launchUrl(
                          Uri.parse(
                            "https://www.paypal.com/donate/?business=UR3VZ962M4F4N&item_name=Support+the+developer+of+Level+Up%21&currency_code=USD",
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: frostedGlassCard(
                          context,
                          baseRadius: 12,
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 14),
                            vertical: Responsive.height(context, 10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.favorite_outline,
                                color: Colors.white70,
                                size: Responsive.scale(context, 20),
                              ),
                              SizedBox(width: Responsive.width(context, 12)),
                              Expanded(
                                child: Text(
                                  "Donate via PayPal",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 14),
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white38,
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
    );
  }
}
