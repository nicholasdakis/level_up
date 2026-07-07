import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_data_manager.dart'
    show authenticatedGet, authenticatedPost;

class WaterLogsNotifier extends AsyncNotifier<Map<String, List<int>>> {
  @override
  Future<Map<String, List<int>>> build() async => {};

  // loads all water logs from the backend
  Future<void> load() async {
    final response = await authenticatedGet('water_logs');
    if (response.statusCode != 200) return;
    state = AsyncData(_parse(response.body));
  }

  // optimistically updates local state, rolls back on backend failure
  Future<bool> updateWaterLog(String dateKey, List<int> entriesMl) async {
    final previous = Map<String, List<int>>.from(state.value ?? {});
    state = AsyncData({...previous, dateKey: entriesMl});
    try {
      await authenticatedPost(
        'upsert_water_log',
        body: {
          'date': dateKey,
          'entries_ml': entriesMl.map((ml) => {'amount_ml': ml}).toList(),
        },
      );
      return true;
    } catch (e) {
      state = AsyncData(previous);
      return false;
    }
  }

  Map<String, List<int>> _parse(String body) {
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
}

final waterLogsProvider =
    AsyncNotifierProvider<WaterLogsNotifier, Map<String, List<int>>>(
      WaterLogsNotifier.new,
    );
