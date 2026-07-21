import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import '../services/user_data_manager.dart' show defaultAppColor;
import '../guest.dart';
import '../router.dart';
import 'auth_services.dart';
import '../utility/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterOrLogin extends ConsumerStatefulWidget {
  const RegisterOrLogin({super.key});

  @override
  ConsumerState<RegisterOrLogin> createState() => _RegisterOrLoginState();
}

class _RegisterOrLoginState extends ConsumerState<RegisterOrLogin>
    with SingleTickerProviderStateMixin {
  // Keep track of entered email and password fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? notifyingMessage;
  bool hidePassword = true;
  bool isLoginMode = true; // which tab the user is on
  bool isSubmitting = false; // to prevent double tapping while submitting
  // Tracks whether the user has agreed to the privacy policy and terms, required before sign up
  bool agreedToTerms = false;
  // true once the user taps "Continue with email instead"
  bool showEmailForm = false;

  // Drives the XP preview card, one continuous 0 to 1 tween split into two phases
  late final AnimationController _xpController;
  // t < _level1Fraction: filling level 1 (0→130 XP)
  // t >= _level1Fraction: filling level 2 (0→_level2Xp XP)
  late final double _level1Fraction;
  late final int _level2Xp;
  static const int _level1Max = 130;
  static const int _level2Max = 170;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _level2Xp = 20 + rng.nextInt(31); // 20-50 XP into level 2
    // level 1 takes 130 "units", level 2 partial takes _level2Xp "units"
    // split the 0→1 tween proportionally so speed feels constant
    final totalUnits = _level1Max + _level2Xp;
    _level1Fraction = _level1Max / totalUnits;
    _xpController =
        AnimationController(
          vsync: this,
          duration: Duration(
            milliseconds: (1200 * totalUnits / _level1Max).round(),
          ),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (mounted) _xpController.forward(from: 0);
            });
          }
        });
    _xpController.forward();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/register-or-login',
      screenClass: 'RegisterOrLogin',
    );
  }

  @override
  void dispose() {
    _xpController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // One half of the segmented toggle. Only the text color animates here, the pill background is the sliding thumb above
  Widget buildToggleOption(String label, bool loginMode) {
    final isActive = isLoginMode == loginMode;
    // Active text is white, inactive is faded out
    return GestureDetector(
      onTap: () => setState(() {
        isLoginMode = loginMode;
        // clear any leftover error from the previous mode
        notifyingMessage = null;
      }),
      behavior: HitTestBehavior
          .opaque, // To make the whole button clickable instead of only the text
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 280),
          style: GoogleFonts.manrope(
            color: isActive ? Colors.white : Colors.white60,
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w600,
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  // Method that adds the Login or Registration buttons
  Widget buildAuthModeToggle() {
    // Sliding highlight is behind the active label
    final thumbAlignment = isLoginMode
        ? Alignment.centerLeft
        : Alignment.centerRight;
    // Sliding thumb shows the chosen half. AnimatedAlign tweens between the two sides
    final thumb = AnimatedAlign(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: thumbAlignment,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(Responsive.scale(context, 30)),
          ),
        ),
      ),
    );
    // Text labels sit above the sliding thumb
    final labels = Row(
      children: [
        Expanded(child: buildToggleOption("Log In", true)),
        Expanded(child: buildToggleOption("Sign Up", false)),
      ],
    );
    final radius = BorderRadius.circular(Responsive.scale(context, 40));
    return Container(
      height:
          Responsive.buttonHeight(context, 44) + Responsive.padding(context, 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
      ),
      padding: EdgeInsets.all(Responsive.padding(context, 4)),
      child: Stack(children: [thumb, labels]),
    );
  }

  // Filled rounded text field with a leading icon
  Widget buildAuthField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    final radius = BorderRadius.circular(Responsive.scale(context, 14));
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.manrope(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.7),
            width: Responsive.scale(context, 1.5),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: Responsive.height(context, 18),
          horizontal: Responsive.width(context, 16),
        ),
      ),
    );
  }

  // Method that either logs in or registers depending on the active tab
  Widget buildPrimaryButton() {
    // Label switches with the active tab
    final label = isLoginMode ? "Log In" : "Sign Up";
    // While submitting, the label is replaced with a small spinner
    final buttonChild = isSubmitting
        // true when waiting for Firebase to respond
        // Center loosens the parent's tight width so the SizedBox can stay square instead of being stretched into a flat line
        ? Center(
            child: SizedBox(
              height: Responsive.scale(context, 22),
              width: Responsive.scale(context, 22),
              child: CircularProgressIndicator(
                strokeWidth: Responsive.scale(context, 2),
                color: Colors.white,
              ),
            ),
          )
        : Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 18),
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          );
    // Null onTap disables the button visually and functionally while a request is happening to prevent multiple taps
    return GestureDetector(
      onTap: isSubmitting ? null : handlePrimaryAction,
      child: AnimatedOpacity(
        opacity: isSubmitting ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 17),
            horizontal: Responsive.width(context, 24),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
            gradient: const LinearGradient(
              colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF1E40AF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
          ),
          child: buttonChild,
        ),
      ),
    );
  }

  // Terms and privacy agreement row
  Widget buildTermsCheckbox() {
    final baseTextStyle = GoogleFonts.manrope(
      color: Colors.white38,
      fontSize: Responsive.font(context, 12),
      fontWeight: FontWeight.w400,
    );
    final linkStyle = baseTextStyle.copyWith(
      color: Colors.white54,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white24,
    );
    // Shrink and recolor the default Material checkbox so it fits the dark theme
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.scale(
          scale: Responsive.scale(context, 0.9),
          child: Checkbox(
            value: agreedToTerms,
            onChanged: (value) {
              setState(() {
                agreedToTerms = value ?? false;
                // clear any stale agreement-error
                if (agreedToTerms) notifyingMessage = null;
              });
            },
            checkColor: Colors.black,
            activeColor: Colors.white,
            side: BorderSide(
              color: Colors.white54,
              width: Responsive.scale(context, 1.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Responsive.scale(context, 4)),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        SizedBox(width: Responsive.padding(context, 6)),
        // Text.rich so plain text and the two link spans can mix inline
        Flexible(
          child: Text.rich(
            TextSpan(
              style: baseTextStyle,
              children: [
                const TextSpan(text: "I agree to the "),
                TextSpan(
                  text: "Privacy Policy",
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                      Uri.parse(
                        'https://nicholasdakis.com/level_up/privacy-policy',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                ),
                const TextSpan(text: " and "),
                TextSpan(
                  text: "Terms of Service",
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                      Uri.parse(
                        'https://nicholasdakis.com/level_up/terms-of-service',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Method to call the correct authentication based on the tab
  Future<void> handlePrimaryAction() async {
    // Block sign up until the user agrees to the privacy policy and terms of service
    if (!isLoginMode && !agreedToTerms) {
      setState(
        () => notifyingMessage =
            "Please agree to the Privacy Policy and Terms of Service to continue.",
      );
      return;
    }
    // Update into submitting state and clear any leftover message
    setState(() {
      isSubmitting = true;
      notifyingMessage = null;
    });
    try {
      // Call the correct auth method based on the active tab
      if (isLoginMode) {
        await authService.value.signInWithEmail(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await authService.value.signUpWithEmail(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
      if (!mounted) return;
      // Success message depends on which flow ran
      setState(
        () => notifyingMessage = isLoginMode
            ? "Login successful"
            : "Registration successful",
      );
      context.go('/loading');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // invalid-credential also covers accounts originally made with Google sign in
      if (e.code == 'invalid-credential') {
        setState(
          () => notifyingMessage =
              "Invalid email or password. If your account used 'Continue with Google', use Forgot Password once and set a password to enable email login.",
        );
      } else {
        // Build a generic error for any other Firebase error
        setState(
          () => notifyingMessage =
              "${isLoginMode ? 'Login' : 'Registration'} error: $e",
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Catch anything that is not a Firebase error
      setState(
        () => notifyingMessage =
            "${isLoginMode ? 'Login' : 'Registration'} error: $e",
      );
    } finally {
      // Clear the submitting state in the end
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // Method that sends a password reset email based on the current email field
  Future<void> handleForgotPassword() async {
    // Need an email to send the reset link to
    if (emailController.text.isEmpty) {
      setState(
        () => notifyingMessage =
            "Enter your email in the email field above to reset your password.",
      );
      return;
    }
    try {
      await authService.value.resetPassword(email: emailController.text.trim());
      setState(
        () => notifyingMessage =
            "Password reset email sent to ${emailController.text.trim()}. Check your spam folder if you don't see it.",
      );
    } catch (e) {
      setState(() => notifyingMessage = "Error: $e");
    }
  }

  // Method to sign the user in with Google
  Future<void> handleGoogleSignIn() async {
    try {
      await authService.value.signInWithGoogle(agreedToTerms: agreedToTerms);
      if (!mounted) return;
      appRouter.refresh();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'new-user-no-tos') {
        await showFrostedAlertDialog(
          context: context,
          appColor: defaultAppColor,
          title: "One more step",
          content: Text(
            "Please agree to the Privacy Policy and Terms of Service before creating an account.",
            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          actions: [
            Expanded(
              child: Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Got it",
                    style: dialogButtonStyle(confirm: true),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        setState(
          () => notifyingMessage = "Google sign in failed: ${e.message}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => notifyingMessage = "Google sign in failed: $e");
    }
  }

  // Builds the container shared by the Google and guest buttons so their style stays consistent
  Widget _loginButton({required Widget child, required VoidCallback onTap}) {
    final radius = BorderRadius.circular(Responsive.scale(context, 14));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: Responsive.height(
            context,
            Responsive.isDesktop(context) ? 20 : 14,
          ),
          horizontal: Responsive.width(context, 24),
        ),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: child,
      ),
    );
  }

  Widget buildGoogleButton({bool large = true}) {
    return _loginButton(
      onTap: handleGoogleSignIn,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/google_logo.png',
            width: Responsive.scale(context, 20),
            height: Responsive.scale(context, 20),
          ),
          SizedBox(width: Responsive.width(context, 10)),
          Text(
            "Continue with Google",
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: Responsive.font(context, 15),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOutlinedButton({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return _loginButton(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: Colors.white70,
              size: Responsive.scale(context, 20),
            ),
            SizedBox(width: Responsive.width(context, 10)),
          ],
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: Responsive.font(context, 15),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Builds one feature chip with a circular icon, label, and subtitle
  // staggerDelay offsets the pulse entrance so chips don't all animate in sync
  Widget _featureChip(
    IconData icon,
    String label,
    String subtitle, {
    Duration staggerDelay = Duration.zero,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
                padding: EdgeInsets.all(Responsive.scale(context, 10)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: HugeIcon(
                  icon: icon,
                  color: Colors.white70,
                  size: Responsive.scale(context, 20),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                delay: staggerDelay,
                duration: 1800.ms,
                begin: 1.0,
                end: 1.14,
                curve: Curves.easeInOut,
              ),
          SizedBox(height: Responsive.height(context, 6)),
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: Responsive.font(context, 12),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 2)),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontSize: Responsive.font(context, 10),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // Method that builds the main content, switching between the initial view and the email form
  Widget buildScreen() {
    const dur = Duration(milliseconds: 750);
    const curve = Curves.easeOutCubic;

    // TOP: logo, title, tagline, feature chips, email form
    final topGroup = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: Responsive.padding(context, 20)),
        Center(
          child: AnimatedContainer(
            duration: dur,
            curve: curve,
            height: Responsive.buttonHeight(
              context,
              showEmailForm ? 90.0 : 130.0,
            ),
            child: Image.asset(
              'assets/app_logo_transparent_bg.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: Responsive.padding(context, showEmailForm ? 8 : 14)),
        AnimatedDefaultTextStyle(
          duration: dur,
          curve: curve,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: Responsive.font(context, showEmailForm ? 24.0 : 36.0),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          child: const Text("Level Up!", textAlign: TextAlign.center),
        ),
        if (!showEmailForm)
          Padding(
            padding: EdgeInsets.only(top: Responsive.padding(context, 8)),
            child: Text(
              "Gamify Your Health",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white54,
                fontSize: Responsive.font(context, 15),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        // Feature chips + XP card share the same width via a Row>Expanded>Column
        AnimatedSize(
          duration: dur,
          curve: curve,
          child: !showEmailForm
              ? Padding(
                  padding: EdgeInsets.only(
                    top: Responsive.padding(context, 18),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final chipMargin = constraints.maxWidth / 10;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _featureChip(
                                    HugeIcons.strokeRoundedPencil,
                                    "Log habits",
                                    "Food, water, workouts",
                                    staggerDelay: 0.ms,
                                  )
                                  .animate()
                                  .fadeIn(delay: 100.ms, duration: 400.ms)
                                  .slideY(begin: 0.2, end: 0),
                              _featureChip(
                                    HugeIcons.strokeRoundedStar,
                                    "Earn XP",
                                    "Level up every day",
                                    staggerDelay: 900.ms,
                                  )
                                  .animate()
                                  .fadeIn(delay: 200.ms, duration: 400.ms)
                                  .slideY(begin: 0.2, end: 0),
                              _featureChip(
                                    HugeIcons.strokeRoundedMedal01,
                                    "Compete",
                                    "Climb the leaderboards",
                                    staggerDelay: 1800.ms,
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms, duration: 400.ms)
                                  .slideY(begin: 0.2, end: 0),
                            ],
                          ),
                          SizedBox(height: Responsive.padding(context, 20)),
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.symmetric(
                              horizontal: chipMargin,
                            ),
                            padding: EdgeInsets.all(
                              Responsive.scale(context, 16),
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                Responsive.scale(context, 16),
                              ),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _xpController,
                                  builder: (context, _) {
                                    final t = _xpController.value;
                                    final inLevel2 = t >= _level1Fraction;
                                    final int level = inLevel2 ? 2 : 1;
                                    final int levelMax = inLevel2
                                        ? _level2Max
                                        : _level1Max;
                                    // progress through the current phase (0→1)
                                    final double phase = inLevel2
                                        ? (t - _level1Fraction) /
                                              (1.0 - _level1Fraction)
                                        : t / _level1Fraction;
                                    final int xp =
                                        (phase *
                                                (inLevel2
                                                    ? _level2Xp
                                                    : _level1Max))
                                            .toInt();
                                    // bar fill is xp as a fraction of the full level cap
                                    final double barFill = xp / levelMax;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Level $level",
                                              style: GoogleFonts.manrope(
                                                color: Colors.white70,
                                                fontSize: Responsive.font(
                                                  context,
                                                  13,
                                                ),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              "$xp / $levelMax XP",
                                              style: GoogleFonts.manrope(
                                                color: Colors.white38,
                                                fontSize: Responsive.font(
                                                  context,
                                                  12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: Responsive.height(context, 8),
                                        ),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final barHeight = Responsive.height(
                                              context,
                                              7,
                                            );
                                            final radius = Responsive.scale(
                                              context,
                                              4,
                                            );
                                            return Container(
                                              height: barHeight,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      radius,
                                                    ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      radius,
                                                    ),
                                                child: FractionallySizedBox(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  widthFactor: barFill.clamp(
                                                    0.0,
                                                    1.0,
                                                  ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            radius,
                                                          ),
                                                      gradient:
                                                          const LinearGradient(
                                                            colors: [
                                                              Color(0xFF22D3EE),
                                                              Color(0xFF3B82F6),
                                                            ],
                                                          ),
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        Positioned.fill(
                                                          child: ShaderMask(
                                                            shaderCallback: (rect) => LinearGradient(
                                                              begin: Alignment
                                                                  .centerLeft,
                                                              end: Alignment
                                                                  .centerRight,
                                                              colors: [
                                                                Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.0,
                                                                    ),
                                                                Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.25,
                                                                    ),
                                                                Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.0,
                                                                    ),
                                                              ],
                                                              stops: const [
                                                                0.0,
                                                                0.5,
                                                                1.0,
                                                              ],
                                                            ).createShader(rect),
                                                            child:
                                                                const ColoredBox(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                SizedBox(height: Responsive.height(context, 8)),
                                Center(
                                  child: Text(
                                    "Join today and start earning XP",
                                    style: GoogleFonts.manrope(
                                      color: Colors.white38,
                                      fontSize: Responsive.font(context, 13),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.2, end: 0),
                        ],
                      );
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        // Email form, slides in when tapped
        AnimatedSize(
          duration: dur,
          curve: curve,
          child: showEmailForm
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: Responsive.padding(context, 16)),
                    buildAuthModeToggle(),
                    SizedBox(height: Responsive.padding(context, 16)),
                    buildAuthField(
                      controller: emailController,
                      label: "Email",
                      icon: Icons.mail_outline,
                    ),
                    SizedBox(height: Responsive.padding(context, 12)),
                    buildAuthField(
                      controller: passwordController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      obscure: hidePassword,
                      suffix: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54,
                        ),
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 16)),
                    buildPrimaryButton(),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: curve,
                      child: isLoginMode
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: handleForgotPassword,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF3B82F6),
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 13),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    if (!isLoginMode) ...[
                      SizedBox(height: Responsive.padding(context, 12)),
                      buildTermsCheckbox(),
                    ],
                    SizedBox(height: Responsive.padding(context, 12)),
                    // Divider separating the email form from the social auth options below
                    Row(
                      children: [
                        Expanded(
                          child: Container(height: 1, color: Colors.white12),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.padding(context, 12),
                          ),
                          child: Text(
                            "or",
                            style: GoogleFonts.manrope(
                              color: Colors.white38,
                              fontSize: Responsive.font(context, 13),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(height: 1, color: Colors.white12),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.padding(context, 12)),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    // BOTTOM: Google, guest, email link
    final bottomGroup = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!showEmailForm) ...[
          SizedBox(height: Responsive.padding(context, 20)),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.white12)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 12),
                ),
                child: Text(
                  "GET STARTED",
                  style: GoogleFonts.manrope(
                    color: Colors.white24,
                    fontSize: Responsive.font(context, 11),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: Colors.white12)),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 16)),
        ],
        if (!showEmailForm) ...[
          buildTermsCheckbox(),
          SizedBox(height: Responsive.padding(context, 12)),
        ],
        buildGoogleButton(),
        SizedBox(height: Responsive.padding(context, 12)),
        buildOutlinedButton(
          label: "Browse as a guest",
          icon: HugeIcons.strokeRoundedAnonymous,
          onTap: () {
            FirebaseAnalytics.instance.logEvent(name: 'browse_as_guest');
            Guest.enter(ref);
          },
        ),
        if (notifyingMessage != null) ...[
          SizedBox(height: Responsive.padding(context, 12)),
          Text(
            notifyingMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: notifyingMessage!.startsWith("Password reset email sent")
                  ? Colors.greenAccent.shade100
                  : Colors.redAccent.shade100,
              fontSize: Responsive.font(context, 13),
            ),
          ),
        ],
        if (!showEmailForm) ...[
          SizedBox(height: Responsive.padding(context, 16)),
          GestureDetector(
            onTap: () => setState(() {
              showEmailForm = true;
              notifyingMessage = null;
            }),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Continue with email instead",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Colors.white54,
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: Responsive.width(context, 4)),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: Responsive.scale(context, 12),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: Responsive.padding(context, 20)),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              topGroup,
              SizedBox(height: Responsive.padding(context, 20)),
              bottomGroup,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).top -
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: buildScreen()
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(
                  begin: 0.12,
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),
        ),
      ),
    );
  }
}
