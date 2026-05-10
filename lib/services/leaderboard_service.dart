import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/leaderboard_entry.dart';
import 'user_data_manager.dart';
import '../globals.dart' show isGuest;

class LeaderboardService {
  // Fetches the leaderboard data from the backend
  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    if (isGuest) return [];
    final token = await getIdToken();
    final response = await http
        .post(
          Uri.parse('$backendBaseUrl/get_leaderboard'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': token}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'fetchLeaderboard failed: ${response.statusCode} ${response.body}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body)['users'];
    // Map backend response to LeaderboardEntry objects
    return data.map((entry) => LeaderboardEntry.fromJson(entry)).toList();
  }
}
