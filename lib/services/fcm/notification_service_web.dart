import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('getWebFcmToken')
external JSPromise<JSString?> _getWebFcmToken(String vapidKey);

@JS('Notification.requestPermission')
external JSPromise<JSString> _jsRequestPermission();

Future<String?> getWebFcmTokenSafe(String vapidKey) async {
  try {
    final JSString? jsToken = await _getWebFcmToken(vapidKey).toDart;
    return jsToken?.toDart;
  } catch (e) {
    if (kDebugMode) debugPrint('Error getting FCM token: $e');
    return null;
  }
}

Future<String?> requestNotificationAndToken() async {
  try {
    // Timeout guards against Chrome silently hanging the Promise when notifications are auto-blocked
    final jsPermission = await _jsRequestPermission().toDart.timeout(
      const Duration(seconds: 8),
      onTimeout: () => ''.toJS,
    );
    final permission = jsPermission.toDart;
    if (permission != 'granted') return null;
    const vapidKey =
        "BHOUN3IilK1CAEVwa3wGYU-2Ne801epRrf881PxACR6ZD064wMMrMNH89OCxWm4ArfE7Mc4GJhiZOcd0nbsGPQ0";
    return await getWebFcmTokenSafe(vapidKey);
  } catch (e) {
    if (kDebugMode) debugPrint('Notification permission/token error: $e');
    return null;
  }
}
