import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import '../guest.dart';
import '../router.dart';
import 'auth_services.dart';
import '../utility/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:url_launcher/url_launcher.dart';

class RegisterOrLogin extends StatefulWidget {
  const RegisterOrLogin({super.key});

  @override
  State<RegisterOrLogin> createState() => _RegisterOrLoginState();
}

class _RegisterOrLoginState extends State<RegisterOrLogin> {
  // Keep track of entered email and password fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? notifyingMessage;
  bool hidePassword = true;

  bool isLoginMode = true; // which tab the user is on

  bool isSubmitting = false; // to prevent double tapping while submitting

  // Tracks whether the user has agreed to the privacy policy and terms, required before sign up
  bool agreedToTerms = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Widget buildAnimatedBackground() {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6, -0.8),
                radius: 1.1,
                colors: [Color(0x1A4B2E83), Colors.transparent],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, 0.9),
                radius: 1.0,
                colors: [Color(0x148A2E5C), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method that adds the Login or Registration buttons
  Widget buildAuthModeToggle() {
    // Sliding highlight is behind the active label
    Alignment thumbAlignment;
    if (isLoginMode) {
      thumbAlignment = Alignment.centerLeft;
    } else {
      thumbAlignment = Alignment.centerRight;
    }
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
    return frostedGlassCard(
      context,
      baseRadius: 40,
      padding: EdgeInsets.all(Responsive.padding(context, 4)),
      child: SizedBox(
        height: Responsive.buttonHeight(context, 44),
        child: Stack(children: [thumb, labels]),
      ),
    );
  }

  // One half of the segmented toggle. Only the text color animates here, the pill background is the sliding thumb above
  Widget buildToggleOption(String label, bool loginMode) {
    final isActive = isLoginMode == loginMode;
    // Active text is white, inactive is faded out
    Color textColor;
    if (isActive) {
      textColor = Colors.white;
    } else {
      textColor = Colors.white60;
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          isLoginMode = loginMode;
          // clear any leftover error from the previous mode
          notifyingMessage = null;
        });
      },
      behavior: HitTestBehavior
          .opaque, // To make the whole button clickable instead of only the text
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 280),
          style: GoogleFonts.manrope(
            color: textColor,
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w600,
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
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
    final defaultBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    final enabledBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: const Color(0xFFFF4D86).withValues(alpha: 0.7),
        width: Responsive.scale(context, 1.5),
      ),
    );
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
        border: defaultBorder,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
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
    String label;
    if (isLoginMode) {
      label = "Log In";
    } else {
      label = "Sign Up";
    }
    // While submitting, the label is replaced with a small spinner
    Widget buttonChild;
    if (isSubmitting) {
      // true when waiting for Firebase to respond
      // Center loosens the parent's tight width so the SizedBox can stay square instead of being stretched into a flat line
      buttonChild = Center(
        child: SizedBox(
          height: Responsive.scale(context, 22),
          width: Responsive.scale(context, 22),
          child: CircularProgressIndicator(
            strokeWidth: Responsive.scale(context, 2),
            color: Colors.white,
          ),
        ),
      );
    } else {
      buttonChild = Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 18),
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    // Null onTap disables the button visually and functionally while a request is happening to prevent multiple taps
    VoidCallback? onTapHandler;
    if (isSubmitting) {
      onTapHandler = null;
    } else {
      onTapHandler = handlePrimaryAction;
    }
    return GestureDetector(
      onTap: onTapHandler,
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
              colors: [Color(0xFFFF6BA8), Color(0xFFFF2D6B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: Color(0xFFFF4D86), width: 1.5),
          ),
          child: buttonChild,
        ),
      ),
    );
  }

  // Terms and privacy agreement row
  Widget buildTermsCheckbox() {
    final baseTextStyle = GoogleFonts.manrope(
      color: Colors.white70,
      fontSize: Responsive.font(context, 12),
      fontWeight: FontWeight.w500,
    );
    final linkStyle = baseTextStyle.copyWith(
      color: Colors.white,
      decorationColor: Colors.white54,
    );
    // Shrink and recolor the default Material checkbox so it fits the dark theme
    final checkbox = Transform.scale(
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
    );
    // Text.rich so plain text and the two link spans can mix inline
    final agreementText = Text.rich(
      TextSpan(
        style: baseTextStyle,
        children: [
          const TextSpan(text: "I agree to the "),
          TextSpan(
            text: "Privacy Policy",
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                Uri.parse('https://nicholasdakis.com/level_up/privacy-policy'),
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
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        checkbox,
        SizedBox(width: Responsive.padding(context, 6)),
        Flexible(child: agreementText),
      ],
    );
  }

  // Method to call the correct authentication based on the tab
  Future<void> handlePrimaryAction() async {
    // Block sign up until the user agrees to the privacy policy and terms of service
    if (!isLoginMode && !agreedToTerms) {
      setState(() {
        notifyingMessage =
            "Please agree to the Privacy Policy and Terms of Service to continue.";
      });
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
      String successMessage;
      if (isLoginMode) {
        successMessage = "Login successful";
      } else {
        successMessage = "Registration successful";
      }
      setState(() {
        notifyingMessage = successMessage;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // invalid-credential also covers accounts originally made with Google sign in
      if (e.code == 'invalid-credential') {
        setState(() {
          notifyingMessage =
              "Invalid email or password. If your account used 'Continue with Google', use Forgot Password once and set a password to enable email login.";
        });
      } else {
        // Build a generic error for any other Firebase error
        String mode;
        if (isLoginMode) {
          mode = "Login";
        } else {
          mode = "Registration";
        }
        setState(() {
          notifyingMessage = "$mode error: $e";
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Catch anything that is not a Firebase error
      String mode;
      if (isLoginMode) {
        mode = "Login";
      } else {
        mode = "Registration";
      }
      setState(() {
        notifyingMessage = "$mode error: $e";
      });
    } finally {
      // Clear the submitting state in the end
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // Method that builds the top section, the app logo and the welcome text
  Widget buildTopSection() {
    return Column(
      children: [
        // App logo
        SizedBox(
          height: Responsive.buttonHeight(context, 200),
          child: Image.asset(
            "assets/app_logo_transparent_bg.png",
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: Responsive.padding(context, 14)),
        // Title
        Text(
          "Level Up!",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: Responsive.font(context, 38),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: Responsive.padding(context, 10)),
        Text(
          "Track your habits. Improve yourself. Level Up!",
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: Colors.white38,
            fontSize: Responsive.font(context, 14),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // Method that builds the eye icon used to show or hide the password
  Widget buildPasswordVisibilityToggle() {
    IconData icon;
    if (hidePassword) {
      icon = Icons.visibility_off;
    } else {
      icon = Icons.visibility;
    }
    return IconButton(
      icon: Icon(icon, color: Colors.white54),
      onPressed: () {
        setState(() {
          hidePassword = !hidePassword;
        });
      },
    );
  }

  // Method that shows the terms checkbox only in sign up mode, wrapped in AnimatedSize
  Widget buildTermsCheckboxArea() {
    // Checkbox only makes sense while signing up
    Widget child;
    if (!isLoginMode) {
      child = Padding(
        padding: EdgeInsets.only(top: Responsive.padding(context, 14)),
        child: buildTermsCheckbox(),
      );
    } else {
      child = const SizedBox(width: double.infinity);
    }
    // AnimatedSize smooths the layout jump when switching modes so the checkbox slides in instead of popping
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }

  // Method that sends a password reset email based on the current email field
  Future<void> handleForgotPassword() async {
    // Need an email to send the reset link to
    if (emailController.text.isEmpty) {
      setState(() {
        notifyingMessage =
            "Enter your email in the email field above to reset your password.";
      });
      return;
    }
    try {
      await authService.value.resetPassword(email: emailController.text.trim());
      setState(() {
        notifyingMessage =
            "Success: Password reset email sent to ${emailController.text.trim()}.";
      });
    } catch (e) {
      setState(() {
        notifyingMessage = "Error: $e";
      });
    }
  }

  // Method that shows the forgot password link, only visible in log in mode
  Widget buildForgotPasswordArea() {
    // Forgot password button, only shown in log in mode
    Widget child;
    if (isLoginMode) {
      child = Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: handleForgotPassword,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D86)),
          child: Text(
            "Forgot Password?",
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    } else {
      child = const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }

  // Method that builds the middle section with the tab toggle, fields, primary button, and forgot password
  Widget buildMiddleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildAuthModeToggle(),
        SizedBox(height: Responsive.padding(context, 20)),
        // Email field
        buildAuthField(
          controller: emailController,
          label: "Email",
          icon: Icons.mail_outline,
        ),
        SizedBox(height: Responsive.padding(context, 12)),
        // Password field, the suffix toggles between hidden and visible text
        buildAuthField(
          controller: passwordController,
          label: "Password",
          icon: Icons.lock_outline,
          obscure: hidePassword,
          suffix: buildPasswordVisibilityToggle(),
        ),
        buildTermsCheckboxArea(),
        SizedBox(height: Responsive.padding(context, 16)),
        // Primary button and label switches with the active tab
        buildPrimaryButton(),
        SizedBox(height: Responsive.padding(context, 4)),
        buildForgotPasswordArea(),
        SizedBox(height: Responsive.padding(context, 20)),
        buildSocialDivider(),
        SizedBox(height: Responsive.padding(context, 16)),
        Center(
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildGoogleButton(),
                SizedBox(height: Responsive.padding(context, 16)),
                OutlinedButton.icon(
                  onPressed: _handleContinueAsGuest,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white54,
                      width: Responsive.scale(context, 1.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 14),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 17),
                      horizontal: Responsive.width(context, 20),
                    ),
                  ),
                  icon: Icon(
                    HugeIcons.strokeRoundedAnonymous,
                    color: Colors.white70,
                    size: Responsive.scale(context, 22),
                  ),
                  label: Text(
                    "Continue as a guest",
                    style: GoogleFonts.manrope(
                      color: Colors.white70,
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Method that builds the 'or continue with' divider row that separates email auth from social auth
  Widget buildSocialDivider() {
    // Divider section with a centered label that separates email auth from social auth
    final leftLine = Expanded(
      child: Container(
        margin: EdgeInsets.only(right: Responsive.padding(context, 12)),
        height: Responsive.scale(context, 1),
        color: Colors.white24,
      ),
    );
    final rightLine = Expanded(
      child: Container(
        margin: EdgeInsets.only(left: Responsive.padding(context, 12)),
        height: Responsive.scale(context, 1),
        color: Colors.white24,
      ),
    );
    return Row(
      children: [
        leftLine,
        Text(
          "or continue with",
          style: GoogleFonts.manrope(
            color: Colors.white54,
            fontSize: Responsive.font(context, 13),
            fontWeight: FontWeight.w500,
          ),
        ),
        rightLine,
      ],
    );
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
        // New user — switch to sign-up tab and show TOS dialog
        setState(() => isLoginMode = false);
        await showFrostedAlertDialog(
          context: context,
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
                  child: const Text("Got it"),
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

  // Method that builds the Google sign in button
  Widget buildGoogleButton() {
    return GestureDetector(
      onTap: handleGoogleSignIn,
      child: SvgPicture.asset(
        "assets/continue_with_google.svg",
        height: Responsive.buttonHeight(context, 60),
      ),
    );
  }

  // Method that builds the bottom section with the error message
  Widget buildBottomSection() {
    if (notifyingMessage == null) return const SizedBox.shrink();
    return Column(
      children: [
        Text(
          notifyingMessage!,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: Colors.redAccent.shade100,
            fontSize: Responsive.font(context, 13),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: Responsive.padding(context, 12)),
      ],
    );
  }

  void _handleContinueAsGuest() {
    Guest.enter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141318),
      // Stack layers the animated background behind the scrollable form content
      body: Stack(
        children: [
          // Builds the glow orbs
          Positioned.fill(child: buildAnimatedBackground()),
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Subtract safe area insets so minHeight matches the actual usable space inside SafeArea
                  // to prevent the Column trying to fill the whole screen height and potentially showing only half
                  // of "Continue with Google"
                  minHeight:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).top -
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 24),
                    vertical: Responsive.padding(context, 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: Responsive.padding(context, 4)),
                      // Top section fades in first
                      buildTopSection()
                          .animate()
                          .fadeIn(delay: 0.ms, duration: 500.ms)
                          .slideY(
                            begin: 0.15,
                            duration: 500.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      SizedBox(height: Responsive.padding(context, 20)),
                      // Middle section fades in shortly after the top
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: buildMiddleSection()
                              .animate()
                              .fadeIn(delay: 180.ms, duration: 500.ms)
                              .slideY(
                                begin: 0.15,
                                duration: 500.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ),
                      ),
                      SizedBox(height: Responsive.padding(context, 20)),
                      // Bottom section fades in last
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: buildBottomSection()
                              .animate()
                              .fadeIn(delay: 360.ms, duration: 500.ms)
                              .slideY(
                                begin: 0.15,
                                duration: 500.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ),
                      ),
                      SizedBox(height: Responsive.padding(context, 24)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
