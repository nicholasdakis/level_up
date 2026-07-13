import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart' show isGuest;
import '../services/user_data_manager.dart'
    show authenticatedGet, authenticatedPost;

class WeightLogsNotifier extends AsyncNotifier<Map<String, double>> {
  @override
  Future<Map<String, double>> build() async {
    if (isGuest) {
      final today = DateTime.now();
      final key =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      return {key: 78.4};
    }
    final response = await authenticatedGet('weight_logs');
    if (response.statusCode != 200) return {};
    return _parse(response.body);
  }

  // optimistically updates local state, rolls back on backend failure
  Future<bool> updateWeightLog(String dateKey, double weightKg) async {
    final previous = Map<String, double>.from(state.value ?? {});
    state = AsyncData({...previous, dateKey: weightKg});
    try {
      final response = await authenticatedPost(
        'upsert_weight_log',
        body: {'date': dateKey, 'weight_kg': weightKg},
      );
      if (response.statusCode == 200) return true;
      state = AsyncData(previous);
      return false;
    } catch (e) {
      state = AsyncData(previous);
      return false;
    }
  }

  // optimistically removes local state, rolls back on backend failure
  Future<bool> deleteWeightLog(String dateKey) async {
    final previous = Map<String, double>.from(state.value ?? {});
    final updated = Map<String, double>.from(previous)..remove(dateKey);
    state = AsyncData(updated);
    try {
      final response = await authenticatedPost(
        'delete_weight_log',
        body: {'date': dateKey},
      );
      if (response.statusCode == 200) return true;
      state = AsyncData(previous);
      return false;
    } catch (e) {
      state = AsyncData(previous);
      return false;
    }
  }

  Map<String, double> _parse(String body) {
    try {
      final decoded = jsonDecode(body);
      final List<dynamic> rows = decoded is List
          ? decoded
          : (decoded as Map<String, dynamic>)['weight_logs'] as List<dynamic>;
      final Map<String, double> result = {};
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final dateKey = map['date'] as String;
        final weightKg = (map['weight_kg'] as num).toDouble();
        result[dateKey] = weightKg;
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}

final weightLogsProvider =
    AsyncNotifierProvider<WeightLogsNotifier, Map<String, double>>(
      WeightLogsNotifier.new,
    );

Map<String, double> _parseWeightLogs(String body) {
  try {
    final decoded = jsonDecode(body);
    final List<dynamic> rows = decoded is List
        ? decoded
        : (decoded as Map<String, dynamic>)['weight_logs'] as List<dynamic>;
    final Map<String, double> result = {};
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final dateKey = map['date'] as String;
      final weightKg = (map['weight_kg'] as num).toDouble();
      result[dateKey] = weightKg;
    }
    return result;
  } catch (_) {
    return {};
  }
}

final weightLogsAnalyticsProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final response = await authenticatedGet('weight_logs_analytics');
  if (response.statusCode != 200) return {};
  return _parseWeightLogs(response.body);
});
