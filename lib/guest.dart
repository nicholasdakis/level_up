import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'globals.dart';
import 'models/user_data.dart';
import 'services/user_data_manager.dart' show defaultAppColor;
import 'utility/responsive.dart';

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
    reminders: [],
    appColor: defaultAppColor,
    foodDataByDate: {},
    fcmTokens: [],
  );

  // Called when the user taps "Continue as Guest",sets the flag and triggers the router to navigate past the login screen
  static void enter() {
    isGuest = true;
    guestNotifier.value = true;
  }

  // Called on sign out or when the guest taps "Sign Up" in the block dialog,clears all guest state and sends the router back to login
  static void exit() {
    isGuest = false;
    userDataNotifier.value = null;
    appInitialized = false;
    guestNotifier.value = false;
  }

  // Call from initState on screens that guests should not access,shows the block dialog as soon as the screen opens
  static void blockOnOpen(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) block(context);
    });
  }

  // Shows a dialog telling the guest they need an account to use this feature
  // "Maybe Later" dismisses it, "Sign Up" calls exit() which redirects to the login screen
  static void block(BuildContext context) {
    showFrostedAlertDialog(
      context: context,
      title: "Sign up to do this",
      content: Text(
        "You're browsing as a guest. Create a free account to use this feature.",
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 14),
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(
            "Maybe Later",
            style: GoogleFonts.manrope(color: Colors.white38),
          ),
        ),
        simpleCustomButton(
          "Sign Up",
          14,
          44,
          110,
          context,
          baseColor: defaultAppColor,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            exit();
          },
        ),
      ],
    );
  }
}
