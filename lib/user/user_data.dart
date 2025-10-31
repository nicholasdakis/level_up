class UserData {
  final String uid;
  String? pfpBase64;
  int level;
  int expPoints;
  String? username;
  bool canClaimDailyReward;
  DateTime? lastDailyClaim;

  // constructor
  UserData({
    required this.uid,
    this.pfpBase64,
    this.level = 1,
    this.expPoints = 0,
    this.canClaimDailyReward = true,
    this.lastDailyClaim,
    String? username,
  }) : username = username ?? uid; // Default username is the UID
}
