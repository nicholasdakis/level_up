import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/calorie_calculator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // Load user data from Firestore
  void initState() {
    super.initState();
    initializeUser();
    // Update the HomeScreen with the updated app color
    _appColorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_appColorListener);
    // Initialize confetti controllers
    confettiControllerinit();
  }

  // To prevent memory leaks
  @override
  void dispose() {
    appColorNotifier.removeListener(_appColorListener);
    dailyRewardConfettiController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<bool> canClaimDailyReward() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserData!.uid)
        .get();
    return doc.data()?['canClaimDailyReward'] ?? true;
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

    // Sync ValueNotifier with loaded XP amount for visually accurate Footer experience
    expNotifier.value = currentUserData?.expPoints ?? 0;
    debugPrint('XP loaded: ${currentUserData?.expPoints}');

    // Defer dialog until after the first frame so BuildContext is safely used
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await canClaimDailyReward()) buildDailyRewardDialog();

      // Give users without a username a dialog box to choose one
      if (currentUserData!.username == currentUserData!.uid) {
        await promptUsernameDialog(context);
      }

      if (mounted) setState(() {}); // rebuild UI with loaded stats
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    // Show loading if user data not loaded yet
    if (currentUserData == null) {
      return Scaffold(
        backgroundColor:
            Colors.grey[900], // default color if user's data can't be loaded
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
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
                child: Text(
                  "Level Up!",
                  style: GoogleFonts.dangrek(
                    fontSize: Responsive.font(context, 50),
                    color: Color(0xFFFFFFFF),
                    shadows: [
                      Shadow(
                        offset: Offset(4, 4),
                        blurRadius: 10,
                        color: Colors.black,
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
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Current app version text
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "App version: Beta 03.12",
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
                                customButton(
                                  "Calorie Calculator",
                                  48,
                                  160,
                                  750,
                                  context,
                                  destination: CalorieCalculator(),
                                ),
                                SizedBox(height: 10.h), // Space between buttons
                                // FOOD LOGGING TAB
                                customButton(
                                  "Food Logging",
                                  48,
                                  160,
                                  750,
                                  context,
                                  destination: FoodLogging(),
                                ),
                                SizedBox(height: 10.h), // Space between buttons
                                customButton(
                                  "Explore",
                                  48,
                                  160,
                                  750,
                                  context,
                                  destination: Explore(),
                                ),
                                SizedBox(height: 10.h), // Space between buttons
                                // REMINDERS TAB
                                customButton(
                                  "Reminders",
                                  48,
                                  160,
                                  750,
                                  context,
                                  destination: Reminders(),
                                ),
                                SizedBox(height: 10.h), // Space between buttons
                                // BADGES TAB
                                customButton(
                                  "Badges",
                                  48,
                                  160,
                                  750,
                                  context,
                                  destination: Badges(),
                                ),
                                SizedBox(height: 10.h), // Space between buttons
                                // LEADERBOARD TAB
                                customButton(
                                  "Leaderboard",
                                  48,
                                  160,
                                  750,
                                  context,
                                  destination: Leaderboard(),
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
    );
  }
}
