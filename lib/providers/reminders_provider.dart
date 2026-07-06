import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reminder_data.dart';
import '../services/user_data_manager.dart';

class RemindersNotifier extends AsyncNotifier<List<ReminderData>> {
  @override
  Future<List<ReminderData>> build() async {
    fetchReminders();
    return [];
  }

  // fetches all reminders from the server and replaces local state
  Future<void> fetchReminders() async {
    try {
      final response = await authenticatedGet('reminders');
      if (response.statusCode != 200) {
        throw Exception('getReminders failed: ${response.body}');
      }
      final List data = jsonDecode(response.body)['reminders'];
      state = AsyncData(data.map((r) => ReminderData.fromJson(r)).toList());
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to fetch reminders: $e');
    }
  }

  // posts a new reminder to the backend and refreshes the list; returns false on failure
  Future<bool> addReminder({
    required String message,
    required DateTime scheduledAt,
    required int notificationId,
  }) async {
    final response = await authenticatedPost(
      'set_reminder',
      body: {
        'message': message,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'notification_id': notificationId,
      },
    );
    if (response.statusCode != 200) return false;
    await fetchReminders();
    return true;
  }

  // deletes a reminder from the backend and removes it from local state; returns false on failure
  Future<bool> deleteReminder(ReminderData reminder) async {
    final response = await authenticatedPost(
      'delete_reminder',
      body: {'reminder_id': reminder.id},
    );
    if (response.statusCode != 200) return false;
    final current = state.value ?? [];
    state = AsyncData(current.where((r) => r.id != reminder.id).toList());
    return true;
  }
}

final remindersProvider =
    AsyncNotifierProvider<RemindersNotifier, List<ReminderData>>(
      RemindersNotifier.new,
    );
