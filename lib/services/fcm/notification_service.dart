import 'package:flutter/material.dart';
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

// Show a dialog telling the user their browser is blocking notifications
void showBrowserBlockedDialog(BuildContext context) {
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
