import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/settings/settings_icon_button.dart';
import 'screens/settings.dart';
import 'screens/footer.dart';
import 'screens/daily_rewards.dart';
import 'globals.dart';
import 'utility/responsive.dart';
import 'screens/settings/personal_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'services/user_data_manager.dart' show trackTrivialAchievement;

class _HomeAnimationState {
  static bool buttonsAnimated = false;
}

// Class to remove awkward glow buttons show when scrolling to the very top / bottom
class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // No glow effect
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  late VoidCallback _appColorListener;

  @override
  void initState() {
    super.initState();

    // Update the HomeScreen with the updated app color
    _appColorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_appColorListener);
    appReadyNotifier.addListener(_onAppReady);

    // If data already loaded (e.g. navigating back to home), finish immediately
    if (appReadyNotifier.value) _onAppReady();

    // Initialize confetti controllers
    confettiControllerinit();
  }

  void _onAppReady() {
    if (!mounted) return;
    initializeUser();
    Future.delayed(const Duration(milliseconds: 850), () {
      _HomeAnimationState.buttonsAnimated = true;
    });
  }

  // To prevent memory leaks
  @override
  void dispose() {
    appColorNotifier.removeListener(_appColorListener);
    appReadyNotifier.removeListener(_onAppReady);
    dailyRewardConfettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Method so the skeletonizer works for the buttons before they fade and slide in
  Widget buildPlaceholderButton() {
    return customButton("Placeholder", 48, 160, 750, context, onPressed: () {});
  }

  Future<void> promptUsernameDialog(BuildContext context) async {
    final usernameController = TextEditingController();
    try {
      await showUsernameDialogBox(
        context,
        "Choose your username",
        usernameController,
      );
    } finally {
      usernameController.dispose();
    }
  }

  bool canClaimDailyReward() {
    return currentUserData?.canClaimDailyReward ??
        true; // reads from currentUserData because upon loading, it calls the backend to get the most up-to-date value
  }

  void buildDailyRewardDialog() {
    if (!mounted) return;
    DailyRewardDialog().showDailyRewardDialog(
      context,
      dailyRewardConfettiController,
    );
  }

  // AppShell already loaded user data, updated UTC offset, synced XP, and
  // initialized FCM. HomeScreen only needs to show the home-specific dialogs.
  Future<void> initializeUser() async {
    // Give users without a username a dialog box to choose one
    if (currentUserData!.username != null &&
        currentUserData!.username == currentUserData!.uid) {
      await promptUsernameDialog(context);
    }

    if (canClaimDailyReward() && mounted) buildDailyRewardDialog();

    if (mounted) setState(() => isLoading = false);
  }

  bool isLoading = true;

  Widget _maybeAnimate(Widget button, Duration delay) {
    if (_HomeAnimationState.buttonsAnimated) return button;
    return button
        .animate()
        .fadeIn(delay: delay, duration: 400.ms)
        .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if user data not loaded yet
    return Skeletonizer(
      enabled: isLoading,
      effect: ShimmerEffect(
        baseColor: lightenColor(appColorNotifier.value, 0.3),
        highlightColor: lightenColor(appColorNotifier.value, 0.1),
        duration: const Duration(milliseconds: 1200),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: buildThemeGradient()),
        child: Scaffold(
          drawer: buildSettingsDrawer(
            context,
            // rebuild on pfp image update
            onProfileImageUpdated: () {
              if (!mounted) return;
              setState(() {}); // rebuild HomeScreen
            },
          ),
          backgroundColor: Colors.transparent,
          // Body + Header
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
              Responsive.height(context, 201),
            ), // Alter default appBar size
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  automaticallyImplyLeading:
                      false, // Prevent the automatic hamburger icon from appearing
                  scrolledUnderElevation:
                      0, // So the appBar does not change color when the user scrolls down
                  backgroundColor: darkenColor(
                    appColorNotifier.value.withAlpha(100),
                    0.1,
                  ), // Header color
                  centerTitle: true,
                  toolbarHeight: Responsive.buttonHeight(
                    context,
                    120,
                  ), // Prevent the icon from cutting in half
                  elevation: 0,
                  actions: [
                    Builder(
                      // Wrapped in Builder so Scaffold.of succeeds
                      builder: (context) => SettingsIconButton(
                        onTap: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ],
                  flexibleSpace: Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: Responsive.width(context, 30),
                      ), // Move the title text down a little bit
                      // Manually make the title text, since appBar is already being used
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            subtleTextGradient().createShader(
                              Rect.fromLTWH(
                                0,
                                0,
                                bounds.width,
                                bounds.height,
                              ), // Make a rectangle the same size as the text so the gradient covers it
                            ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Stroke / outline
                            Text(
                              "LEVEL UP!",
                              style: GoogleFonts.dangrek(
                                fontSize: Responsive.font(context, 55),
                                letterSpacing: Responsive.scale(context, 2),
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = Responsive.scale(context, 4)
                                  ..color = Colors.black,
                              ),
                            ),
                            // Fill + glow
                            Text(
                              "LEVEL UP!",
                              style: GoogleFonts.dangrek(
                                fontSize: Responsive.font(context, 55),
                                letterSpacing: Responsive.scale(context, 2),
                                color: Colors
                                    .white, // color is needed but will be masked
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 0),
                                    blurRadius: Responsive.scale(context, 25),
                                    color: appColorNotifier.value.withAlpha(
                                      200,
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
                Container(
                  height: Responsive.height(context, 1),
                  color: Colors.white.withAlpha(25),
                ),
              ],
            ),
          ),
          body: Stack(
            // Stack for confetti to appear on top
            children: [
              Column(
                children: [
                  // Middle body
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: NoGlowScrollBehavior(),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Padding(
                          padding: EdgeInsets.all(
                            Responsive.height(context, 5),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.width(context, 16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Current app version badge
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "BETA 04.26",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 11),
                                      color: Colors.white.withAlpha(80),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                // CALORIE CALCULATOR BUTTON
                                isLoading
                                    ? buildPlaceholderButton()
                                    : _maybeAnimate(
                                        customButton(
                                          "Calorie Calculator",
                                          48,
                                          160,
                                          750,
                                          context,
                                          icon: Icons.calculate_outlined,
                                          onPressed: () {
                                            trackTrivialAchievement(
                                              "calorie_calculator",
                                            );
                                            context.push('/calorie-calculator');
                                          },
                                        ),
                                        0.ms,
                                      ),
                                SizedBox(
                                  height: Responsive.height(context, 12),
                                ),
                                // FOOD LOGGING TAB
                                isLoading
                                    ? buildPlaceholderButton()
                                    : _maybeAnimate(
                                        customButton(
                                          "Food Logging",
                                          48,
                                          160,
                                          750,
                                          context,
                                          icon: Icons.menu_book_outlined,
                                          onPressed: () {
                                            trackTrivialAchievement(
                                              "open_food_logging",
                                            );
                                            context.push('/food-logging');
                                          },
                                        ),
                                        80.ms,
                                      ),
                                SizedBox(
                                  height: Responsive.height(context, 12),
                                ),
                                isLoading
                                    ? buildPlaceholderButton()
                                    : _maybeAnimate(
                                        customButton(
                                          "Explore",
                                          48,
                                          160,
                                          750,
                                          context,
                                          icon: Icons.explore_outlined,
                                          onPressed: () {
                                            trackTrivialAchievement(
                                              "open_explore",
                                            );
                                            context.push('/explore');
                                          },
                                        ),
                                        160.ms,
                                      ),
                                SizedBox(
                                  height: Responsive.height(context, 12),
                                ),
                                // REMINDERS TAB
                                isLoading
                                    ? buildPlaceholderButton()
                                    : _maybeAnimate(
                                        customButton(
                                          "Reminders",
                                          48,
                                          160,
                                          750,
                                          context,
                                          icon: Icons.notifications_outlined,
                                          onPressed: () {
                                            trackTrivialAchievement(
                                              "open_reminders",
                                            );
                                            context.push('/reminders');
                                          },
                                        ),
                                        240.ms,
                                      ),
                                SizedBox(
                                  height: Responsive.height(context, 12),
                                ),
                                // BADGES TAB
                                isLoading
                                    ? buildPlaceholderButton()
                                    : _maybeAnimate(
                                        customButton(
                                          "Badges",
                                          48,
                                          160,
                                          750,
                                          context,
                                          icon: Icons.emoji_events_outlined,
                                          onPressed: () {
                                            trackTrivialAchievement(
                                              "open_badges",
                                            );
                                            context.push('/badges');
                                          },
                                        ),
                                        320.ms,
                                      ),
                                SizedBox(
                                  height: Responsive.height(context, 12),
                                ),
                                // LEADERBOARD TAB
                                isLoading
                                    ? buildPlaceholderButton()
                                    : _maybeAnimate(
                                        customButton(
                                          "Leaderboard",
                                          48,
                                          160,
                                          750,
                                          context,
                                          icon: Icons.leaderboard_outlined,
                                          onPressed: () {
                                            trackTrivialAchievement(
                                              "open_leaderboard",
                                            );
                                            context.push('/leaderboard');
                                          },
                                        ),
                                        400.ms,
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Footer box
                  Footer(
                    profilePicture: userManager.insertProfilePicture(),
                    // Rebuild footer with correct Profile Picture
                    onProfileImageUpdated: () {
                      if (!mounted) return;
                      setState(() {}); // safely rebuild HomeScreen
                    }, // Current state required for rebuilding Home Screen if the user clicks the profile picture for redirection to Personal Preferences
                  ),
                ],
              ),
              // Align Widget must be the last child of this Stack so it appears above all other widgets
              Align(
                alignment: Alignment.topCenter,
                child: buildDailyRewardConfetti(dailyRewardConfettiController),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
