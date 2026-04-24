import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/user_data.dart';
import 'services/user_data_manager.dart';
import 'dart:ui';
import 'utility/responsive.dart';
import 'services/leaderboard_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

// Global leaderboard_service object
final leaderboardService = LeaderboardService();

ValueNotifier<int> expNotifier = ValueNotifier<int>(
  currentUserData?.expPoints ?? 0,
);

// Flips to true when AppInitScreen finishes loading user data
ValueNotifier<bool> appReadyNotifier = ValueNotifier<bool>(false);

// for updating HomeScreen when app color is updated
ValueNotifier<Color> appColorNotifier = ValueNotifier<Color>(
  Color.fromARGB(255, 45, 45, 45),
);

UserData?
currentUserData; // global current user-specific variable (not Firestore-dependent)
final UserDataManager userManager =
    UserDataManager(); // global current user manager variable (not Firestore-dependent)

// Text drop shadow used across the app
Shadow textDropShadow(BuildContext context) {
  return Shadow(
    offset: Offset(Responsive.scale(context, 4), Responsive.scale(context, 4)),
    blurRadius: Responsive.scale(context, 10),
    color: const Color.fromARGB(100, 0, 0, 0),
  );
}

// Tappable social link card with a logo and label
Widget socialLink({
  required String assetPath,
  required String label,
  required String url,
  required BuildContext context,
}) {
  return InkWell(
    splashColor: appColorNotifier.value.withAlpha(100),
    onTap: () => url_launcher.launchUrl(
      Uri.parse(url),
      mode: url_launcher.LaunchMode.externalApplication,
    ),
    child: frostedGlassCard(
      context,
      baseRadius: 14,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 8)),
            child: Image.asset(
              assetPath,
              width: Responsive.width(context, 36),
              height: Responsive.width(context, 36),
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 18),
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white38,
            size: Responsive.width(context, 22),
          ),
        ],
      ),
    ),
  );
}

// Method that externally opens an email with a path and subject
Future<void> sendEmail(
  BuildContext context,
  String email,
  String subject,
) async {
  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: email,
    query: Uri.encodeFull('subject=$subject'),
  );
  if (!await url_launcher.launchUrl(
    emailLaunchUri,
    mode: url_launcher.LaunchMode.externalApplication,
  )) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Failed to open email app. Please manually send an email to n1ch0lasd4k1s@gmail.com.",
        ),
      ),
    );
  }
}

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
        shadows: [textDropShadow(context)],
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

// Frosted glass tappable button
Widget frostedButton(
  String text,
  BuildContext context, {
  required Function() onPressed,
}) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => onPressed(),
      child: frostedGlassCard(
        context,
        baseRadius: 14,
        padding: EdgeInsets.symmetric(
          vertical: Responsive.height(context, 15),
          horizontal: Responsive.width(context, 24),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 18),
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

// Reusable gradient for title and button text
LinearGradient subtleTextGradient() {
  return LinearGradient(
    colors: [
      lightenColor(appColorNotifier.value, 0.65),
      lightenColor(appColorNotifier.value, 0.80),
      lightenColor(appColorNotifier.value, 0.65),
    ],
  );
}

// CREATE THE TITLE TEXT OF EACH NEW SCREEN
Widget createTitle(String text, BuildContext context) {
  return ShaderMask(
    shaderCallback: (bounds) => subtleTextGradient().createShader(
      Rect.fromLTWH(
        0,
        0,
        bounds.width,
        bounds.height,
      ), // Make a rectangle the same size as the text so the gradient covers it
    ),
    child: FittedBox(
      // FittedBox to shrink text on smaller screens
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: GoogleFonts.dangrek(
          fontSize: Responsive.font(context, 40),
          color: Colors.white,
          shadows: [textDropShadow(context)],
        ),
      ),
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
          shadows: [textDropShadow(context)],
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
  String? tooltip,
}) {
  final listTile = Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 2),
      ),
      leading: Icon(
        icon,
        color: Colors.white,
        size: Responsive.scale(context, 22),
      ),
      title: textWithFont(
        text,
        context,
        Responsive.font(context, 16),
        color: Colors.white,
        alignment: TextAlign.left,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.white38,
        size: Responsive.scale(context, 20),
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

  // Wrap in Tooltip if tooltip text is provided
  if (tooltip != null) {
    return Tooltip(
      message: tooltip,
      waitDuration: Duration(milliseconds: 0),
      showDuration: Duration(seconds: 3),
      child: listTile,
    );
  } else {
    return listTile;
  }
}

// CREATE THE CUSTOM TEXT MEANT FOR BUTTONS
Widget buttonText(String text, BuildContext context, double baseFontSize) {
  return ShaderMask(
    shaderCallback: (bounds) => subtleTextGradient().createShader(
      Rect.fromLTWH(
        0,
        0,
        bounds.width,
        bounds.height,
      ), // Make a rectangle the same size as the text so the gradient covers it
    ),
    child: Text(
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
    ),
  );
}

// FROSTED GLASS BUTTON SHELL shared by customButton and simpleCustomButton
// Builds the frosted backdrop, border, shadow, and InkWell ripple
Widget _frostedButtonShell(
  BuildContext context, {
  required Color color,
  required VoidCallback onTap,
  required Widget child,
}) {
  final radius = BorderRadius.circular(Responsive.scale(context, 30));

  final luminance = color.computeLuminance();
  final isDarkBg = luminance < 0.5;

  // Controls subtle depth of base color without destroying identity
  final darkenAmount = isDarkBg ? 0.075 : 0.1;

  // Controls glass visibility; higher on light backgrounds to prevent washed-out look
  final fillAlpha = isDarkBg ? 0.16 : 0.30;

  // Controls edge definition; slightly stronger on light backgrounds for separation
  final borderAlpha = isDarkBg ? 0.18 : 0.30;

  // Controls elevation; reduced on dark backgrounds to avoid heavy floating effect
  final shadowAlpha = isDarkBg ? 0.08 : 0.14;

  return ClipRRect(
    borderRadius: radius,
    child: Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: Responsive.scale(
              context,
              10,
            ), // blur softens background bleed through glass
            sigmaY: Responsive.scale(context, 10),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: darkenColor(
                color,
                darkenAmount,
              ).withValues(alpha: fillAlpha),

              borderRadius: radius,

              border: Border.all(
                color: color.withValues(
                  alpha: borderAlpha,
                ), // defines edge separation from background
                width: Responsive.scale(context, 1.5), // border width scaled
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: shadowAlpha,
                  ), // depth under glass surface
                  offset: Offset(
                    0,
                    Responsive.scale(context, 4),
                  ), // vertical lift illusion
                  blurRadius: Responsive.scale(
                    context,
                    16,
                  ), // softens shadow spread for realism
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        ),

        Material(
          color: Colors.transparent, // keeps ripple overlay non-intrusive
          child: InkWell(
            borderRadius: radius, // ensures ripple matches pill shape exactly
            onTap: onTap,
            splashColor: color.withAlpha(60), // subtle interaction feedback
            highlightColor: color.withValues(
              alpha: 0.06,
            ), // minimal pressed-state tint
            child: Center(child: child),
          ),
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
  IconData? icon,
}) {
  Color color =
      currentUserData!.appColor; // app theme is the user's chosen theme

  Widget child;
  if (icon != null) {
    child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white.withAlpha(200),
          size: Responsive.scale(context, baseFontSize),
        ),
        SizedBox(width: Responsive.width(context, 10)),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: buttonText(text, context, baseFontSize),
          ),
        ),
      ],
    );
  } else {
    child = FittedBox(
      fit: BoxFit.scaleDown,
      child: buttonText(text, context, baseFontSize),
    );
  }

  return SizedBox(
    height: Responsive.buttonHeight(context, baseHeight),
    width: Responsive.scale(context, baseWidth),
    child: _frostedButtonShell(
      context,
      color: color,
      onTap:
          onPressed ??
          () {
            if (destination != null) {
              changeToScreen(context, destination);
            }
          },
      child: child,
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

  return SizedBox(
    height: Responsive.buttonHeight(context, baseHeight),
    width: Responsive.scale(context, baseWidth),
    child: _frostedButtonShell(
      context,
      color: color,
      onTap: onPressed,
      child: buttonText(text, context, Responsive.font(context, baseFontSize)),
    ),
  );
}

// CHANGE SCREEN (DART FILE) WITH A TRANSITION
void changeToScreen(
  BuildContext context,
  Widget destination, {
  Offset? startOffset = const Offset(0, 1),
}) {
  // iOS gets its native horizontal slide gesture
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => destination));
    return;
  }

  // other platforms
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

// Section header label used across the app (e.g. "OVERVIEW", "NOTES", "REMINDER DETAILS")
Widget sectionHeader(
  String text,
  BuildContext context, {
  double baseFontSize = 11,
  EdgeInsetsGeometry? padding,
}) {
  return Padding(
    padding: padding ?? EdgeInsets.only(bottom: Responsive.height(context, 12)),
    child: Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: Responsive.font(context, baseFontSize),
        color: Colors.white38,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );
}

// FROSTED GLASS CARD used across the app (reminders, preferences, etc.)
// ClipRRect clips the blur to the card's rounded corners,
// BackdropFilter blurs whatever is behind the card,
// and the Container adds a translucent white fill + border for the glass look
Widget frostedGlassCard(
  BuildContext context, {
  required Widget child,
  double baseRadius = 20, // corner radius, scaled responsively
  EdgeInsetsGeometry? padding,
}) {
  final cardRadius = BorderRadius.circular(
    Responsive.scale(context, baseRadius),
  );
  return ClipRRect(
    borderRadius: cardRadius,
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: Responsive.scale(context, 12),
        sigmaY: Responsive.scale(context, 12),
      ), // blur intensity
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18), // translucent white fill
          borderRadius: cardRadius,
          border: Border.all(
            color: Colors.white.withAlpha(30), // subtle white border
            width: Responsive.width(context, 1),
          ),
        ),
        padding: padding,
        child: child,
      ),
    ),
  );
}

class DateNavigationRow extends StatelessWidget {
  final DateTime currentDate;
  final void Function(DateTime) onDateChanged;

  const DateNavigationRow({
    super.key,
    required this.currentDate,
    required this.onDateChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_left, color: Colors.white),
          onPressed: () =>
              onDateChanged(currentDate.subtract(const Duration(days: 1))),
        ),
        InkWell(
          splashColor: appColorNotifier.value.withAlpha(100),
          onTap: () => _pickDate(context),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 8)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 12),
              vertical: Responsive.height(context, 6),
            ),
            child: Text(
              "${months[currentDate.month - 1]} ${currentDate.day}, ${currentDate.year}",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 18),
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.arrow_right, color: Colors.white),
          onPressed: () =>
              onDateChanged(currentDate.add(const Duration(days: 1))),
        ),
      ],
    );
  }
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
