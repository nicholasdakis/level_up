Future<String?> getWebFcmToken(
  String vapidKey,
) async => // stub implementation for non-web platforms
    throw UnsupportedError('Web FCM token only available on web');
void showJsNotification(String title, String body) =>
    throw UnsupportedError('JS notifications only available on web');
