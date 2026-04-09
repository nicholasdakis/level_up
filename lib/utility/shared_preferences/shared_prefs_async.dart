import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// All SharedPreferences keys used across the app
class SharedPreferencesKey {
  // Calorie Calculator keys
  static const String calorieCalculatorData = 'calorie_calculator_data';

  // RecentFoodsService keys
  static const String recentFoods = 'recent_foods';

  // POIService keys
  static const String cachedPois = 'cached_pois';
  static const String cachedPoiLat = 'cached_poi_lat';
  static const String cachedPoiLng = 'cached_poi_lng';
  static const String visitedPois = 'cached_visited_pois';
}

// Wrapper around SharedPreferencesAsync that provides commonly needed typed helper methods
class SharedPrefsService {
  // This instance holds its own _prefs object, but all instances read/write to the same device storage
  final SharedPreferencesAsync _prefs =
      SharedPreferencesAsync(); // SharedPreferencesAsync is the package's class

  // Read a JSON-encoded list from storage
  // Returns an empty list if nothing is stored at the key
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    // Try to read the raw JSON string stored at this key
    final raw = await _prefs.getString(key);
    // If nothing was stored, return an empty list as a safe default
    if (raw == null) return [];
    // Parse the JSON string back into a Dart list of dynamic objects
    final List<dynamic> decoded = jsonDecode(raw);
    // Cast each element to Map<String, dynamic> so the caller gets a typed list
    return decoded.cast<Map<String, dynamic>>();
  }

  // Write a list of maps to storage as a JSON string
  Future<void> setJsonList(String key, List<Map<String, dynamic>> list) async {
    // Encode the list to a JSON string and save it under the given key
    await _prefs.setString(key, jsonEncode(list));
  }

  // Read a JSON-encoded map from storage
  // Returns an empty map if nothing is stored at the key
  Future<Map<String, dynamic>> getJsonMap(String key) async {
    // Try to read the raw JSON string stored at this key
    final raw = await _prefs.getString(key);
    // If nothing was stored, return an empty map as a safe default
    if (raw == null) return {};
    // Parse the JSON string and cast it to a typed map
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // Write a map to storage as a JSON string
  Future<void> setJsonMap(String key, Map<String, dynamic> map) async {
    // Encode the map to a JSON string and save it under the given key
    await _prefs.setString(key, jsonEncode(map));
  }

  // Read a raw JSON string from storage (for cases that need custom decoding)
  Future<String?> getString(String key) async {
    // Return the string stored at this key, or null if nothing exists
    return await _prefs.getString(key);
  }

  // Write a raw JSON string to storage
  Future<void> setString(String key, String value) async {
    // Save the string value directly under the given key
    await _prefs.setString(key, value);
  }

  // Read a double from storage
  Future<double?> getDouble(String key) async {
    // Return the double stored at this key, or null if nothing exists
    return await _prefs.getDouble(key);
  }

  // Write a double to storage
  Future<void> setDouble(String key, double value) async {
    // Save the double value directly under the given key
    await _prefs.setDouble(key, value);
  }
}
