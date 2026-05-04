import 'package:flutter/material.dart';
import 'dart:js_interop';
import '../../globals.dart';
import '../../utility/responsive.dart';

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
  // Builder child gives the buttons a live dialog context so Navigator.of(ctx)
  // works even if the outer context (from AppShell) is later unmounted
  showFrostedDialog(
    context: context,
    child: Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          createTitle('Browser Notifications are Disabled', ctx),
          SizedBox(height: Responsive.height(ctx, 16)),
          Text(
            'In-app notifications are enabled, but your browser is blocking them.\n\n'
            'Click "Enable" to request notification permissions from your browser.',
            style: TextStyle(fontSize: Responsive.font(ctx, 15)),
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
                  style: TextStyle(fontSize: Responsive.font(ctx, 16)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final token = await requestNotificationAndToken();
                  if (token != null) {
                    await userManager.initializeFcmToken(token);
                    debugPrint('FCM token obtained after enable button');
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Browser is still blocking notifications.',
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  'Enable',
                  style: TextStyle(fontSize: Responsive.font(ctx, 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
