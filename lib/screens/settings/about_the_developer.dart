import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/user_data_manager.dart' show trackTrivialAchievement;

class AboutTheDeveloper extends StatefulWidget {
  const AboutTheDeveloper({super.key});

  @override
  State<AboutTheDeveloper> createState() => _AboutTheDeveloperState();
}

List<String> overviewItems = [
  "My name is Nicholas Dakis, and I am a Computer Science student at Queens College.",
  "I created Level Up! to learn Flutter and build something useful that people would enjoy using.",
  "It's an app where I had full control over the vision and wanted to emphasize making the app as enjoyable and user-friendly as possible.",
];

class _AboutTheDeveloperState extends State<AboutTheDeveloper> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Body color
        // Header box
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: darkenColor(
            appColorNotifier.value,
            0.025,
          ), // Header color
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/'),
          ),
          title: createTitle("About the Developer", context),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 1)),
            child: Container(
              height: Responsive.height(context, 1),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        // scrollable
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 50),
              vertical: Responsive.padding(context, 30),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.width(context, 500),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Placeholder image (Flutter logo)
                    Center(
                      child: Image.network(
                        "https://upload.wikimedia.org/wikipedia/commons/1/17/Google-flutter-logo.png",
                        width: Responsive.width(context, 300),
                        height: Responsive.height(context, 300),
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 20)),

                    // OVERVIEW SECTION
                    sectionHeader("OVERVIEW", context, baseFontSize: 15),
                    frostedGlassCard(
                      context,
                      baseRadius: 20,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 20),
                        vertical: Responsive.height(context, 16),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < overviewItems.length; i++) ...[
                            if (i > 0)
                              SizedBox(height: Responsive.height(context, 10)),
                            frostedGlassCard(
                              context,
                              baseRadius: 14,
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 16),
                                vertical: Responsive.height(context, 12),
                              ),
                              child: Text(
                                overviewItems[i],
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 18),
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w600,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 30)),

                    // CONNECT WITH ME SECTION
                    sectionHeader("CONNECT WITH ME", context, baseFontSize: 15),
                    // Outer card
                    frostedGlassCard(
                      context,
                      baseRadius: 20,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 20),
                        vertical: Responsive.height(context, 16),
                      ),
                      child: Column(
                        children: [
                          // LinkedIn card
                          socialLink(
                            assetPath: 'assets/linkedin_logo.png',
                            label: 'LinkedIn',
                            url: 'https://www.linkedin.com/in/nicholasdakis',
                            context: context,
                          ),

                          SizedBox(
                            height: Responsive.height(context, 14), // spacing
                          ),

                          // GitHub card
                          socialLink(
                            assetPath: 'assets/github_logo.png',
                            label: 'GitHub',
                            url: 'https://github.com/nicholasdakis',
                            context: context,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 30)),

                    // SEND FEEDBACK SECTION
                    sectionHeader("SEND FEEDBACK", context, baseFontSize: 15),
                    // Outer card
                    frostedGlassCard(
                      context,
                      baseRadius: 20,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 20),
                        vertical: Responsive.height(context, 16),
                      ),
                      child: Column(
                        children: [
                          // Inner text card
                          SizedBox(
                            width: double.infinity,
                            child: frostedGlassCard(
                              context,
                              baseRadius: 14,
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 16),
                                vertical: Responsive.height(context, 12),
                              ),
                              child: Center(
                                child: Text(
                                  "Feel free to send feedback or suggestions to improve Level Up!",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 18),
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height: Responsive.height(context, 14), // spacing
                          ),

                          // Send an email card
                          InkWell(
                            splashColor: appColorNotifier.value.withAlpha(100),
                            onTap: () {
                              trackTrivialAchievement("send_feedback");
                              sendEmail(
                                context,
                                "n1ch0lasd4k1s@gmail.com",
                                "Feedback for Level up!",
                              );
                            },
                            child: frostedGlassCard(
                              context,
                              baseRadius: 14,
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 16),
                                vertical: Responsive.height(context, 12),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(context, 8),
                                    ),
                                    child: Icon(Icons.mail),
                                  ),

                                  SizedBox(
                                    width: Responsive.width(context, 12),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "Send an email",
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 18),
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.white38,
                                    size: Responsive.width(context, 22),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 30)),

                    // DONATE SECTION
                    sectionHeader("DONATE", context, baseFontSize: 15),
                    frostedGlassCard(
                      context,
                      baseRadius: 20,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 20),
                        vertical: Responsive.height(context, 16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: frostedGlassCard(
                              context,
                              baseRadius: 14,
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 16),
                                vertical: Responsive.height(context, 12),
                              ),
                              child: Center(
                                child: Text(
                                  "Feel free to donate using the button below:",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 18),
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 16)),
                          Center(
                            child: InkWell(
                              splashColor: appColorNotifier.value.withAlpha(
                                100,
                              ),
                              onTap: () => launchUrl(
                                Uri.parse(
                                  "https://www.paypal.com/donate/?business=UR3VZ962M4F4N&item_name=Support+the+developer+of+Level+Up%21&currency_code=USD",
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: SvgPicture.network(
                                "https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg",
                                width: Responsive.width(context, 200),
                                placeholderBuilder: (context) =>
                                    CircularProgressIndicator(), // if image fails to load
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
