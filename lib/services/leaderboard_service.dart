import 'dart:convert';
import '../models/leaderboard_entry.dart';
import 'user_data_manager.dart';
import '../globals.dart' show isGuest;

class LeaderboardService {
  final Map<String, List<LeaderboardEntry>> _cache = {};

  // Fetches the leaderboard data from the backend, returning a cached result if available
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    String type = 'xp',
    String period = 'all_time',
    bool forceRefresh = false,
  }) async {
    if (isGuest) return [];
    final key = '$type-$period';
    if (!forceRefresh && _cache.containsKey(key)) return _cache[key]!;

    final response = await authenticatedGet(
      'leaderboard?type=$type&period=$period',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'fetchLeaderboard failed: ${response.statusCode} ${response.body}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body)['users'];
    final entries = data
        .map((entry) => LeaderboardEntry.fromJson(entry))
        .where((entry) => entry.username != 'tester_account')
        .toList();

    _cache[key] = entries;
    return entries;
  }
}
