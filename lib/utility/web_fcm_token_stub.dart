// Stub for non-web platforms where JS interop is not available (just so the code can compile)
Future<String?> getWebFcmToken(String vapidKey) async => null;
void showJsNotification(String title, String body) {}
