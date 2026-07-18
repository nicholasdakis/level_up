import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:hugeicons/hugeicons.dart';
import '../utility/responsive.dart';
import 'global_state.dart';
import 'global_theme.dart';
import 'global_widgets.dart';

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
      style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
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

// Shows a contact topic picker then opens the email app with a prefilled subject
Future<void> showContactDialog(BuildContext context, Color appColor) async {
  const options = [
    ('Report a Bug', HugeIcons.strokeRoundedBug01),
    ('Feature Request', HugeIcons.strokeRoundedIdea01),
    ('General Feedback', HugeIcons.strokeRoundedComment01),
    ('Other', HugeIcons.strokeRoundedMoreHorizontal),
  ];
  final choice = await showFrostedDialog<String>(
    context: context,
    appColor: appColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Contact Us',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 18),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: Responsive.height(context, 4)),
        Text(
          'What can we help you with?',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            color: Colors.white,
          ),
        ),
        SizedBox(height: Responsive.height(context, 16)),
        for (final (label, icon) in options) ...[
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
            child: InkWell(
              onTap: () =>
                  Navigator.of(context, rootNavigator: true).pop(label),
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 12),
              ),
              splashColor: lightenColor(appColor, 0.3).withAlpha(60),
              highlightColor: lightenColor(appColor, 0.2).withAlpha(40),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 14),
                  vertical: Responsive.height(context, 13),
                ),
                decoration: BoxDecoration(
                  color: lightenColor(appColor, 0.15).withAlpha(35),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 12),
                  ),
                  border: Border.all(
                    color: lightenColor(appColor, 0.35).withAlpha(100),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: Responsive.scale(context, 34),
                      height: Responsive.scale(context, 34),
                      decoration: BoxDecoration(
                        color: lightenColor(appColor, 0.25).withAlpha(60),
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 8),
                        ),
                        border: Border.all(
                          color: lightenColor(appColor, 0.35).withAlpha(80),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: Responsive.scale(context, 18),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 12)),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 14),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: Responsive.scale(context, 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 8)),
        ],
        SizedBox(height: Responsive.height(context, 4)),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final subject = choice == 'Other' ? '' : '$choice - Level Up!';
  sendEmail(context, "n1ch0lasd4k1s@gmail.com", subject);
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
  Color? backgroundColor,
  Color? borderColor,
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
        backgroundColor: backgroundColor,
        borderColor: borderColor,
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
  final Color? backgroundColor;
  final Color? borderColor;

  const _FrostedDialogShell({
    required this.child,
    required this.appColor,
    required this.baseRadius,
    this.padding,
    this.maxWidth = 500,
    this.backgroundColor,
    this.borderColor,
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
                  backgroundColor:
                      widget.backgroundColor ?? Colors.white.withAlpha(10),
                  border: Border.all(
                    color: widget.borderColor ?? Colors.white.withAlpha(22),
                    width: Responsive.width(context, 1),
                  ),
                  padding:
                      widget.padding ??
                      EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 28),
                        vertical: Responsive.height(context, 32),
                      ),
                  child: ScrollConfiguration(
                    behavior: NoGlowScrollBehavior(),
                    child: SingleChildScrollView(child: widget.child),
                  ),
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
Future<void> showProFeatureDialog(
  BuildContext context, {
  required String feature,
  required Color appColor,
  required VoidCallback onLearnMore,
  bool isPremium = false,
}) {
  if (isPremium) return Future.value();
  logAnalyticsEvent(
    'pro_feature_dialog_shown',
    parameters: {'feature': feature},
  );
  return showFrostedDialog<void>(
    context: context,
    appColor: appColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        proChip(context),
        SizedBox(height: Responsive.height(context, 16)),
        Text(
          feature,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 17),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: Responsive.height(context, 8)),
        Text(
          'Upgrade to Pro to unlock this feature.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: Responsive.height(context, 24)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text('Dismiss', style: dialogButtonStyle()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                logAnalyticsEvent(
                  'pro_feature_dialog_learn_more',
                  parameters: {'feature': feature},
                );
                onLearnMore();
              },
              child: Text(
                'Learn More',
                style: dialogButtonStyle(confirm: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

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

// Shows a frosted dialog that requires the user to hold a button to confirm a destructive action.
// Returns true only when the hold completes, false or null if cancelled.
Future<bool> showHoldToConfirmDialog({
  required BuildContext context,
  required Color appColor,
  required String title,
  required String subtitle,
  IconData icon = Icons.delete_outline,
  Duration holdDuration = const Duration(milliseconds: 1500),
}) async {
  final result = await showFrostedDialog<bool>(
    context: context,
    appColor: appColor,
    child: _HoldToConfirmDialogContent(
      title: title,
      subtitle: subtitle,
      icon: icon,
      appColor: appColor,
      holdDuration: holdDuration,
    ),
  );
  return result == true;
}

class _HoldToConfirmDialogContent extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color appColor;
  final Duration holdDuration;

  const _HoldToConfirmDialogContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.appColor,
    required this.holdDuration,
  });

  @override
  State<_HoldToConfirmDialogContent> createState() =>
      _HoldToConfirmDialogContentState();
}

class _HoldToConfirmDialogContentState
    extends State<_HoldToConfirmDialogContent> {
  double _progress = 0.0;
  Timer? _timer;
  // fires at ~60fps to drive the progress ring
  static const _tickInterval = Duration(milliseconds: 16);

  // starts filling the ring, pops true when full
  void _startHold() {
    _timer = Timer.periodic(_tickInterval, (_) {
      setState(() {
        _progress +=
            _tickInterval.inMilliseconds / widget.holdDuration.inMilliseconds;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _timer?.cancel();
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      });
    });
  }

  // resets progress if the user lifts or cancels before completing
  void _cancelHold() {
    _timer?.cancel();
    setState(() => _progress = 0.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = onTheme(widget.appColor);
    final c = cardColors(widget.appColor);
    final size = Responsive.scale(context, 64.0);
    final done = _progress >= 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 18),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: Responsive.height(context, 8)),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            color: Colors.white70,
          ),
        ),
        SizedBox(height: Responsive.height(context, 28)),
        Center(
          child: GestureDetector(
            onLongPressStart: (_) => _startHold(),
            onLongPressEnd: (_) => _cancelHold(),
            onLongPressCancel: _cancelHold,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: _progress == 0 ? 1.0 : _progress,
                      strokeWidth: 2,
                      backgroundColor: c.iconBorder.withAlpha(80),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progress == 0 ? Colors.transparent : accent,
                      ),
                    ),
                  ),
                  Container(
                    width: size - Responsive.scale(context, 6),
                    height: size - Responsive.scale(context, 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(20),
                    ),
                    child: Icon(
                      done ? Icons.check : widget.icon,
                      color: accent,
                      size: Responsive.scale(context, 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: Responsive.height(context, 10)),
        Center(
          child: Text(
            _progress > 0 ? 'Keep holding...' : 'Hold to confirm',
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 12),
              color: Colors.white54,
            ),
          ),
        ),
        SizedBox(height: Responsive.height(context, 16)),
        Center(
          child: TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: Text('Cancel', style: dialogButtonStyle()),
          ),
        ),
      ],
    );
  }
}
