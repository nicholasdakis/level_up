import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user/user_data.dart';
import 'user/user_data_manager.dart';
import 'dart:ui';
import 'utility/responsive.dart';

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
  BuildContext context,
  double baseFontSize, {
  TextDecoration? decoration,
  Color? color,
  TextAlign? alignment,
}) {
  return RichText(
    textAlign: alignment ?? TextAlign.center,
    text: TextSpan(
      text: text,
      style: GoogleFonts.manrope(
        fontSize: Responsive.font(
          context,
          baseFontSize,
        ), // Scale based on device
        color: color ?? Colors.white,
        shadows: [
          Shadow(
            offset: Offset(
              Responsive.scale(context, 4), // Scale based on device
              Responsive.scale(context, 4), // Scale based on device
            ),
            blurRadius: Responsive.scale(context, 10), // Scale based on device
            color: const Color.fromARGB(255, 0, 0, 0),
          ),
        ],
        decoration: decoration ?? TextDecoration.none,
      ),
    ),
  );
}

// CREATE THE TITLE TEXT OF EACH NEW SCREEN
Widget createTitle(String text, BuildContext context) {
  return Text(
    text,
    style: GoogleFonts.dangrek(
      fontSize: Responsive.font(context, 24), // Scale based on device
      color: Colors.white,
      shadows: [
        Shadow(
          offset: Offset(
            Responsive.scale(context, 4), // Scale based on device
            Responsive.scale(context, 4), // Scale based on device
          ),
          blurRadius: Responsive.scale(context, 10), // Scale based on device
          color: const Color.fromARGB(255, 0, 0, 0),
        ),
      ],
    ),
  );
}

// CREATE TEXT INSIDE OF A CARD
Widget textWithCard(String text, BuildContext context, double baseFontSize) {
  return Card(
    elevation: Responsive.scale(context, 10), // Scale based on device
    color: appColorNotifier.value.withAlpha(64),
    child: Padding(
      padding: EdgeInsets.all(
        Responsive.padding(context, 4),
      ), // Scale based on device
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(
            context,
            baseFontSize,
          ), // Scale based on device
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(
                Responsive.scale(context, 4), // Scale based on device
                Responsive.scale(context, 4), // Scale based on device
              ),
              blurRadius: Responsive.scale(
                context,
                10,
              ), // Scale based on device
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
  BuildContext context, {
  Widget? destination,
  Offset startOffset = const Offset(0, 1),
}) {
  return Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Icon(icon, color: Colors.white),
      title: textWithFont(
        text,
        context,
        Responsive.font(context, 18), // scaled responsively
        color: Colors.white,
        alignment: TextAlign.left,
      ),
      hoverColor: Colors.white.withAlpha(50),
      onTap: () {
        Navigator.pop(context); // close the drawer
        if (destination != null) {
          changeToScreen(context, destination, startOffset: startOffset);
        }
      },
    ),
  );
}

// CREATE THE CUSTOM TEXT MEANT FOR BUTTONS
Widget buttonText(String text, BuildContext context, double baseFontSize) {
  return Text(
    text,
    textAlign: TextAlign.center,
    style: GoogleFonts.dangrek(
      fontSize: Responsive.font(context, baseFontSize), // Scale based on device
      color: Colors.white,
      shadows: [
        Shadow(
          offset: Offset(
            -Responsive.scale(context, 1), // Scale based on device
            -Responsive.scale(context, 1), // Scale based on device
          ),
          color: Colors.black,
        ),
        Shadow(
          offset: Offset(
            Responsive.scale(context, 1), // Scale based on device
            -Responsive.scale(context, 1), // Scale based on device
          ),
          color: Colors.black,
        ),
        Shadow(
          offset: Offset(
            -Responsive.scale(context, 1), // Scale based on device
            Responsive.scale(context, 1), // Scale based on device
          ),
          color: Colors.black,
        ),
        Shadow(
          offset: Offset(
            Responsive.scale(context, 1), // Scale based on device
            Responsive.scale(context, 1), // Scale based on device
          ),
          color: Colors.black,
        ),
      ],
    ),
  );
}

// CREATE THE CUSTOM BUTTONS THAT CAN OPTIONALLY LEAD TO NEW SCREENS (destinations)
Widget customButton(
  String text,
  double baseFontSize,
  double baseHeight,
  double baseWidth,
  BuildContext context, {
  Widget? destination,
  VoidCallback? onPressed,
  Color? baseColor,
}) {
  Color color =
      baseColor ??
      currentUserData!.appColor; // app theme is the user's chosen theme
  final int red = (color.r * 255).round().clamp(0, 255);
  final int green = (color.g * 255).round().clamp(0, 255);
  final int blue = (color.b * 255).round().clamp(0, 255);

  return SizedBox(
    height: Responsive.buttonHeight(
      context,
      baseHeight,
    ), // Scale based on device
    width: Responsive.scale(context, baseWidth), // Scale based on device
    child: ClipRRect(
      borderRadius: BorderRadius.circular(
        Responsive.scale(context, 30),
      ), // Scale based on device
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: Responsive.scale(context, 15), // Scale based on device
              sigmaY: Responsive.scale(context, 15), // Scale based on device
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB((0.15 * 255).round(), red, green, blue),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 30),
                ), // Scale based on device
                border: Border.all(
                  color: Color.fromARGB((0.3 * 255).round(), red, green, blue),
                  width: Responsive.scale(
                    context,
                    1.5,
                  ), // Scale based on device
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB((0.25 * 255).round(), 0, 0, 0),
                    offset: Offset(
                      0,
                      Responsive.scale(context, 4), // Scale based on device
                    ),
                    blurRadius: Responsive.scale(
                      context,
                      10,
                    ), // Scale based on device
                    spreadRadius: Responsive.scale(
                      context,
                      1,
                    ), // Scale based on device
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 30),
              ), // Scale based on device
              onTap:
                  onPressed ??
                  () {
                    if (destination != null) {
                      changeToScreen(context, destination);
                    }
                  },
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
              child: Center(
                child: buttonText(
                  text,
                  context,
                  baseFontSize,
                ), // Scale inside text
              ),
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
    height: Responsive.buttonHeight(context, 150), // Scale based on device
    width: Responsive.scale(context, 300), // Scale based on device
    child: ClipRRect(
      borderRadius: BorderRadius.circular(
        Responsive.scale(context, 30),
      ), // Scale based on device
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: Responsive.scale(context, 15), // Scale based on device
              sigmaY: Responsive.scale(context, 15), // Scale based on device
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB((0.15 * 255).round(), red, green, blue),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 30),
                ), // Scale based on device
                border: Border.all(
                  color: Color.fromARGB((0.3 * 255).round(), red, green, blue),
                  width: Responsive.scale(
                    context,
                    1.5,
                  ), // Scale based on device
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB((0.25 * 255).round(), 0, 0, 0),
                    offset: Offset(
                      0,
                      Responsive.scale(context, 4), // Scale based on device
                    ),
                    blurRadius: Responsive.scale(
                      context,
                      10,
                    ), // Scale based on device
                    spreadRadius: Responsive.scale(
                      context,
                      1,
                    ), // Scale based on device
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 30),
              ), // Scale based on device
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
              child: Center(
                child: buttonText(text, context, 16),
              ), // Base font size scaled inside
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
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionDuration: Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final start = startOffset ?? Offset(0.0, 1.0);
        final finish = Offset.zero;
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
