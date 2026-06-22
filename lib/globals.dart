import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'models/user_data.dart';
import 'services/user_data_manager.dart';
import 'dart:ui';
import 'utility/responsive.dart';
import 'services/leaderboard_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

// Global leaderboard_service object
final leaderboardService = LeaderboardService();

const Duration dailyRewardCooldown = Duration(hours: 23);
const Duration snackBarDuration = Duration(milliseconds: 1500);
const Duration snackBarDurationImportant = Duration(seconds: 3);

ValueNotifier<int> expNotifier = ValueNotifier<int>(0);

// Flips to true when AppInitScreen finishes loading user data
ValueNotifier<bool> appReadyNotifier = ValueNotifier<bool>(false);

// set to true by AppInitScreen once init completes, reset to false on logout
bool appInitialized = false;

// Captured in main() before runApp so the original browser URL is preserved
Uri appLaunchUri = Uri();

// set to true when the user chooses "Continue as Guest" — skips auth and backend writes
bool isGuest = false;

// set to true while a Google Sign-In TOS check is in progress — suppresses router redirect
bool suppressAuthRedirect = false;

// Notifies go_router to re-run redirect when guest state changes
ValueNotifier<bool> guestNotifier = ValueNotifier<bool>(false);

// for updating HomeScreen when app color is updated
ValueNotifier<Color> appColorNotifier = ValueNotifier<Color>(defaultAppColor);

// incremented each time a food is logged so home screen can refresh
ValueNotifier<int> foodLogNotifier = ValueNotifier<int>(0);

// Subclass exposes notifyListeners() publicly so callers can ping it after
// mutating fields on the existing UserData object without replacing the reference
class UserDataNotifier extends ValueNotifier<UserData?> {
  UserDataNotifier(super.value);

  @override
  void notifyListeners() => super.notifyListeners();
}

// Notifier so any widget can rebuild automatically when user data changes
final UserDataNotifier userDataNotifier = UserDataNotifier(null);

// Getter so all existing reads of currentUserData require zero changes
UserData? get currentUserData => userDataNotifier.value;
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

// Removes the overscroll glow effect that lights up widgets at the top/bottom of a scroll view
class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

// Tappable social link card with a logo and label
Widget socialLink({
  String? assetPath,
  IconData? icon,
  required String label,
  required String url,
  required BuildContext context,
  VoidCallback? onTap,
}) {
  return InkWell(
    splashColor: appColorNotifier.value.withAlpha(60),
    borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
    onTap:
        onTap ??
        () => url_launcher.launchUrl(
          Uri.parse(url),
          mode: url_launcher.LaunchMode.externalApplication,
        ),
    child: frostedGlassCard(
      context,
      baseRadius: 14,
      backgroundColor: appColorNotifier.value.computeLuminance() < 0.2
          ? darkenColor(appColorNotifier.value, 0.08).withAlpha(60)
          : Colors.white.withAlpha(40),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 12),
      ),
      child: Row(
        children: [
          if (assetPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(Responsive.scale(context, 8)),
              child: Image.asset(
                assetPath,
                width: Responsive.width(context, 36),
                height: Responsive.width(context, 36),
                filterQuality: FilterQuality.high,
              ),
            )
          else if (icon != null)
            Container(
              width: Responsive.width(context, 36),
              height: Responsive.width(context, 36),
              decoration: BoxDecoration(
                color: cardColors(appColorNotifier.value).iconBox,
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 8),
                ),
              ),
              child: Icon(
                icon,
                color: cardColors(appColorNotifier.value).onCard,
                size: Responsive.scale(context, 20),
              ),
            ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 18),
                color: cardColors(appColorNotifier.value).onCard,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: cardColors(appColorNotifier.value).onCard.withAlpha(160),
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

// Helper method for wrapping dialogs and giving them the frosted glass card appearance
Future<T?> showFrostedDialog<T>({
  required BuildContext context,
  required Widget child,
  bool dismissible = true,
  EdgeInsetsGeometry? padding,
  double baseRadius = 20,
  double maxWidth = 500,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    builder: (ctx) => _FrostedDialogShell(
      outerContext: context,
      baseRadius: baseRadius,
      padding: padding,
      child: child,
    ),
  );
}

// Stateful shell so it rebuilds when the keyboard inset changes
class _FrostedDialogShell extends StatefulWidget {
  final BuildContext outerContext;
  final Widget child;
  final double baseRadius;
  final EdgeInsetsGeometry? padding;

  const _FrostedDialogShell({
    required this.outerContext,
    required this.child,
    required this.baseRadius,
    this.padding,
  });

  @override
  State<_FrostedDialogShell> createState() => _FrostedDialogShellState();
}

class _FrostedDialogShellState extends State<_FrostedDialogShell> {
  @override
  Widget build(BuildContext context) {
    // On web the browser partially handles keyboard scrolling, so only apply
    // a fraction of viewInsets to avoid double-counting on iOS PWA.
    final rawInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardInset = kIsWeb ? rawInset * 0.2 : rawInset;
    final ctx = widget.outerContext;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: Responsive.width(ctx, 24),
        right: Responsive.width(ctx, 24),
        top: Responsive.height(ctx, 40),
        bottom: Responsive.height(ctx, 24) + keyboardInset,
      ),
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: Responsive.dialogWidth(ctx),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                Responsive.scale(ctx, widget.baseRadius),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: frostedGlassCard(
                  ctx,
                  baseRadius: widget.baseRadius,
                  backgroundColor: Colors.white.withAlpha(10),
                  border: Border.all(
                    color: Colors.white.withAlpha(22),
                    width: Responsive.width(ctx, 1),
                  ),
                  padding:
                      widget.padding ??
                      EdgeInsets.symmetric(
                        horizontal: Responsive.width(ctx, 28),
                        vertical: Responsive.height(ctx, 32),
                      ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Alert-style frosted dialog with title, optional content, and actions
Future<T?> showFrostedAlertDialog<T>({
  required BuildContext context,
  required String title,
  Widget? content,
  required List<Widget> actions,
  bool dismissible = true,
}) {
  return showFrostedDialog<T>(
    context: context,
    dismissible: dismissible,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 20),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (content != null) ...[
          SizedBox(height: Responsive.height(context, 16)),
          content,
        ],
        SizedBox(height: Responsive.height(context, 24)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: actions,
        ),
      ],
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

// sRGB gamma expansion (IEC 61966-2-1)
double _linearize(double c) =>
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

// Relative luminance per WCAG 2.x, correctly weights red/green/blue for human vision
double _relativeLuminance(Color c) {
  final r = _linearize((c.r * 255).round() / 255);
  final g = _linearize((c.g * 255).round() / 255);
  final b = _linearize((c.b * 255).round() / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// Convert sRGB Color to Oklab [L, a, b]
// Oklab is perceptually uniform: equal L steps look equal to the eye on any hue
List<double> _toOklab(Color c) {
  final r = _linearize((c.r * 255).round() / 255);
  final g = _linearize((c.g * 255).round() / 255);
  final b = _linearize((c.b * 255).round() / 255);
  final l = pow(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    1 / 3,
  ).toDouble();
  final m = pow(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    1 / 3,
  ).toDouble();
  final s = pow(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    1 / 3,
  ).toDouble();
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

// Convert Oklab [L, a, b] to sRGB Color, clamping to valid range
Color _fromOklab(List<double> lab) {
  final l = lab[0], a = lab[1], b = lab[2];
  final lc = l + 0.3963377774 * a + 0.2158037573 * b;
  final mc = l - 0.1055613458 * a - 0.0638541728 * b;
  final sc = l - 0.0894841775 * a - 1.2914855480 * b;
  final ll = lc * lc * lc, mm = mc * mc * mc, ss = sc * sc * sc;
  double toSrgb(double x) {
    final linear = x <= 0.0031308
        ? 12.92 * x
        : 1.055 * pow(x.clamp(0.0, 1.0), 1 / 2.4) - 0.055;
    return linear.clamp(0.0, 1.0);
  }

  return Color.from(
    alpha: 1.0,
    red: toSrgb(4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss),
    green: toSrgb(-1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss),
    blue: toSrgb(-0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss),
  );
}

// Shift a color's Oklab L channel by [amount] (positive = lighter, negative = darker)
Color _oklabShift(Color color, double amount) {
  final lab = _toOklab(color);
  lab[0] = (lab[0] + amount).clamp(0.0, 1.0);
  return _fromOklab(lab);
}

// Consistent card surface colors using perceptually uniform Oklab shifts
// Branches on relative luminance (not HSL lightness) so red/pink/purple are handled correctly
({
  List<Color> gradient,
  Color border,
  Color iconBox,
  Color splashColor,
  Color highlightColor,
  Color onCard, // text and icon color that stays readable on the card surface
})
cardColors(Color base) {
  // Relative luminance correctly identifies red (~0.06) as dark even though HSL calls it mid-tone
  final isDark = _relativeLuminance(base) < 0.18;
  return (
    gradient: isDark
        ? [_oklabShift(base, 0.15), _oklabShift(base, 0.10)]
        : [_oklabShift(base, -0.08), _oklabShift(base, -0.05)],
    border: isDark
        ? _oklabShift(base, 0.20).withAlpha(180)
        : _oklabShift(base, -0.16).withAlpha(180),
    iconBox: isDark
        ? _oklabShift(base, 0.18).withAlpha(160)
        : _oklabShift(base, -0.14).withAlpha(160),
    splashColor: isDark
        ? _oklabShift(base, 0.25).withAlpha(60)
        : _oklabShift(base, -0.20).withAlpha(60),
    highlightColor: isDark
        ? _oklabShift(base, 0.25).withAlpha(30)
        : _oklabShift(base, -0.20).withAlpha(30),
    onCard: lightenColor(base, 0.45),
  );
}

// Frosted glass tappable button
// Pass a [color] to tint the button with the theme color, otherwise it uses a neutral white glass
Widget frostedButton(
  String text,
  BuildContext context, {
  required Function() onPressed,
  Color? color,
  bool small = false,
}) {
  final bg = color != null
      ? cardColors(color).gradient.first.withAlpha(180)
      : Colors.white.withAlpha(18);
  final border = color != null
      ? Border.all(color: lightenColor(color, 0.2).withAlpha(160), width: 1)
      : Border.all(color: Colors.white.withAlpha(40), width: 1);
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => onPressed(),
      child: frostedGlassCard(
        context,
        baseRadius: 14,
        backgroundColor: bg,
        border: border,
        padding: EdgeInsets.symmetric(
          vertical: Responsive.height(context, small ? 8 : 15),
          horizontal: Responsive.width(context, small ? 14 : 24),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, small ? 13 : 18),
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
      lightenColor(appColorNotifier.value, 0.45),
      lightenColor(appColorNotifier.value, 0.50),
      lightenColor(appColorNotifier.value, 0.45),
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
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 40),
          fontWeight: FontWeight.w800,
          color: Colors.white,
          shadows: [textDropShadow(context)],
        ),
      ),
    ),
  );
}

// CREATE THE CUSTOM TEXT MEANT FOR BUTTONS
Widget buttonText(String text, BuildContext context, double baseFontSize) {
  final double fontSize = Responsive.font(context, baseFontSize);

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
      style: GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        shadows: [
          // Dark shadow below
          Shadow(
            offset: Offset(0, 2),
            blurRadius: 4,
            color: Colors.black.withAlpha(180),
          ),
          // Light shadow above
          Shadow(
            offset: Offset(0, -1),
            blurRadius: 3,
            color: Colors.white.withAlpha(60),
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
                color: lightenColor(color, 0.30).withValues(
                  alpha: borderAlpha,
                ), // defines edge separation from background
                width: Responsive.scale(context, 3), // border width scaled
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

// CREATE THE CUSTOM BUTTONS
Widget customButton(
  String text,
  double baseFontSize,
  double baseHeight,
  double baseWidth,
  BuildContext context, {
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
    child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 12),
      ), // prevents long labels like "Calorie Calculator" from touching the edges
      child: FittedBox(
        fit: BoxFit
            .scaleDown, // shrinks text if it doesn't fit rather than overflowing
        child: buttonText(text, context, baseFontSize),
      ),
    );
  }

  return SizedBox(
    height: Responsive.buttonHeight(context, baseHeight),
    width: Responsive.scale(context, baseWidth),
    child: _frostedButtonShell(
      context,
      color: color,
      onTap: onPressed ?? () {},
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
        color: lightenColor(appColorNotifier.value, 0.45),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );
}

// FROSTED GLASS CARD used across the app (reminders, preferences, etc.)
// Uses the same gradient + shadow style as the action tiles for visual consistency
Widget frostedGlassCard(
  BuildContext context, {
  required Widget child,
  double baseRadius = 20, // corner radius, scaled responsively
  EdgeInsetsGeometry? padding,
  Color? backgroundColor, // optional override for the card fill color
  BoxBorder? border, // optional override for the card border
  bool shadow = false, // only action tiles need the drop shadow
}) {
  final cardRadius = BorderRadius.circular(
    Responsive.scale(context, baseRadius),
  );
  final c = cardColors(appColorNotifier.value);
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: cardRadius,
      gradient: backgroundColor != null
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c.gradient,
            ),
      color: backgroundColor,
      border: border ?? Border.all(color: c.border, width: 1),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: Responsive.scale(context, 12),
                offset: Offset(0, Responsive.scale(context, 4)),
              ),
            ]
          : null,
    ),
    child: ClipRRect(
      borderRadius: cardRadius,
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
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
    final accent = lightenColor(appColorNotifier.value, 0.45);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () =>
              onDateChanged(currentDate.subtract(const Duration(days: 1))),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: accent,
            size: Responsive.scale(context, 20),
          ),
        ),
        SizedBox(width: Responsive.width(context, 16)),
        GestureDetector(
          onTap: () => _pickDate(context),
          child: Text(
            "${months[currentDate.month - 1]} ${currentDate.day}, ${currentDate.year}",
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 17),
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: Responsive.width(context, 16)),
        GestureDetector(
          onTap: () => onDateChanged(currentDate.add(const Duration(days: 1))),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: accent,
            size: Responsive.scale(context, 20),
          ),
        ),
      ],
    );
  }
}

// Returns a flat solid background using the chosen theme color
Gradient buildThemeGradient() {
  return LinearGradient(
    colors: [appColorNotifier.value, appColorNotifier.value],
  );
}
