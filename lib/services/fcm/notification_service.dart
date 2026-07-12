import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../../globals.dart';
import '../../providers/user_data_provider.dart';
import '../../utility/responsive.dart';
import 'notification_service_stub.dart'
    if (dart.library.js_interop) 'notification_service_web.dart'
    as platform;

// Re-export platform functions so callers don't need to know the split
Future<String?> requestNotificationAndToken() =>
    platform.requestNotificationAndToken();

Future<String?> getWebFcmTokenSafe(String vapidKey) =>
    platform.getWebFcmTokenSafe(vapidKey);

// notDetermined: shows the OS permission prompt, saves the token if granted
// denied + skipIfDenied=true: returns false silently (respects user choice)
// denied + skipIfDenied=false: shows "Notifications Blocked" dialog with Open Settings
// authorized: returns true immediately, nothing to do
Future<bool> requestNotificationPermissionIfNeeded(
  BuildContext context,
  UserDataNotifierNew notifier, {
  required Color appColor,
  String message = '',
  String title = 'Notifications Disabled in Settings',
  bool skipIfDenied = false,
}) async {
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
      if (token != null) await notifier.initializeFcmToken(token);
      return true;
    }
    return false;
  } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
    if (skipIfDenied) return false; // respect the user's choice, don't nag
    if (context.mounted) {
      showFrostedAlertDialog(
        context: context,
        appColor: appColor,
        title: title,
        content: Text(
          message,
          style: TextStyle(
            fontSize: Responsive.font(context, 14),
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Dismiss", style: dialogButtonStyle()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              const AndroidIntent(
                action: 'android.settings.APP_NOTIFICATION_SETTINGS',
                flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
                arguments: {
                  'android.provider.extra.APP_PACKAGE':
                      'com.nicholasdakis.levelup',
                },
              ).launch();
            },
            child: Text(
              "Open Settings",
              style: dialogButtonStyle(confirm: true),
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
void showBrowserBlockedDialog(
  BuildContext context,
  UserDataNotifierNew notifier, {
  required Color appColor,
}) {
  showFrostedDialog(
    context: context,
    appColor: appColor,
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
                child: Text('Cancel', style: dialogButtonStyle()),
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
                      await notifier.initializeFcmToken(token);
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
                child: Text('Enable', style: dialogButtonStyle(confirm: true)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
