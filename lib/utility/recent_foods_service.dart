import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentFoodsService {
  // Key used to store the recent foods list in SharedPreferences
  static const String _key = 'recent_foods';
  // Maximum number of recent foods to store
  static const int _maxRecent = 30;

  // SharedPreferencesAsync instance to access persistent local storage
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // Load the recent foods from local storage as a list of maps that represents each food
  Future<List<Map<String, dynamic>>> getRecentFoods() async {
    final raw = await _prefs.getString(
      _key,
    ); // retrieve JSON string from storage
    if (raw == null) return []; // if nothing stored yet, return empty list
    final List<dynamic> decoded = jsonDecode(
      raw,
    ); // decode JSON into a dynamic list
    return decoded.cast<Map<String, dynamic>>();
    // cast dynamic list to List<Map<String, dynamic>> for type safety
  }

  // Add a new food to the recent foods list
  // Keeps the list ordered with most recent at the front and avoids duplicates
  Future<void> addRecentFood(Map<String, dynamic> food) async {
    final recents = await getRecentFoods(); // fetch the current list

    recents.removeWhere(
      (f) => f['food_name'] == food['food_name'],
    ); // remove any existing entry with the same name to avoid duplicates

    recents.insert(
      0,
      Map<String, dynamic>.from(food),
    ); // insert the new food at the start so it shows as the most recent

    if (recents.length > _maxRecent) {
      recents.removeRange(_maxRecent, recents.length);
    } // if list exceeds the max size, remove the oldest entries from the end

    await _prefs.setString(_key, jsonEncode(recents));
    // save the updated list back to SharedPreferences as a JSON string
  }
}
