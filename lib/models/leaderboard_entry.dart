import 'dart:convert';
import 'dart:typed_data';

class LeaderboardEntry {
  final String uid;
  final String? username;
  final int level;
  final int expPoints;
  final Uint8List? pfpBytes;

  LeaderboardEntry({
    required this.uid,
    this.username,
    required this.level,
    required this.expPoints,
    this.pfpBytes,
  });

  // Factory constructor parses the backend response into a LeaderboardEntry by extracting and
  // converting its fields, then passing them to the main constructor
  factory LeaderboardEntry.fromJson(Map<String, dynamic> data) {
    return LeaderboardEntry(
      uid: data['uid'],
      username: data['username'],
      level: data['level'] ?? 1,
      expPoints: data['exp_points'] ?? 0,
      pfpBytes: data['pfp_base64'] != null
          ? base64Decode(data['pfp_base64'])
          : null, // pfp decodes once on initialization
    );
  }
}
