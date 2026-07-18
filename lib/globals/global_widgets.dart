import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../utility/responsive.dart';
import 'global_theme.dart';
import 'global_state.dart';
import 'global_dialogs.dart';

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
            color: cardColors(appColor).onCard,
            size: Responsive.width(context, 22),
          ),
        ],
      ),
    ),
  );
}

Widget _proChipStatic(BuildContext context) => Container(
  padding: EdgeInsets.symmetric(
    horizontal: Responsive.width(context, 5),
    vertical: Responsive.height(context, 1),
  ),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    ),
    borderRadius: BorderRadius.circular(Responsive.scale(context, 4)),
  ),
  child: Text(
    'PRO',
    style: GoogleFonts.manrope(
      fontSize: Responsive.font(context, 8),
      color: Colors.black.withAlpha(180),
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
    ),
  ),
);

Widget proChip(BuildContext context, {Animation<double>? animation}) =>
    ShimmerWidget(
      accent: const Color(0xFFFFD700),
      colors: const [
        Color(0xFFFFD700),
        Color(0xFFFFA500),
        Colors.white,
        Color(0xFFFFA500),
        Color(0xFFFFD700),
      ],
      animation: animation,
      child: _proChipStatic(context),
    );

// Shimmering username + PRO chip for premium users on the leaderboard
class ShimmerProRow extends StatefulWidget {
  final String username;
  final double fontSize;
  final Color appColor;
  final VoidCallback? onProTap;
  const ShimmerProRow({
    super.key,
    required this.username,
    required this.fontSize,
    required this.appColor,
    this.onProTap,
  });

  @override
  State<ShimmerProRow> createState() => _ShimmerProRowState();
}

class _ShimmerProRowState extends State<ShimmerProRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      accent: lightenColor(widget.appColor, 0.45),
      colors: [
        lightenColor(widget.appColor, 0.3),
        lightenColor(widget.appColor, 0.45),
        Colors.white,
        lightenColor(widget.appColor, 0.45),
        lightenColor(widget.appColor, 0.3),
      ],
      animation: _ctrl,
      child: GestureDetector(
        onTap: widget.onProTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.username,
              style: GoogleFonts.manrope(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(width: Responsive.width(context, 5)),
            proChip(context, animation: _ctrl),
          ],
        ),
      ),
    );
  }
}

// Primary gradient button, use for all main CTAs across the app
Widget gradientButton(
  BuildContext context, {
  required String label,
  required Color color,
  required VoidCallback onTap,
  IconData? icon,
  bool loading = false,
  bool fullWidth = true,
}) {
  final btn = buttonColors(color);
  final gradient = LinearGradient(
    colors: btn.gradient,
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  final border = Border.all(color: btn.border, width: 1.5);
  return GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, fullWidth ? 0 : 20),
        vertical: Responsive.height(context, 14),
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
        border: border,
      ),
      child: loading
          ? Center(
              child: SizedBox(
                width: Responsive.scale(context, 18),
                height: Responsive.scale(context, 18),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          : Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: Colors.white,
                    size: Responsive.scale(context, 16),
                  ),
                  SizedBox(width: Responsive.width(context, 6)),
                ],
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    ),
  );
}

// Frosted glass tappable button
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
        color: color ?? Colors.white,
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

// CREATE THE TITLE TEXT OF EACH NEW SCREEN
Widget createTitle(String text, BuildContext context, Color appColor) {
  return ShaderMask(
    shaderCallback: (bounds) => subtleTextGradient(
      appColor,
    ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
    child: FittedBox(
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
  late final AnimationController _cardPulseController;
  late final Animation<double> _cardScale;

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
    _cardPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _cardScale = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _cardPulseController, curve: Curves.easeInOut),
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
    _cardPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final radius = BorderRadius.circular(Responsive.scale(context, 20));

    final tooltip = ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF1E40AF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
        ),
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
                fontSize: Responsive.font(context, 18),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: Responsive.height(context, 6)),
            Text(
              widget.description,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 15),
                color: Colors.white.withAlpha(200),
              ),
            ),
          ],
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
                  child: ScaleTransition(scale: _cardScale, child: tooltip),
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
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = onTheme(appColor).withAlpha(15),
          ),
        ),
        Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, baseFontSize),
            color: onTheme(appColor),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    ),
  );
}

// Reusable pull-to-refresh wrapper that renders a themed spinner above content
class AppRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color appColor;

  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    required this.appColor,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor = lightenColor(appColor, 0.45);
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      builder: (context, child, controller) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final pulling = controller.value > 0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              if (pulling)
                Positioned(
                  top:
                      MediaQuery.paddingOf(context).top +
                      Responsive.height(context, 8) +
                      (controller.value * Responsive.height(context, 40)),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: Responsive.scale(context, 32),
                      height: Responsive.scale(context, 32),
                      child: CircularProgressIndicator(
                        value: controller.state == IndicatorState.loading
                            ? null
                            : controller.value.clamp(0.0, 1.0),
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
                        backgroundColor: spinnerColor.withAlpha(40),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      child: child,
    );
  }
}

// Sweeping shimmer animation over any child widget
// Pass an external [animation] to share a single controller across multiple widgets to keep in sync
// Omit it to let the widget manage its own internal controller
class ShimmerWidget extends StatefulWidget {
  final Widget child;
  final Color accent;
  final List<Color>? colors;
  final List<double>? stops;
  final Animation<double>? animation;

  const ShimmerWidget({
    super.key,
    required this.child,
    required this.accent,
    this.colors,
    this.stops,
    this.animation,
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _ownCtrl;

  Animation<double> get _anim => widget.animation ?? _ownCtrl!;

  @override
  void initState() {
    super.initState();
    if (widget.animation == null) {
      _ownCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _ownCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final colors =
        widget.colors ?? [accent, accent, Colors.white, accent, accent];
    final stops = widget.stops ?? const [0.0, 0.35, 0.5, 0.65, 1.0];
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final pos = _anim.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + pos * 3.5, 0),
            end: Alignment(-0.5 + pos * 3.5, 0),
            colors: colors,
            stops: stops,
          ).createShader(bounds),
          child: widget.child,
        );
      },
    );
  }
}

// Shared pulsing lock overlay for guest-locked content
Widget guestLockOverlay(BuildContext context, Color appColor) {
  final accent = lightenColor(appColor, 0.45);
  return Positioned.fill(
    child: Center(child: PulsingLockBadge(accent: accent)),
  );
}

class PulsingLockBadge extends StatelessWidget {
  final Color accent;
  const PulsingLockBadge({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      accent: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLockPassword,
            color: Colors.white,
            size: Responsive.scale(context, 26),
          ),
          SizedBox(height: Responsive.height(context, 4)),
          Text(
            'Sign up',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: Responsive.font(context, 12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// FROSTED GLASS CARD used across the app (reminders, preferences, etc.)
Widget frostedGlassCard(
  BuildContext context, {
  required Widget child,
  double baseRadius = 20,
  EdgeInsetsGeometry? padding,
  Color? backgroundColor,
  BoxBorder? border,
  bool shadow = false,
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
      border: border ?? Border.all(color: c.border, width: 1.5),
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
    final accent = lightenColor(appColor, 0.45);
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
