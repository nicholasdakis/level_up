import 'dart:async';
import 'dart:js_interop';

// Binds to the getWebFcmToken() JS function defined in index.html
@JS('getWebFcmToken')
external JSPromise<JSString?> _getWebFcmToken(JSString vapidKey);

// Binds to the showJsNotification() JS function defined in index.html
@JS('showJsNotification')
external void _showJsNotification(JSString title, JSString body);

// Calls getToken() via JS interop, passing the service worker registration
// so Firebase can locate the SW on subdirectory web deployments
Future<String?> getWebFcmToken(String vapidKey) async {
  try {
    final result = await _getWebFcmToken(vapidKey.toJS).toDart;
    return result?.toDart;
  } catch (e) {
    return null;
  }
}

// Shows a browser notification via the Notification API (foreground only)
void showJsNotification(String title, String body) {
  _showJsNotification(title.toJS, body.toJS);
}
