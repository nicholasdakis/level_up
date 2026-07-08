import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'services/user_data_manager.dart';
import 'dart:ui';
import 'utility/responsive.dart';
import 'services/leaderboard_service.dart';
import 'services/workout_session_service.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

// Global leaderboard_service object
final leaderboardService = LeaderboardService();

// Global workout session service, persists in-progress workout across navigation and app kills
final workoutSessionService = WorkoutSessionService();

const Duration dailyRewardCooldown = Duration(hours: 23);
const Duration snackBarDuration = Duration(milliseconds: 1500);
const Duration snackBarDurationImportant = Duration(seconds: 3);

// Flips to true when AppInitScreen finishes loading user data
ValueNotifier<bool> appReadyNotifier = ValueNotifier<bool>(false);

// set to true by AppInitScreen once init completes, reset to false on logout
bool appInitialized = false;

// set to true when the app version is below the minimum required
bool isAppOutdated = false;

// Captured in main() before runApp so the original browser URL is preserved
Uri appLaunchUri = Uri();

// set to true when the user chooses "Continue as Guest" — skips auth and backend writes
bool isGuest = false;

// set to true while a Google Sign-In TOS check is in progress — suppresses router redirect
bool suppressAuthRedirect = false;

// Notifies go_router to re-run redirect when guest state changes
ValueNotifier<bool> guestNotifier = ValueNotifier<bool>(false);

// incremented each time a workout is saved so the workout tab can refresh recent sessions
ValueNotifier<int> workoutLogNotifier = ValueNotifier<int>(0);

// updated by the JS visualViewport resize listener so dialogs shift up on iOS PWA keyboard open
ValueNotifier<double> viewportHeightNotifier = ValueNotifier<double>(0);

// set after onboarding to show a contextual hint on the destination screen
ValueNotifier<String?> onboardingHintNotifier = ValueNotifier<String?>(null);

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
  required Color appColor,
  VoidCallback? onTap,
}) {
  return InkWell(
    splashColor: appColor.withAlpha(60),
    borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
    onTap:
        onTap ??
        () => url_launcher.launchUrl(
          Uri.parse(url),
          mode: url_launcher.LaunchMode.externalApplication,
        ),
    child: frostedGlassCard(
      context,
      color: appColor,
      baseRadius: 14,
      backgroundColor: appColor.computeLuminance() < 0.2
          ? darkenColor(appColor, 0.08).withAlpha(60)
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
                color: cardColors(appColor).iconBox,
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 8),
                ),
              ),
              child: Icon(
                icon,
                color: cardColors(appColor).onCard,
                size: Responsive.scale(context, 20),
              ),
            ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 18),
                color: cardColors(appColor).onCard,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: cardColors(appColor).onCard.withAlpha(160),
            size: Responsive.width(context, 22),
          ),
        ],
      ),
    ),
  );
}

// Shows the force-update dialog, non-dismissable, opens Play Store on confirm
Future<void> showForceUpdateDialog(BuildContext context, Color appColor) async {
  await showFrostedAlertDialog(
    context: context,
    appColor: appColor,
    dismissible: false,
    title: "Update Required",
    content: Text(
      "Hey! There's a new version of Level Up! ready for you. Update to get the latest features and keep everything running smoothly.",
      textAlign: TextAlign.center,
      style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14),
    ),
    actions: [
      TextButton(
        onPressed: () async {
          final uri = Uri.parse(
            'https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup',
          );
          if (await url_launcher.canLaunchUrl(uri)) {
            url_launcher.launchUrl(
              uri,
              mode: url_launcher.LaunchMode.externalApplication,
            );
          }
        },
        child: Text("Update Now", style: dialogButtonStyle(confirm: true)),
      ),
    ],
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

// Custom date picker using CalendarDatePicker inside showFrostedDialog
Future<DateTime?> showThemedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required Color appColor,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
}) {
  final accent = lightenColor(appColor, 0.45);
  final dim = lightenColor(appColor, 0.35);
  DateTime selected = initialDate;

  return showFrostedDialog<DateTime>(
    context: context,
    appColor: appColor,
    padding: EdgeInsets.zero,
    child: Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.dark(
          primary: accent,
          onPrimary: Colors.black87,
          surface: Colors.transparent,
          onSurface: accent,
          onSurfaceVariant: dim,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withAlpha(22),
          thickness: 1,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accent),
        ),
      ),
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalendarDatePicker(
              initialDate: selected,
              firstDate: firstDate,
              lastDate: lastDate,
              onDateChanged: (date) => setState(() => selected = date),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: Responsive.width(ctx, 16),
                right: Responsive.width(ctx, 16),
                bottom: Responsive.height(ctx, 12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(),
                      child: Text('Cancel', style: dialogButtonStyle()),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(selected),
                      child: Text(
                        'OK',
                        style: dialogButtonStyle(confirm: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper method for wrapping dialogs and giving them the frosted glass card appearance
Future<T?> showFrostedDialog<T>({
  required BuildContext context,
  required Widget child,
  required Color appColor,
  bool dismissible = true,
  EdgeInsetsGeometry? padding,
  double baseRadius = 20,
  double maxWidth = 500,
  Color barrierColor = const Color(0x80000000),
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    barrierColor: barrierColor,
    builder: (ctx) => PopScope(
      canPop: dismissible,
      child: _FrostedDialogShell(
        appColor: appColor,
        baseRadius: baseRadius,
        padding: padding,
        maxWidth: maxWidth,
        child: child,
      ),
    ),
  );
}

// Stateful shell so it rebuilds when the keyboard inset changes
class _FrostedDialogShell extends StatefulWidget {
  final Widget child;
  final Color appColor;
  final double baseRadius;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const _FrostedDialogShell({
    required this.child,
    required this.appColor,
    required this.baseRadius,
    this.padding,
    this.maxWidth = 500,
  });

  @override
  State<_FrostedDialogShell> createState() => _FrostedDialogShellState();
}

class _FrostedDialogShellState extends State<_FrostedDialogShell> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: viewportHeightNotifier,
      builder: (context, _, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final rawInset = MediaQuery.viewInsetsOf(context).bottom;
    // On iOS PWA viewInsets.bottom stays 0 because the browser doesn't resize
    // the Flutter viewport. We listen to visualViewport.resize via JS and pipe
    // the height into viewportHeightNotifier. Keyboard height is screen minus
    // that reported height. Only used on web; native platforms use rawInset.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final jsViewportHeight = kIsWeb ? viewportHeightNotifier.value : 0.0;
    final jsInset = jsViewportHeight > 0
        ? (screenHeight - jsViewportHeight).clamp(0.0, screenHeight)
        : 0.0;
    final effectiveInset = rawInset > 0 ? rawInset : jsInset;
    // Cap at 60% so the dialog is never pushed off the top of the screen
    final keyboardInset = effectiveInset.clamp(0.0, screenHeight * 0.6);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: Responsive.width(context, 24),
        right: Responsive.width(context, 24),
        top: Responsive.height(context, 40),
        bottom: Responsive.height(context, 24) + keyboardInset,
      ),
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: Responsive.dialogWidth(context, maxWidth: widget.maxWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, widget.baseRadius),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: frostedGlassCard(
                  context,
                  color: widget.appColor,
                  baseRadius: widget.baseRadius,
                  backgroundColor: Colors.white.withAlpha(10),
                  border: Border.all(
                    color: Colors.white.withAlpha(22),
                    width: Responsive.width(context, 1),
                  ),
                  padding:
                      widget.padding ??
                      EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 28),
                        vertical: Responsive.height(context, 32),
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
  required Color appColor,
  Widget? content,
  required List<Widget> actions,
  bool dismissible = true,
}) {
  return showFrostedDialog<T>(
    context: context,
    appColor: appColor,
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

// Shared text style for dialog cancel/confirm buttons
TextStyle dialogButtonStyle({bool confirm = false}) => GoogleFonts.manrope(
  color: confirm ? Colors.white : Colors.white60,
  fontWeight: confirm ? FontWeight.w700 : FontWeight.w500,
);

// Frosted glass tappable button
// Pass a [color] to tint the button with the theme color, otherwise it uses a neutral white glass
Widget frostedButton(
  String text,
  BuildContext context, {
  required Function() onPressed,
  required Color color,
  bool small = false,
}) {
  final bg = cardColors(color).gradient.first.withAlpha(180);
  final border = Border.all(
    color: lightenColor(color, 0.2).withAlpha(160),
    width: 1,
  );
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => onPressed(),
      child: frostedGlassCard(
        context,
        color: color,
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
LinearGradient subtleTextGradient(Color appColor) {
  return LinearGradient(
    colors: [
      lightenColor(appColor, 0.45),
      lightenColor(appColor, 0.50),
      lightenColor(appColor, 0.45),
    ],
  );
}

// CREATE THE TITLE TEXT OF EACH NEW SCREEN
Widget createTitle(String text, BuildContext context, Color appColor) {
  return ShaderMask(
    shaderCallback: (bounds) => subtleTextGradient(appColor).createShader(
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

// Full-screen onboarding hint overlay shown after the wizard completes.
// Dims the screen, shows a frosted tooltip, and after 5s of inactivity
// fades in a pulsing finger in the center. Tap anywhere to dismiss.
class OnboardingHint extends StatefulWidget {
  final String hintKey;
  final String title;
  final String description;
  final Color appColor;

  const OnboardingHint({
    super.key,
    required this.hintKey,
    required this.title,
    required this.description,
    required this.appColor,
  });

  @override
  State<OnboardingHint> createState() => _OnboardingHintState();
}

class _OnboardingHintState extends State<OnboardingHint>
    with TickerProviderStateMixin {
  bool _visible = false;
  bool _fingerVisible = false;
  Timer? _fingerTimer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    onboardingHintNotifier.addListener(_onHintChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onHintChanged());
  }

  void _onHintChanged() {
    if (onboardingHintNotifier.value == widget.hintKey) {
      if (mounted) setState(() => _visible = true);
      _scheduleFingerHint();
    }
  }

  void _scheduleFingerHint() {
    _fingerTimer?.cancel();
    _fingerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _fingerVisible = true);
    });
  }

  void _dismiss() {
    if (!_visible) return;
    setState(() {
      _visible = false;
      _fingerVisible = false;
    });
    onboardingHintNotifier.value = null;
    _fingerTimer?.cancel();
  }

  @override
  void dispose() {
    onboardingHintNotifier.removeListener(_onHintChanged);
    _fingerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final color = widget.appColor;
    final accentColor = lightenColor(color, 0.45);
    final radius = BorderRadius.circular(Responsive.scale(context, 20));

    final tooltip = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: frostedGlassCard(
          context,
          color: widget.appColor,
          backgroundColor: Colors.white.withAlpha(10),
          border: Border.all(color: Colors.white.withAlpha(22), width: 1),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
            vertical: Responsive.height(context, 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              SizedBox(height: Responsive.height(context, 6)),
              Text(
                widget.description,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Stack(
          children: [
            // Dim overlay, only appears when finger shows
            AnimatedOpacity(
              opacity: _fingerVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Container(color: Colors.black.withAlpha(120)),
            ),
            // Tooltip near top
            Positioned(
              top:
                  MediaQuery.paddingOf(context).top +
                  Responsive.height(context, 16),
              left: Responsive.width(context, 16),
              right: Responsive.width(context, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.desktopContentMaxWidth,
                  ),
                  child: tooltip,
                ),
              ),
            ),
            // Pulsing finger in center, fades in after 5s
            Center(
              child: AnimatedOpacity(
                opacity: _fingerVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => Opacity(
                    opacity: _pulseOpacity.value,
                    child: Transform.scale(
                      scale: _pulseScale.value,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCursorPointer01,
                        color: Colors.white.withAlpha(220),
                        size: Responsive.scale(context, 52),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section header label used across the app (e.g. "OVERVIEW", "NOTES", "REMINDER DETAILS")
Widget sectionHeader(
  String text,
  BuildContext context, {
  required Color appColor,
  double baseFontSize = 15,
  EdgeInsetsGeometry? padding,
}) {
  return Padding(
    padding: padding ?? EdgeInsets.only(bottom: Responsive.height(context, 12)),
    child: Stack(
      children: [
        Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, baseFontSize),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.black.withAlpha(25),
          ),
        ),
        Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, baseFontSize),
            color: lightenColor(appColor, 0.45),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
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
  required Color color,
}) {
  final cardRadius = BorderRadius.circular(
    Responsive.scale(context, baseRadius),
  );
  final c = cardColors(color);
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
  final Color appColor;

  const DateNavigationRow({
    super.key,
    required this.currentDate,
    required this.onDateChanged,
    required this.appColor,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showThemedDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
      appColor: appColor,
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
    final accent = lightenColor(appColor, 0.45); // appColor is the widget field
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
Gradient buildThemeGradient(Color color) {
  return LinearGradient(colors: [color, color]);
}
