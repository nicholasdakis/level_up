import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/calorie_calculator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
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

  @override
  // Load user data from Firestore
  void initState() {
    super.initState();
    initializeUser();
    // Update the HomeScreen with the updated app color
    appColorNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    // Initialize confetti controllers
    confettiControllerinit();
  }

  // To prevent memory leaks
  @override
  void dispose() {
    dailyRewardConfettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Method for initializing the user's stats from Firestore
  Future<void> initializeUser() async {
    await userManager.loadUserData(); // load stats first

    // Sync ValueNotifier with the loaded XP so the footer is accurate upon logging in
    expNotifier.value = currentUserData?.expPoints ?? 0;

    // Check if the Daily Reward Dialog Box should open
    // Defer dialog until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserData!.uid)
          .get();
      final canClaim = doc.data()?['canClaimDailyReward'] ?? true;
      // Only show the daily reward dialog after user data is loaded and mounted
      if (mounted && canClaim) {
        final dailyRewardDialog = DailyRewardDialog();
        dailyRewardDialog.showDailyRewardDialog(
          context,
          dailyRewardConfettiController,
        );
      }

      // Give users without a username a dialog box to choose one
      if (currentUserData!.username == currentUserData!.uid) {
        TextEditingController usernameController = TextEditingController();
        await showUsernameDialogBox(
          context,
          "Choose your username",
          usernameController,
        );
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
    return Scaffold(
      drawer: buildSettingsDrawer(
        context,
        // rebuild on pfp image update
        onProfileImageUpdated: () {
          if (!mounted) return;
          setState(() {}); // rebuild HomeScreen
        },
      ),
      backgroundColor: appColorNotifier.value,
      // Header
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
            appColorNotifier.value,
            0.025,
          ), // Header color

          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(
            context,
            120,
          ), // Scale based on device // Prevent the icon from cutting in half
          elevation: 0,
          actions: [
            // automatically aligns the icon into the top right of the screen
            Padding(
              padding: EdgeInsets.only(
                top: Responsive.height(context, 20),
                right: Responsive.width(context, 20),
              ),
              child: Builder(
                // Wrapped in Builder so Scaffold.of() succeeds
                builder: (context) => IconButton(
                  icon: Icon(
                    Icons.settings,
                    size: Responsive.font(context, 64),
                    color: Colors.white,
                  ),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
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
                        padding: EdgeInsets.all(Responsive.height(context, 5)),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Current app version text
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "App version: Beta 02.27",
                                  style: TextStyle(
                                    color: darkenColor(
                                      appColorNotifier.value,
                                      0.1,
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
    );
  }
}
