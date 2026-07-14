import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart' show isGuest;
import '../models/food_log.dart';
import '../services/user_data_manager.dart';

class FoodLogsNotifier extends AsyncNotifier<List<FoodLog>> {
  @override
  Future<List<FoodLog>> build() async {
    if (isGuest) return [];
    try {
      return await loadFromServer();
    } catch (_) {
      return [];
    }
  }

  // fetches the full food log list from the server and returns it
  Future<List<FoodLog>> loadFromServer() async {
    if (isGuest) return [];
    final response = await authenticatedGet('food_logs_v2');
    if (response.statusCode != 200) {
      throw Exception('food_logs_v2 fetch failed: ${response.body}');
    }
    final List data = jsonDecode(response.body)['food_logs_v2'];
    return data
        .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // re-fetches from the server and replaces local state
  Future<void> refresh() async {
    if (isGuest) return;
    try {
      state = AsyncData(await loadFromServer());
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to refresh food logs: $e');
    }
  }

  // upserts food items for a given date and patches local state with the backend response; returns false on failure
  Future<bool> upsertForDate(
    String date,
    Map<String, List<FoodLog>> mealMap,
  ) async {
    final items = <Map<String, dynamic>>[];
    for (final meal in ['breakfast', 'lunch', 'dinner', 'snacks']) {
      for (final food in (mealMap[meal] ?? [])) {
        items.add({...food.toJson(), 'meal': meal});
      }
    }
    // never send empty items for edit/move, the backend delete sweep would wipe every food log for this entire day
    // deletion now goes through deleteFoodLog directly so this path is only reached for edit and move
    if (items.isEmpty) return true;

    try {
      final response = await authenticatedPost(
        'upsert_food_log_v2',
        body: {'date': date, 'items': items},
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return false;

      final responseData = jsonDecode(response.body);
      final returnedItems = (responseData['items'] as List<dynamic>? ?? [])
          .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final current = List<FoodLog>.from(state.value ?? []);
      current.removeWhere((f) => f.date == date);
      current.addAll(returnedItems);
      state = AsyncData(current);
      return true;
    } catch (_) {
      return false;
    }
  }

  // deletes a single food log by id; removes from local state optimistically and calls backend
  Future<bool> deleteFoodLog(FoodLog log) async {
    final current = List<FoodLog>.from(state.value ?? []);
    state = AsyncData(current.where((f) => f.id != log.id).toList());
    if (log.id == null) {
      return true; // legacy food with no id, local-only removal
    }
    try {
      final response = await authenticatedPost(
        'delete_food_log',
        body: {'id': log.id},
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        state = AsyncData(current); // rollback
        return false;
      }
      return true;
    } catch (_) {
      state = AsyncData(current); // rollback
      return false;
    }
  }
}

final foodLogsProvider = AsyncNotifierProvider<FoodLogsNotifier, List<FoodLog>>(
  FoodLogsNotifier.new,
);

final foodLogsAnalyticsProvider = FutureProvider<List<FoodLog>>((ref) async {
  final response = await authenticatedGet('food_logs_analytics');
  if (response.statusCode != 200) {
    throw Exception('food_logs_analytics fetch failed: ${response.body}');
  }
  final List data = jsonDecode(response.body)['food_logs_v2'];
  return data
      .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});
