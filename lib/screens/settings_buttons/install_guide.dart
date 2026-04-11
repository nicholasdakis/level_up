import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';

// Tutorial screen for installing the app as a PWA on browsers that don't support
class InstallGuide extends StatelessWidget {
  const InstallGuide({super.key});

  Widget _buildStep(BuildContext context, String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Responsive.scale(context, 24),
            height: Responsive.scale(context, 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: appColorNotifier.value.withAlpha(80),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> steps,
    List<Widget>? extras,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 20)),
      child: frostedGlassCard(
        context,
        baseRadius: 16,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: appColorNotifier.value,
                  size: Responsive.scale(context, 22),
                ),
                SizedBox(width: Responsive.width(context, 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.height(context, 14)),
            Divider(color: Colors.white.withAlpha(20), height: 1),
            SizedBox(height: Responsive.height(context, 14)),
            ...steps, // Spread operator to lay out all the steps into the column
            if (extras != null)
              ...extras, // Spread operator to lay out any extras that exist into the column
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.height(context, 100),
          title: createTitle("Install App", context),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 50),
              vertical: Responsive.height(context, 24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App logo section
                Center(
                  child: Image.asset(
                    'assets/app_logo_transparent_bg.png',
                    height: Responsive.height(context, 200),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 8)),
                Center(
                  child: Text(
                    "Install Level Up! for a more convenient experience!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      color: Colors.white38,
                    ),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 28)),

                // Chromium section
                sectionHeader("CHROMIUM-BASED BROWSERS (RECOMMENDED)", context),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "e.g. Chrome, Edge, Brave, Opera - use one of these if possible",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        color: Colors.white38,
                      ),
                    ),
                    Text(
                      "Note: These will not work for iPhone users",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.height(context, 10)),
                _buildSection(
                  context,
                  icon: Icons.download_rounded,
                  title: "Easiest Installation",
                  subtitle: "One-click install supported",
                  steps: [
                    _buildStep(
                      context,
                      "1",
                      "Open Level Up! in your Chromium-based browser.",
                    ),
                    _buildStep(
                      context,
                      "2",
                      "Either press \"Install as a PWA\" in the Settings drawer, or look for the Install icon in the address bar (top right).",
                    ),
                    _buildStep(
                      context,
                      "3",
                      "Confirm the installation prompt.",
                    ),
                    _buildStep(
                      context,
                      "4",
                      "Level Up! will appear on your desktop or home screen.",
                    ),
                  ],
                ),

                // iPhone section
                sectionHeader("IPHONE (SAFARI)", context),
                Text(
                  "Must use Safari - other browsers on iOS don't support PWA install. The \"Install as PWA\" button in the Settings drawer does not work on iPhone.",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 12),
                    color: Colors.white38,
                  ),
                ),
                SizedBox(height: Responsive.height(context, 10)),
                _buildSection(
                  context,
                  icon: Icons.phone_iphone,
                  title: "Add to Home Screen",
                  subtitle: "Safari required on iOS",
                  steps: [
                    _buildStep(context, "1", "Open Level Up! in Safari."),
                    _buildStep(
                      context,
                      "2",
                      "Tap the Share button at the bottom of the screen.",
                    ),
                    _buildStep(
                      context,
                      "3",
                      "Scroll down and tap \"Add to Home Screen\".",
                    ),
                    _buildStep(
                      context,
                      "4",
                      "Tap \"Add\" to confirm. Level Up! will appear on your home screen.",
                    ),
                  ],
                ),

                // Non-Chromium section
                sectionHeader("OTHER BROWSERS", context),
                Text(
                  "e.g. Firefox, Samsung Internet - PWA install is not natively supported. Consider switching to a Chromium-based browser or installing an extension.",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 12),
                    color: Colors.white38,
                  ),
                ),
                SizedBox(height: Responsive.height(context, 10)),
                _buildSection(
                  context,
                  icon: Icons.public,
                  title: "Install via Browser Menu",
                  subtitle: "Steps may vary by browser",
                  steps: [
                    _buildStep(
                      context,
                      "1",
                      "PWA install is not natively supported on non-Chromium browsers.",
                    ),
                    _buildStep(
                      context,
                      "2",
                      "If your browser supports extensions, try installing a PWA extension to add support.",
                    ),
                  ],
                  extras: [
                    Divider(color: Colors.white.withAlpha(20), height: 1),
                    SizedBox(height: Responsive.height(context, 12)),
                    Padding(
                      padding: EdgeInsets.all(Responsive.padding(context, 8.0)),
                      child: Text(
                        "For example, Firefox users may want to try:",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 13),
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    socialLink(
                      assetPath: 'assets/firefox_transparent_bg.png',
                      label:
                          "Progressive Web Apps for Firefox by Filip Štamcar",
                      url:
                          "https://addons.mozilla.org/en-US/firefox/addon/pwas-for-firefox/",
                      context: context,
                    ),
                  ],
                ),

                SizedBox(height: Responsive.height(context, 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
