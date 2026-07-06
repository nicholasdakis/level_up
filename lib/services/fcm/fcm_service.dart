import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../firebase_options.dart';
import '../../globals.dart' hide UserDataNotifier;
import '../../providers/user_data_provider.dart';
import '../user_data_manager.dart' show fcmVapidKey;

// Conditional imports to handle the web interop correctly across platforms
import 'web_fcm_token_stub.dart'
    if (dart.library.js_interop) 'web_fcm_token_web.dart'
    as web_fcm;

// Handles FCM messages received while the app is in the background or terminated
// Re-initializes Firebase since background isolates don't share state with the main app
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only initialize if not already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class FcmService {
  // Initializes FCM, saves the device token, and sets up message listeners
  static Future<void> initialize(
    BuildContext context,
    UserDataNotifier notifier,
  ) async {
    // Background message handler must be registered before any other FCM events
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // iOS only — skip on web to avoid triggering an automatic permission request
    if (!kIsWeb) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Get the device's FCM token and save it to Firestore
    // Timeout prevents hanging if the browser blocks the permission dialog
    String? deviceToken;

    if (kIsWeb) {
      // On web, use JS interop to pass the service worker registration to getToken()
      // Flutter's plugin can't find the SW on subdirectory deployments (e.g. GitHub Pages at /level_up/)
      try {
        deviceToken = await web_fcm
            .getWebFcmToken(fcmVapidKey)
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

    if (kDebugMode) {
      debugPrint('FCM token: ${deviceToken != null ? "obtained" : "NULL"}');
    }

    if (deviceToken != null) {
      await notifier.initializeFcmToken(deviceToken);
    }

    // Update the token in Firestore if Firebase rotates it (e.g. after reinstall)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isNotEmpty) {
        // if Firebase rotates the token while the app is active, add the new one and remove the stale one
        await notifier.addFcmToken(newToken, oldToken: deviceToken);
        deviceToken = newToken;
      }
    });

    if (kIsWeb) {
      final observer = _FcmLifecycleObserver(notifier);
      WidgetsBinding.instance.addObserver(
        observer,
      ); // observer on Web so that it automatically calls refreshToken() on resuming the app
    }

    // Show a browser notification for foreground messages on web
    // (setForegroundNotificationPresentationOptions is iOS-only and does nothing on web)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kIsWeb) {
        final title = message.notification?.title ?? 'Level Up! Reminder';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        web_fcm.showJsNotification(title, body);
      }
    });
  }

  // Re-fetches the FCM token and updates Firestore if it changed
  // Called when the web tab regains visibility after being suspended
  static Future<void> refreshToken(UserDataNotifier notifier) async {
    String? deviceToken;
    try {
      deviceToken = await web_fcm
          .getWebFcmToken(fcmVapidKey)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (e) {
      deviceToken = null;
    }

    if (deviceToken != null &&
        (currentUserData == null ||
            !currentUserData!.fcmTokens.contains(deviceToken))) {
      await notifier.addFcmToken(deviceToken);
    }
  }
}

// Watches for app resume events on web and re-fetches the FCM token
class _FcmLifecycleObserver extends WidgetsBindingObserver {
  final UserDataNotifier notifier;
  _FcmLifecycleObserver(this.notifier);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FcmService.refreshToken(notifier);
    }
  }
}
