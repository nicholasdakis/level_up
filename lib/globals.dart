import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user/user_data.dart';
import 'user/user_data_manager.dart';
import 'dart:ui';

ValueNotifier<int> expNotifier = ValueNotifier<int>(
  currentUserData?.expPoints ?? 0,
);

// for updating HomeScreen when app color is updated
ValueNotifier<Color> appColorNotifier = ValueNotifier<Color>(
  Color.fromARGB(255, 45, 45, 45),
);

UserData?
currentUserData; // global current user-specific variable (not Firestore-dependent)
final UserDataManager userManager =
    UserDataManager(); // global current user manager variable (not Firestore-dependent)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin(); // global instance of the notification plugin

// CREATE TEXT WITH THE MAIN APP FONT
Widget textWithFont(
  String text,
  double screenWidth,
  double letterSize, {
  TextDecoration? decoration,
  Color? color,
  TextAlign? alignment,
}) {
  // optional decoration, alignment and color parameters
  return RichText(
    textAlign: alignment ?? TextAlign.center,
    text: TextSpan(
      text: text,
      style: GoogleFonts.manrope(
        fontSize: screenWidth * letterSize,
        color:
            color ?? Colors.white, // defaults to white if no parameter is given
        shadows: [
          Shadow(
            offset: Offset(4, 4),
            blurRadius: 10,
            color: const Color.fromARGB(255, 0, 0, 0),
          ),
        ],
        decoration:
            decoration ??
            TextDecoration
                .none, // defaults to no decoration if no parameter is given
      ),
    ),
  );
}

// CREATE THE TITLE TEXT OF EACH NEW SCREEN
Widget createTitle(String text, double screenWidth) {
  return Text(
    text,
    style: GoogleFonts.dangrek(
      fontSize: screenWidth * 0.12,
      color: Colors.white,
      shadows: [
        Shadow(
          offset: Offset(4, 4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0),
        ),
      ],
    ),
  );
}

// CREATE TEXT INSIDE OF A CARD
Widget textWithCard(String text, double screenWidth, double letterSize) {
  return Card(
    elevation: 10,
    color: appColorNotifier.value.withAlpha(64),
    child: Padding(
      padding: EdgeInsetsGeometry.all(4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: letterSize * screenWidth,
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(4, 4),
              blurRadius: 10,
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
          ],
        ),
      ),
    ),
  );
}

// ADD ITEMS TO A DRAWER, AND ON TAP: CLOSE THE DRAWER AND CHANGE TO THE APPROPRIATE SCREEN
Widget drawerItem(
  String text,
  IconData icon,
  screenWidth,
  context, {
  Widget? destination,
  Offset? startOffset = const Offset(0, 1),
}) {
  return Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Icon(icon, color: Color(0xFF121212)),
      title: textWithFont(
        text,
        screenWidth,
        0.05,
        color: Colors.white,
        alignment: TextAlign.left,
      ),
      hoverColor: Color.fromARGB(255, 43, 43, 43),
      onTap: () {
        Navigator.pop(context); // close the Drawer
        if (destination != null) {
          changeToScreen(context, destination, startOffset: startOffset);
        }
      },
    ),
  );
}

// CREATE THE CUSTOM TEXT MEANT FOR BUTTONS
Widget buttonText(String text, double letterSize) {
  return Text(
    text,
    textAlign: TextAlign.center,
    style: GoogleFonts.dangrek(
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

// CREATE THE CUSTOM BUTTONS THAT CAN OPTIONALLY LEAD TO NEW SCREENS (destinations)
Widget customButton(
  String text,
  double letterSize,
  double screenHeight,
  double screenWidth,
  BuildContext context, {
  Widget? destination,
  VoidCallback? onPressed,
  Color? baseColor,
}) {
  Color color = baseColor =
      currentUserData!.appColor; // app theme is the user's chosen theme
  // convert the colors to ints to use in the ARGB constructor
  // extract the red, green, blue components from the base color
  final int red = (color.r * 255).round().clamp(0, 255);
  final int green = (color.g * 255).round().clamp(0, 255);
  final int blue = (color.b * 255).round().clamp(0, 255);

  return SizedBox(
    height: screenHeight * 0.15, // Button height relative to screen
    width: screenWidth * 0.90, // Button width relative to screen
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30), // Rounded corners
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 15,
              sigmaY: 15,
            ), // Blur background, add glass-like effect
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB(
                  (0.15 * 255).round(),
                  red,
                  green,
                  blue,
                ), // Translucent background color
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Color.fromARGB(
                    (0.3 * 255).round(),
                    red,
                    green,
                    blue,
                  ), // Border with opacity
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB(
                      (0.25 * 255).round(),
                      0,
                      0,
                      0,
                    ), // shadows
                    offset: Offset(0, 4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap:
                  onPressed ??
                  () {
                    if (destination != null) {
                      changeToScreen(context, destination);
                    }
                  },
              // ripple effect when clicking
              splashColor: Color.fromARGB(
                (0.1 * 255).round(),
                red,
                green,
                blue,
              ), // Ripple color
              highlightColor: Color.fromARGB(
                (0.05 * 255).round(),
                red,
                green,
                blue,
              ), // Highlight on tap
              child: Center(
                child: buttonText(text, screenWidth * 0.1),
              ), // Text centered and sized
            ),
          ),
        ],
      ),
    ),
  );
}

// Simpler version of the customButton widget code to visually have customButtons without all the logic their constructors need
Widget simpleCustomButton(
  String text,
  BuildContext context, {
  required VoidCallback onPressed,
  Color baseColor = Colors.blue,
}) {
  final red = (baseColor.red).clamp(0, 255);
  final green = (baseColor.green).clamp(0, 255);
  final blue = (baseColor.blue).clamp(0, 255);

  final screenHeight = MediaQuery.of(context).size.height;
  final screenWidth = MediaQuery.of(context).size.width;

  return SizedBox(
    height: screenHeight * 0.15,
    width: screenWidth * 0.90,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB((0.15 * 255).round(), red, green, blue),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Color.fromARGB((0.3 * 255).round(), red, green, blue),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB((0.25 * 255).round(), 0, 0, 0),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onPressed,
              splashColor: Color.fromARGB(
                (0.1 * 255).round(),
                red,
                green,
                blue,
              ),
              highlightColor: Color.fromARGB(
                (0.05 * 255).round(),
                red,
                green,
                blue,
              ),
              child: Center(child: buttonText(text, screenWidth * 0.1)),
            ),
          ),
        ],
      ),
    ),
  );
}

// CHANGE SCREEN (DART FILE) WITH A TRANSITION
void changeToScreen(
  BuildContext context,
  Widget destination, {
  Offset? startOffset = const Offset(0, 1),
}) {
  Navigator.push(
    context,
    PageRouteBuilder(
      // Animation when switching screen
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionDuration: Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final start =
            startOffset ??
            Offset(
              0.0,
              1.0,
            ); // Choose where to start, or default to starting right below the screen
        final finish = Offset.zero; // Stop right at the top of the screen
        final tween = Tween(
          begin: start,
          end: finish,
        ).chain(CurveTween(curve: Curves.easeIn));
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    ),
  );
}
