// home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/settings/settings_icon_button.dart';
import 'screens/settings.dart';
import 'screens/footer.dart';
import 'screens/daily_rewards.dart';
import 'authentication/auth_services.dart';
import 'globals.dart';
import 'utility/responsive.dart';
import 'screens/onboarding.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'services/user_data_manager.dart' show trackTrivialAchievement;
import 'services/fcm/notification_service.dart';
import 'services/fcm/web_fcm_token_stub.dart'
    if (dart.library.js_interop) 'services/fcm/web_fcm_token_web.dart'
    as web_fcm;

class _HomeAnimationState {
  static bool buttonsAnimated = false;
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

  // 0 = buttons step, 1 = footer step, 2 = settings step, -1 = tour not active
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

  Future<void> buildDailyRewardDialog() async {
    if (!mounted) return;
    await DailyRewardDialog().showDailyRewardDialog(
      context,
      dailyRewardConfettiController,
    );
  }

  // Advances the tour step on tap, finishing after the settings step
  Future<void> _onTourTap() async {
    if (_tourStep == 0) {
      setState(() => _tourStep = 1);
    } else if (_tourStep == 1) {
      setState(() => _tourStep = 2);
    } else if (_tourStep == 2) {
      setState(() => _tourStep = -1);
      await showUsernameSetupDialog(context);
      if (canClaimDailyReward() && mounted) {
        await buildDailyRewardDialog();
        // Ask for notification permission after the first reward so the user understands why
        if (mounted) await requestNotificationPermissionIfNeeded(context);
      }
    }
  }

  // AppShell already loaded user data, updated UTC offset, synced XP, and
  // initialized FCM. HomeScreen only needs to show the home-specific dialogs.
  Future<void> initializeUser() async {
    if (currentUserData == null) return;

    if (userManager.lastLoadFailed) {
      if (!mounted) return;
      setState(() => loadFailed = true);
      await showFrostedAlertDialog(
        context: context,
        title: "Failed to load",
        content: Text(
          "Check your connection and try again.",
          style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _retry();
            },
            child: const Text("Retry"),
          ),
        ],
      );
      return;
    }

    if (canClaimDailyReward() && mounted && !isNewUser && !isGuest) {
      buildDailyRewardDialog();
    }

    if (mounted) {
      setState(() => isLoading = false);
      if (kIsWeb &&
          !isNewUser &&
          web_fcm.getNotificationPermission() != 'granted' &&
          currentUserData!.notificationsEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showBrowserBlockedDialog(context);
        });
      }
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

  // Guest user footer
  Widget _buildGuestFooter() {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return GestureDetector(
      onTap: () async {
        await authService.value.signOut(); // clears guest state
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          Responsive.width(context, 24),
          Responsive.height(context, 16),
          Responsive.width(context, 24),
          Responsive.height(context, 16) + bottomInset,
        ),
        decoration: BoxDecoration(
          color: darkenColor(appColorNotifier.value, 0.025),
          border: Border(
            top: BorderSide(
              color: Colors.white.withAlpha(25),
              width: Responsive.height(context, 3),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're in guest mode",
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "Create an account to save your progress",
                    style: GoogleFonts.manrope(
                      color: Colors.white54,
                      fontSize: Responsive.font(context, 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.width(context, 12)),
            frostedButton(
              "Sign Up",
              context,
              onPressed: () async {
                await authService.value
                    .signOut(); // exits guest mode and redirects to login
              },
            ),
          ],
        ),
      ),
    );
  }

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
                    // Step 2 on mobile: left-anchored narrow card so the gear icon stays visible
                    Positioned(
                      left: Responsive.width(context, 16),
                      right: (_tourStep == 2 && Responsive.isMobile(context))
                          ? null
                          : Responsive.width(context, 16),
                      top: (_tourStep == 0 || _tourStep == 2)
                          ? Responsive.height(context, 16)
                          : null,
                      bottom: _tourStep == 1
                          ? Responsive.height(context, 100)
                          : null,
                      child: (_tourStep == 2 && Responsive.isMobile(context))
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width -
                                    Responsive.width(context, 120),
                              ),
                              child:
                                  buildShowcaseTooltip(
                                        context,
                                        title: 'Settings',
                                        description:
                                            'The gear icon to the right opens a settings drawer where you can update your preferences, send feedback, and more.',
                                      )
                                      .animate(key: ValueKey(_tourStep))
                                      .fadeIn(duration: 200.ms),
                            )
                          : Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 500,
                                ),
                                child: buildShowcaseTooltip(
                                  context,
                                  title: _tourStep == 0
                                      ? 'Main Features'
                                      : _tourStep == 1
                                      ? 'Footer'
                                      : 'Settings',
                                  description: _tourStep == 0
                                      ? 'Below are your six main tabs: Food Logging, Explore, Leaderboard, Badges, Reminders, and Calorie Calculator.'
                                      : _tourStep == 1
                                      ? 'Below is your footer bar which contains your level, XP bar, and profile picture. Tapping your profile picture takes you to your Personal Preferences tab.'
                                      : 'The gear icon to the right opens a settings drawer where you can update your preferences, send feedback, and more.',
                                ).animate(key: ValueKey(_tourStep)).fadeIn(duration: 200.ms),
                              ),
                            ),
                    ),
                    // Tap hint at the bottom
                    Positioned(
                      bottom: Responsive.height(context, 12),
                      left: 0,
                      right: 0,
                      child: Text(
                        _tourStep == 2
                            ? 'Tap anywhere to finish'
                            : 'Tap anywhere to continue',
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
                          // On web use the original padding; on native add status bar height since flexibleSpace renders behind it
                          top: kIsWeb
                              ? Responsive.width(context, 30)
                              : Responsive.height(context, 20) + MediaQuery.paddingOf(context).top * 1.5,
                          // Reserve space for the settings button on the right so the title never overlaps it
                          left: Responsive.width(context, 70),
                          right: Responsive.width(context, 70),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
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
                                      ..strokeWidth = Responsive.scale(
                                        context,
                                        3,
                                      )
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
                                        blurRadius: Responsive.scale(
                                          context,
                                          25,
                                        ),
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
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // room above first button
                                    SizedBox(
                                      height: Responsive.height(context, 8),
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
                                                    context.push(
                                                      '/food-logging',
                                                    );
                                                  },
                                                ),
                                                0.ms,
                                              ),
                                        SizedBox(
                                          height: Responsive.height(
                                            context,
                                            12,
                                          ),
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
                                          height: Responsive.height(
                                            context,
                                            12,
                                          ),
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
                                                    context.push(
                                                      '/leaderboard',
                                                    );
                                                  },
                                                ),
                                                160.ms,
                                              ),
                                        SizedBox(
                                          height: Responsive.height(
                                            context,
                                            12,
                                          ),
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
                                          height: Responsive.height(
                                            context,
                                            12,
                                          ),
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
                                          height: Responsive.height(
                                            context,
                                            12,
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
                    ),
                    // Footer: show sign-up prompt for guests, normal XP footer for real users
                    if (isGuest)
                      _buildGuestFooter()
                    else
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
