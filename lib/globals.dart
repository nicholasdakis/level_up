import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user/user_data.dart';
import 'user/user_data_manager.dart';

ValueNotifier<int> expNotifier = ValueNotifier<int>(
  currentUserData?.expPoints ?? 0,
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
      style: GoogleFonts.russoOne(
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
    color: Color.fromARGB(255, 36, 36, 36).withAlpha(200),
    child: Padding(
      padding: EdgeInsetsGeometry.all(4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.russoOne(
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
  VoidCallback? onPressed, // optional callback for custom actions
}) {
  return SizedBox(
    // to explicitly control the ElevatedButton size
    height: screenHeight * 0.15,
    width: screenWidth * 0.90,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Color(0xFF2A2A2A), // Actual button color
        foregroundColor: Colors.white, // Button text color
        side: BorderSide(color: Colors.black, width: screenWidth * 0.005),
      ),
      onPressed:
          onPressed ??
          () {
            // If no custom action provided, fallback to navigation
            if (destination == null) {
              // No destination, so stop
              return;
            }
            changeToScreen(context, destination);
          },
      child: buttonText(text, screenWidth * 0.1),
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
