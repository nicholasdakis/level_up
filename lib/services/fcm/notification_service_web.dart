import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import '../user_data_manager.dart';

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
    return await getWebFcmTokenSafe(fcmVapidKey);
  } catch (e) {
    if (kDebugMode) debugPrint('Notification permission/token error: $e');
    return null;
  }
}
