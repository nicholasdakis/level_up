import 'leaderboard_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  // Prefetches leaderboard on app start to populate Firestore's local cache (for offline compatibility)
  void prefetchLeaderboard() {
    FirebaseFirestore.instance
        .collection('users-public')
        .orderBy('level', descending: true)
        .orderBy('expPoints', descending: true)
        .get();
  }

  // Fetches the leaderboard data
  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users-public')
        .orderBy('level', descending: true)
        .orderBy('expPoints', descending: true)
        .get();
    // Map Firestore documents to LeaderboardEntry objects
    return snapshot.docs.map((doc) {
      return LeaderboardEntry.fromFirestore(doc);
    }).toList();
  }
}
