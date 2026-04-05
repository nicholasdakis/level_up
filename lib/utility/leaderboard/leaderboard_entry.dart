import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Factory constructor parses the Firestore document into a LeaderboardEntry by extracting and
  // converting its fields, then passing them to the main constructor
  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      uid: doc.id,
      username: data['username'],
      level: data['level'] ?? 1,
      expPoints: data['expPoints'] ?? 0,
      pfpBytes: data['pfpBase64'] != null
          ? base64Decode(data['pfpBase64'])
          : null, // pfp decodes once on initialization
    );
  }
}
