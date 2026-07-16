import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart' show isGuest;
import '../models/food_log.dart';
import '../services/user_data_manager.dart';

class FoodLogsNotifier extends AsyncNotifier<List<FoodLog>> {
  // cache of already-fetched dates so switching days doesn't re-fetch
  final Map<String, List<FoodLog>> _cache = {};

  @override
  Future<List<FoodLog>> build() async => [];

  bool isCached(String date) => _cache.containsKey(date);

  // fetches a single day from the server, caches the result, merges into state
  Future<void> loadDate(String date) async {
    if (isGuest) return;
    if (_cache.containsKey(date)) return;
    try {
      final response = await authenticatedGet('food_logs_for_date?date=$date');
      if (response.statusCode != 200) return;
      final List data = jsonDecode(response.body)['food_logs_v2'];
      final logs = data
          .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _cache[date] = logs;
      final current = List<FoodLog>.from(state.value ?? []);
      current.removeWhere((f) => f.date == date);
      current.addAll(logs);
      state = AsyncData(current);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load food logs for $date: $e');
    }
  }

  // re-fetches a specific date from the server, bypassing cache
  Future<void> refresh(String date) async {
    if (isGuest) return;
    try {
      final response = await authenticatedGet('food_logs_for_date?date=$date');
      if (response.statusCode != 200) return;
      final List data = jsonDecode(response.body)['food_logs_v2'];
      final logs = data
          .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _cache[date] = logs;
      final current = List<FoodLog>.from(state.value ?? []);
      current.removeWhere((f) => f.date == date);
      current.addAll(logs);
      state = AsyncData(current);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to refresh food logs for $date: $e');
    }
  }

  // upserts food items for a given date and patches local state with the backend response
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

      _cache[date] = returnedItems;
      final current = List<FoodLog>.from(state.value ?? []);
      current.removeWhere((f) => f.date == date);
      current.addAll(returnedItems);
      state = AsyncData(current);
      return true;
    } catch (_) {
      return false;
    }
  }

  // inserts a single new food log row
  Future<FoodLog?> addFoodLog(String date, FoodLog food) async {
    try {
      final response = await authenticatedPost(
        'add_food_log',
        body: {
          'date': date,
          'item': {...food.toJson(), 'meal': food.meal},
        },
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;
      final returned = FoodLog.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body)['item']),
      );
      final current = List<FoodLog>.from(state.value ?? []);
      current.add(returned);
      _cache[date] = current.where((f) => f.date == date).toList();
      state = AsyncData(current);
      return returned;
    } catch (_) {
      return null;
    }
  }

  // deletes a single food log by id; removes from local state optimistically and calls backend
  Future<bool> deleteFoodLog(FoodLog log) async {
    final current = List<FoodLog>.from(state.value ?? []);
    state = AsyncData(current.where((f) => f.id != log.id).toList());
    if (log.id == null) {
      return true;
    }
    try {
      final response = await authenticatedPost(
        'delete_food_log',
        body: {'id': log.id},
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        state = AsyncData(current);
        return false;
      }
      _cache[log.date] = (state.value ?? [])
          .where((f) => f.date == log.date)
          .toList();
      return true;
    } catch (_) {
      state = AsyncData(current);
      return false;
    }
  }

  // clears the cache and all state on sign out
  void clear() {
    _cache.clear();
    state = const AsyncData([]);
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
