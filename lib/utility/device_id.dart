import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'shared_preferences/shared_prefs_async.dart';

// Returns a stable device ID for FCM token upsert keying
// Android uses androidId (survives reinstalls, resets on factory reset
// iOS and web generate a UUID on first run and persist it in SharedPreferences
Future<String> getDeviceId() async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.id.isNotEmpty) return info.id;
    } catch (_) {}
  }

  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(SharedPreferencesKey.deviceId);
  if (stored != null && stored.isNotEmpty) return stored;

  final generated = const Uuid().v4();
  await prefs.setString(SharedPreferencesKey.deviceId, generated);
  return generated;
}
