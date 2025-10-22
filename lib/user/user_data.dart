class UserData {
  final String uid;
  String? pfpBase64;
  int level;
  int expPoints;

  // constructor
  UserData({
    required this.uid,
    this.pfpBase64,
    this.level = 1,
    this.expPoints = 0,
  });
}
