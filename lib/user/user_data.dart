import 'package:flutter/material.dart';
import 'reminder_data.dart';

class UserData {
  final String uid;
  String? pfpBase64;
  int level;
  int expPoints;
  bool canClaimDailyReward;
  DateTime? lastDailyClaim;
  List<ReminderData> reminders;
  String? username;
  Color appColor;

  // constructor
  UserData({
    required this.uid,
    this.pfpBase64,
    this.level = 1,
    this.expPoints = 0,
    this.canClaimDailyReward = true,
    this.lastDailyClaim,
    this.appColor = Colors.blue, // default app color is blue
    String? username,
    this.reminders = const [],
  }) : username = username ?? uid; // Default username is the UID
}
