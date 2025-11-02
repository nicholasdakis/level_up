class ReminderData {
  final String message;
  final DateTime dateTime;
  final int notificationId;

  // Create a ReminderData instance with required fields
  ReminderData({
    required this.message,
    required this.dateTime,
    required this.notificationId,
  });

  // Convert this ReminderData object to a Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'dateTime': dateTime
          .toIso8601String(), // store as ISO string for compatibility
      'notificationId': notificationId,
    };
  }

  // Creates a ReminderData object from a Map retrieved from Firestore
  ReminderData.fromMap(Map<String, dynamic> map)
    : message = map['message'] ?? '',
      dateTime = DateTime.parse(
        map['dateTime'],
      ), // parse ISO string back to DateTime
      notificationId = map['notificationId'] ?? 0;
}
