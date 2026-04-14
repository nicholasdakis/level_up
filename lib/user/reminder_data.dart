class ReminderData {
  final String id; // unique identifier for the reminder
  final String message; // the reminder text shown to the user
  final DateTime scheduledAt; // when the reminder is scheduled to fire
  final int notificationId; // local notification ID used to cancel/update it
  final bool claimed; // whether the user has already acted on this reminder

  ReminderData({
    required this.id,
    required this.message,
    required this.scheduledAt,
    required this.notificationId,
    required this.claimed,
  });

  factory ReminderData.fromJson(Map<String, dynamic> json) {
    return ReminderData(
      id: json['id'],
      message: json['message'],
      scheduledAt: DateTime.parse(
        json['scheduled_at'],
      ).toLocal(), // ISO string from backend, converted to local time
      notificationId: json['notification_id'],
      claimed: json['claimed'],
    );
  }
}
