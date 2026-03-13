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
        fontSize: Responsive.font(context, baseFontSize),
        color: color ?? Colors.white,
        shadows: [
          Shadow(
            offset: Offset(
              Responsive.scale(context, 4),
              Responsive.scale(context, 4),
            ),
            blurRadius: Responsive.scale(context, 10),
            color: const Color.fromARGB(255, 0, 0, 0),
          ),
        ],
        decoration: decoration ?? TextDecoration.none,
      ),
    ),
  );
}

Color darkenColor(Color color, [double amount = .1]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

Color lightenColor(Color color, [double amount = .1]) {
  final hsl = HSLColor.fromColor(color);
  final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
  return hslLight.toColor();
}

// CREATE THE TITLE TEXT OF EACH NEW SCREEN
Widget createTitle(String text, BuildContext context) {
  return Text(
    text,
    style: GoogleFonts.dangrek(
      fontSize: Responsive.font(context, 40),
      color: Colors.white,
      shadows: [
        Shadow(
          offset: Offset(
            Responsive.scale(context, 4),
            Responsive.scale(context, 4),
          ),
          blurRadius: Responsive.scale(context, 10),
          color: const Color.fromARGB(255, 0, 0, 0),
        ),
      ],
    ),
  );
}

// CREATE TEXT INSIDE OF A CARD
Widget textWithCard(String text, BuildContext context, double baseFontSize) {
  return Card(
    elevation: Responsive.scale(context, 10),
    color: darkenColor(appColorNotifier.value, 0.025), // Header color
    child: Padding(
      padding: EdgeInsets.all(Responsive.padding(context, 4)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, baseFontSize),
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(
                Responsive.scale(context, 4),
                Responsive.scale(context, 4),
              ),
              blurRadius: Responsive.scale(context, 10),
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
      fontSize: Responsive.font(context, baseFontSize),
      color: Colors.white,
      shadows: [
        Shadow(
          offset: Offset(
            -Responsive.scale(context, 1),
            -Responsive.scale(context, 1),
          ),
          color: Colors.black,
        ),
        Shadow(
          offset: Offset(
            Responsive.scale(context, 1),
            -Responsive.scale(context, 1),
          ),
          color: Colors.black,
        ),
        Shadow(
          offset: Offset(
            -Responsive.scale(context, 1),
            Responsive.scale(context, 1),
          ),
          color: Colors.black,
        ),
        Shadow(
          offset: Offset(
            Responsive.scale(context, 1),
            Responsive.scale(context, 1),
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
    height: Responsive.buttonHeight(context, baseHeight),
    width: Responsive.scale(context, baseWidth),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(Responsive.scale(context, 30)),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: Responsive.scale(context, 15),
              sigmaY: Responsive.scale(context, 15),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB((0.15 * 255).round(), red, green, blue),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 30),
                ),
                border: Border.all(
                  color: Color.fromARGB((0.3 * 255).round(), red, green, blue),
                  width: Responsive.scale(context, 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB((0.25 * 255).round(), 0, 0, 0),
                    offset: Offset(0, Responsive.scale(context, 4)),
                    blurRadius: Responsive.scale(context, 10),
                    spreadRadius: Responsive.scale(context, 1),
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
              ),
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
  double baseFontSize,
  double baseHeight,
  double baseWidth,
  BuildContext context, {
  required VoidCallback onPressed, // function to execute on tap
  Color? baseColor, // optional color, default will follow currentUserData
}) {
  Color color =
      baseColor ??
      currentUserData!.appColor; // app theme is the user's chosen theme
  final int red = (color.r * 255).round().clamp(0, 255); // red channel
  final int green = (color.g * 255).round().clamp(0, 255); // green channel
  final int blue = (color.b * 255).round().clamp(0, 255); // blue channel

  // set sizes based on screen context like customButton
  final double buttonHeight = Responsive.buttonHeight(context, baseHeight);
  final double buttonWidth = Responsive.scale(context, baseWidth);
  final double fontSize = Responsive.font(context, baseFontSize);

  return SizedBox(
    height: buttonHeight, // scale like customButton
    width: buttonWidth,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(
        Responsive.scale(
          context,
          30,
        ), // rounded corners scale like customButton
      ),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: Responsive.scale(context, 15), // blur like customButton
              sigmaY: Responsive.scale(context, 15), // blur like customButton
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB(
                  (0.15 * 255).round(),
                  red,
                  green,
                  blue,
                ), // translucent color
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 30), // border radius same as clip
                ),
                border: Border.all(
                  color: Color.fromARGB(
                    (0.3 * 255).round(),
                    red,
                    green,
                    blue,
                  ), // border alpha
                  width: Responsive.scale(context, 1.5), // border width scaled
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB(
                      (0.25 * 255).round(),
                      0,
                      0,
                      0,
                    ), // shadow alpha
                    offset: Offset(
                      0,
                      Responsive.scale(context, 4), // shadow y-offset
                    ),
                    blurRadius: Responsive.scale(context, 10), // shadow blur
                    spreadRadius: Responsive.scale(context, 1), // shadow spread
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent, // keep material transparent
            child: InkWell(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 30), // ripple matches button shape
              ),
              onTap: onPressed, // user tap
              splashColor: Color.fromARGB(
                (0.1 * 255).round(),
                red,
                green,
                blue,
              ), // splash color like customButton
              highlightColor: Color.fromARGB(
                (0.05 * 255).round(),
                red,
                green,
                blue,
              ), // highlight color like customButton
              child: Center(
                child: buttonText(
                  text,
                  context,
                  fontSize,
                ), // use calculated fontSize
              ),
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

Gradient buildThemeGradient() {
  final base = appColorNotifier.value;
  final darkEdge = darkenColor(base, 0.015); // dark sides
  final mid = lightenColor(base, 0.015); // center lighter

  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      darkEdge,
      darkEdge,
      mid, // center stripe
      darkEdge,
      darkEdge,
    ],
    stops: [
      0.0, 0.1, 0.5, 0.9, 1.0, // positions of each stripe
    ],
  );
}
