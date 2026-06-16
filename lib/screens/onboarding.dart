// onboarding.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '/globals.dart';
import '/services/user_data_manager.dart';
import '/utility/responsive.dart';

// Welcome card shown before the showcase tour starts
Future<void> showWelcomeTourDialog(BuildContext context) async {
  final accentColor = lightenColor(appColorNotifier.value, 0.3);
  await showFrostedDialog(
    context: context,
    dismissible: false,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/app_logo_circle.png',
            width: Responsive.scale(context, 72),
            height: Responsive.scale(context, 72),
          ),
          SizedBox(height: Responsive.height(context, 18)),
          Text(
            'Welcome to Level Up!',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 22),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: Responsive.height(context, 10)),
          Text(
            "Let's take a quick look at everything you can do.",
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              color: Colors.white60,
            ),
          ),
          SizedBox(height: Responsive.height(context, 28)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: appColorNotifier.value,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.height(context, 14),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: accentColor.withAlpha(80), width: 1),
                ),
              ),
              child: Text(
                "Show me around",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Shown at the end of the new-user showcase tour, and can only be closed after a username is set
Future<void> showUsernameSetupDialog(BuildContext context) async {
  await showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => const _UsernameSetupDialog(),
  );
}

// Shown after username setup, telling new users the app is new and asks for a review
Future<void> showNewUserAppReviewDialog(BuildContext context) async {
  final accentColor = lightenColor(appColorNotifier.value, 0.45);
  await showFrostedAlertDialog(
    context: context,
    title: "One Last Thing",
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: Responsive.height(context, 8)),
        Text(
          "Level Up! is a brand new app and your feedback means everything right now.",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        SizedBox(height: Responsive.height(context, 10)),
        Text(
          "If you're enjoying it, leaving a quick review on the Play Store would help a lot!",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        child: Text("Maybe Later", style: TextStyle(color: Colors.white38)),
      ),
      TextButton(
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          if (kIsWeb) {
            await url_launcher.launchUrl(
              Uri.parse(
                'https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup',
              ),
              mode: url_launcher.LaunchMode.externalApplication,
            );
          } else {
            final review = InAppReview.instance;
            if (await review.isAvailable()) {
              await review.requestReview();
            } else {
              await review.openStoreListing(
                appStoreId: 'com.nicholasdakis.levelup',
              );
            }
          }
        },
        child: Text(
          "Leave a Review",
          style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

// Builds a random username in the format AdjectiveNoun#### (e.g. SwiftFalcon4213)
String generateRandomUsername() {
  final rand = Random();
  final adjectives = [
    'Swift',
    'Bold',
    'Iron',
    'Stellar',
    'Nova',
    'Cosmic',
    'Turbo',
    'Epic',
    'Neon',
    'Phantom',
    'Shadow',
    'Blazing',
    'Golden',
    'Thunder',
    'Mighty',
    'Fierce',
    'Sharp',
    'Nimble',
    'Agile',
    'Brave',
    'Peak',
    'Prime',
    'Apex',
    'Rapid',
    'Steel',
    'Solar',
    'Lunar',
    'Atomic',
    'Hyper',
    'Ultra',
    'Blaze',
    'Frost',
    'Storm',
    'Ember',
    'Grit',
    'Radiant',
    'Savage',
    'Sleek',
    'Solid',
    'Crisp',
    'Elite',
    'Vital',
    'Feral',
    'Rough',
    'Keen',
    'Lone',
    'Dark',
    'Wild',
    'Hype',
    'Clutch',
    'Raw',
    'Jade',
    'Onyx',
    'Coral',
    'Azure',
    'Crimson',
    'Silver',
    'Obsidian',
  ];
  final nouns = [
    'Runner',
    'Lifter',
    'Climber',
    'Sprinter',
    'Warrior',
    'Champion',
    'Grinder',
    'Beast',
    'Titan',
    'Legend',
    'Viper',
    'Hawk',
    'Wolf',
    'Falcon',
    'Racer',
    'Surge',
    'Forge',
    'Crest',
    'Pulse',
    'Hustle',
    'Striker',
    'Hunter',
    'Ranger',
    'Knight',
    'Archer',
    'Blade',
    'Phantom',
    'Specter',
    'Rogue',
    'Scout',
    'Drifter',
    'Nomad',
    'Crusher',
    'Slayer',
    'Duelist',
    'Lancer',
    'Brawler',
    'Reaper',
    'Sniper',
    'Vanguard',
    'Condor',
    'Cobra',
    'Jaguar',
    'Lynx',
    'Panther',
    'Raptor',
    'Stallion',
    'Tempest',
    'Cyclone',
    'Inferno',
    'Avalanche',
    'Comet',
    'Eclipse',
  ];
  final adj = adjectives[rand.nextInt(adjectives.length)];
  final noun = nouns[rand.nextInt(nouns.length)];
  final number = rand.nextInt(9999) + 1; // 1-9999
  return '$adj$noun$number';
}

// Glass-styled showcase tooltip
Widget buildShowcaseTooltip(
  BuildContext context, {
  required String title,
  required String description,
}) {
  final accentColor = lightenColor(appColorNotifier.value, 0.3);
  final radius = BorderRadius.circular(Responsive.scale(context, 20));
  return ClipRRect(
    borderRadius: radius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: frostedGlassCard(
        context,
        backgroundColor: Colors.white.withAlpha(10),
        border: Border.all(color: Colors.white.withAlpha(22), width: 1),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            SizedBox(height: Responsive.height(context, 6)),
            Text(
              description,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _UsernameSetupDialog extends StatefulWidget {
  const _UsernameSetupDialog();

  @override
  State<_UsernameSetupDialog> createState() => _UsernameSetupDialogState();
}

class _UsernameSetupDialogState extends State<_UsernameSetupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose(); // prevent memory leaks
    super.dispose();
  }

  // Only pops if the username update succeeds
  Future<void> _confirm() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a username."),
          duration: snackBarDuration,
        ),
      );
      return;
    }
    if (trimmed.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Username must be 20 characters or fewer."),
          duration: snackBarDuration,
        ),
      );
      return;
    }
    if (await UserDataManager().updateUsername(trimmed, context)) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _generate() {
    _controller.text = generateRandomUsername();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = lightenColor(appColorNotifier.value, 0.3);

    return PopScope(
      canPop: false,
      child: Dialog(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      insetPadding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 24),
        vertical: Responsive.height(context, 40),
      ),
      child: SizedBox(
        width: Responsive.dialogWidth(context, maxWidth: 500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: frostedGlassCard(
              context,
              backgroundColor: Colors.white.withAlpha(10),
              border: Border.all(
                color: Colors.white.withAlpha(22),
                width: Responsive.width(context, 1),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 28),
                vertical: Responsive.height(context, 32),
              ),
              child: SingleChildScrollView(
                child:
                    Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/app_logo_circle.png',
                              width: Responsive.scale(context, 72),
                              height: Responsive.scale(context, 72),
                            ),
                            SizedBox(height: Responsive.height(context, 20)),
                            Text(
                              "Choose your name!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 22),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 10)),
                            Text(
                              "What do you go by?",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 14),
                                color: Colors.white60,
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 32)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _controller,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: Responsive.font(context, 15),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter a username...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white30,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withAlpha(12),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.white.withAlpha(25),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: accentColor.withAlpha(180),
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: Responsive.width(context, 14),
                                      vertical: Responsive.height(context, 13),
                                    ),
                                  ),
                                ),
                                SizedBox(height: Responsive.height(context, 4)),
                                // Shuffles in a new random username without clearing the field manually
                                TextButton.icon(
                                  onPressed: _generate,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.width(context, 4),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.shuffle_rounded,
                                    color: accentColor.withAlpha(180),
                                    size: Responsive.scale(context, 16),
                                  ),
                                  label: Text(
                                    'Generate a random name',
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 13),
                                      color: accentColor.withAlpha(180),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(context, 28)),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _confirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appColorNotifier.value,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    vertical: Responsive.height(context, 16),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: accentColor.withAlpha(80),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  "Let's go!",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 16),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.06, duration: 350.ms),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
