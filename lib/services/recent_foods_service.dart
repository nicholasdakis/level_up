import '../utility/shared_preferences/shared_prefs_async.dart';

class RecentFoodsService {
  // Default max if the user hasn't set a preference
  static const int _defaultMax = 30;
  // Sentinel value meaning no limit on recent foods
  static const int unlimited = 0;

  // Centralized cache wrapper for SharedPreferences
  final SharedPrefsService _prefs = SharedPrefsService();

  // Returns the user's configured recent foods max, 0 means unlimited, null means not set (use default)
  Future<int?> getRecentFoodsMax() async {
    return await _prefs.getInt(SharedPreferencesKey.recentFoodsMax);
  }

  // Saves the user's recent foods max preference, pass 0 for unlimited
  Future<void> setRecentFoodsMax(int max) async {
    await _prefs.setInt(SharedPreferencesKey.recentFoodsMax, max);
  }

  // Load the recent foods from local storage as a list of maps that represents each food
  Future<List<Map<String, dynamic>>> getRecentFoods() async {
    // Call the service method that gets the json list, converts it to Dart, and then maps it to a List<Map<String, dynamic>>
    return await _prefs.getJsonList(SharedPreferencesKey.recentFoods);
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

    // Respect user's max setting, 0 means unlimited so no trimming, null means use default
    final stored = await getRecentFoodsMax();
    final max = stored ?? _defaultMax;
    if (max != unlimited && recents.length > max) {
      recents.removeRange(max, recents.length);
    } // if list exceeds the max size, remove the oldest entries from the end

    await _prefs.setJsonList(SharedPreferencesKey.recentFoods, recents);
    // save the updated list back to SharedPreferences as a JSON string
  }

  // Remove a single food from the recent foods list by name
  Future<void> removeRecentFood(String foodName) async {
    final recents = await getRecentFoods(); // fetch the current list
    recents.removeWhere(
      (f) => f['food_name'] == foodName,
    ); // remove the matching entry
    await _prefs.setJsonList(
      SharedPreferencesKey.recentFoods,
      recents,
    ); // save the updated list back
  }
}
