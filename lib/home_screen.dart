import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/calorie_calculator.dart';
import 'screens/settings_buttons/settings_icon_button.dart';
import 'screens/explore.dart';
import 'screens/food_logging.dart';
import 'screens/reminders.dart';
import 'screens/badges.dart';
import 'screens/leaderboard.dart';
import 'screens/settings.dart';
import 'screens/footer.dart';
import 'screens/daily_rewards.dart';
import 'globals.dart';
import 'utility/responsive.dart';
import 'screens/settings_buttons/personal_preferences.dart';
import 'utility/fcm/fcm_service.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'user/user_data_manager.dart' show trackTrivialAchievement;

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late VoidCallback _appColorListener;

  // Controller that fades and slides each button into place one after the other
  late final AnimationController entranceController;

  @override
  void initState() {
    super.initState();

    // Load user data from Postgres, then initialize FCM once data is ready
    initializeUser();

    // Update the HomeScreen with the updated app color
    _appColorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_appColorListener);

    // Initialize confetti controllers
    confettiControllerinit();

    // Controller for the staggered button entrance animation
    entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  // To prevent memory leaks
  @override
  void dispose() {
    appColorNotifier.removeListener(_appColorListener);
    dailyRewardConfettiController.dispose();
    _scrollController.dispose();
    entranceController.dispose();
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

  // Method for initializing the user upon app boot up
  Future<void> initializeUser() async {
    await userManager.loadUserData();
    if (mounted) setState(() {});

    // Sync ValueNotifier with loaded XP amount for visually accurate Footer experience
    expNotifier.value = currentUserData?.expPoints ?? 0;
    debugPrint('XP loaded: ${currentUserData?.expPoints}');

    // Defer dialog until after the first frame so BuildContext is safely used
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Give users without a username a dialog box to choose one
      if (currentUserData!.username == currentUserData!.uid) {
        await promptUsernameDialog(context);
      }

      if (canClaimDailyReward() && mounted) buildDailyRewardDialog();

      if (mounted) {
        setState(() {
          isLoading = false;
        }); // rebuild UI with loaded stats

        // Start the staggered button entrance animation once data is ready
        entranceController.forward();
      }
    });

    // Initialize FCM in the background so it doesn't block the UI from rendering
    if (mounted) FcmService.initialize(context);
  }

  bool isLoading = true; // for the skeletonizer

  // Helper that fades and slides a child into place using a portion of the entrance timeline
  Widget buildStaggered(double start, double end, Widget child) {
    // Make a curve that only runs between start and end out of the full 0.0 to 1.0 timeline
    final curve = CurvedAnimation(
      parent: entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    // Slide the child up from slightly below its final position
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(curve);

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
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
              Responsive.height(context, 200),
            ), // Alter default appBar size
            child: AppBar(
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
                    shaderCallback: (bounds) => subtleTextGradient().createShader(
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
                                color: appColorNotifier.value.withAlpha(200),
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
          body: Stack(
            // Stack for confetti to appear on top
            children: [
              Column(
                children: [
                  // Middle body
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
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
                                  // Current app version text
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "App version: Beta 04.18",
                                      style: TextStyle(
                                        color: darkenColor(
                                          appColorNotifier.value,
                                          0.3,
                                        ),
                                        fontSize: Responsive.font(context, 15),
                                      ),
                                    ),
                                  ),
                                  // CALORIE CALCULATOR BUTTON
                                  isLoading
                                      ? buildPlaceholderButton()
                                      : buildStaggered(
                                          0.0,
                                          0.5,
                                          customButton(
                                            "Calorie Calculator",
                                            48,
                                            160,
                                            750,
                                            context,
                                            onPressed: () {
                                              trackTrivialAchievement(
                                                "calorie_calculator",
                                              );
                                              changeToScreen(
                                                context,
                                                CalorieCalculator(),
                                              );
                                            },
                                          ),
                                        ),
                                  SizedBox(
                                    height: Responsive.height(context, 12),
                                  ), // Space between buttons
                                  // FOOD LOGGING TAB
                                  isLoading
                                      ? buildPlaceholderButton()
                                      : buildStaggered(
                                          0.1,
                                          0.6,
                                          customButton(
                                            "Food Logging",
                                            48,
                                            160,
                                            750,
                                            context,
                                            onPressed: () {
                                              trackTrivialAchievement(
                                                "open_food_logging",
                                              );
                                              changeToScreen(
                                                context,
                                                FoodLogging(),
                                              );
                                            },
                                          ),
                                        ),
                                  SizedBox(
                                    height: Responsive.height(context, 12),
                                  ), // Space between buttons
                                  isLoading
                                      ? buildPlaceholderButton()
                                      : buildStaggered(
                                          0.2,
                                          0.7,
                                          customButton(
                                            "Explore",
                                            48,
                                            160,
                                            750,
                                            context,
                                            onPressed: () {
                                              trackTrivialAchievement(
                                                "open_explore",
                                              );
                                              changeToScreen(
                                                context,
                                                Explore(),
                                              );
                                            },
                                          ),
                                        ),
                                  SizedBox(
                                    height: Responsive.height(context, 12),
                                  ), // Space between buttons
                                  // REMINDERS TAB
                                  isLoading
                                      ? buildPlaceholderButton()
                                      : buildStaggered(
                                          0.3,
                                          0.8,
                                          customButton(
                                            "Reminders",
                                            48,
                                            160,
                                            750,
                                            context,
                                            onPressed: () {
                                              trackTrivialAchievement(
                                                "open_reminders",
                                              );
                                              changeToScreen(
                                                context,
                                                Reminders(),
                                              );
                                            },
                                          ),
                                        ),
                                  SizedBox(
                                    height: Responsive.height(context, 12),
                                  ), // Space between buttons
                                  // BADGES TAB
                                  isLoading
                                      ? buildPlaceholderButton()
                                      : buildStaggered(
                                          0.4,
                                          0.9,
                                          customButton(
                                            "Badges",
                                            48,
                                            160,
                                            750,
                                            context,
                                            onPressed: () {
                                              trackTrivialAchievement(
                                                "open_badges",
                                              );
                                              changeToScreen(context, Badges());
                                            },
                                          ),
                                        ),
                                  SizedBox(
                                    height: Responsive.height(context, 12),
                                  ), // Space between buttons
                                  // LEADERBOARD TAB
                                  isLoading
                                      ? buildPlaceholderButton()
                                      : buildStaggered(
                                          0.5,
                                          1,
                                          customButton(
                                            "Leaderboard",
                                            48,
                                            160,
                                            750,
                                            context,
                                            onPressed: () {
                                              trackTrivialAchievement(
                                                "open_leaderboard",
                                              );
                                              changeToScreen(
                                                context,
                                                Leaderboard(),
                                              );
                                            },
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Footer box
                  Footer(
                    screenHeight: screenHeight,
                    screenWidth: screenWidth,
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
