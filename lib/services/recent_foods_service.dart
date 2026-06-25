import '../utility/shared_preferences/shared_prefs_async.dart';

class RecentFoodsService {
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
}
