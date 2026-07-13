import '../services/user_data_manager.dart' show authenticatedPost;

class RecentFoodsService {
  // Sentinel value meaning no limit on recent foods
  static const int unlimited = 0;

  // Saves the user's recent foods max preference to the backend, pass 0 for unlimited (premium only)
  Future<bool> setRecentFoodsMax(int max) async {
    final response = await authenticatedPost(
      'update_recent_foods_max',
      body: {'max': max},
    );
    return response.statusCode == 200;
  }
}
