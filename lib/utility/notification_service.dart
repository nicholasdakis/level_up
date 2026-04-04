import 'package:flutter/material.dart';
import 'dart:js_interop';
import '../globals.dart';
import 'responsive.dart';

// JS interop to get the FCM token on web
@JS('getWebFcmToken')
external JSPromise<JSString?> _getWebFcmToken(String vapidKey);

@JS('Notification.requestPermission')
external JSPromise<JSString> _jsRequestPermission();

// Safely retrieve the web FCM token with error handling and null checks, returning a Dart String? instead of a JSString?
Future<String?> getWebFcmTokenSafe(String vapidKey) async {
  try {
    final JSString? jsToken = await _getWebFcmToken(vapidKey).toDart;
    return jsToken?.toDart; // JSString? -> String?
  } catch (e) {
    debugPrint('Error getting FCM token: $e');
    return null;
  }
}

// Request browser permission and get token
Future<String?> requestNotificationAndToken() async {
  try {
    final permission = (await _jsRequestPermission().toDart).toDart;
    if (permission != 'granted') return null;

    const vapidKey =
        "BHOUN3IilK1CAEVwa3wGYU-2Ne801epRrf881PxACR6ZD064wMMrMNH89OCxWm4ArfE7Mc4GJhiZOcd0nbsGPQ0";
    return await getWebFcmTokenSafe(vapidKey);
  } catch (e) {
    debugPrint('Notification permission/token error: $e');
    return null;
  }
}

// Show a dialog telling the user their browser is blocking notifications
void showBrowserBlockedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: appColorNotifier.value.withAlpha(150),
      title: Text(
        'Browser Notifications are Disabled',
        style: TextStyle(
          fontSize: Responsive.font(context, 20),
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        'In-app notifications are enabled, but your browser is blocking them.\n\n'
        'Click "Enable" to request notification permissions from your browser.',
        style: TextStyle(fontSize: Responsive.font(context, 15)),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(fontSize: Responsive.font(context, 16)),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop(); // close dialog first

            final token = await requestNotificationAndToken();
            if (token != null) {
              await userManager.initializeFcmToken(token);
              debugPrint('FCM token obtained after enable button');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Browser is still blocking notifications.'),
                ),
              );
            }
          },
          child: Text(
            'Enable',
            style: TextStyle(fontSize: Responsive.font(context, 16)),
          ),
        ),
      ],
    ),
  );
}
