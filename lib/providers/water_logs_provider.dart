import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart' show isGuest;
import '../guest.dart';
import '../services/user_data_manager.dart'
    show authenticatedGet, authenticatedPost;

class WaterLogsNotifier extends AsyncNotifier<Map<String, List<int>>> {
  @override
  Future<Map<String, List<int>>> build() async {
    if (isGuest) {
      final today = DateTime.now();
      final key =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      return Guest.fakeWaterLogs(key);
    }
    final response = await authenticatedGet('water_logs');
    if (response.statusCode != 200) return {};
    return _parseWaterLogs(response.body);
  }

  // optimistically updates local state, rolls back on backend failure
  Future<bool> updateWaterLog(String dateKey, List<int> entriesMl) async {
    final previous = Map<String, List<int>>.from(state.value ?? {});
    state = AsyncData({...previous, dateKey: entriesMl});
    try {
      final response = await authenticatedPost(
        'upsert_water_log',
        body: {
          'date': dateKey,
          'entries_ml': entriesMl.map((ml) => {'amount_ml': ml}).toList(),
        },
      );
      if (response.statusCode == 200) return true;
      state = AsyncData(previous);
      return false;
    } catch (e) {
      state = AsyncData(previous);
      return false;
    }
  }
}

final waterLogsProvider =
    AsyncNotifierProvider<WaterLogsNotifier, Map<String, List<int>>>(
      WaterLogsNotifier.new,
    );

Map<String, List<int>> _parseWaterLogs(String body) {
  try {
    final decoded = jsonDecode(body);
    final List<dynamic> rows = decoded is List
        ? decoded
        : (decoded as Map<String, dynamic>)['water_logs'] as List<dynamic>;
    final Map<String, List<int>> result = {};
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final dateKey = map['date'] as String;
      final entries = (map['entries_ml'] as List<dynamic>?) ?? [];
      result[dateKey] = entries
          .map((e) => (e as Map<String, dynamic>)['amount_ml'] as int)
          .toList();
    }
    return result;
  } catch (_) {
    return {};
  }
}

final waterLogsAnalyticsProvider = FutureProvider<Map<String, List<int>>>((
  ref,
) async {
  final response = await authenticatedGet('water_logs_analytics');
  if (response.statusCode != 200) return {};
  return _parseWaterLogs(response.body);
});
