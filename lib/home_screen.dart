// home_screen.dart
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
import 'screens/onboarding.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late VoidCallback _appColorListener;

  // 0 = buttons step, 1 = footer step, -1 = tour not active
  int _tourStep = -1;

  @override
  void initState() {
    super.initState();

    // Update the HomeScreen with the updated app color
    _appColorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_appColorListener);

    // Initialize confetti controllers before _onAppReady
    confettiControllerinit();

    // If data is already loaded and the user doesn't need onboarding, skip the skeleton entirely
    // New users keep isLoading = true so the skeleton shows instead of a flash of home content
    final needsOnboarding =
        currentUserData?.username != null &&
        currentUserData?.username == currentUserData?.uid;
    if (appReadyNotifier.value &&
        !userManager.lastLoadFailed &&
        !needsOnboarding) {
      isLoading = false;
    }

    appReadyNotifier.addListener(_onAppReady);
    if (appReadyNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onAppReady();
      });
    }
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
    return simpleCustomButton(
      "Placeholder",
      48,
      160,
      750,
      context,
      onPressed: () {},
      baseColor: appColorNotifier.value,
    );
  }

  bool get isNewUser =>
      currentUserData?.username != null &&
      currentUserData?.username == currentUserData?.uid;

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

  // Advances the tour step on tap, finishing after the footer step
  Future<void> _onTourTap() async {
    if (_tourStep == 0) {
      // advance from buttons to footer
      setState(() => _tourStep = 1);
    } else if (_tourStep == 1) {
      // finish the tour and show the username dialog, and then give the daily reward dialog
      setState(() => _tourStep = -1);
      await showUsernameSetupDialog(context);
      if (canClaimDailyReward() && mounted) {
        buildDailyRewardDialog();
      }
    }
  }

  // AppShell already loaded user data, updated UTC offset, synced XP, and
  // initialized FCM. HomeScreen only needs to show the home-specific dialogs.
  Future<void> initializeUser() async {
    if (currentUserData == null) return;

    if (userManager.lastLoadFailed) {
      if (mounted) setState(() => loadFailed = true);
      return;
    }

    if (canClaimDailyReward() && mounted && !isNewUser) {
      buildDailyRewardDialog();
    }

    if (mounted) {
      setState(() => isLoading = false);
      if (isNewUser) {
        // Wait for the frame after isLoading = false so all targets are visible
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await showWelcomeTourDialog(context);
          if (!mounted) return;
          setState(() => _tourStep = 0); // start the tour on the buttons step
        });
      }
    }
  }

  // Method that retries loading user data after a failed fetch
  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      loadFailed = false;
      isLoading = true;
    });
    await userManager.loadUserData();
    if (currentUserData != null) {
      appColorNotifier.value = currentUserData!.appColor;
    }
    if (mounted) initializeUser();
  }

  bool isLoading = true;
  bool loadFailed = false;

  bool get _tourActive => _tourStep != -1;

  Widget _maybeAnimate(Widget button, Duration delay) {
    if (_HomeAnimationState.buttonsAnimated) return button;
    return button
        .animate()
        .fadeIn(delay: delay, duration: 400.ms)
        .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(ignoring: loadFailed, child: _buildBody()),
        // Full-screen tap catcher that advances the tour when active
        if (_tourActive)
          DefaultTextStyle(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onTourTap,
                child: Stack(
                  children: [
                    // Semi-transparent overlay so the UI behind is still visible
                    Container(color: Colors.black.withAlpha(120)),
                    // Tooltip positioned at the top for buttons step, bottom for footer step
                    Positioned(
                      left: Responsive.width(context, 16),
                      right: Responsive.width(context, 16),
                      top: _tourStep == 0
                          ? Responsive.height(context, 16)
                          : null,
                      bottom: _tourStep == 1
                          ? Responsive.height(context, 100)
                          : null,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child:
                              buildShowcaseTooltip(
                                    context,
                                    title: _tourStep == 0
                                        ? 'Main Features'
                                        : 'Footer',
                                    description: _tourStep == 0
                                        ? 'Below are your six main tabs: Food Logging, Explore, Leaderboard, Badges, Reminders, and Calorie Calculator.'
                                        : 'Below is your footer bar which contains your level, XP bar, and profile picture. Tapping your profile picture takes you to your Personal Preferences tab.',
                                  )
                                  .animate(key: ValueKey(_tourStep))
                                  .fadeIn(
                                    duration: 200.ms,
                                  ), // key so the animation plays for each tooltip
                        ),
                      ),
                    ),
                    // Tap hint at the bottom
                    Positioned(
                      bottom: Responsive.height(context, 12),
                      left: 0,
                      right: 0,
                      child: Text(
                        'Tap anywhere to continue',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (loadFailed)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 40),
              ),
              child: frostedGlassCard(
                context,
                baseRadius: 20,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 24),
                  vertical: Responsive.height(context, 28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Failed to load.",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 16),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 6)),
                    Text(
                      "Check your connection and try again.",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 13),
                        color: Colors.white54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Responsive.height(context, 20)),
                    simpleCustomButton(
                      "Retry",
                      16,
                      50,
                      160,
                      context,
                      onPressed: _retry,
                      baseColor: appColorNotifier.value,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return IgnorePointer(
      ignoring:
          _tourActive, // clicks are disregarded when the tutorial tour is showing
      // Show loading if user data not loaded yet
      child: Skeletonizer(
        enabled: isLoading,
        effect: ShimmerEffect(
          baseColor: darkenColor(appColorNotifier.value, 0.1),
          highlightColor: lightenColor(appColorNotifier.value, 0.2),
          duration: const Duration(milliseconds: 1200),
        ),
        child: Container(
          decoration: BoxDecoration(gradient: buildThemeGradient()),
          child: Scaffold(
            key: _scaffoldKey,
            drawer: buildSettingsDrawer(
              context,
              scaffoldKey: _scaffoldKey,
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
                    backgroundColor: darkenColor(appColorNotifier.value, 0.025),
                    centerTitle: true,
                    toolbarHeight: Responsive.buttonHeight(
                      context,
                      120,
                    ), // Prevent the icon from cutting in half
                    elevation: 0,
                    actions: [
                      SettingsIconButton(
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
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
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: Responsive.font(context, 55),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: Responsive.scale(context, 2),
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = Responsive.scale(context, 3)
                                    ..color = Colors.black.withAlpha(180),
                                ),
                              ),
                              // Fill + glow
                              Text(
                                "LEVEL UP!",
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: Responsive.font(context, 55),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: Responsive.scale(context, 2),
                                  color: Colors.white,
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
                  // Separator between header and body
                  Container(
                    height: Responsive.height(context, 3),
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
                                  // room above first button
                                  SizedBox(
                                    height: Responsive.height(context, 8),
                                  ),
                                  // Current app version badge
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        bottom: Responsive.height(context, 4),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.width(
                                          context,
                                          10,
                                        ),
                                        vertical: Responsive.height(context, 4),
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(12),
                                        borderRadius: BorderRadius.circular(
                                          Responsive.scale(context, 20),
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withAlpha(20),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        "BETA 05.04",
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(
                                            context,
                                            11,
                                          ),
                                          color: Colors.white.withAlpha(80),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // MAIN TABS
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                                onPressed: () {
                                                  trackTrivialAchievement(
                                                    "open_food_logging",
                                                  );
                                                  context.push('/food-logging');
                                                },
                                              ),
                                              0.ms,
                                            ),
                                      SizedBox(
                                        height: Responsive.height(context, 12),
                                      ),
                                      // EXPLORE TAB
                                      isLoading
                                          ? buildPlaceholderButton()
                                          : _maybeAnimate(
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
                                                  context.push('/explore');
                                                },
                                              ),
                                              80.ms,
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
                                                onPressed: () {
                                                  trackTrivialAchievement(
                                                    "open_leaderboard",
                                                  );
                                                  context.push('/leaderboard');
                                                },
                                              ),
                                              160.ms,
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
                                                onPressed: () {
                                                  trackTrivialAchievement(
                                                    "open_badges",
                                                  );
                                                  context.push('/badges');
                                                },
                                              ),
                                              240.ms,
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
                                                onPressed: () {
                                                  trackTrivialAchievement(
                                                    "open_reminders",
                                                  );
                                                  context.push('/reminders');
                                                },
                                              ),
                                              320.ms,
                                            ),
                                      SizedBox(
                                        height: Responsive.height(context, 12),
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
                                                onPressed: () {
                                                  trackTrivialAchievement(
                                                    "calorie_calculator",
                                                  );
                                                  context.push(
                                                    '/calorie-calculator',
                                                  );
                                                },
                                              ),
                                              400.ms,
                                            ),
                                    ],
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
                  child: buildDailyRewardConfetti(
                    dailyRewardConfettiController,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
