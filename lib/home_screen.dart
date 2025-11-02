import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'screens/calorie_calculator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/explore.dart';
import 'screens/food_logging.dart';
import 'screens/reminders.dart';
import 'screens/badges.dart';
import 'screens/leaderboard.dart';
import 'screens/settings.dart';
import 'screens/footer.dart';
import 'screens/daily_rewards.dart';
import 'globals.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  // Load user data from Firestore
  void initState() {
    super.initState();
    initializeUser();
  }

  // Method for initializing the user's stats from Firestore
  Future<void> initializeUser() async {
    await userManager.loadUserData(); // load stats first

    // Sync ValueNotifier with the loaded XP so the footer is accurate upon logging in
    expNotifier.value = currentUserData?.expPoints ?? 0;

    // Check if the Daily Reward Dialog Box should open
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserData!.uid)
        .get();
    final canClaim = doc.data()?['canClaimDailyReward'] ?? true;
    // Only show the daily reward dialog after user data is loaded and mounted
    if (mounted && canClaim) {
      if (mounted && canClaim) {
        final dailyRewardDialog = DailyRewardDialog();
        await dailyRewardDialog.showDailyRewardDialog(context);
      }
    }

    if (mounted) setState(() {}); // rebuild UI with loaded stats
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
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      drawer: buildSettingsDrawer(
        screenWidth,
        context,
        onProfileImageUpdated: () {
          if (!mounted) return;
          setState(() {}); // rebuild HomeScreen
        },
      ),
      backgroundColor: Color(0xFF1E1E1E),
      // Header
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          screenHeight * 0.15,
        ), // Alter default appBar size
        child: AppBar(
          automaticallyImplyLeading:
              false, // Prevent the automatic hamburger icon from appearing
          scrolledUnderElevation:
              0, // So the appBar does not change color when the user scrolls down
          backgroundColor: Color(0xFF121212),
          centerTitle: true,
          toolbarHeight:
              screenHeight * 0.5, // Prevent the icon from cutting in half
          elevation: 0,
          actions: [
            // automatically aligns the icon into the top right of the screen
            Padding(
              padding: EdgeInsets.only(
                top: screenHeight * 0.05,
                right: screenWidth * 0.025,
              ),
              child: Builder(
                // Wrapped in Builder so Scaffold.of() succeeds
                builder: (context) => IconButton(
                  icon: Icon(
                    Icons.settings,
                    size: screenWidth * 0.1,
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
                top: screenWidth * 0.125,
              ), // Move the title text down a little bit
              // Manually make the title text, since appBar is already being used
              child: Text(
                "Level Up!",
                style: GoogleFonts.dangrek(
                  fontSize: screenWidth * 0.13,
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
      body: Column(
        children: [
          // Middle body
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(screenHeight * 0.02),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // CALORIE CALCULATOR BUTTON
                        customButton(
                          "Calorie Calculator",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          destination: CalorieCalculator(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // FOOD LOGGING TAB
                        customButton(
                          "Food Logging",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          destination: FoodLogging(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        customButton(
                          "Explore",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          destination: Explore(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // REMINDERS TAB
                        customButton(
                          "Reminders",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          destination: Reminders(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // BADGES TAB
                        customButton(
                          "Badges",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          destination: Badges(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // LEADERBOARD TAB
                        customButton(
                          "Leaderboard",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
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
    );
  }
}
