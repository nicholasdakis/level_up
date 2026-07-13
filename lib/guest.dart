import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'globals.dart';
import 'models/user_data.dart';
import 'providers/user_data_provider.dart';
import 'services/user_data_manager.dart' show defaultAppColor;
import 'utility/responsive.dart';

class _ShimmerSignUp extends StatelessWidget {
  const _ShimmerSignUp();

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      accent: lightenColor(defaultAppColor, 0.45),
      child: Text(
        'Sign Up',
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: Responsive.font(context, 14),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class Guest {
  // Blank user data used while browsing as a guest so the app has something to render
  static UserData get defaultUserData => UserData(
    uid: 'guest',
    pfpBase64: null,
    level: 1,
    expPoints: 0,
    canClaimDailyReward: true,
    notificationsEnabled: false,
    lastDailyClaim: null,
    username: 'Guest',
    appColor: defaultAppColor,
    fcmTokens: [],
  );

  // Called when the user taps "Continue as Guest", sets the flag and triggers the router to navigate past the login screen
  static void enter(WidgetRef ref) {
    isGuest = true;
    appInitialized = true;
    ref.read(userDataProvider.notifier).setUserData(Guest.defaultUserData);
    guestNotifier.value = true;
    appReadyNotifier.setReady();
  }

  // Called on sign out or when the guest taps "Sign Up" in the block dialog, clears all guest state and sends the router back to login
  static void exit() {
    isGuest = false;
    appInitialized = false;
    appReadyNotifier.reset();
    guestNotifier.value = false;
  }

  // Call from initState on screens that guests should not access, shows the block dialog as soon as the screen opens
  static void blockOnOpen(
    BuildContext context, {
    String title = 'Sign up to do this',
    String description = "Create a free account to use this feature.",
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        block(context, title: title, description: description);
      }
    });
  }

  // Shows a dialog telling the guest they need an account to use this feature
  // "Maybe Later" dismisses it, "Sign Up" calls exit() which redirects to the login screen
  static void block(
    BuildContext context, {
    String title = 'Sign up to do this',
    String description = "Create a free account to use this feature.",
  }) {
    showFrostedAlertDialog(
      context: context,
      appColor: defaultAppColor,
      title: title,
      content: Text(
        description,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 14),
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text("Maybe Later", style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            exit();
          },
          child: const _ShimmerSignUp(),
        ),
      ],
    );
  }
}
