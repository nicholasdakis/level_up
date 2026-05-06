import 'dart:async';
import 'dart:js_interop';

// Binds to the getWebFcmToken() JS function defined in index.html
@JS('getWebFcmToken')
external JSPromise<JSString?> _getWebFcmToken(JSString vapidKey);

// Reads Notification.permission without triggering a permission request
@JS('Notification.permission')
external String get _notificationPermission;

// Binds to the showJsNotification() JS function defined in index.html
@JS('showJsNotification')
external void _showJsNotification(JSString title, JSString body);

// Calls getToken() via JS interop, passing the service worker registration
// so Firebase can locate the SW on subdirectory web deployments.
// Only proceeds if the browser has already granted notification permission —
// calling getToken() without permission triggers an automatic request that Chrome blocks.
Future<String?> getWebFcmToken(String vapidKey) async {
  if (_notificationPermission != 'granted') return null;
  try {
    final result = await _getWebFcmToken(vapidKey.toJS).toDart;
    return result?.toDart;
  } catch (e) {
    return null;
  }
}

// Returns the browser's current notification permission: 'granted', 'denied', or 'default'
String getNotificationPermission() => _notificationPermission;

// Shows a browser notification via the Notification API (foreground only)
void showJsNotification(String title, String body) {
  _showJsNotification(title.toJS, body.toJS);
}
