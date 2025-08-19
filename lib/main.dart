import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// --- Imports for switching screens ---
import 'screens/calorie_calculator.dart';
import 'screens/food_logging.dart';
import 'screens/reminders.dart';
import 'screens/badges.dart';
import 'screens/leaderboard.dart';
import 'screens/calorie_calculator_buttons/results.dart';

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

  Widget buttonText(String text, double letterSize) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.workSans(
        fontSize: letterSize,
        color: Colors.white,
        shadows: [
          Shadow(
            // Up Left
            offset: Offset(-1, -1),
            color: Colors.black,
          ),
          Shadow(
            // Up Right
            offset: Offset(1, -1),
            color: Colors.black,
          ),
          Shadow(
            // Down Left
            offset: Offset(-1, 1),
            color: Colors.black,
          ),
          Shadow(
            // Down Right
            offset: Offset(1, 1),
            color: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget customButton(
    String text,
    double letterSize,
    double screenHeight,
    double screenWidth,
    BuildContext context,
    Widget destination,
  ) {
    return SizedBox(
      // to explicitly control the ElevatedButton size
      height: screenHeight * 0.15,
      width: screenWidth * 0.90,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: Color(0xFF2A2A2A), // Actual button color
          foregroundColor: Colors.white, // Button text color
          side: BorderSide(color: Colors.black, width: screenWidth * 0.005),
        ),
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              // Animation when switching screen
              pageBuilder: (context, animation, secondaryAnimation) =>
                  destination,
              transitionDuration: Duration(milliseconds: 400),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const start = Offset(
                      0.0,
                      1.0,
                    ); // Start right below the screen
                    const finish =
                        Offset.zero; // Stop right at the top of the screen
                    final tween = Tween(
                      begin: start,
                      end: finish,
                    ).chain(CurveTween(curve: Curves.easeIn));
                    final offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
            ),
          );
        },
        child: buttonText(text, screenWidth * 0.1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      drawer: Drawer(
        // The contents of the Settings gear icon button
        child: Container(
          color: Color.fromARGB(
            255,
            43,
            43,
            43,
          ), // Body color of the settings popup
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xFF121212),
                ), // Header color of the settings popup
                child: textWithFont(
                  "Settings",
                  screenWidth,
                  0.15,
                  color: Colors.white,
                ),
              ),
              ListTile(
                leading: Icon(Icons.account_circle, color: Color(0xFF121212)),
                title: textWithFont(
                  "Personal Preferences",
                  screenWidth,
                  0.05,
                  color: Colors.white,
                  alignment: TextAlign.left,
                ),
                onTap: () => Navigator.pop(context), // close the Drawer
              ),
              ListTile(
                leading: Icon(
                  Icons.person_pin_rounded,
                  color: Color(0xFF121212),
                ),
                title: textWithFont(
                  "About",
                  screenWidth,
                  0.05,
                  color: Colors.white,
                  alignment: TextAlign.left,
                ),
                onTap: () => Navigator.pop(context), // close the Drawer
              ),
              ListTile(
                leading: Icon(Icons.phone_iphone, color: Color(0xFF121212)),
                title: textWithFont(
                  "Contact",
                  screenWidth,
                  0.05,
                  color: Colors.white,
                  alignment: TextAlign.left,
                ),
                onTap: () => Navigator.pop(context), // close the Drawer
              ),
              ListTile(
                leading: Icon(Icons.monetization_on, color: Color(0xFF121212)),
                title: textWithFont(
                  "Donate",
                  screenWidth,
                  0.05,
                  color: Colors.white,
                  alignment: TextAlign.left,
                ),
                onTap: () => Navigator.pop(context), // close the Drawer
              ),
            ],
          ),
        ),
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
                          CalorieCalculator(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // FOOD LOGGING TAB
                        customButton(
                          "Food Logging",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          FoodLogging(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // REMINDERS TAB
                        customButton(
                          "Reminders",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          Reminders(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // BADGES TAB
                        customButton(
                          "Badges",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          Badges(),
                        ),
                        SizedBox(height: 10.h), // Space between buttons
                        // LEADERBOARD TAB
                        customButton(
                          "Leaderboard",
                          screenWidth * 0.1,
                          screenHeight,
                          screenWidth,
                          context,
                          Leaderboard(),
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
