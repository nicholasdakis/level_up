import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';
import '../../globals.dart';

// Conditional imports to handle the web interop correctly across platforms
import 'web_fcm_token_stub.dart'
    if (dart.library.js_interop) 'web_fcm_token_web.dart'
    as web_fcm;

// Handles FCM messages received while the app is in the background or terminated
// Re-initializes Firebase since background isolates don't share state with the main app
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    'onBackgroundMessage: ${message.messageId} | ${message.data.toString()}',
  );
}

class FcmService {
  // Initializes FCM, saves the device token, and sets up message listeners
  static Future<void> initialize(BuildContext context) async {
    // Background message handler must be registered before any other FCM events
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // requestPermission hangs on web if the browser silently blocks the dialog, so skip it
    // getToken() handles permissions on web natively
    if (!kIsWeb) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Show notifications even when the app is in the foreground (iOS only)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Get the device's FCM token and save it to Firestore
    // Timeout prevents hanging if the browser blocks the permission dialog
    const vapidKey =
        "BHOUN3IilK1CAEVwa3wGYU-2Ne801epRrf881PxACR6ZD064wMMrMNH89OCxWm4ArfE7Mc4GJhiZOcd0nbsGPQ0";

    String? deviceToken;

    if (kIsWeb) {
      // On web, use JS interop to pass the service worker registration to getToken()
      // Flutter's plugin can't find the SW on subdirectory deployments (e.g. GitHub Pages at /level_up/)
      try {
        deviceToken = await web_fcm
            .getWebFcmToken(vapidKey)
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
      } catch (e) {
        deviceToken = null;
      }
    } else {
      // On mobile, just get the token normally
      deviceToken = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
    }

    debugPrint('FCM token: ${deviceToken != null ? "obtained" : "NULL"}');

    if (deviceToken != null) {
      await userManager.initializeFcmToken(deviceToken);
    } else if (currentUserData?.notificationsEnabled == true) {
      // Token is null with notifications enabled, browser is blocking them
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showBrowserBlockedDialog(context);
      });
    }

    // Update the token in Firestore if Firebase rotates it (e.g. after reinstall)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      // if Firebase rotates the token while the app is active, add the new one
      if (newToken.isNotEmpty) await userManager.addFcmToken(newToken);
    });

    if (kIsWeb) {
      final observer = _FcmLifecycleObserver();
      WidgetsBinding.instance.addObserver(
        observer,
      ); // observer on Web so that it automatically calls refreshToken() on resuming the app
    }

    // Show a browser notification for foreground messages on web
    // (setForegroundNotificationPresentationOptions is iOS-only and does nothing on web)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'onMessage: ${message.notification?.title} - ${message.notification?.body}',
      );
      if (kIsWeb) {
        final title = message.notification?.title ?? 'Level Up! Reminder';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        web_fcm.showJsNotification(title, body);
      }
    });
  }

  // Re-fetches the FCM token and updates Firestore if it changed
  // Called when the web tab regains visibility after being suspended
  static Future<void> refreshToken() async {
    const vapidKey =
        "BHOUN3IilK1CAEVwa3wGYU-2Ne801epRrf881PxACR6ZD064wMMrMNH89OCxWm4ArfE7Mc4GJhiZOcd0nbsGPQ0";

    String? deviceToken;
    try {
      deviceToken = await web_fcm
          .getWebFcmToken(vapidKey)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (e) {
      deviceToken = null;
    }

    debugPrint(
      'FCM token refresh: ${deviceToken != null ? "obtained" : "NULL"}',
    );

    if (deviceToken != null &&
        (currentUserData == null ||
            !currentUserData!.fcmTokens.contains(deviceToken))) {
      await userManager.addFcmToken(deviceToken);
    }
  }
}

// Watches for app resume events on web and re-fetches the FCM token
class _FcmLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FcmService.refreshToken();
    }
  }
}
