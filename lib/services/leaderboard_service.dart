import 'dart:convert';
import '../models/leaderboard_entry.dart';
import 'user_data_manager.dart';
import '../globals.dart' show isGuest;

class LeaderboardService {
  // Fetches the leaderboard data from the backend
  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    if (isGuest) return [];
    final response = await authenticatedGet('leaderboard');

    if (response.statusCode != 200) {
      throw Exception(
        'fetchLeaderboard failed: ${response.statusCode} ${response.body}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body)['users'];
    // Map backend response to LeaderboardEntry objects
    return data
        .map((entry) => LeaderboardEntry.fromJson(entry))
        .where((entry) => entry.username != 'tester_account')
        .toList();
  }
}
