import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'screens/calorie_calculator.dart';
import 'screens/food_logging.dart';
import 'screens/reminders.dart';
import 'screens/badges.dart';
import 'screens/leaderboard.dart';
import 'screens/settings.dart';
import 'globals.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Base size, scales from this
      minTextAdapt: true, // Keep text readable on very small screens
      builder: (context, child) {
        return MaterialApp(debugShowCheckedModeBanner: false, home: child);
      },
      child: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      drawer: buildSettingsDrawer(screenWidth, context),
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
              child: Text(
                "Level Up!",
                style: GoogleFonts.pacifico(
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
          Container(
            height: screenHeight * 0.15,
            width: screenWidth,
            color: Color(0xFF121212),
            padding: EdgeInsets.all(25),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer bar
                Container(
                  height: screenHeight * 0.020,
                  width: screenWidth * 0.615,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Inner bar
                Container(
                  height: screenHeight * 0.015,
                  width: screenWidth * 0.6,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 227, 210, 210),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
