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

  // Getter for the screen to read the live leaderboard data (for online use)
  Stream<List<LeaderboardEntry>> getLeaderboardStream() {
    return FirebaseFirestore.instance
        .collection('users-public')
        .orderBy('level', descending: true)
        .orderBy('expPoints', descending: true)
        .snapshots()
        .map((snapshot) {
          // Map Firestore documents to LeaderboardEntry objects
          return snapshot.docs.map((doc) {
            return LeaderboardEntry.fromFirestore(doc);
          }).toList();
        });
  }
}
