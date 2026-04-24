import '../utility/shared_preferences/shared_prefs_async.dart';

class RecentFoodsService {
  // Maximum number of recent foods to store
  static const int _maxRecent = 30;

  // Centralized cache wrapper for SharedPreferences
  final SharedPrefsService _prefs = SharedPrefsService();

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

    if (recents.length > _maxRecent) {
      recents.removeRange(_maxRecent, recents.length);
    } // if list exceeds the max size, remove the oldest entries from the end

    await _prefs.setJsonList(SharedPreferencesKey.recentFoods, recents);
    // save the updated list back to SharedPreferences as a JSON string
  }
}
