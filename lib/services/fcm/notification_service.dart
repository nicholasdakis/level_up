import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import 'notification_service_stub.dart'
    if (dart.library.js_interop) 'notification_service_web.dart'
    as platform;

// Re-export platform functions so callers don't need to know the split
Future<String?> requestNotificationAndToken() =>
    platform.requestNotificationAndToken();

Future<String?> getWebFcmTokenSafe(String vapidKey) =>
    platform.getWebFcmTokenSafe(vapidKey);

// Requests OS notification permission if not yet determined, or shows a dialog if denied
// Returns true if notifications are granted, false if denied.
Future<bool> requestNotificationPermissionIfNeeded(BuildContext context) async {
  if (kIsWeb) {
    return true; // web uses showBrowserBlockedDialog directly via a user gesture
  }

  final settings = await FirebaseMessaging.instance.getNotificationSettings();

  if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
    // First time asking, so show the OS permission dialog
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (result.authorizationStatus == AuthorizationStatus.authorized) {
      // Permission just granted, grab the token now since we skipped it at startup
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await userManager.initializeFcmToken(token);
      return true;
    }
    return false;
  } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
    // Already denied — can't re-prompt, tell the user to go to device settings
    if (context.mounted) {
      showFrostedAlertDialog(
        context: context,
        title: "Notifications Blocked",
        content: Text(
          "Enable notifications for Level Up! in your device settings to receive reminders.",
          style: TextStyle(fontSize: Responsive.font(context, 15)),
        ),
        actions: [
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Dismiss"),
              ),
            ),
          ),
        ],
      );
    }
    return false;
  }
  return true;
}

// Show a dialog telling the user their browser is blocking notifications
void showBrowserBlockedDialog(BuildContext context) {
  showFrostedDialog(
    context: context,
    child: Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Browser Notifications Disabled',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: Responsive.font(ctx, 17),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Responsive.height(ctx, 16)),
          Text(
            'In-app notifications are enabled, but your browser is blocking them.\n\n'
            'Click "Enable" to request notification permissions from your browser.',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: Responsive.font(ctx, 14),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Responsive.height(ctx, 24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(ctx, 15),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();

                  // Schedule the async work after the current Flutter frame completes
                  Future.microtask(() async {
                    // Request browser notification permission and FCM token (Web)
                    final token = await requestNotificationAndToken();

                    if (token != null) {
                      // Store/initialize token in backend so push notifications can work
                      await userManager.initializeFcmToken(token);
                    } else if (context.mounted) {
                      // If permission was denied or browser blocked it, inform the user
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Browser is still blocking notifications.',
                          ),
                        ),
                      );
                    }
                  });
                },
                child: Text(
                  'Enable',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(ctx, 15),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
